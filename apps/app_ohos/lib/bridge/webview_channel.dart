import 'package:flutter/services.dart';

class WebViewChannel {
  static const MethodChannel _channel = MethodChannel('com.venera.webview');

  static Future<void> openWebView({required String url}) async {
    await _channel.invokeMethod<void>('open', {'url': url});
  }

  static void registerHandlers({
    required void Function(List<Map<String, String>> cookies) onCookiesReceived,
    required void Function(String url) onCloudflareDetected,
    required void Function(List<Map<String, String>> cookies) onCloudflareResolved,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCookiesReceived':
          final raw = call.arguments as List<dynamic>;
          final cookies = raw
              .map((e) => (e as Map<dynamic, dynamic>)
                  .map((k, v) => MapEntry(k.toString(), v.toString())))
              .toList();
          onCookiesReceived(cookies);
          return null;
        case 'onCloudflareDetected':
          onCloudflareDetected(call.arguments as String);
          return null;
        case 'onCloudflareResolved':
          final raw = call.arguments as List<dynamic>;
          final cookies = raw
              .map((e) => (e as Map<dynamic, dynamic>)
                  .map((k, v) => MapEntry(k.toString(), v.toString())))
              .toList();
          onCloudflareResolved(cookies);
          return null;
        default:
          throw MissingPluginException(
            'No implementation for method ${call.method}',
          );
      }
    });
  }

  static Future<void> evaluateJs({required String jsCode}) async {
    await _channel.invokeMethod<void>('evaluateJs', {'jsCode': jsCode});
  }

  static Future<String?> getCurrentUrl() async {
    return await _channel.invokeMethod<String>('getCurrentUrl');
  }

  static Future<Map<String, String>> getCookies(String url) async {
    var result = await _channel.invokeMethod<List<dynamic>>('getCookies', {'url': url});
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
  }

  static Future<void> loadUrl(String url) async {
    await _channel.invokeMethod<void>('loadUrl', {'url': url});
  }

  static Future<dynamic> evalJs(String jsCode) async {
    return await _channel.invokeMethod<dynamic>('evalJs', {'jsCode': jsCode});
  }

  static Future<void> clearCookies(String url) async {
    await _channel.invokeMethod<void>('clearCookies', {'url': url});
  }

  static Future<void> close() async {
    await _channel.invokeMethod<void>('close');
  }
}
