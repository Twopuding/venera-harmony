import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/js_engine.dart';

/// Forwards comic-source JS UI calls to ArkTS when native shell is active.
class JsUiChannel {
  static const MethodChannel _channel = MethodChannel('com.venera.jsui');

  static int _nextId = 0;
  static final Map<int, List<JSAutoFreeFunction>> _dialogActions = {};
  static final Map<int, JSAutoFreeFunction?> _inputValidators = {};
  static final Map<int, Completer<String?>> _inputCompleters = {};
  static final Map<int, Completer<int?>> _selectCompleters = {};

  static bool get useNativeUi =>
      App.isOhos && appdata.settings['useNativeUi'] != false;

  static void registerHandlers() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDialogAction':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = (args['id'] as num).toInt();
          final index = (args['actionIndex'] as num).toInt();
          final actions = _dialogActions.remove(id);
          if (actions != null && index >= 0 && index < actions.length) {
            actions[index].call([]);
          }
          return null;
        case 'onInputResult':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = (args['id'] as num).toInt();
          final value = args['value']?.toString();
          final validator = _inputValidators.remove(id);
          final completer = _inputCompleters.remove(id);
          if (validator != null && value != null) {
            final res = validator.call([value]);
            if (res != null) {
              return {'error': res.toString()};
            }
          }
          completer?.complete(value);
          return null;
        case 'onSelectResult':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = (args['id'] as num).toInt();
          final index = args['index'];
          final completer = _selectCompleters.remove(id);
          if (index is num) {
            completer?.complete(index.toInt());
          } else {
            completer?.complete(null);
          }
          return null;
        case 'onLoadingCancel':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = (args['id'] as num).toInt();
          final onCancel = _loadingCancelCallbacks.remove(id);
          onCancel?.call([]);
          return null;
        default:
          throw MissingPluginException(
            'No implementation for method ${call.method}',
          );
      }
    });
  }

  static final Map<int, JSAutoFreeFunction> _loadingCancelCallbacks = {};

  static Future<dynamic> handleUIMessage(Map<String, dynamic> message) async {
    switch (message['function']) {
      case 'showMessage':
        final m = message['message'];
        if (m.toString().isNotEmpty) {
          await _channel.invokeMethod<void>('showMessage', {
            'message': m.toString(),
          });
        }
        return null;
      case 'showDialog':
        return _showDialog(message);
      case 'launchUrl':
        return null;
      case 'showLoading':
        final onCancel = message['onCancel'];
        JSAutoFreeFunction? func;
        if (onCancel is JSInvokable) {
          func = JSAutoFreeFunction(onCancel);
        }
        return _showLoading(func);
      case 'cancelLoading':
        final id = message['id'];
        if (id is int) {
          await _channel.invokeMethod<void>('cancelLoading', {'id': id});
        }
        return null;
      case 'showInputDialog':
        return _showInputDialog(message);
      case 'showSelectDialog':
        return _showSelectDialog(message);
      default:
        return null;
    }
  }

  static Future<void> _showDialog(Map<String, dynamic> message) async {
    final id = _nextId++;
    final actions = <JSAutoFreeFunction>[];
    final actionMeta = <Map<String, String>>[];
    for (final action in message['actions'] as List<dynamic>? ?? []) {
      if (action is! Map) {
        continue;
      }
      if (action['callback'] is! JSInvokable) {
        continue;
      }
      actions.add(JSAutoFreeFunction(action['callback'] as JSInvokable));
      actionMeta.add({
        'text': action['text']?.toString() ?? 'OK',
        'style': (action['style'] ?? 'text').toString(),
      });
    }
    if (actions.isEmpty) {
      actionMeta.add({'text': 'OK', 'style': 'text'});
    } else {
      _dialogActions[id] = actions;
    }
    await _channel.invokeMethod<void>('showDialog', {
      'id': id,
      'title': message['title']?.toString() ?? '',
      'content': message['content']?.toString() ?? '',
      'actions': actionMeta,
    });
  }

  static Future<int> _showLoading(JSAutoFreeFunction? onCancel) async {
    final id = _nextId++;
    if (onCancel != null) {
      _loadingCancelCallbacks[id] = onCancel;
    }
    await _channel.invokeMethod<void>('showLoading', {
      'id': id,
      'cancellable': onCancel != null,
    });
    return id;
  }

  static Future<String?> _showInputDialog(Map<String, dynamic> message) async {
    final id = _nextId++;
    final title = message['title']?.toString() ?? '';
    final validator = message['validator'];
    JSAutoFreeFunction? func;
    if (validator is JSInvokable) {
      func = JSAutoFreeFunction(validator);
    }
    _inputValidators[id] = func;
    final completer = Completer<String?>();
    _inputCompleters[id] = completer;
    await _channel.invokeMethod<void>('showInputDialog', {
      'id': id,
      'title': title,
    });
    return completer.future;
  }

  static Future<int?> _showSelectDialog(Map<String, dynamic> message) async {
    final id = _nextId++;
    final title = message['title']?.toString() ?? '';
    final options = (message['options'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final initialIndex = message['initialIndex'];
    final completer = Completer<int?>();
    _selectCompleters[id] = completer;
    await _channel.invokeMethod<void>('showSelectDialog', {
      'id': id,
      'title': title,
      'options': options,
      'initialIndex': initialIndex is int ? initialIndex : 0,
    });
    return completer.future;
  }
}
