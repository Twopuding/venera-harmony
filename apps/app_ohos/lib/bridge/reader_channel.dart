import 'package:flutter/services.dart';

class ReaderChannel {
  static const MethodChannel _channel = MethodChannel('com.venera.reader');

  static EventChannel? _imageProgressChannel;
  static Stream<double>? _imageProgressStream;

  static Stream<double> get onImageProgress {
    _imageProgressChannel ??= const EventChannel('com.venera.reader/imageProgress');
    _imageProgressStream ??= _imageProgressChannel!
        .receiveBroadcastStream()
        .map((event) => (event as num).toDouble());
    return _imageProgressStream!;
  }

  static Future<void> openReader({
    required String id,
    required String sourceKey,
    int initialEp = 0,
    int initialPage = 0,
  }) async {
    await _channel.invokeMethod<void>('open', {
      'id': id,
      'sourceKey': sourceKey,
      'initialEp': initialEp,
      'initialPage': initialPage,
    });
  }

  static void registerHandlers({
    required Future<Map<String, dynamic>> Function(
        String id, String sourceKey) onLoadData,
    required Future<Map<String, dynamic>> Function(
        Map<dynamic, dynamic> args) onLoadChapterImages,
    required Future<Uint8List> Function(
        String key, int ep, int page) onLoadImage,
    required Future<void> Function(
        Map<dynamic, dynamic> args) onUpdateHistory,
    required Future<Map<String, dynamic>> Function() onGetSettings,
    required Future<Map<String, dynamic>> Function(
        String key) onAddImageFavorite,
    required Future<void> Function(
        Map<dynamic, dynamic> args) onRead,
    required Future<void> Function() onClosed,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLoadData':
          final args = call.arguments as Map<dynamic, dynamic>;
          return await onLoadData(
            args['id'] as String,
            args['sourceKey'] as String,
          );
        case 'onLoadChapterImages':
          return await onLoadChapterImages(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'onLoadImage':
          final args = call.arguments as Map<dynamic, dynamic>;
          return await onLoadImage(
            args['key'] as String,
            args['ep'] as int,
            args['page'] as int,
          );
        case 'onUpdateHistory':
          await onUpdateHistory(call.arguments as Map<dynamic, dynamic>);
          return null;
        case 'onGetSettings':
          return await onGetSettings();
        case 'onAddImageFavorite':
          final args = call.arguments as Map<dynamic, dynamic>;
          return await onAddImageFavorite(args['key'] as String);
        case 'onRead':
          await onRead(call.arguments as Map<dynamic, dynamic>);
          return null;
        case 'onClosed':
          await onClosed();
          return null;
        default:
          throw MissingPluginException(
            'No implementation for method ${call.method}',
          );
      }
    });
  }

  static Future<void> notifySettingsChanged(
    String key,
    dynamic value,
  ) async {
    await _channel.invokeMethod<void>('notifySettingsChanged', {
      'key': key,
      'value': value,
    });
  }
}
