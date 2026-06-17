import 'dart:typed_data';

import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/images.dart';

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
    await for (final progress in ImageDownloader.loadThumbnail(key, null, null)) {
      if (progress.imageBytes != null) {
        return progress.imageBytes!;
      }
    }
    return Uint8List(0);
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

  static Future<Map<String, dynamic>> getSettings() async {
    return {
      'readerMode': appdata.settings['readerMode'],
      'enableTapToTurnPages': appdata.settings['enableTapToTurnPages'],
      'enablePageAnimation': appdata.settings['enablePageAnimation'],
      'showPageNumberInReader': appdata.settings['showPageNumberInReader'],
      'enableClockAndBatteryInfoInReader':
          appdata.settings['enableClockAndBatteryInfoInReader'],
    };
  }
}
