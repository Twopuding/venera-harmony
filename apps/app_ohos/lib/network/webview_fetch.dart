import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/webview.dart';

import 'cookie_jar.dart';

/// Result of a request performed through the in-app WebView.
class WebviewFetchResult {
  final int? status;

  final Map<String, String> headers;

  final Uint8List? bodyBytes;

  /// True when the body looks like a Cloudflare challenge page instead of the
  /// real response (the fetch followed a CF redirect).
  final bool isChallenge;

  WebviewFetchResult({
    this.status,
    this.headers = const {},
    this.bodyBytes,
    this.isChallenge = false,
  });

  String? get bodyText {
    final bytes = bodyBytes;
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }
}

/// Performs HTTP requests through the in-app WebView (ArkWeb) when the app's
/// dart:io HttpClient is blocked by Cloudflare.
///
/// The WebView uses a real browser TLS/HTTP stack, so Cloudflare serves it
/// normally (this is exactly what the user observes: "跳转 webview 后正常访问").
/// We park the WebView on the origin root of the target URL so the request can
/// be re-issued as a same-origin `fetch()` from the page context, with the
/// browser engine handling TLS/HTTP/JS challenges.
class WebviewFetch {
  WebviewFetch._();

  static bool _busy = false;

  /// Max decoded body size accepted from the WebView (base64 round-trip).
  static const int maxBodyBytes = 12 * 1024 * 1024;

  /// Perform [url] through the WebView. Returns null on any failure so the
  /// caller falls back to the original error.
  static Future<WebviewFetchResult?> fetch({
    required String url,
    String method = 'GET',
    Map<String, dynamic>? headers,
    Object? data,
  }) async {
    if (_busy) {
      // Serialize: wait for the in-flight session (bounded).
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (_busy && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_busy) return null;
    }
    _busy = true;
    try {
      return await _fetchInternal(
        url: url,
        method: method,
        headers: headers,
        data: data,
      );
    } finally {
      _busy = false;
    }
  }

  static Future<WebviewFetchResult?> _fetchInternal({
    required String url,
    String method = 'GET',
    Map<String, dynamic>? headers,
    Object? data,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    // Park on the origin root so the later fetch() is same-origin (no CORS)
    // and CF runs its challenge flow against a real page for the whole domain.
    final originRoot = '${uri.origin}/';
    Log.warning('WebviewFetch', 'Opening WebView at $originRoot for $url (method=$method)');

    var finished = false;
    var startedFetch = false;
    var savedCookies = false;
    var triedNavigate = false;
    var triedExactUrl = false;
    var loggedPageOnce = false;
    Timer? pollTimer;

    void finish() {
      if (finished) return;
      finished = true;
      pollTimer?.cancel();
      pollTimer = null;
    }

    Future<void> check() async {
      if (finished) return;
      final state = AppWebview.activeState;
      if (state == null) return;
      try {
        final head =
            (await state.evaluateJavascript('document.head ? document.head.innerHTML : ""'))?.toString() ?? '';
        final body =
            (await state.evaluateJavascript('document.body ? document.body.innerHTML : ""'))?.toString() ?? '';
        final challenging = head.contains('#challenge-success-text') ||
            head.contains('#challenge-error-text') ||
            head.contains('#challenge-form') ||
            body.contains('challenge-platform') ||
            body.contains('window._cf_chl_opt') ||
            body.contains('cf-turnstile') ||
            body.contains('Checking your browser');
        if (challenging) return; // keep waiting for the challenge to resolve

        // The device's network may serve the origin root as a placeholder
        // (e.g. raw nginx) instead of the site. Fall back to the exact
        // failing URL, which the user confirmed loads normally.
        final title = await state.getPageTitle();
        if (!loggedPageOnce) {
          loggedPageOnce = true;
          final pageUrl =
              (await state.evaluateJavascript('document.URL'))?.toString() ?? '';
          Log.warning(
            'WebviewFetch',
            'page loaded: url=$pageUrl title=$title bodyLen=${body.length}',
          );
        }
        if (isPlaceholderPage(title: title, body: body) &&
            !triedExactUrl &&
            (method.toUpperCase() == 'GET' ||
                method.toUpperCase() == 'HEAD')) {
          triedExactUrl = true;
          startedFetch = false;
          savedCookies = false;
          Log.warning(
            'WebviewFetch',
            'Origin root is a placeholder page (title=$title); '
            'navigating to exact URL $url',
          );
          try {
            await state.loadUrl(url);
          } catch (e, s) {
            Log.warning('WebviewFetch', 'navigate to exact URL error: $e\n$s');
          }
          return;
        }

        // Harvest cookies + UA once the real page is up.
        if (!savedCookies) {
          final cookies = await state.getCookies(originRoot);
          if (cookies.isNotEmpty) {
            saveWebviewCookies(originRoot, cookies);
            savedCookies = true;
          }
          final ua = await state.getUserAgent();
          if (ua != null && ua.isNotEmpty) {
            saveWebviewUa(ua);
          }
        }

        if (!startedFetch) {
          // Only fetch once the page is actually a real page; on about:blank
          // (still loading) the fetch would be cross-origin and get blocked by
          // CORS. If the origin root redirected somewhere else, the fetch may
          // still fail with a CORS error, which is handled as a failure below.
          final pageUrl =
              (await state.evaluateJavascript('document.URL'))?.toString() ?? '';
          if (pageUrl.isEmpty ||
              pageUrl == 'about:blank' ||
              pageUrl == 'null' ||
              pageUrl == 'undefined' ||
              !pageUrl.startsWith('http')) {
            return;
          }
          startedFetch = true;
          await state.runFetchScript(
            url: url,
            method: method,
            headers: headers,
            data: data,
          );
        }
      } catch (e, s) {
        Log.warning('WebviewFetch', 'check() error: $e\n$s');
      }
    }

    // Push the WebView (fire-and-forget; polling runs while it is open).
    final pushFuture = App.rootContext.to(
      () => AppWebview(
        initialUrl: originRoot,
        singlePage: true,
        // Prefer the UA saved from a previous pass so CF sees a consistent
        // client; otherwise let ArkWeb use its system UA (confirmed to pass).
        userAgent: appdata.implicitData['ua'] is String
            ? appdata.implicitData['ua'] as String
            : null,
        onLoadStop: check,
        onTitleChange: (_) => check,
      ),
    );

    pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      check();
    });

