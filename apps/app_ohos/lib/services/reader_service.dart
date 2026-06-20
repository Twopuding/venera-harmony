import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';

/// UI-free reader operations for ArkTS ReaderBridge handlers.
class ReaderService {
  static Future<Map<String, dynamic>> loadData(
    String id,
    String sourceKey,
  ) async {
    final comicSource = ComicSource.find(sourceKey);
    final history = HistoryManager().find(
      id,
      ComicType.fromKey(sourceKey),
    );

    if (comicSource == null) {
      final localComic = LocalManager().find(
        id,
        ComicType.fromKey(sourceKey),
      );
      if (localComic == null) {
        return {'error': 'comic not found'};
      }
      final h = history ??
          History.fromModel(model: localComic, ep: 0, page: 0);
      return _readerPropsJson(
        sourceKey: sourceKey,
        id: id,
        name: localComic.title,
        author: localComic.subtitle,
        tags: localComic.tags,
        chapters: localComic.chapters?.toJson(),
        history: h,
      );
    }

    final comic = await comicSource.loadComicInfo!(id);
    if (comic.error) {
      return {'error': comic.errorMessage};
    }
    final h = history ??
        History.fromModel(model: comic.data, ep: 0, page: 0);
    return _readerPropsJson(
      sourceKey: sourceKey,
      id: id,
      name: comic.data.title,
      author: comic.data.findAuthor() ?? '',
      tags: comic.data.plainTags,
      chapters: comic.data.chapters?.toJson(),
      history: h,
    );
  }

  static Map<String, dynamic> _readerPropsJson({
    required String sourceKey,
    required String id,
    required String name,
    required String author,
    required List<String> tags,
    required dynamic chapters,
    required History history,
  }) {
    final chapterList = <Map<String, dynamic>>[];
    if (chapters is Map) {
      var order = 0;
      for (final entry in chapters.entries) {
        if (entry.value is Map) continue;
        chapterList.add({
          'id': entry.key.toString(),
          'name': entry.value.toString(),
          'order': order++,
        });
      }
    }

    return {
      'comicId': id,
      'sourceKey': sourceKey,
      'comicName': name,
      'author': author,
      'tags': tags.join(', '),
      'chapters': chapterList,
      'history': {
        'ep': history.ep,
        'page': history.page,
        'group': history.group,
      },
    };
  }

  static Future<Map<String, dynamic>> loadChapterImages(
    Map<dynamic, dynamic> args,
  ) async {
    final comicId = args['comicId']?.toString() ?? args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final chapterId = args['chapterId']?.toString() ?? '';
    final chapterIndex = (args['chapterIndex'] as num?)?.toInt();

    final type = ComicType.fromKey(sourceKey);
    final chapters = args['chapters'];

    if (type == ComicType.local ||
        LocalManager().isDownloaded(
          comicId,
          type,
          chapterIndex ?? 1,
          chapters != null ? ComicChapters.fromJson(chapters) : null,
        )) {
      try {
        final ep = chapterIndex ?? 1;
        final images = await LocalManager().getImages(comicId, type, ep);
        return {'images': images, 'error': null};
      } catch (e) {
        return {'error': e.toString(), 'images': <String>[]};
      }
    }

    final source = ComicSource.find(sourceKey);
    if (source?.loadComicPages == null) {
      return {'error': 'Source cannot load pages', 'images': <String>[]};
    }

    final res = await source!.loadComicPages!(comicId, chapterId);
    if (res.error) {
      return {'error': res.errorMessage, 'images': <String>[]};
    }
    return {'images': res.data, 'error': null};
  }

  static Future<Uint8List> loadImage(
    String key,
    int ep,
    int page,
  ) async {
    return loadImageFromArgs({
      'key': key,
      'ep': ep,
      'page': page,
    });
  }

  static Future<Uint8List> loadImageFromArgs(
    Map<dynamic, dynamic> args,
  ) async {
    final key = args['key']?.toString() ?? '';
    final ep = (args['ep'] as num?)?.toInt() ?? 1;
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final sourceKey = args['sourceKey']?.toString();
    final comicId = args['comicId']?.toString() ?? '';
    final chapterId = args['chapterId']?.toString() ?? '';

    Uint8List? imageBytes;
    if (key.startsWith('file://')) {
      final file = File(key);
      if (await file.exists()) {
        imageBytes = await file.readAsBytes();
      } else {
        return Uint8List(0);
      }
    } else if (sourceKey != null &&
        sourceKey.isNotEmpty &&
        comicId.isNotEmpty &&
        chapterId.isNotEmpty) {
      await for (final event in ImageDownloader.loadComicImage(
        key,
        sourceKey,
        comicId,
        chapterId,
      )) {
        if (event.imageBytes != null) {
          imageBytes = event.imageBytes;
          break;
        }
      }
    } else {
      await for (final progress in ImageDownloader.loadThumbnail(key, null, null)) {
        if (progress.imageBytes != null) {
          imageBytes = progress.imageBytes;
          break;
        }
      }
    }

    if (imageBytes == null || imageBytes.isEmpty) {
      return Uint8List(0);
    }

    if (appdata.settings['enableCustomImageProcessing'] == true) {
      imageBytes = await _applyCustomImageProcessing(
        imageBytes,
        comicId,
        chapterId,
        page,
        sourceKey,
      );
    }
    return imageBytes;
  }

