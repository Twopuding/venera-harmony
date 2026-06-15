import 'dart:typed_data';

class FileInfo {
  final String? name;
  final bool? isDir;
  final int? size;
  final DateTime? modified;

  const FileInfo({this.name, this.isDir, this.size, this.modified});
}

class WebdavClient {
  Future<List<FileInfo>> readDir(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> remove(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> write(String path, List<int> data) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<Uint8List> read(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> read2File(String remotePath, String localPath) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> mkdir(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> mkdirAll(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> removeDir(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> rename(String path, String newName, {bool overwrite = false}) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> copy(String src, String dest, {bool overwrite = false}) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<void> move(String src, String dest, {bool overwrite = false}) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<bool> exists(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }

  Future<FileInfo?> stat(String path) async {
    throw UnsupportedError('WebDAV not supported on HarmonyOS');
  }
}

WebdavClient newClient(
  String url, {
  String? user,
  String? password,
  dynamic adapter,
}) {
  return WebdavClient();
}

class RHttpAdapter {
  RHttpAdapter();
}
