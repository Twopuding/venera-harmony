import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/follow_updates.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/download.dart';
import 'package:venera/network/images.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/data.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/import_comic.dart';
import 'package:venera/foundation/log.dart';
import 'package:yaml/yaml.dart';

/// UI-free data operations for ArkTS DataBridge handlers.
class DataService {
  /// Suppresses native settings notifications while a bridge write is in flight.
  static bool suppressSettingsNotify = false;

  static Map<String, dynamic> comicToJson(Comic comic) => comic.toJson();

  static Map<String, dynamic> historyToJson(History history) {
    return {
      'id': history.id,
      'title': history.title,
      'subtitle': history.subtitle,
      'cover': history.cover,
      'ep': history.ep,
      'page': history.page,
      'group': history.group,
      'sourceKey': history.sourceKey,
      'time': history.time.millisecondsSinceEpoch,
      'maxPage': history.maxPage,
      'description': history.description,
    };
  }

  static Map<String, dynamic> favoriteToJson(FavoriteItem item) {
    return {
      'id': item.id,
      'title': item.name,
      'name': item.name,
      'author': item.author,
      'cover': item.coverPath,
      'coverPath': item.coverPath,
      'sourceKey': item.type.sourceKey,
      'tags': item.tags,
      'time': item.time,
    };
  }

  static Map<String, dynamic> localComicToJson(LocalComic comic) {
    return {
      'id': comic.id,
      'title': comic.title,
      'subtitle': comic.subtitle,
      'cover': comic.cover,
      'sourceKey': comic.comicType.sourceKey,
      'tags': comic.tags,
      'description': comic.description,
    };
  }

  static Map<String, dynamic> comicDetailsToJson(ComicDetails details) {
    return {
      ...details.toJson(),
      'sourceKey': details.sourceKey,
      'chapters': details.chapters?.toJson(),
      'recommend': details.recommend?.map(comicToJson).toList(),
    };
  }

  static Future<Map<String, dynamic>> exploreLoadPage(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final pageTitle = args['pageTitle']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;

    final source = ComicSource.find(sourceKey);
    if (source == null) {
      return {'error': 'Comic source not found: $sourceKey'};
    }

    ExplorePageData? data;
    for (final item in source.explorePages) {
      if (item.title == pageTitle) {
        data = item;
        break;
      }
    }
    if (data == null) {
      return {'error': 'Explore page not found: $pageTitle'};
    }

    if (data.loadPage != null) {
      final res = await data.loadPage!(page);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map(comicToJson).toList(),
        'hasMore': res.subData,
      };
    }

