import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/platform/ohos_platform_services.dart';
import 'package:venera/utils/translations.dart';

typedef WebviewOnTitleChange = void Function(String title);
typedef WebviewOnNavigation = bool Function(String url);
typedef WebviewOnStarted = void Function();
typedef WebviewOnLoadStop = void Function();

class AppWebview extends StatefulWidget {
  AppWebview({
    super.key,
    this.initialUrl,
    this.initialData,
    this.onTitleChange,
    this.onNavigation,
    this.onStarted,
    this.onLoadStop,
    this.userAgent,
    this.singlePage = false,
  });

  final String? initialUrl;
  final String? initialData;
  final WebviewOnTitleChange? onTitleChange;
  final WebviewOnNavigation? onNavigation;
  final WebviewOnStarted? onStarted;
  final WebviewOnLoadStop? onLoadStop;
  final String? userAgent;
  final bool singlePage;

  static String? webViewEnvironment;

  static final _activeStates = <AppWebviewState>[];

  static AppWebviewState? get activeState =>
      _activeStates.isNotEmpty ? _activeStates.last : null;

  @override
  State<AppWebview> createState() => AppWebviewState();
}

class AppWebviewState extends State<AppWebview> {
  InAppWebViewController? _controller;

  String _title = '';
  String _currentUrl = '';
  bool _isLoading = true;

