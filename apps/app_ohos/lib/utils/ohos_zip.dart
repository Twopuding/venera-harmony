import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

class ZipFile {
  final String _path;
  late final ZipEncoder _encoder;
  late final List<_ZipEntry> _entries;
  bool _closed = false;

  ZipFile._(this._path)
      : _encoder = ZipEncoder(),
        _entries = [];

  static ZipFile open(String path) {
    return ZipFile._(path);
  }

  static void openAndExtract(String archivePath, String outDirPath) {
    var file = File(archivePath);
    var bytes = file.readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);
    _extractArchive(archive, outDirPath);
  }

  static Future<void> openAndExtractAsync(
    String archivePath,
    String outDirPath, {
    int numThreads = 4,
  }) async {
    var file = File(archivePath);
    var bytes = await file.readAsBytes();
    var archive = ZipDecoder().decodeBytes(bytes);
    _extractArchive(archive, outDirPath);
  }

  static Future<void> compressFolderAsync(
    String srcPath,
    String outPath, {
    int numThreads = 4,
  }) async {
    compressFolder(srcPath, outPath);
  }

  static void compressFolder(String srcPath, String outPath) {
    var archive = Archive();
    var dir = Directory(srcPath);
    if (!dir.existsSync()) {
      throw FileSystemException('Source directory not found', srcPath);
    }
    _addDirectoryToArchive(archive, dir, srcPath);
    var zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      File(outPath).writeAsBytesSync(zipData);
    }
  }

  void addFile(String entryName, String filePath) {
    if (_closed) throw StateError('ZipFile is closed');
    var file = File(filePath);
    var bytes = file.readAsBytesSync();
    _entries.add(_ZipEntry(entryName, Uint8List.fromList(bytes)));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    var archive = Archive();
    for (var entry in _entries) {
      archive.addFile(ArchiveFile(entry.name, entry.data.length, entry.data));
    }
    var zipData = _encoder.encode(archive);
    if (zipData != null) {
      File(_path).writeAsBytesSync(zipData);
    }
  }

  static void _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String basePath,
  ) {
    for (var entity in dir.listSync(recursive: false)) {
      if (entity is File) {
        var relativePath = entity.path.substring(basePath.length + 1);
        var bytes = entity.readAsBytesSync();
        var name = relativePath.replaceAll('\\', '/');
        archive.addFile(
            ArchiveFile(name, bytes.length, Uint8List.fromList(bytes)));
      } else if (entity is Directory) {
        _addDirectoryToArchive(archive, entity, basePath);
      }
    }
  }

  static void _extractArchive(Archive archive, String outDir) {
    for (var file in archive) {
      var filePath = '$outDir/${file.name.replaceAll('\\', '/')}';
      var outFile = File(filePath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(file.content as List<int>);
    }
  }
}

class _ZipEntry {
  final String name;
  final Uint8List data;
  _ZipEntry(this.name, this.data);
}

Uint8List tdeflCompressData(
  Uint8List data,
  bool wrapWithGzip,
  bool useRawDeflate,
  int level,
) {
  var compressed = GZipEncoder().encode(data, level: level);
  if (compressed != null) {
    return Uint8List.fromList(compressed);
  }
  return data;
}