    // Wait for the fetch result (or timeout).
    WebviewFetchResult? result;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!finished && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 300));
      final state = AppWebview.activeState;
      if (state == null) {
        // WebView was closed (user backed out) before we finished.
        finish();
        break;
      }
      final raw = await state.pollFetchResult();
      if (raw != null) {
        final canReadDirectly = method.toUpperCase() == 'GET' ||
            method.toUpperCase() == 'HEAD';
        if (raw['error'] == null) {
          final parsed = _parse(raw);
          final unusable = parsed == null ||
              parsed.isChallenge ||
              _isGarbageBody(parsed);
          if (unusable && !triedNavigate && canReadDirectly) {
            // fetch result is a challenge page, placeholder content, or
            // undecodable — navigate the WebView to the URL and read the
            // rendered page (the browser context passes CF and renders
            // JSON/HTML as text).
            triedNavigate = true;
            Log.warning(
              'WebviewFetch',
              'fetch result unusable (challenge/placeholder); reading exact URL',
            );
            final read = await _navigateAndRead(state, url);
            if (read != null && !_isGarbageBody(read)) {
              result = read;
              finish();
              break;
            }
          } else if (!unusable) {
            result = parsed;
            finish();
            break;
          }
        } else if (!triedNavigate && canReadDirectly) {
          // fetch() failed — typically CORS for a cross-origin URL. Navigate
          // the WebView to the URL itself and read the rendered page.
          triedNavigate = true;
          result = await _navigateAndRead(state, url);
          if (result != null) {
            finish();
            break;
          }
        }
      }
    }
    finish();

    // Close the WebView if it is still open, then let the route settle.
    if (AppWebview.activeState != null) {
      App.rootPop();
    }
    try {
      await pushFuture;
    } catch (e, s) {
      Log.warning('WebviewFetch', 'pushFuture error: $e\n$s');
    }

    if (result == null) {
      Log.warning('WebviewFetch', 'WebView fallback failed for $url');
    } else {
      Log.warning(
        'WebviewFetch',
        'WebView fallback succeeded for $url '
        '(status=${result.status}, bytes=${result.bodyBytes?.length})',
      );
    }
    return result;
  }

  /// Cross-origin fallback: navigate the WebView to [url] and read the
  /// rendered page (JSON APIs render as body text; HTML via outerHTML).
  static Future<WebviewFetchResult?> _navigateAndRead(
    AppWebviewState state,
    String url,
  ) async {
    try {
      await state.loadUrl(url);
    } catch (e, s) {
      Log.warning('WebviewFetch', 'navigateAndRead loadUrl error: $e\n$s');
      return null;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 400));
      final text = await state.getPageText();
      final html = await state.getPageHtml();
      final content = (text != null && text.trim().isNotEmpty)
          ? text
          : html;
      if (content == null || content.trim().isEmpty) continue;
      if (content.contains('challenge-platform') ||
          content.contains('window._cf_chl_opt') ||
          content.contains('cf-turnstile') ||
          content.contains('Checking your browser')) {
        continue; // still on a CF challenge page
      }
      return WebviewFetchResult(
        status: 200,
        bodyBytes: utf8.encode(content),
      );
    }
    return null;
  }

  static bool _isGarbageBody(WebviewFetchResult result) {
    final bytes = result.bodyBytes;
    if (bytes == null) return false;
    final text = utf8.decode(bytes, allowMalformed: true);
    return isPlaceholderPage(title: null, body: text);
  }

  static WebviewFetchResult? _parse(Map<String, dynamic> raw) {
    if (raw['error'] != null) return null;
    final status = raw['status'];
    var headers = <String, String>{};
    final rawHeaders = raw['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) => headers[k.toString()] = v.toString());
    }
    final b64 = raw['bodyBase64']?.toString() ?? '';
    if (b64.isEmpty) {
      return WebviewFetchResult(
        status: status is int ? status : null,
        headers: headers,
      );
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      return null;
    }
    if (bytes.length > maxBodyBytes) {
      Log.warning('WebviewFetch', 'body too large (${bytes.length}), dropping');
      return null;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final isChallenge = text.contains('challenge-platform') ||
        text.contains('window._cf_chl_opt') ||
        text.contains('cf-turnstile') ||
        text.contains('Checking your browser');
    return WebviewFetchResult(
      status: status is int ? status : null,
      headers: headers,
      bodyBytes: bytes,
      isChallenge: isChallenge,
    );
  }
}

