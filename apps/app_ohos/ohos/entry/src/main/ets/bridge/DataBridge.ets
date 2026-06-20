import { MethodResult } from '@ohos/flutter_ohos';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler, CHANNEL_DATA_NAME } from './FlutterBridge';
import { SettingsMirror } from '../utils/SettingsMirror';
import { DataService } from '../service/DataService';

const DATA_BRIDGE_DOMAIN: number = 0x0000;
const DATA_BRIDGE_TAG: string = 'DataBridge';

interface SettingNotifyWaiter {
  key: string;
  value: Object | null;
  resolve: (matched: boolean) => void;
  timer: number;
}

export class DataBridge implements MethodCallHandler {
  private static instance: DataBridge | null = null;
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private settingNotifyWaiters: SettingNotifyWaiter[] = [];

  static getInstance(): DataBridge {
    if (DataBridge.instance === null) {
      DataBridge.instance = new DataBridge();
    }
    return DataBridge.instance;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_DATA_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'notifySettingsChanged') {
      let args = call.args as Record<string, Object> | null;
      let key: string = '';
      let value: Object | null = null;
      if (args !== null) {
        if (args['key'] !== undefined && args['key'] !== null) {
          key = args['key'].toString();
        }
        value = args['value'] as Object | null;
      }
      this.resolveSettingWaiters(key, value);
      if (key.length > 0 && key !== '_batch') {
        SettingsMirror.applyPatch(key, value as Object);
      }
      hilog.info(DATA_BRIDGE_DOMAIN, DATA_BRIDGE_TAG,
        'notifySettingsChanged %{public}s=%{public}s', key, JSON.stringify(value));
      AppStorage.setOrCreate<number>('settingsVersion', Date.now());
      result.success(null);
      return;
    }
    if (call.method === 'notifyDataEvent') {
      AppStorage.setOrCreate<number>('dataEventVersion', Date.now());
      result.success(null);
      return;
    }
    result.notImplemented();
  }

  waitForSettingApplied(key: string, value: Object | null, timeoutMs: number): Promise<boolean> {
    return new Promise((resolve: (matched: boolean) => void) => {
      let timer: number = setTimeout(() => {
        this.removeSettingWaiter(key, resolve);
        resolve(false);
      }, timeoutMs);
      this.settingNotifyWaiters.push({
        key: key,
        value: value,
        resolve: resolve,
        timer: timer
      });
    });
  }

  private removeSettingWaiter(key: string, resolve: (matched: boolean) => void): void {
    for (let i: number = this.settingNotifyWaiters.length - 1; i >= 0; i--) {
      let waiter = this.settingNotifyWaiters[i];
      if (waiter.key === key && waiter.resolve === resolve) {
        clearTimeout(waiter.timer);
        this.settingNotifyWaiters.splice(i, 1);
        return;
      }
    }
  }

  private bridgeValuesMatch(expected: Object | null, actual: Object | null | undefined): boolean {
    if (expected === null) {
      return actual === null || actual === undefined;
    }
    if (typeof expected === 'boolean') {
      if (expected === false) {
        return actual === false || actual === 0 || actual === undefined || actual === null;
      }
      return actual === true || actual === 1;
    }
    return actual === expected;
  }

  private resolveSettingWaiters(key: string, value: Object | null | undefined): void {
    for (let i: number = this.settingNotifyWaiters.length - 1; i >= 0; i--) {
      let waiter = this.settingNotifyWaiters[i];
      if (waiter.key === key && this.bridgeValuesMatch(waiter.value, value)) {
        clearTimeout(waiter.timer);
        waiter.resolve(true);
        this.settingNotifyWaiters.splice(i, 1);
      }
    }
  }

  private invoke(method: string, args: Object | null): Promise<Object | null> {
    let started: number = Date.now();
    hilog.info(DATA_BRIDGE_DOMAIN, DATA_BRIDGE_TAG, 'invoke start %{public}s', method);
    return this.bridge.invokeMethodAsync(CHANNEL_DATA_NAME, method, args).then((result: Object | null) => {
      hilog.info(DATA_BRIDGE_DOMAIN, DATA_BRIDGE_TAG,
        'invoke done %{public}s %{public}dms', method, Date.now() - started);
      return result;
    }).catch((err: Error) => {
      hilog.error(DATA_BRIDGE_DOMAIN, DATA_BRIDGE_TAG,
        'invoke failed %{public}s %{public}s', method, err.message);
      throw err;
    });
  }

  pingBackend(): Promise<Object | null> {
    return this.invoke('pingBackend', null);
  }

  exploreLoadPage(sourceKey: string, pageTitle: string, page: number, next?: string): Promise<Object | null> {
    let params: ExploreLoadPageParams = {
      sourceKey: sourceKey,
      pageTitle: pageTitle,
      page: page
    };
    if (next !== undefined && next.length > 0) {
      params.next = next;
    }
    return this.invoke('exploreLoadPage', params);
  }

  getHistory(): Promise<Object | null> {
    return this.invoke('getHistory', null);
  }

  deleteHistory(id: string, sourceKey: string): Promise<Object | null> {
    let params: DeleteHistoryParams = {
      id: id,
      sourceKey: sourceKey
    };
    return this.invoke('deleteHistory', params);
  }

  getSettings(): Promise<Object | null> {
    return this.invoke('getSettings', null);
  }

  getSettingsJson(): Promise<Object | null> {
    return this.invoke('getSettingsJson', null);
  }

  setSetting(key: string, value: Object | null): Promise<Object | null> {
    let params: SetSettingParams = {
      key: key,
      value: value
    };
    return this.invoke('setSetting', params);
  }

  setSettingNoWait(key: string, value: Object | null): Promise<void> {
    let params: SetSettingParams = {
      key: key,
      value: value
    };
    return this.invoke('setSetting', params).then(() => {
      return;
    });
  }

  getComicSources(): Promise<Object | null> {
    return this.invoke('getComicSources', null);
  }

  getExploreConfig(): Promise<Object | null> {
    return this.invoke('getExploreConfig', null);
  }

  getCategoryConfig(): Promise<Object | null> {
    return this.invoke('getCategoryConfig', null);
  }

  getCategoryParts(key: string): Promise<Object | null> {
    let params: CategoryPartsParams = { key: key };
    return this.invoke('getCategoryParts', params);
  }

  categoryLoadPage(params: CategoryLoadParams): Promise<Object | null> {
    return this.invoke('categoryLoadPage', params);
  }

  search(sourceKey: string, keyword: string, page: number, option: string, next?: string): Promise<Object | null> {
    let params: SearchParams = {
      sourceKey: sourceKey,
      keyword: keyword,
      page: page,
      option: option
    };
    if (next !== undefined && next.length > 0) {
      params.next = next;
    }
    return this.invoke('search', params);
  }

  resolveComicLink(url: string): Promise<Object | null> {
    let params: UrlParams = { url: url };
    return this.invoke('resolveComicLink', params);
  }

  getSearchOptions(sourceKey: string): Promise<Object | null> {
    let params: SourceKeyParams = { sourceKey: sourceKey };
    return this.invoke('getSearchOptions', params);
  }

  getSearchHistory(): Promise<Object | null> {
    return this.invoke('getSearchHistory', null);
  }

  loadComicInfo(sourceKey: string, id: string): Promise<Object | null> {
    let params: LoadComicParams = {
      sourceKey: sourceKey,
      id: id
    };
    return this.invoke('loadComicInfo', params);
  }

  likeComic(sourceKey: string, id: string, isLiking: boolean): Promise<Object | null> {
    let params: LikeComicParams = { sourceKey: sourceKey, id: id, isLiking: isLiking };
    return this.invoke('likeComic', params);
  }

  getFavoriteFolders(): Promise<Object | null> {
    return this.invoke('getFavoriteFolders', null);
  }

  getFavorites(folder: string, isNetwork: boolean, readFilter?: string): Promise<Object | null> {
    let params: GetFavoritesParams = {
      folder: folder,
      isNetwork: isNetwork
    };
    if (readFilter !== undefined && readFilter.length > 0) {
      params.readFilter = readFilter;
    }
    return this.invoke('getFavorites', params);
  }

  loadNetworkFavorites(sourceKey: string, page: number, folder?: string): Promise<Object | null> {
    let params: NetworkFavParams = {
      sourceKey: sourceKey,
      page: page
    };
    if (folder !== undefined) {
      params.folder = folder;
    }
    return this.invoke('loadNetworkFavorites', params);
  }

  getLocalComics(): Promise<Object | null> {
    return this.invoke('getLocalComics', null);
  }

  getDownloadTasks(): Promise<Object | null> {
    return this.invoke('getDownloadTasks', null);
  }

  webdavUpload(): Promise<Object | null> {
    return this.invoke('webdavUpload', null);
  }

  webdavDownload(): Promise<Object | null> {
    return this.invoke('webdavDownload', null);
  }

  loadCoverImage(url: string, sourceKey?: string, cid?: string, fallback?: boolean): Promise<Object | null> {
    let params: CoverImageParams = { url: url };
    if (sourceKey !== undefined) {
      params.sourceKey = sourceKey;
    }
    if (cid !== undefined) {
      params.cid = cid;
    }
    if (fallback !== undefined) {
      params.fallbackToLocalCover = fallback;
    }
    return this.invoke('loadCoverImage', params);
  }

  clearSearchHistory(): Promise<Object | null> {
    return this.invoke('clearSearchHistory', null);
  }

  clearHistory(): Promise<Object | null> {
    return this.invoke('clearHistory', null);
  }

  getSyncStatus(): Promise<Object | null> {
    return this.invoke('getSyncStatus', null);
  }

  getFollowUpdatesSummary(): Promise<Object | null> {
    return this.invoke('getFollowUpdatesSummary', null);
  }

  getFollowUpdatesList(): Promise<Object | null> {
    return this.invoke('getFollowUpdatesList', null);
  }

  checkFollowUpdates(): Promise<Object | null> {
    return this.invoke('checkFollowUpdates', null);
  }

  setFollowUpdatesFolder(folder: string | null): Promise<Object | null> {
    let params: Record<string, Object> = {};
    if (folder !== null && folder.length > 0) {
      params['folder'] = folder;
    }
    return this.invoke('setFollowUpdatesFolder', params);
  }

  markFavoriteAsRead(id: string, sourceKey: string): Promise<Object | null> {
    let params: ComicIdSourceParams = { id: id, sourceKey: sourceKey };
    return this.invoke('markFavoriteAsRead', params);
  }

  getFavoriteFolderCounts(): Promise<Object | null> {
    return this.invoke('getFavoriteFolderCounts', null);
  }

  createFavoriteFolder(name: string): Promise<Object | null> {
    let createParams: NameParams = { name: name };
    return this.invoke('createFavoriteFolder', createParams);
  }

  deleteFavoriteFolder(name: string): Promise<Object | null> {
    let deleteFolderParams: NameParams = { name: name };
    return this.invoke('deleteFavoriteFolder', deleteFolderParams);
  }

  addFavorite(params: AddFavoriteParams): Promise<Object | null> {
    return this.invoke('addFavorite', params);
  }

  removeFavorite(folder: string, id: string, sourceKey: string): Promise<Object | null> {
    let removeParams: RemoveFavoriteParams = { folder: folder, id: id, sourceKey: sourceKey };
    return this.invoke('removeFavorite', removeParams);
  }

  reorderFavorites(folder: string, ids: string[]): Promise<Object | null> {
    let reorderParams: ReorderFavoritesParams = { folder: folder, ids: ids };
    return this.invoke('reorderFavorites', reorderParams);
  }

  loadFavoriteFoldersRemote(sourceKey: string, comicId?: string): Promise<Object | null> {
    let params: RemoteFoldersParams = { sourceKey: sourceKey };
    if (comicId !== undefined) {
      params.comicId = comicId;
    }
    return this.invoke('loadFavoriteFoldersRemote', params);
  }

  pauseDownload(index: number): Promise<Object | null> {
    let pauseParams: IndexParams = { index: index };
    return this.invoke('pauseDownload', pauseParams);
  }

  resumeDownload(index: number): Promise<Object | null> {
    let resumeParams: IndexParams = { index: index };
    return this.invoke('resumeDownload', resumeParams);
  }

  cancelDownload(index: number): Promise<Object | null> {
    let cancelParams: IndexParams = { index: index };
    return this.invoke('cancelDownload', cancelParams);
  }

  moveDownloadToFirst(index: number): Promise<Object | null> {
    let moveParams: IndexParams = { index: index };
    return this.invoke('moveDownloadToFirst', moveParams);
  }

  aggregatedSearch(keyword: string, page: number = 1): Promise<Object | null> {
    let aggParams: AggregatedSearchParams = { keyword: keyword, page: page };
    return this.invoke('aggregatedSearch', aggParams);
  }

  loadComments(sourceKey: string, id: string, page: number, subId?: string, replyTo?: string): Promise<Object | null> {
    let params: CommentsParams = { sourceKey: sourceKey, id: id, page: page };
    if (subId !== undefined) {
      params.subId = subId;
    }
    if (replyTo !== undefined) {
      params.replyTo = replyTo;
    }
    return this.invoke('loadComments', params);
  }

  postComment(sourceKey: string, id: string, content: string, subId?: string, replyTo?: string): Promise<Object | null> {
    let params: PostCommentParams = { sourceKey: sourceKey, id: id, content: content };
    if (subId !== undefined) {
      params.subId = subId;
    }
    if (replyTo !== undefined) {
      params.replyTo = replyTo;
    }
    return this.invoke('postComment', params);
  }

  loadThumbnails(sourceKey: string, id: string): Promise<Object | null> {
    let thumbParams: LoadComicParams = { sourceKey: sourceKey, id: id };
    return this.invoke('loadThumbnails', thumbParams);
  }

  loadRanking(categoryKey: string, option: string, page: number): Promise<Object | null> {
    let rankParams: LoadRankingParams = { categoryKey: categoryKey, option: option, page: page };
    return this.invoke('loadRanking', rankParams);
  }

  randomCategoryRefresh(params: CategoryLoadParams): Promise<Object | null> {
    return this.invoke('randomCategoryRefresh', params);
  }

  getImageFavorites(keyword?: string): Promise<Object | null> {
    let params: ImageFavParams = {};
    if (keyword !== undefined) {
      params.keyword = keyword;
    }
    return this.invoke('getImageFavorites', params);
  }

  getImageFavoriteImages(id: string, sourceKey: string): Promise<Object | null> {
    let params: ComicIdSourceParams = { id: id, sourceKey: sourceKey };
    return this.invoke('getImageFavoriteImages', params);
  }

  deleteImageFavorites(ids: string[], sourceKey: string): Promise<Object | null> {
    let delImgParams: DeleteImageFavoritesParams = { ids: ids, sourceKey: sourceKey };
    return this.invoke('deleteImageFavorites', delImgParams);
  }

  removeComicSource(key: string): Promise<Object | null> {
    let removeSourceParams: KeyParams = { key: key };
    return this.invoke('removeComicSource', removeSourceParams);
  }

  addComicSourceFromUrl(url: string): Promise<Object | null> {
    let params: UrlParams = { url: url };
    return this.invoke('addComicSourceFromUrl', params);
  }

  importComicSourceFromContent(content: string, fileName: string): Promise<Object | null> {
    let params: ImportContentParams = { content: content, fileName: fileName };
    return this.invoke('importComicSourceFromContent', params);
  }

  updateComicSource(key: string): Promise<Object | null> {
    let params: KeyParams = { key: key };
    return this.invoke('updateComicSource', params);
  }

  checkComicSourceUpdates(): Promise<Object | null> {
    return this.invoke('checkComicSourceUpdates', null);
  }

  readComicSourceFile(key: string): Promise<Object | null> {
    let params: KeyParams = { key: key };
    return this.invoke('readComicSourceFile', params);
  }

  saveComicSourceFile(key: string, content: string): Promise<Object | null> {
    let params: SaveSourceFileParams = { key: key, content: content };
    return this.invoke('saveComicSourceFile', params);
  }

  reloadJsEngine(): Promise<Object | null> {
    return this.invoke('reloadJsEngine', null);
  }

  clearCache(): Promise<Object | null> {
    return this.invoke('clearCache', null);
  }

  getAppInfo(): Promise<Object | null> {
    return this.invoke('getAppInfo', null);
  }

  deleteLocalComic(id: string, sourceKey: string): Promise<Object | null> {
    let delLocalParams: DeleteHistoryParams = { id: id, sourceKey: sourceKey };
    return this.invoke('deleteLocalComic', delLocalParams);
  }

  startDownload(sourceKey: string, id: string, chapters?: number[]): Promise<Object | null> {
    let params: StartDownloadParams = { sourceKey: sourceKey, id: id };
    if (chapters !== undefined) {
      params.chapters = chapters;
    }
    return this.invoke('startDownload', params);
  }

  importComicFromPath(path: string): Promise<Object | null> {
    let importParams: PathParams = { path: path };
    return this.invoke('importComicFromPath', importParams);
  }

  getNetworkFavoriteSources(): Promise<Object | null> {
    return this.invoke('getNetworkFavoriteSources', null);
  }

  getSearchTagSuggestions(keyword: string, sourceKey: string): Promise<Object | null> {
    let params: TagSuggestParams = { keyword: keyword, sourceKey: sourceKey };
    return this.invoke('getSearchTagSuggestions', params);
  }

  getComicSourceSettings(sourceKey: string): Promise<Object | null> {
    let params: SourceKeyParams = { sourceKey: sourceKey };
    return this.invoke('getComicSourceSettings', params);
  }

  setComicSourceSetting(sourceKey: string, key: string, value: Object | null): Promise<Object | null> {
    let params: SourceSettingParams = { sourceKey: sourceKey, key: key, value: value };
    return this.invoke('setComicSourceSetting', params);
  }

  computeImageFavoritesChart(): Promise<Object | null> {
    return this.invoke('computeImageFavoritesChart', null);
  }

  getComicSourceAccountConfig(sourceKey: string): Promise<Object | null> {
    let params: SourceKeyParams = { sourceKey: sourceKey };
    return this.invoke('getComicSourceAccountConfig', params);
  }

  comicSourceLogin(
    sourceKey: string,
    username?: string,
    password?: string,
    cookies?: string[]
  ): Promise<Object | null> {
    let params: ComicSourceLoginParams = { sourceKey: sourceKey };
    if (username !== undefined) {
      params.username = username;
    }
    if (password !== undefined) {
      params.password = password;
    }
    if (cookies !== undefined) {
      params.cookies = cookies;
    }
    return this.invoke('comicSourceLogin', params);
  }

  comicSourceLogout(sourceKey: string): Promise<Object | null> {
    let params: SourceKeyParams = { sourceKey: sourceKey };
    return this.invoke('comicSourceLogout', params);
  }

  comicSourceRelogin(sourceKey: string): Promise<Object | null> {
    let params: SourceKeyParams = { sourceKey: sourceKey };
    return this.invoke('comicSourceRelogin', params);
  }

  invokeComicSourceCallback(sourceKey: string, settingKey: string): Promise<Object | null> {
    let params: SourceCallbackParams = { sourceKey: sourceKey, settingKey: settingKey };
    return this.invoke('invokeComicSourceCallback', params);
  }

  getLocalFavoriteFolderNames(): Promise<Object | null> {
    return this.invoke('getLocalFavoriteFolderNames', null);
  }

  fetchComicSourceCatalog(url: string): Promise<Object | null> {
    let params: UrlParams = { url: url };
    return this.invoke('fetchComicSourceCatalog', params);
  }

  updateFavoriteInfo(folder: string, id: string, sourceKey: string): Promise<Object | null> {
    let params: FavoriteInfoParams = { folder: folder, id: id, sourceKey: sourceKey };
    return this.invoke('updateFavoriteInfo', params);
  }

  downloadFavoriteComics(items: FavoriteComicItem[]): Promise<Object | null> {
    let params: DownloadFavParams = { items: items };
    return this.invoke('downloadFavoriteComics', params);
  }

  getAppLogs(): Promise<Object | null> {
    return this.invoke('getAppLogs', null);
  }

  addImageFavorite(params: Record<string, Object>): Promise<Object | null> {
    return this.invoke('addImageFavorite', params);
  }

  loadChapterComments(sourceKey: string, comicId: string, subId: string, page: number,
    replyTo?: string): Promise<Object | null> {
    let params: ChapterCommentsParams = {
      sourceKey: sourceKey,
      comicId: comicId,
      subId: subId,
      page: page
    };
    if (replyTo !== undefined) {
      params.replyTo = replyTo;
    }
    return this.invoke('loadChapterComments', params);
  }

  exportComics(items: ExportComicItem[], format: string): Promise<Object | null> {
    let params: ExportComicsParams = { items: items, format: format };
    return this.invoke('exportComics', params);
  }

  exportAppData(): Promise<Object | null> {
    return this.invoke('exportAppData', null);
  }

  importAppData(path: string): Promise<Object | null> {
    let params: ImportAppDataParams = { path: path };
    return this.invoke('importAppData', params);
  }

  runJsCode(code: string): Promise<Object | null> {
    let params: RunJsCodeParams = { code: code };
    return this.invoke('runJsCode', params);
  }

  removeInvalidFavorites(): Promise<Object | null> {
    return this.invoke('removeInvalidFavorites', null);
  }

  likeComment(
    sourceKey: string,
    id: string,
    subId: string,
    commentId: string,
    isLiking: boolean
  ): Promise<Object | null> {
    let params: LikeCommentParams = {
      sourceKey: sourceKey,
      id: id,
      subId: subId,
      commentId: commentId,
      isLiking: isLiking
    };
    return this.invoke('likeComment', params);
  }

  voteComment(
    sourceKey: string,
    id: string,
    subId: string,
    commentId: string,
    isUp: boolean,
    isCancel: boolean
  ): Promise<Object | null> {
    let params: VoteCommentParams = {
      sourceKey: sourceKey,
      id: id,
      subId: subId,
      commentId: commentId,
      isUp: isUp,
      isCancel: isCancel
    };
    return this.invoke('voteComment', params);
  }

  importLocalComic(
    mode: string,
    path?: string,
    downloadPath?: string,
    selectedFolder?: string,
    copyToLocal?: boolean
  ): Promise<Object | null> {
    let params: ImportLocalComicParams = { mode: mode };
    if (path !== undefined) {
      params.path = path;
    }
    if (downloadPath !== undefined) {
      params.downloadPath = downloadPath;
    }
    if (selectedFolder !== undefined) {
      params.selectedFolder = selectedFolder;
    }
    if (copyToLocal !== undefined) {
      params.copyToLocal = copyToLocal;
    }
    return this.invoke('importLocalComic', params);
  }

  getComicTileStatuses(): Promise<Object | null> {
    return this.invoke('getComicTileStatuses', null);
  }

  refreshHistory(id: string, sourceKey: string): Promise<Object | null> {
    let params: DeleteHistoryParams = { id: id, sourceKey: sourceKey };
    return this.invoke('refreshHistory', params);
  }

  setReaderSetting(
    comicId: string,
    sourceKey: string,
    key: string,
    value: Object | null
  ): Promise<Object | null> {
    let params: SetReaderSettingParams = {
      comicId: comicId,
      sourceKey: sourceKey,
      key: key,
      value: value
    };
    return this.invoke('setReaderSetting', params);
  }

  setComicSpecificSettingsEnabled(
    comicId: string,
    sourceKey: string,
    enabled: boolean
  ): Promise<Object | null> {
    let params: SetComicSpecificParams = {
      comicId: comicId,
      sourceKey: sourceKey,
      enabled: enabled
    };
    return this.invoke('setComicSpecificSettingsEnabled', params);
  }

  checkForUpdate(): Promise<Object | null> {
    return this.invoke('checkForUpdate', null);
  }
}