  static Future<Uint8List> _applyCustomImageProcessing(
    Uint8List imageBytes,
    String cid,
    String eid,
    int page,
    String? sourceKey,
  ) async {
    final script = appdata.settings['customImageProcessing'].toString();
    if (!script.contains('function processImage')) {
      return imageBytes;
    }
    final func = JsEngine().runCode('''
      (() => {
        $script
        return processImage;
      })()
    ''');
    if (func is! JSInvokable) {
      return imageBytes;
    }
    final autoFreeFunc = JSAutoFreeFunction(func);
    final result = autoFreeFunc([imageBytes, cid, eid, page, sourceKey]);
    if (result is Uint8List) {
      return result;
    }
    if (result is Future) {
      final futureResult = await result;
      if (futureResult is Uint8List) {
        return futureResult;
      }
    } else if (result is Map) {
      final image = result['image'];
      if (image is Uint8List) {
        return image;
      }
      if (image is Future) {
        final futureImage = await image;
        if (futureImage is Uint8List) {
          return futureImage;
        }
      }
    }
    return imageBytes;
  }

  static Future<void> updateHistory(Map<dynamic, dynamic> args) async {
    final comicId = args['comicId']?.toString() ?? args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final ep = (args['ep'] as num?)?.toInt() ?? 1;
    final page = (args['page'] as num?)?.toInt() ?? 1;

    final type = ComicType.fromKey(sourceKey);
    var history = HistoryManager().find(comicId, type);
    if (history == null) {
      return;
    }
    history.ep = ep;
    history.page = page;
    history.time = DateTime.now();
    await HistoryManager().addHistoryAsync(history);
  }

  static Future<Map<String, dynamic>> getSettings([
    Map<dynamic, dynamic>? args,
  ]) async {
    final comicId = args?['comicId']?.toString() ?? '';
    final sourceKey = args?['sourceKey']?.toString() ?? '';

    dynamic setting(String key) {
      if (comicId.isNotEmpty && sourceKey.isNotEmpty) {
        return appdata.settings.getReaderSetting(comicId, sourceKey, key);
      }
      return appdata.settings.getDeviceReaderSetting(key);
    }

    return {
      'readerMode': setting('readerMode'),
      'enableTapToTurnPages': setting('enableTapToTurnPages'),
      'reverseTapToTurnPages': setting('reverseTapToTurnPages'),
      'enablePageAnimation': setting('enablePageAnimation'),
      'showPageNumberInReader': setting('showPageNumberInReader'),
      'enableClockAndBatteryInfoInReader':
          setting('enableClockAndBatteryInfoInReader'),
      'enableDoubleTapToZoom': setting('enableDoubleTapToZoom'),
      'enableLongPressToZoom': setting('enableLongPressToZoom'),
      'longPressZoomPosition': setting('longPressZoomPosition'),
      'autoPageTurningInterval': setting('autoPageTurningInterval'),
      'showChapterComments': setting('showChapterComments'),
      'showChapterCommentsAtEnd': setting('showChapterCommentsAtEnd'),
      'limitImageWidth': setting('limitImageWidth'),
      'preloadImageCount': setting('preloadImageCount'),
      'enableTurnPageByVolumeKey': setting('enableTurnPageByVolumeKey'),
      'quickCollectImage': setting('quickCollectImage'),
      'readerScreenPicNumberForLandscape':
          setting('readerScreenPicNumberForLandscape'),
      'readerScreenPicNumberForPortrait':
          setting('readerScreenPicNumberForPortrait'),
      'showSingleImageOnFirstPage': setting('showSingleImageOnFirstPage'),
      'enableCustomImageProcessing': setting('enableCustomImageProcessing'),
      'readerScrollSpeed': setting('readerScrollSpeed'),
      'showSystemStatusBar': setting('showSystemStatusBar'),
      'comicSpecificEnabled': comicId.isNotEmpty && sourceKey.isNotEmpty
          ? appdata.settings.isComicSpecificSettingsEnabled(comicId, sourceKey)
          : false,
      'deviceSpecificEnabled':
          appdata.settings.isDeviceSpecificSettingsEnabled(),
    };
  }
}
