import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

class OhosPlatform {
  static bool get isOhos {
    try {
      return Platform.isOhos;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {
    if (!isOhos) return;
    _initSqlite3();
    await _initDirectories();
  }

  static void _initSqlite3() {
    open.overrideForAll(() {
      return DynamicLibrary.open('libsqlite3.so');
    });
  }

  static Future<void> _initDirectories() async {
    var dataPath = applicationSupportPath;
    var cachePath = applicationCachePath;
    var dataDir = Directory(dataPath);
    var cacheDir = Directory(cachePath);
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  static String get applicationSupportPath {
    return Platform.environment['OHOS_APP_DATA_PATH'] ??
        '/data/storage/el2/base/files';
  }

  static String get applicationCachePath {
    return Platform.environment['OHOS_APP_CACHE_PATH'] ??
        '/data/storage/el2/base/cache';
  }

  static String get temporaryPath {
    return Platform.environment['OHOS_APP_CACHE_PATH'] ??
        '/data/storage/el2/base/cache/temp';
  }

  static String get applicationDocumentsPath {
    return Platform.environment['OHOS_APP_DOC_PATH'] ??
        '/data/storage/el2/base/files';
  }

  static String? get externalStoragePath {
    return Platform.environment['OHOS_EXTERNAL_STORAGE_PATH'];
  }
}
