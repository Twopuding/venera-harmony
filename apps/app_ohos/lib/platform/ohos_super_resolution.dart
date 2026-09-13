import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class OhosSuperResolution {
  static const _channel = MethodChannel('venera/method_channel');
  static bool _initialized = false;
  static bool? _available;
  static bool _failedInit = false;
  static int _initRetryCount = 0;
  static const int _maxInitRetries = 3;
  static int _fileCounter = 0;
  static Future<void>? _processingQueue;

  static int _nextFileId() {
    _fileCounter++;
    return _fileCounter;
  }

  static Future<bool> isAvailable() async {
    if (_available == true) return true;
    try {
      var result = await _channel.invokeMethod<bool>('srIsAvailable');
      debugPrint('[SR] isAvailable result: $result');
      if (result == true) {
        _available = true;
      }
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[SR] isAvailable exception: $e');
      return false;
    }
  }

  static Future<bool> initialize() async {
    if (_initialized) return true;
    if (_failedInit && _initRetryCount >= _maxInitRetries) {
      debugPrint('[SR] initialize skipped: failed $_initRetryCount times');
      return false;
    }
    _initRetryCount++;
    debugPrint('[SR] initialize attempt $_initRetryCount/$_maxInitRetries');
    try {
      var result = await _channel.invokeMethod<bool>('srInitialize');
      debugPrint('[SR] initialize result: $result');
      _initialized = result ?? false;
      if (_initialized) {
        _available = true;
        _initRetryCount = 0;
      } else {
        _failedInit = true;
      }
    } on PlatformException catch (e) {
      debugPrint('[SR] initialize exception: $e');
      _initialized = false;
      _failedInit = true;
    }
    return _initialized;
  }

  static Future<Uint8List?> processImage(Uint8List imageData) async {
    var prev = _processingQueue;
    var completer = Completer<Uint8List?>();
    _processingQueue = completer.future;
    if (prev != null) {
      await prev;
    }

    try {
      if (_failedInit && _initRetryCount >= _maxInitRetries) {
        completer.complete(null);
        return null;
      }
      if (!_initialized) {
        bool success = await initialize();
        if (!success) {
          completer.complete(null);
          return null;
        }
      }
      var tempDir = Directory.systemTemp;
      var fileId = _nextFileId();
      var inputFile = File('${tempDir.path}/sr_input_$fileId');
      await inputFile.writeAsBytes(imageData);
      var resultPath = await _channel.invokeMethod<String>('srProcessFile', {
        'filePath': inputFile.path,
      });
      if (resultPath != null && resultPath.isNotEmpty) {
        var resultFile = File(resultPath);
        if (await resultFile.exists()) {
          var resultBytes = await resultFile.readAsBytes();
          await resultFile.delete();
          await inputFile.delete();
          var result = Uint8List.fromList(resultBytes);
          completer.complete(result);
          return result;
        }
      }
      await inputFile.delete();
      completer.complete(null);
      return null;
    } catch (e) {
      debugPrint('[SR] processImage error: $e');
      completer.complete(null);
      return null;
    }
  }

  static void reset() {
    _initialized = false;
    _available = null;
    _failedInit = false;
    _initRetryCount = 0;
    _processingQueue = null;
  }
}