interface ExploreLoadPageParams {
  sourceKey: string;
  pageTitle: string;
  page: number;
  next?: string;
}

interface DeleteHistoryParams {
  id: string;
  sourceKey: string;
}

interface SetReaderSettingParams {
  comicId: string;
  sourceKey: string;
  key: string;
  value: Object | null;
}

interface SetComicSpecificParams {
  comicId: string;
  sourceKey: string;
  enabled: boolean;
}

interface SetSettingParams {
  key: string;
  value: Object | null;
}

interface CategoryPartsParams {
  key: string;
}

export interface CategoryLoadParams {
  categoryKey: string;
  category: string;
  param?: string;
  options?: string[];
  page: number;
}

interface SearchParams {
  sourceKey: string;
  keyword: string;
  page: number;
  option: string;
  next?: string;
}

interface LoadComicParams {
  sourceKey: string;
  id: string;
}

interface GetFavoritesParams {
  folder: string;
  isNetwork: boolean;
  readFilter?: string;
}

interface NetworkFavParams {
  sourceKey: string;
  page: number;
  folder?: string;
}

interface CoverImageParams {
  url: string;
  sourceKey?: string;
  cid?: string;
  fallbackToLocalCover?: boolean;
}

export interface AddFavoriteParams {
  folder: string;
  sourceKey: string;
  id: string;
  title: string;
  cover: string;
  author: string;
  tags: string[];
  updateTime?: string;
}