  String get title => _title;
  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? '';
    AppWebview._activeStates.add(this);
  }

  Future<String> getCurrentUrl() async {
    final url = await _controller?.getUrl();
    if (url != null) {
      _currentUrl = url.toString();
    }
    return _currentUrl;
  }

  Future<void> loadUrl(String url) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _currentUrl = url;
      });
    }
    try {
      await (_controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url))) ??
              Future<void>.value())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      Log.warning('Webview', 'loadUrl timed out: $url');
    }
  }

  Future<void> loadData(String data, {String mimeType = 'text/html'}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await _controller?.loadData(data: data, mimeType: mimeType);
  }

  Future<dynamic> evaluateJavascript(String source) async {
    // Guard against ArkWeb hanging while a page is still loading: never let
    // a JS evaluation block the caller indefinitely.
    try {
      return await (_controller?.evaluateJavascript(source: source) ??
              Future<dynamic>.value(null))
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return null;
    }
  }

  Future<void> clearCache() async {
    await InAppWebViewController.clearAllCache();
  }

  Future<Map<String, String>> getCookies(String url) async {
    // Prefer ArkWeb WebCookieManager — includes HttpOnly (cf_clearance).
    // flutter_inappwebview_ohos does not implement CookieManager.
    // Merge full URL + origin/ so domain cookies are not missed.
    final ohos = await OhosWebCookies.fetchMerged(url);
    if (ohos.isNotEmpty) {
      return ohos;
    }
    try {
      final list = await CookieManager.instance()
          .getCookies(
            url: WebUri(url),
            webViewController: _controller,
          )
          .timeout(const Duration(seconds: 1));
      final cookies = <String, String>{};
      for (final c in list) {
        if (c.name.isNotEmpty) {
          cookies[c.name] = c.value?.toString() ?? '';
        }
      }
      if (cookies.isNotEmpty) return cookies;
    } catch (_) {}
    try {
      final result = await evaluateJavascript('document.cookie');
      if (result != null) {
        var raw = result.toString();
        if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
          raw = raw.substring(1, raw.length - 1);
        }
        return OhosWebCookies.parseCookieHeader(raw);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, String>> getLocalStorage() async {
    try {
      final result = await evaluateJavascript('''
        (function() {
          var items = {};
          for (var i = 0; i < localStorage.length; i++) {
            var key = localStorage.key(i);
            if (key !== null) {
              items[key] = localStorage.getItem(key);
            }
          }
          return items;
        })()
      ''');
      if (result is Map) {
        return result.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<String?> getUserAgent() async {
    try {
      final result =
          await evaluateJavascript('navigator.userAgent');
      if (result == null) return null;
      var ua = result.toString();
      if (ua.length >= 2 && ua.startsWith('"') && ua.endsWith('"')) {
        ua = ua.substring(1, ua.length - 1);
      }
      return ua;
    } catch (_) {
      return null;
    }
  }

  /// Start a same-origin `fetch()` in the page for [url] and store the result
  /// (a JSON string with status/headers/bodyBase64) on
  /// `window.__veneraFetchResult`. Poll [pollFetchResult] until it appears.
  ///
  /// Used by the Cloudflare fallback: the page is parked on the target origin
  /// so the fetch is same-origin (no CORS), and the ArkWeb engine performs the
  /// request with its browser-grade TLS/HTTP stack.
  Future<void> runFetchScript({
    required String url,
    String method = 'GET',
    Map<String, dynamic>? headers,
    Object? data,
  }) async {
    // Headers a browser forbids setting on fetch(); the engine fills them.
    const forbidden = {
      'host',
      'content-length',
      'connection',
      'transfer-encoding',
      'accept-encoding',
      'cookie',
      'set-cookie',
      'user-agent',
    };
    final safeHeaders = <String, String>{};
    (headers ?? {}).forEach((key, value) {
      if (value == null) return;
      if (forbidden.contains(key.toLowerCase())) return;
      safeHeaders[key] = value.toString();
    });

    String bodyExpr = 'null';
    if (data is String && data.isNotEmpty) {
      bodyExpr = jsonEncode(data);
    } else if (data is Map && data.isNotEmpty) {
      final form = data.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      bodyExpr = 'new URLSearchParams(${jsonEncode(form)})';
    }

    final script = '''
(function() {
  window.__veneraFetchResult = null;
  var url = ${jsonEncode(url)};
  var opts = {
    method: ${jsonEncode(method.toUpperCase())},
    headers: ${jsonEncode(safeHeaders)},
    credentials: 'include',
    redirect: 'follow'
  };
  var body = $bodyExpr;
  if (body !== null) { opts.body = body; }
  fetch(url, opts).then(function(r) {
    return r.arrayBuffer().then(function(buf) {
      var bytes = new Uint8Array(buf);
      var CHUNK = 0x8000;
      var bin = '';
      for (var i = 0; i < bytes.length; i += CHUNK) {
        var sub = bytes.subarray(i, Math.min(i + CHUNK, bytes.length));
        bin += String.fromCharCode.apply(null, sub);
      }
      var hdrs = {};
      r.headers.forEach(function(v, k) { hdrs[k] = v; });
      window.__veneraFetchResult = JSON.stringify({
        status: r.status,
        ok: r.ok,
        headers: hdrs,
        bodyBase64: btoa(bin)
      });
    });
  }).catch(function(e) {
    window.__veneraFetchResult = JSON.stringify({
      error: String((e && e.message) ? e.message : e)
    });
  });
})();
''';
    try {
      await evaluateJavascript(script);
    } catch (err) {
      Log.warning('Webview', 'runFetchScript error: $err');
    }
  }

  /// Poll the result set by [runFetchScript]. Returns the decoded map once the
  /// fetch settled, or null while it is still pending / on failure.
  Future<Map<String, dynamic>?> pollFetchResult() async {
    try {
      final res = await evaluateJavascript('window.__veneraFetchResult');
      if (res == null) return null;
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        return map.isEmpty ? null : map;
      }
      final s = res.toString();
      if (s.isEmpty || s == 'null' || s == 'undefined') return null;
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return map.isEmpty ? null : map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reset the fetch result slot.
  Future<void> clearFetchResult() async {
    try {
      await evaluateJavascript('window.__veneraFetchResult = null;');
    } catch (_) {}
  }

  /// Read the current page title (used to detect placeholder/nginx pages).
  Future<String?> getPageTitle() async {
    try {
      final res = await evaluateJavascript('document.title');
      return _cleanJsString(res);
    } catch (_) {
      return null;
    }
  }

  /// Read the current page body as plain text (JSON API responses render as
  /// body text when the page navigates to them).
  Future<String?> getPageText() async {
    try {
      final res =
          await evaluateJavascript('document.body ? document.body.innerText : ""');
      return _cleanJsString(res);
    } catch (_) {
      return null;
    }
  }

  /// Read the whole current page HTML.
  Future<String?> getPageHtml() async {
    try {
      final res = await evaluateJavascript(
          'document.documentElement ? document.documentElement.outerHTML : ""');
      return _cleanJsString(res);
    } catch (_) {
      return null;
    }
  }

  static String? _cleanJsString(dynamic res) {
    if (res == null) return null;
    var s = res.toString();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  @override
  void dispose() {
    AppWebview._activeStates.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: (widget.initialUrl != null &&
              widget.initialUrl!.isNotEmpty)
          ? URLRequest(url: WebUri(widget.initialUrl!))
          : null,
      initialData: widget.initialData != null
          ? InAppWebViewInitialData(data: widget.initialData!)
          : null,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: widget.userAgent,
        useShouldOverrideUrlLoading: widget.onNavigation != null,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        thirdPartyCookiesEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.onStarted?.call();
      },
      onLoadStart: (controller, url) {
        if (!mounted) return;
        setState(() {
          _isLoading = true;
          if (url != null) {
            _currentUrl = url.toString();
          }
        });
      },
      onLoadStop: (controller, url) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (url != null) {
            _currentUrl = url.toString();
          }
        });
        widget.onLoadStop?.call();
      },
      onTitleChanged: (controller, title) {
        if (title == null) return;
        if (mounted) {
          setState(() {
            _title = title;
          });
        } else {
          _title = title;
        }
        widget.onTitleChange?.call(title);
      },
      shouldOverrideUrlLoading: widget.onNavigation == null
          ? null
          : (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              final cancel = widget.onNavigation!(url);
              return cancel
                  ? NavigationActionPolicy.CANCEL
                  : NavigationActionPolicy.ALLOW;
            },
    );

    return Scaffold(
      appBar: Appbar(
        title: Text(_title.isEmpty ? 'WebView'.tl : _title),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: webView),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

/// Legacy Ability-based WebView for login flows that still use the native channel.
class DesktopWebview {
  static Future<bool> isAvailable() async => true;

  final WebviewOnTitleChange? onTitleChange;
  final WebviewOnNavigation? onNavigation;
  final WebviewOnStarted? onStarted;
  final VoidCallback? onClose;

  final String initialUrl;

  DesktopWebview({
    required this.initialUrl,
    this.onTitleChange,
    this.onNavigation,
    this.onStarted,
    this.onClose,
  });

  static const _channelName = 'com.venera.webview';

  String? _title;
  String? _ua;

  String? get userAgent => _ua;
  String? get title => _title;

  void open() async {
    try {
      await const MethodChannel(_channelName)
          .invokeMethod<void>('open', {'url': initialUrl});
    } on MissingPluginException {
      //
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      onStarted?.call();
    });
  }

  Future<String?> evaluateJavascript(String source) async {
    try {
      return await const MethodChannel(_channelName)
          .invokeMethod<String>('evalJs', {'jsCode': source});
    } on MissingPluginException {
      return null;
    }
  }

  Future<Map<String, String>> getCookies(String url) async {
    try {
      var result = await const MethodChannel(_channelName)
          .invokeMethod<List<dynamic>>('getCookies', {'url': url});
      if (result == null) return {};
      var cookies = <String, String>{};
      for (var item in result) {
        if (item is Map<dynamic, dynamic>) {
          var map = item.map((k, v) => MapEntry(k.toString(), v.toString()));
          cookies[map['name'] ?? ''] = map['value'] ?? '';
        }
      }
      cookies.removeWhere((key, value) => key.isEmpty);
      return cookies;
    } on MissingPluginException {
      return {};
    }
  }

  Future<Map<String, String>> getLocalStorage() async {
    try {
      var result = await const MethodChannel(_channelName)
          .invokeMethod<Map<dynamic, dynamic>>('getLocalStorage');
      if (result == null) return {};
      var localStorage = <String, String>{};
      result.forEach((key, value) {
        localStorage[key.toString()] = value.toString();
      });
      return localStorage;
    } on MissingPluginException {
      return {};
    }
  }

  Future<String?> getUserAgent() async {
    try {
      var ua = await const MethodChannel(_channelName)
          .invokeMethod<String>('getUserAgent');
      if (ua != null) {
        _ua = ua;
      }
      return ua;
    } on MissingPluginException {
      return null;
    }
  }

  void close() async {
    try {
      await const MethodChannel(_channelName).invokeMethod<void>('close');
    } on MissingPluginException {
      //
    }
    onClose?.call();
  }
}

Future<void> openUrlInBrowser(String url) async {
  await OhosUrlLauncher.launchUrlString(url);
}
