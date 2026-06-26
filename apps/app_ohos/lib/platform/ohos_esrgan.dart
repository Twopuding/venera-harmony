import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;

class OhosESRGAN {
  static const _channel = MethodChannel('venera/method_channel');
  static bool _initialized = false;
  static bool? _available;

  static Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      var result = await _channel.invokeMethod<bool>('esrganIsAvailable');
      _available = result ?? false;
    } on PlatformException {
      _available = false;
    }
    return _available!;
  }

  static Future<bool> initialize() async {
    if (_initialized) return true;
    
    try {
      ByteData modelData = await rootBundle.load('rawfile/realesr-animevideov3.ms');
      Uint8List modelBytes = modelData.buffer.asUint8List();
      
      var result = await _channel.invokeMethod<bool>('esrganInitialize', {
        'modelData': modelBytes,
      });
      
      _initialized = result ?? false;
      _available = _initialized;
    } on PlatformException catch (e) {
      print('ESRGAN initialize failed: $e');
      _initialized = false;
      _available = false;
    }
    return _initialized;
  }

  static Future<Uint8List?> processImage(Uint8List imageData) async {
    if (!_initialized) {
      bool success = await initialize();
      if (!success) return null;
    }
    
    try {
      var result = await _channel.invokeMethod<Uint8List>('esrganProcess', {
        'imageData': imageData,
      });
      return result;
    } on PlatformException catch (e) {
      print('ESRGAN process failed: $e');
      return null;
    }
  }

  static void reset() {
    _initialized = false;
    _available = null;
  }
}
