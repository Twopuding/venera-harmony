import 'dart:io';

class OhosPathProvider {
  static Future<Directory> getApplicationSupportDirectory() async {
    var path = OhosPathProvider._appDataPath;
    var dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getApplicationCacheDirectory() async {
    var path = OhosPathProvider._appCachePath;
    var dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getApplicationDocumentsDirectory() async {
    var path = OhosPathProvider._appDocPath;
    var dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory?> getExternalStorageDirectory() async {
    var path = OhosPathProvider._externalStoragePath;
    if (path == null) return null;
    var dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<Directory>?> getExternalStorageDirectories() async {
    var path = OhosPathProvider._externalStoragePath;
    if (path == null) return null;
    var dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return [dir];
  }

  static String get _appDataPath =>
      Platform.environment['OHOS_APP_DATA_PATH'] ?? '/data/storage/el2/base/files';

  static String get _appCachePath =>
      Platform.environment['OHOS_APP_CACHE_PATH'] ?? '/data/storage/el2/base/cache';

  static String get _appDocPath =>
      Platform.environment['OHOS_APP_DOC_PATH'] ?? '/data/storage/el2/base/files';

  static String? get _externalStoragePath =>
      Platform.environment['OHOS_EXTERNAL_STORAGE_PATH'];
}
