import 'dart:io';

class SZArchive {
  static Future<void> extractIsolates(
    String archivePath,
    String outDirPath,
    int numIsolates,
  ) async {
    await _extract7z(archivePath, outDirPath);
  }

  static Future<void> _extract7z(String archivePath, String outDirPath) async {
    var result = await Process.run('7z', ['x', archivePath, '-o$outDirPath', '-y']);
    if (result.exitCode != 0) {
      throw ProcessException(
        '7z',
        ['x', archivePath, '-o$outDirPath'],
        '7z extraction failed: ${result.stderr}',
        result.exitCode,
      );
    }
  }
}
