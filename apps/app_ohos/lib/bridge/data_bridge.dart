import 'dart:async';

import 'package:flutter/services.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/services/data_service.dart';

class DataBridge {
  static const MethodChannel _channel = MethodChannel('com.venera.data');
  static const EventChannel _eventChannel =
      EventChannel('com.venera.data/events');

  static Stream<Map<String, dynamic>>? _events;

  static Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{'type': event.toString()};
    });
    return _events!;
  }

  static void registerHandlers() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exploreLoadPage':
          return await DataService.exploreLoadPage(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getHistory':
          return DataService.getHistory();
        case 'getSettings':
          return DataService.getSettings();
        case 'setSetting':
          return DataService.setSetting(
            call.arguments as Map<dynamic, dynamic>,
          );
        default:
          throw MissingPluginException(
            'No implementation for method ${call.method}',
          );
      }
    });
  }

  static void notifySettingsChanged(String key, dynamic value) {
    _channel.invokeMethod<void>('notifySettingsChanged', {
      'key': key,
      'value': value,
    });
  }
}

void installDataBridgeSettingsListener() {
  appdata.settings.addListener(() {
    DataBridge.notifySettingsChanged('_batch', null);
  });
}