interface RemoteFoldersParams {
  sourceKey: string;
  comicId?: string;
}

interface CommentsParams {
  sourceKey: string;
  id: string;
  page: number;
  subId?: string;
  replyTo?: string;
}

interface PostCommentParams {
  sourceKey: string;
  id: string;
  content: string;
  subId?: string;
  replyTo?: string;
}

interface ImageFavParams {
  keyword?: string;
}

interface StartDownloadParams {
  sourceKey: string;
  id: string;
  chapters?: number[];
}

interface NameParams {
  name: string;
}

interface RemoveFavoriteParams {
  folder: string;
  id: string;
  sourceKey: string;
}

interface ReorderFavoritesParams {
  folder: string;
  ids: string[];
}

interface IndexParams {
  index: number;
}

interface AggregatedSearchParams {
  keyword: string;
  page: number;
}

interface LoadRankingParams {
  categoryKey: string;
  option: string;
  page: number;
}

interface DeleteImageFavoritesParams {
  ids: string[];
  sourceKey: string;
}

interface KeyParams {
  key: string;
}

interface PathParams {
  path: string;
}

interface UrlParams {
  url: string;
}

interface SourceKeyParams {
  sourceKey: string;
}

interface LikeComicParams {
  sourceKey: string;
  id: string;
  isLiking: boolean;
}

