import 'dart:async';

import 'package:flutter/services.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/services/data_service.dart';

class DataBridge {
  static const MethodChannel _channel = MethodChannel('com.venera.data');
  static const EventChannel _eventChannel =
      EventChannel('com.venera.data/events');

  static Stream<Map<String, dynamic>>? _events;

  static Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{'type': event.toString()};
    });
    return _events!;
  }

  static void registerHandlers() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exploreLoadPage':
          return await DataService.exploreLoadPage(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getHistory':
          return DataService.getHistory();
        case 'pingBackend':
          return DataService.pingBackend();
        case 'deleteHistory':
          return DataService.deleteHistory(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getSettings':
          return DataService.getSettings();
        case 'getSettingsJson':
          return DataService.getSettingsJson();
        case 'setSetting':
          final setResult = DataService.setSetting(
            call.arguments as Map<dynamic, dynamic>,
          );
          if (setResult == 'ok' ||
              (setResult is Map && (setResult['ok'] == true || setResult['ok'] == 1))) {
            final key = (call.arguments as Map<dynamic, dynamic>)['key']?.toString() ?? '';
            DataBridge.notifySettingsChanged(
              key,
              appdata.settings[key],
            );
          }
          return setResult;
        case 'getComicSources':
          return DataService.getComicSources();
        case 'getExploreConfig':
          return DataService.getExploreConfig();
        case 'getCategoryConfig':
          return DataService.getCategoryConfig();
        case 'getCategoryParts':
          return DataService.getCategoryParts(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'categoryLoadPage':
          return await DataService.categoryLoadPage(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'search':
          return await DataService.search(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'resolveComicLink':
          return DataService.resolveComicLink(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getSearchOptions':
          return DataService.getSearchOptions(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getSearchHistory':
          return DataService.getSearchHistory();
        case 'loadComicInfo':
          return await DataService.loadComicInfo(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'likeComic':
          return await DataService.likeComic(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getFavoriteFolders':
          return DataService.getFavoriteFolders();
        case 'getFavorites':
          return DataService.getFavorites(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadNetworkFavorites':
          return await DataService.loadNetworkFavorites(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getLocalComics':
          return DataService.getLocalComics();
        case 'getDownloadTasks':
          return DataService.getDownloadTasks();
        case 'webdavUpload':
          return await DataService.webdavUpload();
        case 'webdavDownload':
          return await DataService.webdavDownload();
        case 'loadCoverImage':
          return await DataService.loadCoverImage(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'clearSearchHistory':
          return DataService.clearSearchHistory();
        case 'clearHistory':
          return DataService.clearHistory();
        case 'getSyncStatus':
          return DataService.getSyncStatus();
        case 'getFollowUpdatesSummary':
          return DataService.getFollowUpdatesSummary();
        case 'getFollowUpdatesList':
          return DataService.getFollowUpdatesList();
        case 'checkFollowUpdates':
          return await DataService.checkFollowUpdates();
        case 'setFollowUpdatesFolder':
          return DataService.setFollowUpdatesFolder(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'markFavoriteAsRead':
          return DataService.markFavoriteAsRead(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getFavoriteFolderCounts':
          return DataService.getFavoriteFolderCounts();
        case 'createFavoriteFolder':
          return DataService.createFavoriteFolder(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'deleteFavoriteFolder':
          return DataService.deleteFavoriteFolder(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'addFavorite':
          return DataService.addFavorite(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'removeFavorite':
          return DataService.removeFavorite(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'reorderFavorites':
          return DataService.reorderFavorites(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadFavoriteFoldersRemote':
          return await DataService.loadFavoriteFoldersRemote(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'pauseDownload':
          return DataService.pauseDownload(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'resumeDownload':
          return DataService.resumeDownload(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'cancelDownload':
          return DataService.cancelDownload(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'moveDownloadToFirst':
          return DataService.moveDownloadToFirst(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'aggregatedSearch':
          return await DataService.aggregatedSearch(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadComments':
          return await DataService.loadComments(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'postComment':
          return await DataService.postComment(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadThumbnails':
          return await DataService.loadThumbnails(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadRanking':
          return await DataService.loadRanking(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'randomCategoryRefresh':
          return await DataService.randomCategoryRefresh(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getImageFavorites':
          return DataService.getImageFavorites(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getImageFavoriteImages':
          return DataService.getImageFavoriteImages(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'deleteImageFavorites':
          return DataService.deleteImageFavorites(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'removeComicSource':
          return await DataService.removeComicSource(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'addComicSourceFromUrl':
          return await DataService.addComicSourceFromUrl(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'importComicSourceFromContent':
          return await DataService.importComicSourceFromContent(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'updateComicSource':
          return await DataService.updateComicSource(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'checkComicSourceUpdates':
          return await DataService.checkComicSourceUpdates();
        case 'readComicSourceFile':
          return DataService.readComicSourceFile(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'saveComicSourceFile':
          return await DataService.saveComicSourceFile(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'reloadJsEngine':
          return await DataService.reloadJsEngine();
        case 'clearCache':
          return await DataService.clearCache();
        case 'getAppInfo':
          return DataService.getAppInfo();
        case 'deleteLocalComic':
          return DataService.deleteLocalComic(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'startDownload':
          final downloadResult = await DataService.startDownload(
            call.arguments as Map<dynamic, dynamic>,
          );
          if (downloadResult['ok'] == true) {
            DataBridge.notifyDataEvent('download');
          }
          return downloadResult;
        case 'importComicFromPath':
          return await DataService.importComicFromPath(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getNetworkFavoriteSources':
          return DataService.getNetworkFavoriteSourcesJson();
        case 'getSearchTagSuggestions':
          return DataService.getSearchTagSuggestions(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getComicSourceSettings':
          return DataService.getComicSourceSettings(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'setComicSourceSetting':
          return DataService.setComicSourceSetting(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'computeImageFavoritesChart':
          return await DataService.computeImageFavoritesChart();
        case 'getComicSourceAccountConfig':
          return DataService.getComicSourceAccountConfig(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'comicSourceLogin':
          return await DataService.comicSourceLogin(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'comicSourceLogout':
          return DataService.comicSourceLogout(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'comicSourceRelogin':
          return await DataService.comicSourceRelogin(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'invokeComicSourceCallback':
          return await DataService.invokeComicSourceCallback(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getLocalFavoriteFolderNames':
          return DataService.getLocalFavoriteFolderNames();
        case 'fetchComicSourceCatalog':
          return await DataService.fetchComicSourceCatalog(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'updateFavoriteInfo':
          return await DataService.updateFavoriteInfo(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'downloadFavoriteComics':
          return await DataService.downloadFavoriteComics(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getAppLogs':
          return DataService.getAppLogs();
        case 'addImageFavorite':
          return await DataService.addImageFavorite(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'loadChapterComments':
          return await DataService.loadChapterComments(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'exportComics':
          return await DataService.exportComics(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'exportAppData':
          return await DataService.exportAppDataBridge();
        case 'importAppData':
          return await DataService.importAppDataBridge(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'runJsCode':
          return DataService.runJsCode(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'removeInvalidFavorites':
          return await DataService.removeInvalidFavorites();
        case 'likeComment':
          return await DataService.likeComment(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'voteComment':
          return await DataService.voteComment(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'importLocalComic':
          return await DataService.importLocalComic(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'getComicTileStatuses':
          return DataService.getComicTileStatuses();
        case 'refreshHistory':
          return await DataService.refreshHistory(
            call.arguments as Map<dynamic, dynamic>,
          );
        case 'setReaderSetting':
          final readerSetResult = DataService.setReaderSetting(
            call.arguments as Map<dynamic, dynamic>,
          );
          if (readerSetResult == 'ok' ||
              (readerSetResult is Map &&
                  (readerSetResult['ok'] == true || readerSetResult['ok'] == 1))) {
            final args = call.arguments as Map<dynamic, dynamic>;
            scheduleMicrotask(() {
              DataBridge.notifySettingsChanged(
                args['key']?.toString() ?? '',
                args['value'],
              );
            });
          }
          return readerSetResult;
        case 'setComicSpecificSettingsEnabled':
          final enableResult = DataService.setComicSpecificSettingsEnabled(
            call.arguments as Map<dynamic, dynamic>,
          );
          if (enableResult['ok'] == true) {
            scheduleMicrotask(() {
              DataBridge.notifySettingsChanged('comicSpecificSettings', null);
            });
          }
          return enableResult;
        case 'checkForUpdate':
          return await DataService.checkForUpdate();
        default:
          throw MissingPluginException(
            'No implementation for method ${call.method}',
          );
      }
    });
  }

  static void notifySettingsChanged(String key, dynamic value) {
    _channel.invokeMethod<void>('notifySettingsChanged', {
      'key': key,
      'value': value,
    });
  }

  static void notifyDataEvent(String type, [Map<String, dynamic>? data]) {
    _channel.invokeMethod<void>('notifyDataEvent', {
      'type': type,
      if (data != null) ...data,
    });
  }
}

void installDataBridgeSettingsListener() {
  appdata.settings.addListener(() {
    if (DataService.suppressSettingsNotify) {
      return;
    }
    scheduleMicrotask(() {
      DataBridge.notifySettingsChanged('_batch', null);
    });
  });
}
