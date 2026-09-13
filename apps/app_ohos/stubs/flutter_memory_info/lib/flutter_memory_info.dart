import 'package:flutter/services.dart';

class MemoryInfo {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<int?> getFreePhysicalMemorySize() async {
    try {
      final result = await _channel.invokeMethod<int>('getFreeMemory');
      return result;
    } catch (e) {
      return null;
    }
  }
}
