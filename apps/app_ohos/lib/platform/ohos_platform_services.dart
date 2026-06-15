import 'package:flutter/services.dart';

class OhosUrlLauncher {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<bool> launchUrlString(String url) async {
    try {
      var result = await _channel.invokeMethod<bool>('launchUrl', {'url': url});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class OhosSharePlus {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<void> shareText(String text) async {
    await _channel.invokeMethod('shareText', {'text': text});
  }

  static Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? fileNameOverride,
  }) async {
    await _channel.invokeMethod('shareFile', {
      'filePath': filePath,
      'mimeType': mimeType,
      'fileNameOverride': fileNameOverride,
    });
  }

  static Future<void> shareFileFromData({
    required List<int> data,
    required String mimeType,
    required String fileName,
  }) async {
    await _channel.invokeMethod('shareFileFromData', {
      'data': data,
      'mimeType': mimeType,
      'fileName': fileName,
    });
  }
}

class OhosFileDialog {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<String?> pickDirectory() async {
    try {
      var result = await _channel.invokeMethod<String>('pickDirectory');
      return result;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> pickFile({
    List<String>? extensions,
  }) async {
    try {
      var result = await _channel.invokeMethod<String>('pickFile', {
        'extensions': extensions,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> saveFile({
    required String sourceFilePath,
    String? suggestedName,
  }) async {
    try {
      var result = await _channel.invokeMethod<String>('saveFile', {
        'sourceFilePath': sourceFilePath,
        'suggestedName': suggestedName,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }
}

class OhosLocalAuth {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<bool> canCheckBiometrics() async {
    try {
      var result = await _channel.invokeMethod<bool>('canCheckBiometrics');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canCheckFace() async {
    try {
      var result = await _channel.invokeMethod<bool>('checkFaceAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canCheckFingerprint() async {
    try {
      var result = await _channel.invokeMethod<bool>('checkFingerprintAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isDeviceSupported() async {
    try {
      var result = await _channel.invokeMethod<bool>('isDeviceSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      var result = await _channel.invokeMethod<bool>('authenticate', {
        'localizedReason': localizedReason,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticateWithFace({required String localizedReason}) async {
    try {
      var result = await _channel.invokeMethod<bool>('authenticateWithFace', {
        'localizedReason': localizedReason,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticateWithFingerprint({required String localizedReason}) async {
    try {
      var result = await _channel.invokeMethod<bool>('authenticateWithFingerprint', {
        'localizedReason': localizedReason,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticateWithPin({required String localizedReason}) async {
    try {
      var result = await _channel.invokeMethod<bool>('authenticateWithPin', {
        'localizedReason': localizedReason,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class OhosBattery {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<int> get batteryLevel async {
    try {
      var result = await _channel.invokeMethod<int>('getBatteryLevel');
      return result ?? -1;
    } on PlatformException {
      return -1;
    }
  }

  static Future<String> get batteryState async {
    try {
      var result = await _channel.invokeMethod<String>('getBatteryState');
      return result ?? 'unknown';
    } on PlatformException {
      return 'unknown';
    }
  }
}

class OhosScreenOn {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<void> setScreenOn(bool on) async {
    await _channel.invokeMethod('setScreenOn', {'on': on});
  }
}

class OhosProxy {
  static const _channel = MethodChannel('venera/method_channel');

  static Future<String?> getProxy() async {
    try {
      var result = await _channel.invokeMethod<String>('getProxy');
      if (result == null || result == 'No Proxy') return null;
      return result;
    } on PlatformException {
      return null;
    }
  }
}
