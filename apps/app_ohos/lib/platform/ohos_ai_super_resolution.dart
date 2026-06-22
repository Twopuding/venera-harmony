import 'dart:typed_data';
import 'package:flutter/services.dart';

class OhosAiSuperResolution {
  static const _channel = MethodChannel('venera/method_channel');
  static bool? _isAvailable;

  static Future<bool> isAvailable() async {
    if (_isAvailable != null) return _isAvailable!;
    try {
      var result = await _channel.invokeMethod<bool>('isAiSuperResolutionAvailable');
      _isAvailable = result ?? false;
    } on PlatformException {
      _isAvailable = false;
    }
    return _isAvailable!;
  }

  static Future<Uint8List?> processImage(Uint8List imageData) async {
    try {
      var result = await _channel.invokeMethod<Uint8List>('aiSuperResolution', {
        'imageData': imageData,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }

  static void resetAvailability() {
    _isAvailable = null;
  }
}