interface ComicIdSourceParams {
  id: string;
  sourceKey: string;
}

interface ImportContentParams {
  content: string;
  fileName: string;
}

interface SaveSourceFileParams {
  key: string;
  content: string;
}

interface TagSuggestParams {
  keyword: string;
  sourceKey: string;
}

interface SourceSettingParams {
  sourceKey: string;
  key: string;
  value: Object | null;
}

interface FavoriteInfoParams {
  folder: string;
  id: string;
  sourceKey: string;
}

interface FavoriteComicItem {
  id: string;
  sourceKey: string;
}

interface DownloadFavParams {
  items: FavoriteComicItem[];
}

interface ImageFavoriteParams {
  comicId: string;
  sourceKey: string;
  title: string;
  author: string;
  tags: string[];
  ep: number;
  page: number;
  imageKey: string;
  eid: string;
  epName?: string;
  maxPage?: number;
}

interface ChapterCommentsParams {
  sourceKey: string;
  comicId: string;
  subId: string;
  page: number;
  replyTo?: string;
}

interface ExportComicItem {
  id: string;
  sourceKey: string;
}

interface ExportComicsParams {
  items: ExportComicItem[];
  format: string;
}

interface ImportAppDataParams {
  path: string;
}

interface RunJsCodeParams {
  code: string;
}

interface LikeCommentParams {
  sourceKey: string;
  id: string;
  subId: string;
  commentId: string;
  isLiking: boolean;
}

interface VoteCommentParams {
  sourceKey: string;
  id: string;
  subId: string;
  commentId: string;
  isUp: boolean;
  isCancel: boolean;
}

interface ImportLocalComicParams {
  mode: string;
  path?: string;
  downloadPath?: string;
  selectedFolder?: string;
  copyToLocal?: boolean;
}

interface ComicSourceLoginParams {
  sourceKey: string;
  username?: string;
  password?: string;
  cookies?: string[];
}

interface SourceCallbackParams {
  sourceKey: string;
  settingKey: string;
}