/// Save WebView cookies into the app cookie jar, scoped to the registrable
/// domain so all subdomains of the protected site share them.
void saveWebviewCookies(String url, Map<String, String> cookies) {
  final uri = Uri.tryParse(url);
  if (uri == null || cookies.isEmpty) return;
  var domain = uri.host;
  final splits = domain.split('.');
  if (splits.length > 1) {
    domain = '.${splits[splits.length - 2]}.${splits[splits.length - 1]}';
  }
  try {
    SingleInstanceCookieJar.instance?.saveFromResponse(
      uri,
      List<io.Cookie>.generate(cookies.length, (index) {
        var cookie = io.Cookie(
          cookies.keys.elementAt(index),
          cookies.values.elementAt(index),
        );
        cookie.domain = domain;
        return cookie;
      }),
    );
  } catch (e, s) {
    Log.warning('WebviewFetch', 'saveWebviewCookies error: $e\n$s');
  }
}

/// Remember the WebView user agent so the dart:io client presents the same UA.
void saveWebviewUa(String ua) {
  if (ua.isEmpty) return;
  if (appdata.implicitData['ua'] == ua) return;
  appdata.implicitData['ua'] = ua;
  appdata.writeImplicitData();
}

/// True when a page looks like a server placeholder or gateway error page
/// (e.g. a raw nginx default site) instead of the real site.
bool isPlaceholderPage({String? title, String? body}) {
  final titleLower = (title ?? '').toLowerCase();
  final bodyLower = (body ?? '').toLowerCase();
  if (titleLower.contains('welcome to nginx') ||
      bodyLower.contains('welcome to nginx')) {
    return true;
  }
  // Common gateway error pages (502/503/504/403/404 ...) served in place of
  // the site.
  if (RegExp(r'^\s*(50[0-9]|40[0-9])\b').hasMatch(titleLower)) {
    return true;
  }
  return false;
}
