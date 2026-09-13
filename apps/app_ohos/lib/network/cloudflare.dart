import 'dart:async';

import 'package:dio/dio.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/webview.dart';

import 'webview_fetch.dart';

class CloudflareException implements DioException {
  final String url;

  CloudflareException(this.url);

  @override
  String toString() {
    return "CloudflareException: $url";
  }

  static CloudflareException? fromString(String message) {
    var match = RegExp(r"CloudflareException: (.+)").firstMatch(message);
    if (match == null) return null;
    return CloudflareException(match.group(1)!);
  }

  @override
  DioException copyWith(
      {RequestOptions? requestOptions,
      Response<dynamic>? response,
      DioExceptionType? type,
      Object? error,
      StackTrace? stackTrace,
      String? message}) {
    return this;
  }

  @override
  Object? get error => this;

  @override
  String? get message => toString();

  @override
  RequestOptions get requestOptions => RequestOptions();

  @override
  Response? get response => null;

  @override
  StackTrace get stackTrace => StackTrace.empty;

  @override
  DioExceptionType get type => DioExceptionType.badResponse;

  @override
  DioExceptionReadableStringBuilder? stringBuilder;
}

/// Returns true when [e] is (or wraps) a Cloudflare challenge rejection.
bool isCloudflareError(Object e) {
  if (e is CloudflareException) return true;
  return CloudflareException.fromString(e.toString()) != null;
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final ua = appdata.implicitData['ua'];
    if (ua is String && ua.isNotEmpty) {
      options.headers['user-agent'] = ua;
    } else if (options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = webUA;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 403) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 403) {
      var err = _check(response);
      if (err != null) {
        handler.reject(err);
        return;
      }
    }
    handler.next(response);
  }

  CloudflareException? _check(Response response) {
    final mitigated = response.headers['cf-mitigated'];
    if (mitigated != null &&
        mitigated.isNotEmpty &&
        mitigated.first == 'challenge') {
      final ua = appdata.implicitData['ua'];
      if (ua is String && ua.isNotEmpty) {
        Log.warning(
          'Cloudflare',
          'WebView已通但 HttpClient TLS 仍被拦 (cf-mitigated): '
          '${response.requestOptions.uri}',
        );
      }
      return CloudflareException(response.requestOptions.uri.toString());
    }
    return null;
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  final url = e.url;
  final uri = Uri.parse(url);
  // Open the exact failing URL first (the user confirmed it loads normally);
  // fall back to the origin root if the exact URL is a placeholder.
  final challengeUrl = url;
  final fallbackUrl = '${uri.origin}/';

  var success = false;
  var savedAny = false;
  var loadedOnce = false;
  var triedFallback = false;
  var checking = false;
  var stableNoClearance = 0;
  Timer? pollTimer;

  Future<void> finish(
    AppWebviewState webviewState,
    Map<String, String> cookies, {
    required bool hasClearance,
  }) async {
    if (success) return;
    success = true;
    pollTimer?.cancel();
    pollTimer = null;

    saveWebviewCookies(challengeUrl, cookies);
    savedAny = true;
    Log.warning(
      'Cloudflare',
      'Saved ${cookies.length} cookies (cf_clearance=$hasClearance) '
      'keys=${cookies.keys.join(",")}',
    );

    final ua = await webviewState.getUserAgent();
    if (ua != null && ua.isNotEmpty) {
      saveWebviewUa(ua);
      final preview = ua.length > 80 ? '${ua.substring(0, 80)}...' : ua;
      Log.warning('Cloudflare', 'Saved WebView UA: $preview');
    } else {
      Log.warning('Cloudflare', 'No UA from WebView');
    }

    if (App.rootContext.mounted) {
      App.rootContext.pop();
    }
  }

  Future<void> check(AppWebviewState webviewState) async {
    if (success || checking) return;
    checking = true;
    try {
      final head =
          await webviewState.evaluateJavascript('document.head.innerHTML') ??
              '';
      final body =
          await webviewState.evaluateJavascript('document.body.innerHTML') ??
              '';
      final headStr = head.toString();
      final bodyStr = body.toString();
      final isChallenging = headStr.contains('#challenge-success-text') ||
          headStr.contains('#challenge-error-text') ||
          headStr.contains('#challenge-form') ||
          bodyStr.contains('challenge-platform') ||
          bodyStr.contains('window._cf_chl_opt') ||
          bodyStr.contains('cf-turnstile') ||
          bodyStr.contains('Checking your browser');
      if (isChallenging) {
        stableNoClearance = 0;
        return;
      }

      final bodyTrim = bodyStr.trim();
      if (bodyTrim.isEmpty || bodyTrim == 'null' || bodyTrim == 'undefined') {
        return;
      }

      // The device's network may serve a placeholder (e.g. raw nginx) for the
      // exact URL; fall back to the origin root.
      final title = await webviewState.getPageTitle();
      if (isPlaceholderPage(title: title, body: bodyStr) && !triedFallback) {
        triedFallback = true;
        stableNoClearance = 0;
        Log.warning(
          'Cloudflare',
          'Page is a placeholder (title=$title); navigating to $fallbackUrl',
        );
        try {
          await webviewState.loadUrl(fallbackUrl);
        } catch (err, stack) {
          Log.warning('Cloudflare', 'navigate to fallback error: $err\n$stack');
        }
        return;
      }
      loadedOnce = true;

      // Page is up; harvest cookies/UA immediately so a later retry (or the
      // WebView fetch fallback in JsEngine._http) benefits from them.
      final cookies = await webviewState.getCookies(challengeUrl);
      if (cookies.isNotEmpty && !savedAny) {
        saveWebviewCookies(challengeUrl, cookies);
        savedAny = true;
      }
      final ua = await webviewState.getUserAgent();
      if (ua != null && ua.isNotEmpty) {
        saveWebviewUa(ua);
      }

      final hasClearance = cookies['cf_clearance'] != null;
      Log.warning(
        'Cloudflare',
        'poll cookies=${cookies.length} cf_clearance=$hasClearance '
        'stable=$stableNoClearance',
      );

      if (hasClearance) {
        await finish(webviewState, cookies, hasClearance: true);
        return;
      }

      // Keep waiting instead of closing after ~3s: a managed challenge may
      // issue cf_clearance a few seconds after the page renders.
      stableNoClearance++;
      if (stableNoClearance >= 10) {
        Log.warning(
          'Cloudflare',
          'No cf_clearance within budget; saving cookies/UA and closing',
        );
        await finish(webviewState, cookies, hasClearance: false);
      }
    } catch (err, stack) {
      Log.warning('Cloudflare', 'check() error: $err\n$stack');
    } finally {
      checking = false;
    }
  }

  void scheduleCheck() {
    final state = AppWebview.activeState;
    if (state != null) {
      check(state);
    }
  }

  Log.warning(
    'Cloudflare',
    'Opening Flutter WebView for verification: $challengeUrl (system UA)',
  );

  pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    scheduleCheck();
  });

  try {
    await App.rootContext.to(
      () => AppWebview(
        initialUrl: challengeUrl,
        // Use ArkWeb system UA so CF treats this as a real browser; the UA is
        // harvested and reused by the dart:io client afterwards.
        singlePage: true,
        onTitleChange: (_) => scheduleCheck(),
        onLoadStop: scheduleCheck,
        onStarted: scheduleCheck,
      ),
    );
  } catch (err, stack) {
    Log.error('Cloudflare', 'Failed to open WebView: $err', stack);
    pollTimer?.cancel();
    return;
  } finally {
    pollTimer?.cancel();
    pollTimer = null;
  }

  if (success) {
    onFinished();
  } else if (savedAny || loadedOnce) {
    // The page loaded (real site or data page) even without cf_clearance;
    // retry — JsEngine._http will use the WebView fetch fallback for the data.
    Log.warning(
      'Cloudflare',
      'Verification ended with saved cookies/loaded page; retrying',
    );
    onFinished();
  } else {
    Log.warning('Cloudflare', 'Verification cancelled or failed');
  }
}