    if (data.loadNext != null) {
      final next = page <= 1 ? null : args['next']?.toString();
      final res = await data.loadNext!(next);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map(comicToJson).toList(),
        'hasMore': res.subData,
        'next': res.subData is String ? res.subData : null,
      };
    }

    return {'error': 'Explore page has no loader: $pageTitle'};
  }

  static Map<String, dynamic> getHistory() {
    final histories = HistoryManager().getAll();
    return {
      'histories': histories.map(historyToJson).toList(),
    };
  }

  static Map<String, dynamic> pingBackend() {
    return {'ok': HistoryManager().isInitialized};
  }

  static Map<String, dynamic> deleteHistory(Map<dynamic, dynamic> args) {
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (id.isEmpty || sourceKey.isEmpty) {
      return {'error': 'Missing id or sourceKey'};
    }
    HistoryManager().remove(id, ComicType.fromKey(sourceKey));
    return {'ok': true};
  }

  static Map<String, dynamic> getSettings() {
    final settings = Map<String, dynamic>.from(
      appdata.toJson()['settings'] as Map<String, dynamic>,
    );
    settings['webdavAutoSync'] = appdata.implicitData['webdavAutoSync'] ?? true;
    return settings;
  }

  static String getSettingsJson() {
    return jsonEncode(getSettings());
  }

  static dynamic _normalizeBridgeValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value == 1 || value == '1' || value == 'true') {
      return true;
    }
    if (value == 0 || value == '0' || value == 'false') {
      return false;
    }
    return value;
  }

  static Object setSetting(Map<dynamic, dynamic> args) {
    final key = args['key']?.toString();
    if (key == null || key.isEmpty) {
      return {'error': 'Missing setting key'};
    }
    final value = _normalizeBridgeValue(args['value']);
    debugPrint('DataService.setSetting key=$key value=$value (${value.runtimeType})');
    if (key == 'webdavAutoSync') {
      appdata.implicitData['webdavAutoSync'] = value == true;
      appdata.writeImplicitData();
      return 'ok';
    }
    suppressSettingsNotify = true;
    try {
      appdata.settings[key] = value;
      appdata.saveData().catchError((Object e, StackTrace s) {
        Log.error('setSetting', 'saveData failed for $key: $e', s);
      });
      return 'ok';
    } catch (e, s) {
      Log.error('setSetting', 'Failed to apply $key: $e', s);
      return {'error': e.toString()};
    } finally {
      suppressSettingsNotify = false;
    }
  }

  static Object setReaderSetting(Map<dynamic, dynamic> args) {
    final comicId = args['comicId']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final key = args['key']?.toString() ?? '';
    if (comicId.isEmpty || sourceKey.isEmpty || key.isEmpty) {
      return {'error': 'Missing comicId, sourceKey, or key'};
    }
    final value = _normalizeBridgeValue(args['value']);
    suppressSettingsNotify = true;
    try {
      appdata.settings.setReaderSetting(comicId, sourceKey, key, value);
      appdata.saveData().catchError((Object e, StackTrace s) {
        Log.error('setReaderSetting', 'saveData failed for $key: $e', s);
      });
      return 'ok';
    } catch (e, s) {
      Log.error('setReaderSetting', 'Failed to apply $key: $e', s);
      return {'error': e.toString()};
    } finally {
      suppressSettingsNotify = false;
    }
  }

  static Map<String, dynamic> setComicSpecificSettingsEnabled(
    Map<dynamic, dynamic> args,
  ) {
    final comicId = args['comicId']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (comicId.isEmpty || sourceKey.isEmpty) {
      return {'error': 'Missing comicId or sourceKey'};
    }
    appdata.settings.setEnabledComicSpecificSettings(
      comicId,
      sourceKey,
      args['enabled'] == true,
    );
    appdata.saveData();
    return {'ok': true};
  }

  static void validateComicSourcePages() {
    final explorePages = List.from(appdata.settings['explore_pages'] as List);
    final categoryPages = List.from(appdata.settings['categories'] as List);
    final networkFavorites = List.from(appdata.settings['favorites'] as List);

    final totalExplorePages = ComicSource.all()
        .map((e) => e.explorePages.map((p) => p.title))
        .expand((element) => element)
        .toList();
    final totalCategoryPages = ComicSource.all()
        .map((e) => e.categoryData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();
    final totalNetworkFavorites = ComicSource.all()
        .map((e) => e.favoriteData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();

    for (final page in List.from(explorePages)) {
      if (!totalExplorePages.contains(page)) {
        explorePages.remove(page);
      }
    }
    for (final page in List.from(categoryPages)) {
      if (!totalCategoryPages.contains(page)) {
        categoryPages.remove(page);
      }
    }
    for (final page in List.from(networkFavorites)) {
      if (!totalNetworkFavorites.contains(page)) {
        networkFavorites.remove(page);
      }
    }

    appdata.settings['explore_pages'] = explorePages.toSet().toList();
    appdata.settings['categories'] = categoryPages.toSet().toList();
    appdata.settings['favorites'] = networkFavorites.toSet().toList();
    appdata.saveData();
  }

  static void addAllPagesWithComicSource(ComicSource source) {
    final explorePages = List.from(appdata.settings['explore_pages'] as List);
    final categoryPages = List.from(appdata.settings['categories'] as List);
    final networkFavorites = List.from(appdata.settings['favorites'] as List);
    final searchPages = List.from(appdata.settings['searchSources'] as List);

    if (source.explorePages.isNotEmpty) {
      for (final page in source.explorePages) {
        if (!explorePages.contains(page.title)) {
          explorePages.add(page.title);
        }
      }
    }
    if (source.categoryData != null &&
        !categoryPages.contains(source.categoryData!.key)) {
      categoryPages.add(source.categoryData!.key);
    }
    if (source.favoriteData != null &&
        !networkFavorites.contains(source.favoriteData!.key)) {
      networkFavorites.add(source.favoriteData!.key);
    }
    if (source.searchPageData != null && !searchPages.contains(source.key)) {
      searchPages.add(source.key);
    }

    appdata.settings['explore_pages'] = explorePages.toSet().toList();
    appdata.settings['categories'] = categoryPages.toSet().toList();
    appdata.settings['favorites'] = networkFavorites.toSet().toList();
    appdata.settings['searchSources'] = searchPages.toSet().toList();
    appdata.saveData();
  }

  static Map<String, dynamic> getComicSources() {
    return {
      'sources': ComicSource.all().map((s) {
        final remoteVersion = ComicSourceManager().availableUpdates[s.key];
        final hasUpdate = remoteVersion != null &&
            _compareSemVer(remoteVersion, s.version);
        return {
          'key': s.key,
          'name': s.name,
          'version': s.version,
          'remoteVersion': remoteVersion,
          'hasUpdate': hasUpdate,
          'hasSearch': s.searchPageData != null,
          'hasCategory': s.categoryData != null,
          'explorePages': s.explorePages.map((e) => e.title).toList(),
          'categoryKey': s.categoryData?.key,
          'categoryTitle': s.categoryData?.title,
          'favoriteKey': s.favoriteData?.key,
          'favoriteTitle': s.favoriteData?.title,
          'hasNetworkFavorite': s.favoriteData?.loadComic != null,
          'hasAccount': s.account != null,
          'isLogged': s.isLogged,
          'loginWebsite': s.account?.loginWebsite,
        };
      }).toList(),
      'updateCount': ComicSource.all().where((s) {
        final remote = ComicSourceManager().availableUpdates[s.key];
        return remote != null && _compareSemVer(remote, s.version);
      }).length,
    };
  }

  static Map<String, dynamic> getExploreConfig() {
    final allTitles = ComicSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((p) => p.title))
        .toList();
    final pages = List<String>.from(appdata.settings['explore_pages'] as List)
        .where((e) => allTitles.contains(e))
        .toList();
    final pageSources = <Map<String, String>>[];
    for (final title in pages) {
      for (final source in ComicSource.all()) {
        if (source.explorePages.any((p) => p.title == title)) {
          pageSources.add({'title': title, 'sourceKey': source.key});
          break;
        }
      }
    }
    return {'pages': pages, 'pageSources': pageSources};
  }

  static Map<String, dynamic> getCategoryConfig() {
    final allKeys = ComicSource.all()
        .map((e) => e.categoryData?.key)
        .whereType<String>()
        .toList();
    final categories = List<String>.from(appdata.settings['categories'] as List)
        .whereType<String>()
        .where((e) => allKeys.contains(e))
        .toList();
    final categoryMeta = <Map<String, String>>[];
    for (final key in categories) {
      for (final source in ComicSource.all()) {
        if (source.categoryData?.key == key) {
          categoryMeta.add({
            'key': key,
            'title': source.categoryData!.title,
            'sourceKey': source.key,
          });
          break;
        }
      }
    }
    return {'categories': categories, 'categoryMeta': categoryMeta};
  }

  static Map<String, dynamic> getCategoryParts(Map<dynamic, dynamic> args) {
    final key = args['key']?.toString() ?? '';
    CategoryData? data;
    for (final source in ComicSource.all()) {
      if (source.categoryData?.key == key) {
        data = source.categoryData;
        break;
      }
    }
    if (data == null) {
      return {'error': 'Category not found: $key'};
    }
    final parts = data.categories.map((part) {
      return {
        'title': part.title,
        'enableRandom': part.enableRandom,
        'items': part.categories
            .map((item) => {
                  'label': item.label,
                  'target': {
                    'sourceKey': item.target.sourceKey,
                    'page': item.target.page,
                    'attributes': item.target.attributes,
                  },
                })
            .toList(),
      };
    }).toList();
    return {
      'key': data.key,
      'title': data.title,
      'enableRankingPage': data.enableRankingPage,
      'buttons': data.buttons.map((b) => {'label': b.label}).toList(),
      'parts': parts,
    };
  }

  static Future<Map<String, dynamic>> categoryLoadPage(
    Map<dynamic, dynamic> args,
  ) async {
    final categoryKey = args['categoryKey']?.toString() ?? '';
    final category = args['category']?.toString() ?? '';
    final param = args['param']?.toString();
    final optionsValue = (args['options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final pageNum = (args['page'] as num?)?.toInt() ?? 1;

    ComicSource? source;
    CategoryComicsData? data;
    for (final s in ComicSource.all()) {
      if (s.categoryData?.key == categoryKey) {
        source = s;
        data = s.categoryComicsData;
        break;
      }
    }
    if (source == null || data == null) {
      return {'error': 'Category comics not found: $categoryKey'};
    }

    final res = await data.load(category, param, optionsValue, pageNum);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {
      'comics': res.data.map(comicToJson).toList(),
      'hasMore': res.subData,
    };
  }

  static Future<Map<String, dynamic>> search(Map<dynamic, dynamic> args) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final keyword = args['keyword']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final optionList = (args['options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final option = args['option']?.toString() ?? '';
    final searchOptions =
        optionList.isNotEmpty ? optionList : (option.isNotEmpty ? [option] : <String>[]);

    final source = ComicSource.find(sourceKey);
    final searchData = source?.searchPageData;
    if (searchData == null) {
      return {'error': 'Search not available for $sourceKey'};
    }

    if (keyword.isNotEmpty) {
      appdata.addSearchHistory(keyword);
      appdata.saveData();
    }

    if (searchData.loadPage != null) {
      final res = await searchData.loadPage!(keyword, page, searchOptions);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map(comicToJson).toList(),
        'hasMore': res.subData,
      };
    }

    if (searchData.loadNext != null) {
      final next = page <= 1 ? null : args['next']?.toString();
      final res = await searchData.loadNext!(keyword, next, searchOptions);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map(comicToJson).toList(),
        'hasMore': res.subData,
        'next': res.subData is String ? res.subData : null,
      };
    }

    return {'error': 'Search loader not configured'};
  }

  static Map<String, dynamic> resolveComicLink(Map<dynamic, dynamic> args) {
    final url = args['url']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return {'found': false};
    }
    for (final source in ComicSource.all()) {
      final handler = source.linkHandler;
      if (handler != null && handler.domains.contains(uri.host)) {
        final id = handler.linkToId(url);
        if (id != null) {
          return {'found': true, 'comicId': id, 'sourceKey': source.key};
        }
      }
    }
    return {'found': false};
  }

  static Map<String, dynamic> getSearchOptions(Map<dynamic, dynamic> args) {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    final searchOptions = source?.searchPageData?.searchOptions;
    if (searchOptions == null || searchOptions.isEmpty) {
      return {'options': <String, String>{}};
    }
    return {'options': Map<String, String>.from(searchOptions.first.options)};
  }

  static Map<String, dynamic> getSearchHistory() {
    return {
      'history': List<String>.from(appdata.settings['searchHistory'] ?? []),
    };
  }

  static Future<Map<String, dynamic>> loadComicInfo(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';

    final type = ComicType.fromKey(sourceKey);
    if (type == ComicType.local || LocalManager().find(id, type) != null) {
      final local = LocalManager().find(id, type);
      if (local == null) {
        return {'error': 'Local comic not found'};
      }
      return {
        'comic': {
          'id': local.id,
          'title': local.title,
          'subTitle': local.subtitle,
          'cover': local.cover,
          'description': local.description,
          'tags': local.tags,
          'sourceKey': sourceKey,
          'chapters': local.chapters?.toJson(),
          'isLocal': true,
        },
      };
    }

    final source = ComicSource.find(sourceKey);
    if (source?.loadComicInfo == null) {
      return {'error': 'Cannot load comic info'};
    }

    final res = await source!.loadComicInfo!(id);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'comic': comicDetailsToJson(res.data)};
  }

  static Future<Map<String, dynamic>> likeComic(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final isLiking = args['isLiking'] as bool? ?? true;
    final source = ComicSource.find(sourceKey);
    if (source?.likeOrUnlikeComic == null) {
      return {'error': 'Like not supported'};
    }
    final res = await source!.likeOrUnlikeComic!(id, isLiking);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'ok': true, 'isLiked': isLiking};
  }

  static Map<String, dynamic> getFavoriteFolders() {
    return {
      'folders': LocalFavoritesManager().folderNames,
    };
  }

  static Map<String, dynamic> getFavorites(Map<dynamic, dynamic> args) {
    final folder = args['folder']?.toString() ?? '';
    final isNetwork = args['isNetwork'] == true;

    if (isNetwork) {
      final source = ComicSource.find(folder);
      if (source?.favoriteData == null) {
        return {'error': 'Network favorites not available'};
      }
      return {'error': 'Use loadNetworkFavorites async method'};
    }

    if (!LocalFavoritesManager().existsFolder(folder)) {
      return {'comics': <Map<String, dynamic>>[]};
    }

    final comics = _filterFavoriteComics(
      LocalFavoritesManager().getFolderComics(folder),
      args['readFilter']?.toString(),
    );
    return {
      'comics': comics.map(favoriteToJson).toList(),
    };
  }

  static List<FavoriteItem> _filterFavoriteComics(
    List<FavoriteItem> comics,
    String? readFilter,
  ) {
    if (readFilter == null || readFilter == 'All') {
      return comics;
    }
    return comics.where((comic) {
      final history = HistoryManager().find(comic.id, comic.type);
      if (readFilter == 'UnCompleted') {
        return history == null || history.page != history.maxPage;
      }
      if (readFilter == 'Completed') {
        return history != null &&
            (history.maxPage ?? 0) > 0 &&
            history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  static Future<Map<String, dynamic>> loadNetworkFavorites(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final folder = args['folder']?.toString();
    final source = ComicSource.find(sourceKey);
    final favoriteData = source?.favoriteData;
    if (favoriteData?.loadComic == null) {
      return {'error': 'Network favorites not available'};
    }
    final res = await favoriteData!.loadComic!(page, folder);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {
      'comics': res.data.map((c) {
        return {
          'id': c.id,
          'title': c.title,
          'cover': c.cover,
          'sourceKey': sourceKey,
          'favoriteId': c.favoriteId,
        };
      }).toList(),
      'hasMore': res.subData,
    };
  }

  static Map<String, dynamic> getLocalComics() {
    final comics = LocalManager().getComics(LocalSortType.timeDesc);
    return {
      'comics': comics.map(localComicToJson).toList(),
    };
  }

  static Map<String, dynamic> getDownloadTasks() {
    final tasks = LocalManager().downloadingTasks;
    return {
      'tasks': tasks.map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'progress': t.progress,
          'message': t.message,
          'cover': t.cover,
          'isPaused': t.isPaused,
          'isError': t.isError,
          'speed': t.speed,
        };
      }).toList(),
    };
  }

  static Future<Map<String, dynamic>> webdavUpload() async {
    try {
      await DataSync().uploadData();
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> webdavDownload() async {
    try {
      await DataSync().downloadData();
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> openReaderParams(Map<dynamic, dynamic> args) {
    return {
      'comicId': args['id']?.toString() ?? args['comicId']?.toString() ?? '',
      'sourceKey': args['sourceKey']?.toString() ?? '',
      'initialEp': args['initialEp']?.toString() ?? '1',
      'initialPage': (args['initialPage'] as num?)?.toInt() ?? 1,
    };
  }

  static Future<Map<String, dynamic>> loadCoverImage(
    Map<dynamic, dynamic> args,
  ) async {
    final url = args['url']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString();
    final cid = args['cid']?.toString();
    final fallback = args['fallbackToLocalCover'] == true;
    if (url.isEmpty) {
      return {'error': 'Empty cover url'};
    }
    try {
      if (url.startsWith('file://')) {
        final file = File(url.substring(7));
        return {'base64': base64Encode(await file.readAsBytes())};
      }
      await for (final progress in ImageDownloader.loadThumbnail(
        url,
        sourceKey,
        cid,
      )) {
        if (progress.imageBytes != null) {
          return {'base64': base64Encode(progress.imageBytes!)};
        }
      }
      if (fallback && sourceKey != null && cid != null) {
        final localComic = LocalManager().find(
          cid,
          ComicType.fromKey(sourceKey),
        );
        if (localComic != null && await localComic.coverFile.exists()) {
          return {
            'base64': base64Encode(await localComic.coverFile.readAsBytes()),
          };
        }
      }
      return {'error': 'Failed to load cover'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> clearSearchHistory() {
    appdata.clearSearchHistory();
    appdata.saveData();
    return {'ok': true};
  }

  static Map<String, dynamic> clearHistory() {
    final all = HistoryManager().getAll();
    for (final h in all) {
      HistoryManager().remove(h.id, ComicType.fromKey(h.sourceKey));
    }
    return {'ok': true};
  }

  static Map<String, dynamic> getSyncStatus() {
    final sync = DataSync();
    return {
      'enabled': sync.isEnabled,
      'isUploading': sync.isUploading,
      'isDownloading': sync.isDownloading,
      'lastError': sync.lastError,
    };
  }

  static Map<String, dynamic> getFollowUpdatesSummary() {
    final folder = appdata.settings['followUpdatesFolder']?.toString();
    if (folder == null || !LocalFavoritesManager().existsFolder(folder)) {
      return {'folder': null, 'count': 0};
    }
    return {
      'folder': folder,
      'count': LocalFavoritesManager().countUpdates(folder),
    };
  }

  static Map<String, dynamic> getFollowUpdatesList() {
    final folder = appdata.settings['followUpdatesFolder']?.toString();
    if (folder == null || !LocalFavoritesManager().existsFolder(folder)) {
      return {'comics': <Map<String, dynamic>>[]};
    }
    final comics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder);
    return {
      'comics': comics.map((c) {
        return {
          'id': c.id,
          'title': c.name,
          'cover': c.coverPath,
          'sourceKey': c.type.sourceKey,
          'hasNewUpdate': c.hasNewUpdate,
          'updateTime': c.updateTime,
          'author': c.author,
        };
      }).toList(),
    };
  }

  static Future<Map<String, dynamic>> checkFollowUpdates() async {
    final folder = appdata.settings['followUpdatesFolder']?.toString();
    if (folder == null || !LocalFavoritesManager().existsFolder(folder)) {
      return {'error': 'Not configured'};
    }
    var updated = 0;
    await for (final progress in updateFolder(folder, true)) {
      updated = progress.updated;
    }
    return {'ok': true, 'updated': updated};
  }

  static Map<String, dynamic> setFollowUpdatesFolder(
    Map<dynamic, dynamic> args,
  ) {
    final folder = args['folder']?.toString();
    if (folder == null || folder.isEmpty) {
      appdata.settings['followUpdatesFolder'] = null;
      appdata.saveData();
      return {'ok': true};
    }
    if (!LocalFavoritesManager().existsFolder(folder)) {
      return {'ok': false, 'error': 'Folder not found'};
    }
    LocalFavoritesManager().prepareTableForFollowUpdates(folder);
    appdata.settings['followUpdatesFolder'] = folder;
    appdata.saveData();
    return {'ok': true};
  }

  static Map<String, dynamic> markFavoriteAsRead(Map<dynamic, dynamic> args) {
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (id.isEmpty) {
      return {'error': 'Missing id'};
    }
    LocalFavoritesManager().markAsRead(id, ComicType.fromKey(sourceKey));
    return {'ok': true};
  }

  static Map<String, dynamic> getFavoriteFolderCounts() {
    final mgr = LocalFavoritesManager();
    final counts = <String, int>{};
    for (final folder in mgr.folderNames) {
      counts[folder] = mgr.folderComics(folder);
    }
    return {'counts': counts, 'folders': mgr.folderNames};
  }

  static Map<String, dynamic> createFavoriteFolder(Map<dynamic, dynamic> args) {
    final name = args['name']?.toString() ?? '';
    if (name.isEmpty) {
      return {'error': 'Missing folder name'};
    }
    try {
      final folder = LocalFavoritesManager().createFolder(name);
      return {'ok': true, 'folder': folder};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> deleteFavoriteFolder(Map<dynamic, dynamic> args) {
    final name = args['name']?.toString() ?? '';
    if (name.isEmpty) {
      return {'error': 'Missing folder name'};
    }
    try {
      LocalFavoritesManager().deleteFolder(name);
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> addFavorite(Map<dynamic, dynamic> args) {
    final folder = args['folder']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final title = args['title']?.toString() ?? '';
    final cover = args['cover']?.toString() ?? '';
    final author = args['author']?.toString() ?? '';
    final tags = (args['tags'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    if (folder.isEmpty || id.isEmpty) {
      return {'error': 'Missing folder or id'};
    }
    final item = FavoriteItem(
      id: id,
      name: title,
      coverPath: cover,
      author: author,
      type: ComicType.fromKey(sourceKey),
      tags: tags,
    );
    final ok = LocalFavoritesManager().addComic(
      folder,
      item,
      null,
      args['updateTime']?.toString(),
    );
    return {'ok': ok};
  }

  static Map<String, dynamic> removeFavorite(Map<dynamic, dynamic> args) {
    final folder = args['folder']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (folder.isEmpty || id.isEmpty) {
      return {'error': 'Missing folder or id'};
    }
    LocalFavoritesManager().deleteComicWithId(
      folder,
      id,
      ComicType.fromKey(sourceKey),
    );
    return {'ok': true};
  }

  static Map<String, dynamic> reorderFavorites(Map<dynamic, dynamic> args) {
    final folder = args['folder']?.toString() ?? '';
    final ids = (args['ids'] as List?)?.map((e) => e.toString()).toList();
    if (folder.isEmpty || ids == null) {
      return {'error': 'Missing folder or ids'};
    }
    final comics = LocalFavoritesManager().getFolderComics(folder);
    final ordered = <FavoriteItem>[];
    for (final id in ids) {
      final comic = comics.firstWhere(
        (c) => c.id == id,
        orElse: () => comics.first,
      );
      if (comic.id == id) {
        ordered.add(comic);
      }
    }
    for (final c in comics) {
      if (!ids.contains(c.id)) {
        ordered.add(c);
      }
    }
    LocalFavoritesManager().reorder(ordered, folder);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> loadFavoriteFoldersRemote(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final comicId = args['comicId']?.toString();
    final source = ComicSource.find(sourceKey);
    final loadFolders = source?.favoriteData?.loadFolders;
    if (loadFolders == null) {
      return {'error': 'Remote folders not available'};
    }
    final res = await loadFolders(comicId);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'folders': res.data};
  }

  static Map<String, dynamic> pauseDownload(Map<dynamic, dynamic> args) {
    final index = (args['index'] as num?)?.toInt() ?? 0;
    final tasks = LocalManager().downloadingTasks;
    if (index < 0 || index >= tasks.length) {
      return {'error': 'Invalid task index'};
    }
    tasks[index].pause();
    return {'ok': true};
  }

  static Map<String, dynamic> resumeDownload(Map<dynamic, dynamic> args) {
    final index = (args['index'] as num?)?.toInt() ?? 0;
    final tasks = LocalManager().downloadingTasks;
    if (index < 0 || index >= tasks.length) {
      return {'error': 'Invalid task index'};
    }
    tasks[index].resume();
    return {'ok': true};
  }

  static Map<String, dynamic> cancelDownload(Map<dynamic, dynamic> args) {
    final index = (args['index'] as num?)?.toInt() ?? 0;
    final tasks = LocalManager().downloadingTasks;
    if (index < 0 || index >= tasks.length) {
      return {'error': 'Invalid task index'};
    }
    tasks[index].cancel();
    return {'ok': true};
  }

  static Map<String, dynamic> moveDownloadToFirst(Map<dynamic, dynamic> args) {
    final index = (args['index'] as num?)?.toInt() ?? 0;
    final tasks = LocalManager().downloadingTasks;
    if (index < 0 || index >= tasks.length) {
      return {'error': 'Invalid task index'};
    }
    LocalManager().moveToFirst(tasks[index]);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> aggregatedSearch(
    Map<dynamic, dynamic> args,
  ) async {
    final keyword = args['keyword']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    if (keyword.isEmpty) {
      return {'results': <Map<String, dynamic>>[]};
    }
    final all = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    final settings = List<String>.from(
      (appdata.settings['searchSources'] as List?)?.map((e) => e.toString()) ??
          [],
    );
    final sourceKeys = settings.where(all.contains).toList();
    final results = <Map<String, dynamic>>[];
    for (final key in sourceKeys) {
      final res = await search({
        'sourceKey': key,
        'keyword': keyword,
        'page': page,
        'option': '',
      });
      results.add({
        'sourceKey': key,
        'sourceName': ComicSource.find(key)?.name ?? key,
        ...res,
      });
    }
    return {'results': results};
  }

  static Future<Map<String, dynamic>> loadComments(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final subId = args['subId']?.toString();
    final replyTo = args['replyTo']?.toString();
    final source = ComicSource.find(sourceKey);
    final loader = source?.commentsLoader;
    if (loader == null) {
      return {'error': 'Comments not available'};
    }
    final res = await loader(id, subId, page, replyTo);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {
      'comments': res.data
          .map((c) => {
                'userName': c.userName,
                'avatar': c.avatar,
                'content': c.content,
                'time': c.time,
                'replyCount': c.replyCount,
                'id': c.id,
                'score': c.score,
                'isLiked': c.isLiked,
                'voteStatus': c.voteStatus,
              })
          .toList(),
      'hasMore': res.subData,
    };
  }

  static Future<Map<String, dynamic>> postComment(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final content = args['content']?.toString() ?? '';
    final subId = args['subId']?.toString();
    final replyTo = args['replyTo']?.toString();
    final source = ComicSource.find(sourceKey);
    final sender = source?.sendCommentFunc;
    if (sender == null) {
      return {'error': 'Post comment not available'};
    }
    final res = await sender(id, subId, content, replyTo);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'ok': res.data};
  }

  static Future<Map<String, dynamic>> loadThumbnails(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    final loader = source?.loadComicThumbnail;
    if (loader == null) {
      return {'error': 'Thumbnails not available'};
    }
    final res = await loader(id, null);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'thumbnails': res.data};
  }

  static Future<Map<String, dynamic>> loadRanking(
    Map<dynamic, dynamic> args,
  ) async {
    final categoryKey = args['categoryKey']?.toString() ?? '';
    final option = args['option']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    CategoryComicsData? data;
    for (final source in ComicSource.all()) {
      if (source.categoryData?.key == categoryKey) {
        data = source.categoryComicsData;
        break;
      }
    }
    if (data?.rankingData == null) {
      return {'error': 'Ranking not found'};
    }
    final ranking = data!.rankingData!;
    final options = ranking.options;
    var effectiveOption = option;
    if (effectiveOption.isEmpty && options.isNotEmpty) {
      effectiveOption = options.keys.first;
    }
    if (ranking.load != null) {
      final res = await ranking.load!(effectiveOption, page);
      if (res.error) {
        return {
          'error': res.errorMessage,
          'options': options,
        };
      }
      return {
        'comics': res.data.map(comicToJson).toList(),
        'hasMore': res.subData,
        'options': options,
      };
    }
    return {'error': 'Ranking loader not configured', 'options': options};
  }

  static Future<Map<String, dynamic>> randomCategoryRefresh(
    Map<dynamic, dynamic> args,
  ) async {
    return categoryLoadPage({
      ...args,
      'page': 1,
      'options': ['random'],
    });
  }

  static Map<String, dynamic> getImageFavorites(Map<dynamic, dynamic> args) {
    final keyword = args['keyword']?.toString();
    final comics = ImageFavoriteManager().getAll(keyword);
    return {
      'comics': comics.map((c) {
        return {
          'id': c.id,
          'title': c.title,
          'subTitle': c.subTitle,
          'sourceKey': c.sourceKey,
          'imageCount': c.imageFavoritesEp.fold<int>(
            0,
            (sum, ep) => sum + ep.imageFavorites.length,
          ),
        };
      }).toList(),
    };
  }

  static Map<String, dynamic> getImageFavoriteImages(
    Map<dynamic, dynamic> args,
  ) {
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final comic = ImageFavoriteManager().find(id, sourceKey);
    if (comic == null) {
      return {'error': 'Comic not found'};
    }
    final images = <Map<String, dynamic>>[];
    for (final ep in comic.imageFavoritesEp) {
      for (final img in ep.imageFavorites) {
        images.add({
          'url': img.imageKey,
          'ep': ep.ep,
          'page': img.page,
        });
      }
    }
    return {'images': images};
  }

  static Map<String, dynamic> deleteImageFavorites(Map<dynamic, dynamic> args) {
    final ids = args['ids'] as List?;
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (ids == null) {
      return {'error': 'Missing ids'};
    }
    for (final id in ids) {
      final comic = ImageFavoriteManager().find(id.toString(), sourceKey);
      if (comic != null) {
        ImageFavoriteManager().addOrUpdateOrDelete(
          ImageFavoritesComic(
            comic.id,
            [],
            comic.title,
            comic.sourceKey,
            comic.tags,
            comic.translatedTags,
            comic.time,
            comic.author,
            comic.other,
            comic.subTitle,
            comic.maxPage,
          ),
        );
      }
    }
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> removeComicSource(
    Map<dynamic, dynamic> args,
  ) async {
    final key = args['key']?.toString() ?? '';
    if (key.isEmpty) {
      return {'error': 'Missing source key'};
    }
    final source = ComicSource.find(key);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    final filePath = source.filePath;
    ComicSourceManager().remove(key);
    try {
      await File(filePath).delete();
    } catch (_) {}
    await ComicSourceManager().reload();
    validateComicSourcePages();
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> addComicSourceFromUrl(
    Map<dynamic, dynamic> args,
  ) async {
    final url = args['url']?.toString() ?? '';
    if (url.isEmpty) {
      return {'error': 'Empty url'};
    }
    try {
      final splits = url.split('/');
      splits.removeWhere((element) => element.isEmpty);
      final fileName = splits.last;
      final res = await AppDio().get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'cache-time': 'no'},
        ),
      );
      final comicSource =
          await ComicSourceParser().createAndParse(res.data!, fileName);
      ComicSourceManager().add(comicSource);
      addAllPagesWithComicSource(comicSource);
      await appdata.saveData();
      await ComicSourceManager().reload();
      return {'ok': true, 'key': comicSource.key};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> importComicSourceFromContent(
    Map<dynamic, dynamic> args,
  ) async {
    final content = args['content']?.toString() ?? '';
    final fileName = args['fileName']?.toString() ?? 'source.js';
    if (content.isEmpty) {
      return {'error': 'Empty content'};
    }
    try {
      final comicSource =
          await ComicSourceParser().createAndParse(content, fileName);
      ComicSourceManager().add(comicSource);
      addAllPagesWithComicSource(comicSource);
      await appdata.saveData();
      await ComicSourceManager().reload();
      return {'ok': true, 'key': comicSource.key};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateComicSource(
    Map<dynamic, dynamic> args,
  ) async {
    final key = args['key']?.toString() ?? '';
    final source = ComicSource.find(key);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    if (Uri.tryParse(source.url)?.hasScheme != true) {
      return {'error': 'Invalid url config'};
    }
    try {
      ComicSourceManager().remove(source.key);
      final res = await AppDio().get<String>(
        source.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'cache-time': 'no'},
        ),
      );
      await ComicSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
      if (ComicSourceManager().availableUpdates.containsKey(source.key)) {
        ComicSourceManager().availableUpdates.remove(source.key);
      }
      await ComicSourceManager().reload();
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkComicSourceUpdates() async {
    if (ComicSource.all().isEmpty) {
      return {'count': 0};
    }
    try {
      final dio = AppDio();
      final res = await dio.get<String>(appdata.settings['comicSourceListUrl']);
      if (res.statusCode != 200) {
        return {'count': -1, 'error': 'Network error'};
      }
      final list = jsonDecode(res.data!) as List;
      final versions = <String, String>{};
      for (final source in list) {
        versions[source['key']] = source['version'];
      }
      final shouldUpdate = <String>[];
      for (final source in ComicSource.all()) {
        if (versions.containsKey(source.key) &&
            _compareSemVer(versions[source.key]!, source.version)) {
          shouldUpdate.add(source.key);
        }
      }
      if (shouldUpdate.isNotEmpty) {
        final updates = <String, String>{};
        for (final key in shouldUpdate) {
          updates[key] = versions[key]!;
        }
        ComicSourceManager().updateAvailableUpdates(updates);
      }
      final updateList = shouldUpdate
          .map((key) {
            final source = ComicSource.find(key);
            return {
              'key': key,
              'name': source?.name ?? key,
              'remoteVersion': versions[key],
              'localVersion': source?.version,
            };
          })
          .toList();
      return {'count': shouldUpdate.length, 'updates': updateList};
    } catch (e) {
      return {'count': -1, 'error': e.toString()};
    }
  }

  static bool _compareSemVer(String remote, String local) {
    try {
      final r = remote.split('.').map(int.parse).toList();
      final l = local.split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final rv = i < r.length ? r[i] : 0;
        final lv = i < l.length ? l[i] : 0;
        if (rv > lv) return true;
        if (rv < lv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> readComicSourceFile(
    Map<dynamic, dynamic> args,
  ) {
    final key = args['key']?.toString() ?? '';
    final source = ComicSource.find(key);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    try {
      final content = File(source.filePath).readAsStringSync();
      return {'content': content, 'path': source.filePath};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> saveComicSourceFile(
    Map<dynamic, dynamic> args,
  ) async {
    final key = args['key']?.toString() ?? '';
    final content = args['content']?.toString() ?? '';
    final source = ComicSource.find(key);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    try {
      await ComicSourceParser().parse(content, source.filePath);
      await File(source.filePath).writeAsString(content);
      await ComicSourceManager().reload();
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> reloadJsEngine() async {
    await JsEngine().ensureInit();
    JsEngine().runCode('ComicSource.sources = {};');
    await ComicSourceManager().reload();
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> clearCache() async {
    await CacheManager().clear();
    return {'ok': true};
  }

  static Map<String, dynamic> getAppInfo() {
    return {
      'version': App.version,
      'dataPath': App.isInitialized ? App.dataPath : '',
    };
  }

  static Map<String, dynamic> deleteLocalComic(Map<dynamic, dynamic> args) {
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final comic = LocalManager().find(id, ComicType.fromKey(sourceKey));
    if (comic == null) {
      return {'error': 'Comic not found'};
    }
    LocalManager().deleteComic(comic);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> startDownload(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final chapters = (args['chapters'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        <int>[];
    final source = ComicSource.find(sourceKey);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    if (LocalManager().isDownloading(id, ComicType.fromKey(sourceKey))) {
      return {'error': 'Already downloading'};
    }
    final info = await loadComicInfo({'sourceKey': sourceKey, 'id': id});
    if (info['error'] != null) {
      return info;
    }
    final comicMap = info['comic'] as Map<String, dynamic>;
    final detailsRes = await source.loadComicInfo!(id);
    if (detailsRes.error) {
      return {'error': detailsRes.errorMessage};
    }
    final comic = detailsRes.data;
    if (comic.chapters == null || chapters.isEmpty) {
      LocalManager().addTask(ImagesDownloadTask(
        source: source,
        comicId: id,
        comic: comic,
      ));
    } else {
      LocalManager().addTask(ImagesDownloadTask(
        source: source,
        comicId: id,
        comic: comic,
        chapters: chapters.map((i) => comic.chapters!.ids.elementAt(i)).toList(),
      ));
    }
    return {'ok': true, 'title': comicMap['title']};
  }

  static Future<Map<String, dynamic>> importComicFromPath(
    Map<dynamic, dynamic> args,
  ) async {
    final path = args['path']?.toString() ?? '';
    if (path.isEmpty) {
      return {'error': 'Missing path'};
    }
    try {
      final comic = await CBZ.import(File(path));
      LocalManager().add(comic);
      return {'ok': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static List<String> getNetworkFavoriteSources() {
    return ComicSource.all()
        .where((s) => s.favoriteData?.loadComic != null)
        .map((s) => s.key)
        .toList();
  }

  static Map<String, dynamic> getNetworkFavoriteSourcesJson() {
    return {'sources': getNetworkFavoriteSources()};
  }

  static Map<String, dynamic> getSearchTagSuggestions(
    Map<dynamic, dynamic> args,
  ) {
    final keyword = args['keyword']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source == null || source.enableTagsSuggestions != true) {
      return {'suggestions': <String>[]};
    }
    final text = keyword.split(' ').last;
    if (text.isEmpty) {
      return {'suggestions': <String>[]};
    }
    bool check(String key, String value) {
      if (text.isEmpty) return false;
      if (key.length >= text.length &&
              key.substring(0, text.length) == text ||
          (key.contains(' ') &&
              key.split(' ').last.length >= text.length &&
              key.split(' ').last.substring(0, text.length) == text)) {
        return true;
      }
      return value.length >= text.length && value.contains(text);
    }

    final suggestions = <String>[];
    void find(Map<String, String> map) {
      for (final entry in map.entries) {
        if (suggestions.length >= 100) break;
        if (check(entry.key, entry.value)) {
          suggestions.add(entry.key);
        }
      }
    }

    find(TagsTranslation.femaleTags);
    find(TagsTranslation.maleTags);
    find(TagsTranslation.parodyTags);
    find(TagsTranslation.characterTranslations);
    find(TagsTranslation.otherTags);
    find(TagsTranslation.mixedTags);
    find(TagsTranslation.languageTranslations);
    find(TagsTranslation.artistTags);
    find(TagsTranslation.groupTags);
    find(TagsTranslation.cosplayerTags);
    return {'suggestions': suggestions};
  }

  static Map<String, dynamic> getComicSourceSettings(
    Map<dynamic, dynamic> args,
  ) {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source == null) {
      return {'settings': <Map<String, dynamic>>[]};
    }
    final settingsMap = source.getSettingsDynamic() ?? source.settings;
    if (settingsMap == null) {
      return {'settings': <Map<String, dynamic>>[]};
    }
    source.data['settings'] ??= {};
    final items = <Map<String, dynamic>>[];
    for (final entry in settingsMap.entries) {
      final key = entry.key;
      final meta = Map<String, dynamic>.from(entry.value as Map);
      final type = meta['type']?.toString() ?? '';
      final item = <String, dynamic>{
        'key': key,
        'type': type,
        'title': meta['title'],
        'default': meta['default'],
        'current': source.data['settings'][key] ?? meta['default'],
      };
      if (type == 'select' && meta['options'] is List) {
        item['options'] = (meta['options'] as List)
            .map((o) => {
                  'value': (o as Map)['value'],
                  'text': o['text'] ?? o['value'],
                })
            .toList();
      }
      if (type == 'input') {
        item['validator'] = meta['validator'];
      }
      if (type == 'callback') {
        item['buttonText'] = meta['buttonText'] ?? 'Click';
      }
      items.add(item);
    }
    return {'settings': items};
  }

  static Map<String, dynamic> setComicSourceSetting(
    Map<dynamic, dynamic> args,
  ) {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final key = args['key']?.toString() ?? '';
    final value = args['value'];
    final source = ComicSource.find(sourceKey);
    if (source == null || key.isEmpty) {
      return {'error': 'Invalid source or key'};
    }
    source.data['settings'] ??= {};
    source.data['settings'][key] = value;
    source.saveData();
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> computeImageFavoritesChart() async {
    try {
      final computed = await ImageFavoriteManager.computeImageFavorites();
      List<Map<String, dynamic>> mapEntries(List<TextWithCount> items) {
        return items
            .map((e) => {'label': e.text, 'count': e.count})
            .toList();
      }

      return {
        'tags': mapEntries(computed.tags),
        'authors': mapEntries(computed.authors),
        'comics': mapEntries(computed.comics),
        'totalImages': computed.count,
      };
    } catch (e, s) {
      Log.error('computeImageFavoritesChart', e.toString(), s);
      return {
        'tags': <Map<String, dynamic>>[],
        'authors': <Map<String, dynamic>>[],
        'comics': <Map<String, dynamic>>[],
        'totalImages': 0,
      };
    }
  }

  static Map<String, dynamic> getComicSourceAccountConfig(
    Map<dynamic, dynamic> args,
  ) {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source?.account == null) {
      return {'hasAccount': false};
    }
    final account = source!.account!;
    final infoItems = <Map<String, dynamic>>[];
    for (final item in account.infoItems) {
      infoItems.add({
        'title': item.title,
        'data': item.data?.call(),
      });
    }
    return {
      'hasAccount': true,
      'isLogged': source.isLogged,
      'loginWebsite': account.loginWebsite,
      'registerWebsite': account.registerWebsite,
      'hasPasswordLogin': account.login != null,
      'hasCookieLogin': account.validateCookies != null,
      'cookieFields': account.cookieFields ?? <String>[],
      'infoItems': infoItems,
    };
  }

  static Future<Map<String, dynamic>> comicSourceLogin(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source?.account == null) {
      return {'error': 'Account not available'};
    }
    final account = source!.account!;
    if (account.login != null) {
      final username = args['username']?.toString() ?? '';
      final password = args['password']?.toString() ?? '';
      if (username.isEmpty || password.isEmpty) {
        return {'error': 'Cannot be empty'};
      }
      final res = await account.login!(username, password);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {'ok': true, 'isLogged': source.isLogged};
    }
    if (account.validateCookies != null && account.cookieFields != null) {
      final cookies = (args['cookies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final ok = await account.validateCookies!(cookies);
      if (!ok) {
        return {'error': 'Invalid cookies'};
      }
      source.data['account'] = 'ok';
      source.saveData();
      return {'ok': true, 'isLogged': source.isLogged};
    }
    return {'error': 'Login not supported'};
  }

  static Map<String, dynamic> comicSourceLogout(Map<dynamic, dynamic> args) {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source?.account == null) {
      return {'error': 'Account not available'};
    }
    source!.data['account'] = null;
    source.account?.logout();
    source.saveData();
    ComicSourceManager().notifyStateChange();
    return {'ok': true, 'isLogged': false};
  }

  static Future<Map<String, dynamic>> comicSourceRelogin(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source?.account?.login == null) {
      return {'error': 'Re-login not available'};
    }
    if (source!.data['account'] is! List) {
      return {'error': 'No data'};
    }
    final accountData = source.data['account'] as List;
    final res = await source.account!.login!(
      accountData[0].toString(),
      accountData[1].toString(),
    );
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'ok': true, 'isLogged': source.isLogged};
  }

  static Future<Map<String, dynamic>> invokeComicSourceCallback(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final settingKey = args['settingKey']?.toString() ?? '';
    final source = ComicSource.find(sourceKey);
    if (source == null) {
      return {'error': 'Source not found'};
    }
    final settingsMap = source.getSettingsDynamic() ?? source.settings;
    if (settingsMap == null || !settingsMap.containsKey(settingKey)) {
      return {'error': 'Setting not found'};
    }
    final meta = Map<String, dynamic>.from(settingsMap[settingKey] as Map);
    if (meta['type']?.toString() != 'callback') {
      return {'error': 'Not a callback setting'};
    }
    final func = meta['callback'];
    if (func == null) {
      return {'error': 'No callback'};
    }
    final result = func([]);
    if (result is Future) {
      await result;
    }
    return {'ok': true};
  }

  static Map<String, dynamic> getLocalFavoriteFolderNames() {
    return {'folders': LocalFavoritesManager().folderNames};
  }

  static Future<Map<String, dynamic>> fetchComicSourceCatalog(
    Map<dynamic, dynamic> args,
  ) async {
    final url = args['url']?.toString() ?? '';
    if (url.isEmpty) {
      return {'error': 'Empty url'};
    }
    try {
      final res = await AppDio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (res.statusCode != 200) {
        return {'error': 'Network error'};
      }
      final list = jsonDecode(res.data!) as List;
      return {'entries': list};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateFavoriteInfo(
    Map<dynamic, dynamic> args,
  ) async {
    final folder = args['folder']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (folder.isEmpty || id.isEmpty) {
      return {'error': 'Missing folder or id'};
    }
    final comics = LocalFavoritesManager().getFolderComics(folder);
    final index = comics.indexWhere(
      (c) => c.id == id && c.type.sourceKey == sourceKey,
    );
    if (index < 0) {
      return {'error': 'Favorite not found'};
    }
    LocalFavoritesManager().updateInfo(folder, comics[index]);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> downloadFavoriteComics(
    Map<dynamic, dynamic> args,
  ) async {
    final items = (args['items'] as List?) ?? [];
    var count = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      final sourceKey = raw['sourceKey']?.toString() ?? '';
      if (id.isEmpty || sourceKey.isEmpty) continue;
      final res = await startDownload({
        'sourceKey': sourceKey,
        'id': id,
      });
      if (res['ok'] == true) count++;
    }
    return {'ok': true, 'count': count};
  }

  static Map<String, dynamic> getAppLogs() {
    return {
      'logs': Log.logs
          .map((l) => {
                'level': l.level.name,
                'title': l.title,
                'content': l.content,
                'time': l.time.millisecondsSinceEpoch,
              })
          .toList(),
    };
  }

  static Future<Map<String, dynamic>> addImageFavorite(
    Map<dynamic, dynamic> args,
  ) async {
    final comicId = args['comicId']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final title = args['title']?.toString() ?? '';
    final author = args['author']?.toString() ?? '';
    final tags = (args['tags'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    final ep = (args['ep'] as num?)?.toInt() ?? 1;
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final imageKey = args['imageKey']?.toString() ?? '';
    final eid = args['eid']?.toString() ?? '';
    if (comicId.isEmpty || imageKey.isEmpty) {
      return {'error': 'Missing comicId or imageKey'};
    }
    var comic = ImageFavoriteManager().find(comicId, sourceKey);
    comic ??= ImageFavoritesComic(
      comicId,
      [],
      title,
      sourceKey,
      tags,
      <String>[],
      DateTime.now(),
      author,
      {},
      '',
      0,
    );
    final epName = args['epName']?.toString() ?? '';
    final maxPage = (args['maxPage'] as num?)?.toInt() ?? 0;
    final imageFavorite = ImageFavorite(
      page,
      imageKey,
      null,
      eid,
      comicId,
      ep,
      sourceKey,
      epName,
    );
    ImageFavoritesEp? epEntry;
    for (final entry in comic.imageFavoritesEp) {
      if (entry.ep == ep) {
        epEntry = entry;
        break;
      }
    }
    if (epEntry == null) {
      epEntry = ImageFavoritesEp(eid, ep, [imageFavorite], epName, maxPage);
      comic.imageFavoritesEp.add(epEntry);
    } else {
      epEntry.imageFavorites.add(imageFavorite);
    }
    ImageFavoriteManager().addOrUpdateOrDelete(comic);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> loadChapterComments(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final comicId = args['comicId']?.toString() ?? '';
    final subId = args['subId']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final replyTo = args['replyTo']?.toString();
    final source = ComicSource.find(sourceKey);
    if (source?.chapterCommentsLoader == null) {
      return {'error': 'Chapter comments not supported', 'comments': []};
    }
    final res = await source!.chapterCommentsLoader!(
      comicId,
      subId,
      page,
      replyTo,
    );
    if (res.error) {
      return {'error': res.errorMessage, 'comments': []};
    }
    return {
      'comments': res.data
          .map((c) => {
                'userName': c.userName,
                'avatar': c.avatar,
                'content': c.content,
                'time': c.time,
                'id': c.id,
                'replyCount': c.replyCount,
              })
          .toList(),
      'hasMore': res.subData,
    };
  }

  static Future<Map<String, dynamic>> exportComics(
    Map<dynamic, dynamic> args,
  ) async {
    final format = args['format']?.toString() ?? 'cbz';
    final items = (args['items'] as List?) ?? [];
    if (items.isEmpty) {
      return {'error': 'No comics selected'};
    }
    try {
      final cacheDir = Directory(FilePath.join(App.cachePath, 'comics_export'));
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      cacheDir.createSync(recursive: true);
      var exported = 0;
      for (final raw in items) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        final sourceKey = raw['sourceKey']?.toString() ?? '';
        if (id.isEmpty) continue;
        final type = ComicType.fromKey(sourceKey);
        final comic = LocalManager().find(id, type);
        if (comic == null) continue;
        final ext = format == 'cbz'
            ? '.cbz'
            : format == 'pdf'
                ? '.pdf'
                : format == 'epub'
                    ? '.epub'
                    : '.cbz';
        final fileName = FilePath.join(cacheDir.path, '${comic.title}$ext');
        if (format == 'cbz') {
          await CBZ.export(comic, fileName);
        } else {
          continue;
        }
        exported++;
      }
      if (exported == 0) {
        return {'error': 'No comics exported'};
      }
      return {'ok': true, 'path': cacheDir.path, 'count': exported};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> exportAppDataBridge() async {
    try {
      final file = await exportAppData(false);
      return {'ok': true, 'path': file.path};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> importAppDataBridge(
    Map<dynamic, dynamic> args,
  ) async {
    try {
      final path = args['path']?.toString() ?? '';
      if (path.isEmpty) {
        return {'ok': false, 'error': 'Missing path'};
      }
      await importAppData(File(path));
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> runJsCode(Map<dynamic, dynamic> args) {
    try {
      final code = args['code']?.toString() ?? '';
      final res = JsEngine().runCode(code, '<debug>');
      return {'ok': true, 'result': res.toString()};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeInvalidFavorites() async {
    try {
      final count = await LocalFavoritesManager().removeInvalid();
      return {'ok': true, 'count': count};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> likeComment(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final subId = args['subId']?.toString();
    final commentId = args['commentId']?.toString() ?? '';
    final isLiking = args['isLiking'] == true;
    final source = ComicSource.find(sourceKey);
    final fn = source?.likeCommentFunc;
    if (fn == null) {
      return {'error': 'Like comment not available'};
    }
    final res = await fn(id, subId, commentId, isLiking);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> voteComment(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final id = args['id']?.toString() ?? '';
    final subId = args['subId']?.toString();
    final commentId = args['commentId']?.toString() ?? '';
    final isUp = args['isUp'] == true;
    final isCancel = args['isCancel'] == true;
    final source = ComicSource.find(sourceKey);
    final fn = source?.voteCommentFunc;
    if (fn == null) {
      return {'error': 'Vote comment not available'};
    }
    final res = await fn(id, subId, commentId, isUp, isCancel);
    if (res.error) {
      return {'error': res.errorMessage};
    }
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> importLocalComic(
    Map<dynamic, dynamic> args,
  ) async {
    final mode = args['mode']?.toString() ?? 'file';
    final selectedFolder = args['selectedFolder']?.toString();
    final copyToLocal = args['copyToLocal'] != false;
    final importer =
        ImportComic(selectedFolder: selectedFolder, copyToLocal: copyToLocal);
    try {
      if (mode == 'file') {
        return importComicFromPath(args);
      }
      if (mode == 'localDownloads' || mode == 'scan') {
        final ok = await importer.localDownloads();
        return ok ? {'ok': true} : {'error': 'Import failed'};
      }
      final path = args['path']?.toString() ?? '';
      if (path.isEmpty && mode != 'localDownloads' && mode != 'scan') {
        return {'error': 'Missing path'};
      }
      if (mode == 'directory') {
        final ok = await importer.fromDirectoryPath(path, single: true);
        return ok ? {'ok': true} : {'error': 'Import failed'};
      }
      if (mode == 'multipleDirectory') {
        final ok = await importer.fromDirectoryPath(path, single: false);
        return ok ? {'ok': true} : {'error': 'Import failed'};
      }
      if (mode == 'multipleCbz') {
        final ok = await importer.multipleCbzFromPath(path);
        return ok ? {'ok': true} : {'error': 'Import failed'};
      }
      if (mode == 'ehViewer') {
        final downloadPath = args['downloadPath']?.toString() ?? '';
        if (downloadPath.isEmpty) {
          return {'error': 'Missing download path'};
        }
        final ok = await importer.ehViewerFromPaths(path, downloadPath);
        return ok ? {'ok': true} : {'error': 'Import failed'};
      }
      return {'error': 'Unknown import mode'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> getComicTileStatuses() {
    final favoriteKeys = <String>[];
    final mgr = LocalFavoritesManager();
    for (final folder in mgr.folderNames) {
      for (final item in mgr.getFolderComics(folder)) {
        favoriteKeys.add('${item.sourceKey}:${item.id}');
      }
    }
    final history = <String, Map<String, int>>{};
    for (final h in HistoryManager().getAll()) {
      final key = '${h.type.sourceKey}:${h.id}';
      history[key] = {
        'ep': h.ep,
        'page': h.page == 0 ? 1 : h.page,
      };
    }
    return {
      'favoriteKeys': favoriteKeys,
      'history': history,
    };
  }

  static Future<Map<String, dynamic>> refreshHistory(
    Map<dynamic, dynamic> args,
  ) async {
    final id = args['id']?.toString() ?? '';
    final sourceKey = args['sourceKey']?.toString() ?? '';
    if (id.isEmpty || sourceKey.isEmpty) {
      return {'ok': false};
    }
    final type = ComicType.fromKey(sourceKey);
    final history = HistoryManager().find(id, type);
    if (history == null) {
      return {'ok': false};
    }
    final ok = await HistoryManager().refreshHistoryInfo(history);
    return {'ok': ok};
  }

  static Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final res = await AppDio().get(
        'https://cdn.jsdelivr.net/gh/venera-app/venera@master/pubspec.yaml',
      );
      if (res.statusCode == 200) {
        final data = loadYaml(res.data);
        final version = data['version'];
        if (version != null) {
          final remote = version.toString().split('+')[0];
          return {
            'hasUpdate': _compareAppVersion(remote, App.version),
            'latestVersion': remote,
          };
        }
      }
    } catch (e, s) {
      Log.error('Check Update', e.toString(), s);
    }
    return {'hasUpdate': false};
  }

  static bool _compareAppVersion(String version1, String version2) {
    final v1 = version1.split('.');
    final v2 = version2.split('.');
    for (var i = 0; i < v1.length; i++) {
      if (i >= v2.length) {
        return true;
      }
      final a = int.tryParse(v1[i]) ?? 0;
      final b = int.tryParse(v2[i]) ?? 0;
      if (a > b) {
        return true;
      }
      if (a < b) {
        return false;
      }
    }
    return false;
  }
}
