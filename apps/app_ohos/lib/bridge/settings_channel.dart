import 'package:flutter/services.dart';

class SettingsChannel {
  static const MethodChannel _channel = MethodChannel('com.venera.settings');

  static Future<bool> authenticate({required String reason}) async {
    final result = await _channel.invokeMethod<bool>('authenticate', {
      'reason': reason,
    });
    return result ?? false;
  }

  static Future<String?> pickDirectory() async {
    return await _channel.invokeMethod<String?>('pickDirectory');
  }

  static Future<String?> pickFile({String? mimeType}) async {
    return await _channel.invokeMethod<String?>('pickFile', {
      if (mimeType != null) 'mimeType': mimeType,
    });
  }

  static Future<void> setKeepScreenOn({required bool on}) async {
    await _channel.invokeMethod<void>('setKeepScreenOn', {'on': on});
  }

  static Future<Map<String, dynamic>> getProxy() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getProxy');
    if (result == null) return {};
    return result.map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<String?> saveFile({
    required String sourcePath,
    required String fileName,
  }) async {
    return await _channel.invokeMethod<String?>('saveFile', {
      'sourcePath': sourcePath,
      'fileName': fileName,
    });
  }
}
