import 'dart:async';

import 'package:flutter/services.dart';
import 'package:venera/foundation/log.dart';

class CloudflarePassResult {
  CloudflarePassResult({
    required this.url,
    required this.cookies,
    this.userAgent,
  });

  final String url;
  final Map<String, String> cookies;
  final String? userAgent;
}

class WebViewChannel {
  static const MethodChannel _channel = MethodChannel('com.venera.webview');

  static Completer<CloudflarePassResult?>? _cfCompleter;
  static String? _pendingUserAgent;
  static bool _handlersRegistered = false;

  /// Parse `"a=1; b=2"` cookie header into a name/value map.
  static Map<String, String> parseCookieString(String raw) {
    final cookies = <String, String>{};
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (name.isNotEmpty) {
        cookies[name] = value;
      }
    }
    return cookies;
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic args) {
    if (args is! Map) return null;
    return args.map((k, v) => MapEntry(k.toString(), v));
  }

  static void ensureHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCookiesReceived':
        // Informational; CF flow waits for onCloudflareResolved.
        return null;
      case 'onCloudflareDetected':
        final map = _asStringKeyedMap(call.arguments);
        final url = map?['url']?.toString() ?? call.arguments?.toString();
        Log.info('WebViewChannel', 'Cloudflare challenge detected: $url');
        return null;
      case 'onCloudflareResolved':
        _handleCloudflareResolved(call.arguments);
        return null;
      case 'onUserAgentReceived':
        final map = _asStringKeyedMap(call.arguments);
        final ua = map?['userAgent']?.toString();
        if (ua != null && ua.isNotEmpty) {
          _pendingUserAgent = ua;
        }
        return null;
      case 'onClosed':
        _handleClosed();
        return null;
      default:
        Log.warning(
          'WebViewChannel',
          'Unhandled method from native: ${call.method}',
        );
        return null;
    }
  }

  static void _handleCloudflareResolved(dynamic arguments) {
    final completer = _cfCompleter;
    if (completer == null || completer.isCompleted) return;

    final map = _asStringKeyedMap(arguments);
    if (map == null) {
      Log.error('WebViewChannel', 'onCloudflareResolved: invalid args');
      return;
    }

    final url = map['url']?.toString() ?? '';
    final cookiesRaw = map['cookies']?.toString() ?? '';
    final cookies = parseCookieString(cookiesRaw);
    if (!cookies.containsKey('cf_clearance')) {
      Log.info(
        'WebViewChannel',
        'onCloudflareResolved without cf_clearance, ignoring',
      );
      return;
    }

    final ua = map['userAgent']?.toString() ?? _pendingUserAgent;
    Log.info(
      'WebViewChannel',
      'Cloudflare resolved for $url, cookies=${cookies.length}, ua=${ua != null}',
    );
    completer.complete(
      CloudflarePassResult(url: url, cookies: cookies, userAgent: ua),
    );
  }

  static void _handleClosed() {
    final completer = _cfCompleter;
    if (completer == null || completer.isCompleted) return;
    Log.info('WebViewChannel', 'WebView closed without Cloudflare resolve');
    completer.complete(null);
  }

  static Future<void> openWebView({required String url}) async {
    ensureHandlers();
    await _channel.invokeMethod<void>('open', {'url': url});
  }

  /// Opens native WebViewAbility and waits until CF is resolved or the page is closed.
  /// Returns null if the user cancelled / closed without `cf_clearance`.
  static Future<CloudflarePassResult?> waitForCloudflare(String url) async {
    ensureHandlers();
    if (_cfCompleter != null && !_cfCompleter!.isCompleted) {
      _cfCompleter!.complete(null);
    }
    _pendingUserAgent = null;
    _cfCompleter = Completer<CloudflarePassResult?>();
    try {
      await openWebView(url: url);
    } catch (e, s) {
      Log.error('WebViewChannel', 'Failed to open WebView: $e\n$s');
      if (!_cfCompleter!.isCompleted) {
        _cfCompleter!.complete(null);
      }
      _cfCompleter = null;
      return null;
    }
    try {
      return await _cfCompleter!.future;
    } finally {
      _cfCompleter = null;
      _pendingUserAgent = null;
    }
  }

  static Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on MissingPluginException {
      //
    } catch (e) {
      Log.warning('WebViewChannel', 'close failed: $e');
    }
  }
}
