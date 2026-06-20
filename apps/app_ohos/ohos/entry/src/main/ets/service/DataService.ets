import { DataBridge, AddFavoriteParams, CategoryLoadParams } from '../bridge/DataBridge';
import { Comic } from '../model/Comic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsMirror } from '../utils/SettingsMirror';
import { APP_VERSION_FALLBACK } from '../utils/SettingsConstants';

const DATA_SERVICE_DOMAIN: number = 0x0000;
const DATA_SERVICE_TAG: string = 'DataService';

export interface HistoryItem {
  id: string;
  title: string;
  subtitle: string;
  cover: string;
  ep: number;
  page: number;
  sourceKey: string;
  time: number;
  description: string;
}

export interface ExploreLoadResult {
  comics: Comic[];
  hasMore: boolean;
  error?: string;
  options?: Record<string, string>;
  next?: string;
}

export interface ExplorePageSource {
  title: string;
  sourceKey: string;
}

export interface CategoryMeta {
  key: string;
  title: string;
  sourceKey: string;
}

export interface CategoryPartItem {
  label: string;
  target: CategoryTarget;
}

export interface CategoryTarget {
  sourceKey: string;
  page: string;
  attributes?: Record<string, string>;
}

export interface CategoryPart {
  title: string;
  enableRandom: boolean;
  items: CategoryPartItem[];
}

export interface DownloadTaskInfo {
  id: string;
  title: string;
  progress: number;
  message: string;
  cover?: string;
  isPaused: boolean;
  isError: boolean;
  speed?: number;
}

export interface SyncStatus {
  enabled: boolean;
  isUploading: boolean;
  isDownloading: boolean;
  lastError?: string;
}

export interface FollowUpdatesSummary {
  folder: string | null;
  count: number;
}

export interface ImageFavoriteSummary {
  id: string;
  title: string;
  subTitle: string;
  sourceKey: string;
  imageCount: number;
}

export interface ImageFavoriteImage {
  url: string;
  ep: number;
  page: number;
}

export interface AggregatedSearchResult {
  sourceKey: string;
  sourceName: string;
  comics?: ComicJson[];
  hasMore?: boolean;
  error?: string;
}

export interface AppInfo {
  version: string;
  dataPath: string;
}

export interface CommentInfo {
  userName: string;
  avatar: string;
  content: string;
  time: string;
  replyCount: number;
  id: string;
  score: number;
  isLiked: boolean;
  voteStatus: number;
}

export interface CommentsLoadResult {
  comments: CommentInfo[];
  hasMore: boolean;
  error?: string;
}

export interface RankingLoadResult extends ExploreLoadResult {
  options?: Record<string, string>;
}

export interface AddFavoriteRequest {
  folder: string;
  sourceKey: string;
  id: string;
  title: string;
  cover: string;
  author: string;
  tags: string[];
  updateTime?: string;
}

export interface ComicSourceInfo {
  key: string;
  name: string;
  version?: string;
  remoteVersion?: string;
  hasUpdate?: boolean;
  hasSearch: boolean;
  hasCategory: boolean;
  explorePages: string[];
  categoryKey?: string;
  categoryTitle?: string;
  favoriteKey?: string;
  favoriteTitle?: string;
  hasNetworkFavorite?: boolean;
  hasAccount?: boolean;
  isLogged?: boolean;
  loginWebsite?: string;
}

export interface ComicSourcesResult {
  sources: ComicSourceInfo[];
  updateCount: number;
}

export interface ChartEntryData {
  label: string;
  count: number;
}

export interface ImageFavoritesChartData {
  tags: ChartEntryData[];
  authors: ChartEntryData[];
  comics: ChartEntryData[];
  totalImages: number;
}

export interface ComicSourceUpdateInfo {
  key: string;
  name: string;
  remoteVersion?: string;
  localVersion?: string;
}

export interface ComicSourceUpdatesResult {
  count: number;
  updates: ComicSourceUpdateInfo[];
  error?: string;
}

export interface AccountInfoItemData {
  title: string;
  data?: string;
}

export interface ComicSourceAccountConfig {
  hasAccount: boolean;
  isLogged?: boolean;
  loginWebsite?: string;
  registerWebsite?: string;
  hasPasswordLogin?: boolean;
  hasCookieLogin?: boolean;
  cookieFields?: string[];
  infoItems?: AccountInfoItemData[];
}

export interface CatalogEntry {
  key: string;
  name: string;
  version?: string;
  description?: string;
  fileName?: string;
  url?: string;
}

export interface BackendPingResult {
  ok: boolean;
}

export class DataService {
  private static instance: DataService | null = null;
  private bridge: DataBridge = DataBridge.getInstance();

  static getInstance(): DataService {
    if (DataService.instance === null) {
      DataService.instance = new DataService();
    }
    return DataService.instance;
  }

  private parseBridgeJson<T>(raw: Object | null): T | null {
    if (raw === null) {
      return null;
    }
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw) as T;
      } catch (e) {
        return null;
      }
    }
    return this.parseJson<T>(raw);
  }

  private parseJson<T>(raw: Object | null): T | null {
    if (raw === null) {
      return null;
    }
    try {
      return JSON.parse(JSON.stringify(raw)) as T;
    } catch (e) {
      return null;
    }
  }

  private isOkResult(raw: Object | null): boolean {
    if (raw === null) {
      return false;
    }
    if (typeof raw === 'string') {
      return raw === 'ok';
    }
    if (typeof raw === 'boolean') {
      return raw;
    }
    let parsed = this.parseJson<Record<string, Object>>(raw);
    if (parsed === null) {
      return false;
    }
    if (parsed['error'] !== undefined && parsed['error'] !== null) {
      return false;
    }
    let ok = parsed['ok'];
    return ok === true || ok === 1;
  }

  private asBool(value: Object | undefined | null): boolean | null {
    if (value === true || value === 1) {
      return true;
    }
    if (value === false || value === 0) {
      return false;
    }
    return null;
  }

  private settingValueMatches(
    settings: Record<string, Object>,
    key: string,
    value: Object | null
  ): boolean {
    let actual = settings[key];
    if (value === null) {
      return actual === null || actual === undefined;
    }
    if (typeof value === 'boolean') {
      let actualBool = this.asBool(actual);
      if (actualBool === null) {
        return value === false;
      }
      return actualBool === value;
    }
    return actual === value;
  }

  private bridgeValueForSetting(value: Object | null): Object | null {
    if (typeof value === 'boolean') {
      return value ? 1 : 0;
    }
    return value;
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  async exploreLoadPage(
    sourceKey: string,
    pageTitle: string,
    page: number = 1,
    next?: string
  ): Promise<ExploreLoadResult> {
    let raw: Object | null = await this.bridge.exploreLoadPage(sourceKey, pageTitle, page, next);
    return this.parseExploreResult(raw);
  }

  async getHistory(): Promise<HistoryItem[]> {
    let raw: Object | null = await this.bridge.getHistory();
    let parsed = this.parseJson<HistoryResponse>(raw);
    return parsed?.histories ?? [];
  }

  async pingBackend(): Promise<BackendPingResult> {
    let raw: Object | null = await this.bridge.pingBackend();
    let parsed = this.parseJson<BackendPingResult>(raw);
    return parsed ?? { ok: false };
  }

  async deleteHistory(id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.deleteHistory(id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async getSettings(): Promise<Record<string, Object>> {
    let fromBridge: Record<string, Object> = {};
    let raw: Object | null = await this.bridge.getSettingsJson();
    let parsed = this.parseBridgeJson<Record<string, Object>>(raw);
    if (parsed !== null && Object.keys(parsed).length > 0) {
      fromBridge = parsed;
    } else {
      let legacyRaw: Object | null = await this.bridge.getSettings();
      let legacy = this.parseJson<Record<string, Object>>(legacyRaw);
      if (legacy !== null && Object.keys(legacy).length > 0) {
        fromBridge = legacy;
      }
    }
    let merged: Record<string, Object> = SettingsMirror.mergeFromCache(fromBridge);
    if (Object.keys(merged).length === 0) {
      merged = SettingsMirror.readCache();
    } else if (SettingsMirror.shouldPersistCache(merged)) {
      SettingsMirror.writeCache(merged);
    }
    SettingsMirror.syncFromSettings(merged);
    return merged;
  }

  static settingIsTrue(settings: Record<string, Object>, key: string): boolean {
    let value = settings[key];
    return value === true || value === 1;
  }

  async setSetting(key: string, value: Object | null): Promise<boolean> {
    let bridgeValue: Object | null = this.bridgeValueForSetting(value);
    try {
      await this.bridge.setSettingNoWait(key, bridgeValue);
      if (typeof value === 'boolean') {
        SettingsMirror.applyPatch(key, value);
      }
      await this.delayMs(80);
      let settings = await this.getSettings();
      let matched: boolean = this.settingValueMatches(settings, key, value);
      if (!matched) {
        hilog.warn(DATA_SERVICE_DOMAIN, DATA_SERVICE_TAG,
          'setSetting verify inconclusive %{public}s actual=%{public}s expected=%{public}s',
          key, JSON.stringify(settings[key]), JSON.stringify(value));
      }
      return true;
    } catch (e) {
      hilog.error(DATA_SERVICE_DOMAIN, DATA_SERVICE_TAG,
        'setSetting exception %{public}s err=%{public}s', key, JSON.stringify(e));
      return false;
    }
  }

  async getComicSourcesResult(): Promise<ComicSourcesResult> {
    let raw: Object | null = await this.bridge.getComicSources();
    let parsed = this.parseJson<SourcesResponse>(raw);
    return {
      sources: parsed?.sources ?? [],
      updateCount: parsed?.updateCount ?? 0
    };
  }

  async getComicSources(): Promise<ComicSourceInfo[]> {
    let result: ComicSourcesResult = await this.getComicSourcesResult();
    return result.sources;
  }

  async getExploreConfig(): Promise<ExplorePageSource[]> {
    let raw: Object | null = await this.bridge.getExploreConfig();
    let parsed = this.parseJson<ExploreConfigResponse>(raw);
    return parsed?.pageSources ?? [];
  }

  async getCategoryConfig(): Promise<CategoryMeta[]> {
    let raw: Object | null = await this.bridge.getCategoryConfig();
    let parsed = this.parseJson<CategoryConfigResponse>(raw);
    return parsed?.categoryMeta ?? [];
  }

  async getCategoryParts(key: string): Promise<CategoryPartsResult | null> {
    let raw: Object | null = await this.bridge.getCategoryParts(key);
    return this.parseJson<CategoryPartsResult>(raw);
  }

  async categoryLoadPage(
    categoryKey: string,
    category: string,
    page: number,
    param?: string,
    options?: string[]
  ): Promise<ExploreLoadResult> {
    let params: CategoryLoadParams = {
      categoryKey: categoryKey,
      category: category,
      page: page,
      options: options ?? []
    };
    if (param !== undefined) {
      params.param = param;
    }
    let raw: Object | null = await this.bridge.categoryLoadPage(params);
    return this.parseExploreResult(raw);
  }

  async search(
    sourceKey: string,
    keyword: string,
    page: number = 1,
    option: string = '',
    next?: string
  ): Promise<ExploreLoadResult> {
    let raw: Object | null = await this.bridge.search(sourceKey, keyword, page, option, next);
    return this.parseExploreResult(raw);
  }

  async resolveComicLink(url: string): Promise<ComicLinkResult | null> {
    let raw: Object | null = await this.bridge.resolveComicLink(url);
    return this.parseJson<ComicLinkResult>(raw);
  }

  async getSearchOptions(sourceKey: string): Promise<Record<string, string>> {
    let raw: Object | null = await this.bridge.getSearchOptions(sourceKey);
    let parsed = this.parseJson<SearchOptionsResult>(raw);
    return parsed?.options ?? {};
  }

  async getSearchHistory(): Promise<string[]> {
    let raw: Object | null = await this.bridge.getSearchHistory();
    let parsed = this.parseJson<SearchHistoryResponse>(raw);
    return parsed?.history ?? [];
  }

  async loadComicInfo(sourceKey: string, id: string): Promise<ComicDetailResult | null> {
    let raw: Object | null = await this.bridge.loadComicInfo(sourceKey, id);
    return this.parseJson<ComicDetailResult>(raw);
  }

  async likeComic(sourceKey: string, id: string, isLiking: boolean): Promise<boolean> {
    let raw: Object | null = await this.bridge.likeComic(sourceKey, id, isLiking);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async getFavoriteFolders(): Promise<string[]> {
    let raw: Object | null = await this.bridge.getFavoriteFolders();
    let parsed = this.parseJson<FoldersResponse>(raw);
    return parsed?.folders ?? [];
  }

  async getFavorites(folder: string, readFilter: string = 'All'): Promise<Comic[]> {
    let raw: Object | null = await this.bridge.getFavorites(folder, false, readFilter);
    let parsed = this.parseJson<FavoritesResponse>(raw);
    if (parsed?.comics === undefined) {
      return [];
    }
    return parsed.comics.map((item: ComicJson) => this.toComic(item));
  }

  async loadNetworkFavorites(sourceKey: string, page: number = 1, folder?: string): Promise<ExploreLoadResult> {
    let raw: Object | null = await this.bridge.loadNetworkFavorites(sourceKey, page, folder);
    return this.parseExploreResult(raw);
  }

  async loadFavoriteFoldersRemote(sourceKey: string, comicId?: string): Promise<string[]> {
    let raw: Object | null = await this.bridge.loadFavoriteFoldersRemote(sourceKey, comicId);
    let parsed = this.parseJson<RemoteFoldersResult>(raw);
    if (parsed?.error !== undefined) {
      return [];
    }
    return parsed?.folders ?? [];
  }

  async moveFavoritesToFolder(
    fromFolder: string,
    toFolder: string,
    comics: Comic[]
  ): Promise<boolean> {
    let service: DataService = this;
    for (let i: number = 0; i < comics.length; i++) {
      let comic: Comic = comics[i];
      let added = await service.addFavorite({
        folder: toFolder,
        sourceKey: comic.sourceKey,
        id: comic.id,
        title: comic.title,
        cover: comic.cover,
        author: comic.subtitle,
        tags: comic.tags ?? []
      });
      if (!added) {
        return false;
      }
      let folderKey: string = fromFolder === '^_^[%local_all%]^_^' ? '' : fromFolder;
      if (folderKey.length > 0) {
        await service.removeFavorite(folderKey, comic.id, comic.sourceKey);
      }
    }
    return true;
  }

  async getLocalComics(): Promise<Comic[]> {
    let raw: Object | null = await this.bridge.getLocalComics();
    let parsed = this.parseJson<ComicsResponse>(raw);
    if (parsed?.comics === undefined) {
      return [];
    }
    return parsed.comics.map((item: ComicJson) => this.toComic(item));
  }

  async getDownloadTasks(): Promise<DownloadTaskInfo[]> {
    let raw: Object | null = await this.bridge.getDownloadTasks();
    let parsed = this.parseJson<DownloadTasksResponse>(raw);
    return parsed?.tasks ?? [];
  }

  async webdavUpload(): Promise<string | null> {
    let raw: Object | null = await this.bridge.webdavUpload();
    let parsed = this.parseJson<ErrorResult>(raw);
    return parsed?.error ?? null;
  }

  async webdavDownload(): Promise<string | null> {
    let raw: Object | null = await this.bridge.webdavDownload();
    let parsed = this.parseJson<ErrorResult>(raw);
    return parsed?.error ?? null;
  }

  async loadCoverImageBase64(
    url: string,
    sourceKey?: string,
    cid?: string,
    fallback?: boolean
  ): Promise<string | null> {
    let raw: Object | null = await this.bridge.loadCoverImage(url, sourceKey, cid, fallback);
    let parsed = this.parseJson<CoverImageResult>(raw);
    if (parsed?.error !== undefined && parsed.error.length > 0) {
      return null;
    }
    return parsed?.base64 ?? null;
  }

  async clearSearchHistory(): Promise<void> {
    await this.bridge.clearSearchHistory();
  }

  async clearAllHistory(): Promise<void> {
    await this.bridge.clearHistory();
  }

  async getSyncStatus(): Promise<SyncStatus> {
    let raw: Object | null = await this.bridge.getSyncStatus();
    return this.parseJson<SyncStatus>(raw) ?? {
      enabled: false,
      isUploading: false,
      isDownloading: false
    };
  }

  async getFollowUpdatesSummary(): Promise<FollowUpdatesSummary> {
    let raw: Object | null = await this.bridge.getFollowUpdatesSummary();
    return this.parseJson<FollowUpdatesSummary>(raw) ?? { folder: null, count: 0 };
  }

  async getFollowUpdatesList(): Promise<Comic[]> {
    let raw: Object | null = await this.bridge.getFollowUpdatesList();
    let parsed = this.parseJson<ComicsResponse>(raw);
    if (parsed?.comics === undefined) {
      return [];
    }
    return parsed.comics.map((item: ComicJson) => this.toComic(item));
  }

  async checkFollowUpdates(): Promise<number> {
    let raw: Object | null = await this.bridge.checkFollowUpdates();
    let parsed = this.parseJson<FollowUpdateCheckResult>(raw);
    return parsed?.updated ?? 0;
  }

  async setFollowUpdatesFolder(folder: string | null): Promise<boolean> {
    let raw: Object | null = await this.bridge.setFollowUpdatesFolder(folder);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async markFavoriteAsRead(id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.markFavoriteAsRead(id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async getFavoriteFolderCounts(): Promise<Record<string, number>> {
    let raw: Object | null = await this.bridge.getFavoriteFolderCounts();
    let parsed = this.parseJson<FolderCountsResponse>(raw);
    return parsed?.counts ?? {};
  }

  async createFavoriteFolder(name: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.createFavoriteFolder(name);
    let parsed = this.parseJson<FolderCreateResult>(raw);
    if (parsed?.error !== undefined) {
      return null;
    }
    return parsed?.folder ?? name;
  }

  async deleteFavoriteFolder(name: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.deleteFavoriteFolder(name);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async addFavorite(params: AddFavoriteRequest): Promise<boolean> {
    let bridgeParams: AddFavoriteParams = {
      folder: params.folder,
      sourceKey: params.sourceKey,
      id: params.id,
      title: params.title,
      cover: params.cover,
      author: params.author,
      tags: params.tags
    };
    if (params.updateTime !== undefined) {
      bridgeParams.updateTime = params.updateTime;
    }
    let raw: Object | null = await this.bridge.addFavorite(bridgeParams);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async removeFavorite(folder: string, id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.removeFavorite(folder, id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async reorderFavorites(folder: string, ids: string[]): Promise<boolean> {
    let raw: Object | null = await this.bridge.reorderFavorites(folder, ids);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async pauseDownload(index: number): Promise<boolean> {
    let raw: Object | null = await this.bridge.pauseDownload(index);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async resumeDownload(index: number): Promise<boolean> {
    let raw: Object | null = await this.bridge.resumeDownload(index);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async cancelDownload(index: number): Promise<boolean> {
    let raw: Object | null = await this.bridge.cancelDownload(index);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async moveDownloadToFirst(index: number): Promise<boolean> {
    let raw: Object | null = await this.bridge.moveDownloadToFirst(index);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async aggregatedSearch(keyword: string, page: number = 1): Promise<AggregatedSearchResult[]> {
    let raw: Object | null = await this.bridge.aggregatedSearch(keyword, page);
    let parsed = this.parseJson<AggregatedSearchResponse>(raw);
    return parsed?.results ?? [];
  }

  async loadRanking(categoryKey: string, option: string, page: number): Promise<RankingLoadResult> {
    let raw: Object | null = await this.bridge.loadRanking(categoryKey, option, page);
    let result: RankingLoadResult = this.parseExploreResult(raw) as RankingLoadResult;
    let parsed = this.parseJson<RankingRawResult>(raw);
    if (parsed?.options !== undefined) {
      result.options = parsed.options;
    }
    return result;
  }

  async loadComments(
    sourceKey: string,
    id: string,
    page: number = 1,
    subId?: string,
    replyTo?: string
  ): Promise<CommentsLoadResult> {
    let raw: Object | null = await this.bridge.loadComments(sourceKey, id, page, subId, replyTo);
    let parsed = this.parseJson<CommentsRawResult>(raw);
    if (parsed === null) {
      return { comments: [], hasMore: false, error: 'Empty response' };
    }
    if (parsed.error !== undefined && parsed.error.length > 0) {
      return { comments: [], hasMore: false, error: parsed.error };
    }
    return {
      comments: parsed.comments ?? [],
      hasMore: parsed.hasMore === true
    };
  }

  async getImageFavorites(keyword?: string): Promise<ImageFavoriteSummary[]> {
    let raw: Object | null = await this.bridge.getImageFavorites(keyword);
    let parsed = this.parseJson<ImageFavoritesResponse>(raw);
    return parsed?.comics ?? [];
  }

  async getImageFavoriteImages(id: string, sourceKey: string): Promise<ImageFavoriteImage[]> {
    let raw: Object | null = await this.bridge.getImageFavoriteImages(id, sourceKey);
    let parsed = this.parseJson<ImageFavoriteImagesResponse>(raw);
    return parsed?.images ?? [];
  }

  async deleteImageFavorites(ids: string[], sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.deleteImageFavorites(ids, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async removeComicSource(key: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.removeComicSource(key);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async addComicSourceFromUrl(url: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.addComicSourceFromUrl(url);
    let parsed = this.parseJson<SourceActionResult>(raw);
    if (parsed?.error !== undefined) {
      return null;
    }
    return parsed?.key ?? null;
  }

  async importComicSourceFromContent(content: string, fileName: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.importComicSourceFromContent(content, fileName);
    let parsed = this.parseJson<SourceActionResult>(raw);
    if (parsed?.error !== undefined) {
      return null;
    }
    return parsed?.key ?? null;
  }

  async updateComicSource(key: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.updateComicSource(key);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async checkComicSourceUpdates(): Promise<ComicSourceUpdatesResult> {
    let raw: Object | null = await this.bridge.checkComicSourceUpdates();
    let parsed = this.parseJson<UpdateCheckResult>(raw);
    return {
      count: parsed?.count ?? -1,
      updates: parsed?.updates ?? [],
      error: parsed?.error
    };
  }

  async readComicSourceFile(key: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.readComicSourceFile(key);
    let parsed = this.parseJson<SourceFileResult>(raw);
    if (parsed?.error !== undefined) {
      return null;
    }
    return parsed?.content ?? null;
  }

  async saveComicSourceFile(key: string, content: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.saveComicSourceFile(key, content);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async reloadJsEngine(): Promise<boolean> {
    let raw: Object | null = await this.bridge.reloadJsEngine();
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async clearCache(): Promise<boolean> {
    let raw: Object | null = await this.bridge.clearCache();
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async getAppInfo(): Promise<AppInfo> {
    let fallback: AppInfo = { version: APP_VERSION_FALLBACK, dataPath: '' };
    try {
      let raw: Object | null = await this.bridge.getAppInfo();
      let parsed = this.parseJson<AppInfo>(raw);
      if (parsed === null) {
        return fallback;
      }
      let version = parsed.version ?? '';
      return {
        version: version.length > 0 ? version : fallback.version,
        dataPath: parsed.dataPath ?? ''
      };
    } catch (_) {
      return fallback;
    }
  }

  async deleteLocalComic(id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.deleteLocalComic(id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async startDownload(sourceKey: string, id: string, chapters?: number[]): Promise<boolean> {
    let raw: Object | null = await this.bridge.startDownload(sourceKey, id, chapters);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async importComicFromPath(path: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.importComicFromPath(path);
    let parsed = this.parseJson<ErrorResult>(raw);
    return parsed?.error ?? null;
  }

  async getNetworkFavoriteSources(): Promise<string[]> {
    let raw: Object | null = await this.bridge.getNetworkFavoriteSources();
    let parsed = this.parseJson<NetworkSourcesResponse>(raw);
    return parsed?.sources ?? [];
  }

  async postComment(
    sourceKey: string,
    id: string,
    content: string,
    subId?: string,
    replyTo?: string
  ): Promise<boolean> {
    let raw: Object | null = await this.bridge.postComment(sourceKey, id, content, subId, replyTo);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async loadThumbnails(sourceKey: string, id: string): Promise<string[]> {
    let raw: Object | null = await this.bridge.loadThumbnails(sourceKey, id);
    let parsed = this.parseJson<ThumbnailsResult>(raw);
    if (parsed?.error !== undefined) {
      return [];
    }
    return parsed?.thumbnails ?? [];
  }

  async randomCategoryRefresh(
    categoryKey: string,
    category: string,
    param?: string
  ): Promise<ExploreLoadResult> {
    let params: CategoryLoadParams = {
      categoryKey: categoryKey,
      category: category,
      page: 1,
      options: ['random']
    };
    if (param !== undefined) {
      params.param = param;
    }
    let raw: Object | null = await this.bridge.randomCategoryRefresh(params);
    return this.parseExploreResult(raw);
  }

  async getSearchTagSuggestions(keyword: string, sourceKey: string): Promise<string[]> {
    let raw: Object | null = await this.bridge.getSearchTagSuggestions(keyword, sourceKey);
    let parsed = this.parseJson<TagSuggestionsResponse>(raw);
    return parsed?.suggestions ?? [];
  }

  async getComicSourceSettings(sourceKey: string): Promise<SourceSettingItem[]> {
    let raw: Object | null = await this.bridge.getComicSourceSettings(sourceKey);
    let parsed = this.parseJson<SourceSettingsResponse>(raw);
    return parsed?.settings ?? [];
  }

  async setComicSourceSetting(sourceKey: string, key: string, value: Object | null): Promise<boolean> {
    let raw: Object | null = await this.bridge.setComicSourceSetting(sourceKey, key, value);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async updateFavoriteInfo(folder: string, id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.updateFavoriteInfo(folder, id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async downloadFavoriteComics(items: ExportComicItem[]): Promise<number> {
    let raw: Object | null = await this.bridge.downloadFavoriteComics(items);
    let parsed = this.parseJson<DownloadCountResult>(raw);
    return parsed?.count ?? 0;
  }

  async getAppLogs(): Promise<LogEntry[]> {
    let raw: Object | null = await this.bridge.getAppLogs();
    let parsed = this.parseJson<LogsResponse>(raw);
    return parsed?.logs ?? [];
  }

  async addImageFavorite(params: ImageFavoriteRequest): Promise<boolean> {
    let bridgeParams: Record<string, Object> = {
      'comicId': params.comicId,
      'sourceKey': params.sourceKey,
      'title': params.title,
      'author': params.author,
      'tags': params.tags,
      'ep': params.ep,
      'page': params.page,
      'imageKey': params.imageKey,
      'eid': params.eid
    };
    if (params.epName !== undefined) {
      bridgeParams['epName'] = params.epName;
    }
    if (params.maxPage !== undefined) {
      bridgeParams['maxPage'] = params.maxPage;
    }
    let raw: Object | null = await this.bridge.addImageFavorite(bridgeParams);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async loadChapterComments(
    sourceKey: string,
    comicId: string,
    subId: string,
    page: number,
    replyTo?: string
  ): Promise<CommentsLoadResult> {
    let raw: Object | null = await this.bridge.loadChapterComments(
      sourceKey, comicId, subId, page, replyTo
    );
    let parsed = this.parseJson<CommentsLoadResult>(raw);
    return parsed ?? { comments: [], hasMore: false, error: 'Failed to load' };
  }

  async exportComics(items: ExportComicItem[], format: string): Promise<ExportResult> {
    let raw: Object | null = await this.bridge.exportComics(items, format);
    let parsed = this.parseJson<ExportResult>(raw);
    return parsed ?? { error: 'Export failed' };
  }

  async exportAppData(): Promise<string | null> {
    let raw: Object | null = await this.bridge.exportAppData();
    let parsed = this.parseJson<ExportAppDataResult>(raw);
    if (parsed?.ok === true && parsed.path !== undefined) {
      return parsed.path;
    }
    return null;
  }

  async importAppData(path: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.importAppData(path);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async runJsCode(code: string): Promise<string> {
    let raw: Object | null = await this.bridge.runJsCode(code);
    let parsed = this.parseJson<JsCodeResult>(raw);
    if (parsed?.ok === true && parsed.result !== undefined) {
      return parsed.result;
    }
    return parsed?.error ?? 'Failed';
  }

  async removeInvalidFavorites(): Promise<number> {
    let raw: Object | null = await this.bridge.removeInvalidFavorites();
    let parsed = this.parseJson<RemoveInvalidResult>(raw);
    return parsed?.count ?? 0;
  }

  async likeComment(
    sourceKey: string,
    id: string,
    subId: string,
    commentId: string,
    isLiking: boolean
  ): Promise<boolean> {
    let raw: Object | null = await this.bridge.likeComment(
      sourceKey, id, subId, commentId, isLiking
    );
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async voteComment(
    sourceKey: string,
    id: string,
    subId: string,
    commentId: string,
    isUp: boolean,
    isCancel: boolean
  ): Promise<boolean> {
    let raw: Object | null = await this.bridge.voteComment(
      sourceKey, id, subId, commentId, isUp, isCancel
    );
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async importLocalComic(
    mode: string,
    path?: string,
    downloadPath?: string,
    selectedFolder?: string,
    copyToLocal?: boolean
  ): Promise<string | null> {
    let raw: Object | null = await this.bridge.importLocalComic(
      mode, path, downloadPath, selectedFolder, copyToLocal
    );
    let parsed = this.parseJson<ImportLocalResult>(raw);
    if (parsed?.ok === true) {
      return null;
    }
    return parsed?.error ?? 'Import failed';
  }

  async computeImageFavoritesChart(): Promise<ImageFavoritesChartData> {
    let raw: Object | null = await this.bridge.computeImageFavoritesChart();
    let parsed = this.parseJson<ImageFavoritesChartData>(raw);
    return parsed ?? { tags: [], authors: [], comics: [], totalImages: 0 };
  }

  async getComicSourceAccountConfig(sourceKey: string): Promise<ComicSourceAccountConfig> {
    let raw: Object | null = await this.bridge.getComicSourceAccountConfig(sourceKey);
    let parsed = this.parseJson<ComicSourceAccountConfig>(raw);
    return parsed ?? { hasAccount: false };
  }

  async comicSourceLogin(
    sourceKey: string,
    username?: string,
    password?: string,
    cookies?: string[]
  ): Promise<string | null> {
    let raw: Object | null = await this.bridge.comicSourceLogin(
      sourceKey, username, password, cookies
    );
    let parsed = this.parseJson<ErrorResult>(raw);
    if (parsed?.error !== undefined) {
      return parsed.error;
    }
    return null;
  }

  async comicSourceLogout(sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.comicSourceLogout(sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async comicSourceRelogin(sourceKey: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.comicSourceRelogin(sourceKey);
    let parsed = this.parseJson<ErrorResult>(raw);
    if (parsed?.error !== undefined) {
      return parsed.error;
    }
    return null;
  }

  async invokeComicSourceCallback(sourceKey: string, settingKey: string): Promise<string | null> {
    let raw: Object | null = await this.bridge.invokeComicSourceCallback(sourceKey, settingKey);
    let parsed = this.parseJson<ErrorResult>(raw);
    if (parsed?.error !== undefined) {
      return parsed.error;
    }
    return null;
  }

  async getLocalFavoriteFolderNames(): Promise<string[]> {
    let raw: Object | null = await this.bridge.getLocalFavoriteFolderNames();
    let parsed = this.parseJson<FoldersResponse>(raw);
    return parsed?.folders ?? [];
  }

  async fetchComicSourceCatalog(url: string): Promise<CatalogEntry[]> {
    let raw: Object | null = await this.bridge.fetchComicSourceCatalog(url);
    let parsed = this.parseJson<CatalogResponse>(raw);
    if (parsed?.error !== undefined) {
      return [];
    }
    return parsed?.entries ?? [];
  }

  async getComicTileStatuses(): Promise<ComicTileStatusData> {
    let raw: Object | null = await this.bridge.getComicTileStatuses();
    let parsed = this.parseJson<ComicTileStatusData>(raw);
    return parsed ?? { favoriteKeys: [], history: {} };
  }

  async refreshHistory(id: string, sourceKey: string): Promise<boolean> {
    let raw: Object | null = await this.bridge.refreshHistory(id, sourceKey);
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async setReaderSetting(
    comicId: string,
    sourceKey: string,
    key: string,
    value: Object | null
  ): Promise<boolean> {
    let raw: Object | null = await this.bridge.setReaderSetting(
      comicId, sourceKey, key, value
    );
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async setComicSpecificSettingsEnabled(
    comicId: string,
    sourceKey: string,
    enabled: boolean
  ): Promise<boolean> {
    let raw: Object | null = await this.bridge.setComicSpecificSettingsEnabled(
      comicId, sourceKey, enabled
    );
    let parsed = this.parseJson<OkResult>(raw);
    return parsed?.ok === true;
  }

  async checkForUpdate(): Promise<CheckUpdateResult> {
    let raw: Object | null = await this.bridge.checkForUpdate();
    let parsed = this.parseJson<CheckUpdateResult>(raw);
    return parsed ?? { hasUpdate: false };
  }

  private parseExploreResult(raw: Object | null): ExploreLoadResult {
    let result: ExploreLoadResult = { comics: [], hasMore: false };
    let parsed = this.parseJson<ExploreRawResult>(raw);
    if (parsed === null) {
      result.error = 'Empty response';
      return result;
    }
    if (parsed.error !== undefined && parsed.error.length > 0) {
      result.error = parsed.error;
      return result;
    }
    if (parsed.comics !== undefined) {
      result.comics = parsed.comics.map((item: ComicJson) => this.toComic(item));
    }
    if (typeof parsed.hasMore === 'boolean') {
      result.hasMore = parsed.hasMore;
    } else if (typeof parsed.hasMore === 'string') {
      result.hasMore = parsed.hasMore.length > 0;
      if (parsed.hasMore.length > 0) {
        result.next = parsed.hasMore;
      }
    }
    if (parsed.next !== undefined && parsed.next.length > 0) {
      result.next = parsed.next;
      result.hasMore = true;
    }
    if (parsed.options !== undefined) {
      result.options = parsed.options;
    }
    return result;
  }

  private toComic(item: ComicJson): Comic {
    let comic: Comic = new Comic();
    comic.id = item.id ?? '';
    comic.title = item.title ?? item.name ?? '';
    comic.cover = item.cover ?? item.coverPath ?? '';
    comic.subtitle = item.subTitle ?? item.subtitle ?? item.author ?? '';
    comic.tags = item.tags ?? [];
    comic.description = item.description ?? '';
    comic.sourceKey = item.sourceKey ?? '';
    comic.maxPage = item.maxPage ?? 0;
    comic.language = item.language ?? '';
    comic.favoriteId = item.favoriteId ?? '';
    comic.hasNewUpdate = item.hasNewUpdate === true;
    comic.updateTime = item.updateTime ?? '';
    return comic;
  }
}

interface HistoryResponse {
  histories: HistoryItem[];
}

interface OkResult {
  ok: boolean;
  error?: string;
}

export interface CheckUpdateResult {
  hasUpdate: boolean;
  latestVersion?: string;
}

interface CatalogResponse {
  entries?: CatalogEntry[];
  error?: string;
}

interface SourcesResponse {
  sources: ComicSourceInfo[];
  updateCount?: number;
}

interface ExploreConfigResponse {
  pageSources: ExplorePageSource[];
}

interface CategoryConfigResponse {
  categoryMeta: CategoryMeta[];
}

export interface CategoryPartsResult {
  key: string;
  title: string;
  enableRankingPage: boolean;
  buttons?: CategoryButton[];
  parts: CategoryPart[];
  error?: string;
}

export interface CategoryButton {
  label: string;
}

interface SearchHistoryResponse {
  history: string[];
}

interface ComicDetailResult {
  comic?: ComicDetailJson;
  error?: string;
}

interface ComicDetailJson extends ComicJson {
  chapters?: Record<string, string>;
  isLocal?: boolean;
  isLiked?: boolean;
  likesCount?: number;
  recommend?: ComicJson[];
}

interface FoldersResponse {
  folders: string[];
}

interface FavoritesResponse {
  comics: ComicJson[];
  error?: string;
}

interface ComicsResponse {
  comics: ComicJson[];
}

interface DownloadTasksResponse {
  tasks: DownloadTaskInfo[];
}

interface ErrorResult {
  ok?: boolean;
  error?: string;
}

interface ExploreRawResult {
  comics?: ComicJson[];
  hasMore?: boolean | string;
  error?: string;
  options?: Record<string, string>;
  next?: string;
}

interface ComicJson {
  id?: string;
  title?: string;
  name?: string;
  cover?: string;
  coverPath?: string;
  subTitle?: string;
  subtitle?: string;
  author?: string;
  tags?: string[];
  description?: string;
  sourceKey?: string;
  maxPage?: number;
  language?: string;
  favoriteId?: string;
  hasNewUpdate?: boolean;
  updateTime?: string;
}

interface CoverImageResult {
  base64?: string;
  error?: string;
}

interface FolderCountsResponse {
  counts: Record<string, number>;
  folders: string[];
}

interface FolderCreateResult {
  ok?: boolean;
  folder?: string;
  error?: string;
}

interface RemoteFoldersResult {
  folders?: string[];
  error?: string;
}

interface ThumbnailsResult {
  thumbnails?: string[];
  error?: string;
}

interface SourceActionResult {
  ok?: boolean;
  key?: string;
  error?: string;
}

interface SourceFileResult {
  content?: string;
  path?: string;
  error?: string;
}

interface UpdateCheckResult {
  count?: number;
  updates?: ComicSourceUpdateInfo[];
  error?: string;
}

interface ComicLinkResult {
  found?: boolean;
  comicId?: string;
  sourceKey?: string;
}

interface SearchOptionsResult {
  options?: Record<string, string>;
}

interface FollowUpdateCheckResult {
  ok?: boolean;
  updated?: number;
  error?: string;
}

interface AggregatedSearchResponse {
  results: AggregatedSearchResult[];
}

interface ImageFavoritesResponse {
  comics: ImageFavoriteSummary[];
}

interface ImageFavoriteImagesResponse {
  images?: ImageFavoriteImage[];
  error?: string;
}

interface NetworkSourcesResponse {
  sources: string[];
}

interface CommentsRawResult {
  comments?: CommentInfo[];
  hasMore?: boolean;
  error?: string;
}

interface RankingRawResult {
  comics?: ComicJson[];
  hasMore?: boolean;
  error?: string;
  options?: Record<string, string>;
}

export interface SourceSettingOption {
  value: Object;
  text: string;
}

export interface SourceSettingItem {
  key: string;
  type: string;
  title: string;
  default?: Object;
  current?: Object;
  options?: SourceSettingOption[];
  validator?: string;
  buttonText?: string;
}

export interface LogEntry {
  level: string;
  title: string;
  content: string;
  time: number;
}

export interface ExportComicItem {
  id: string;
  sourceKey: string;
}

export interface ExportResult {
  ok?: boolean;
  path?: string;
  count?: number;
  error?: string;
}

export interface ImageFavoriteRequest {
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

interface SourceSettingsResponse {
  settings: SourceSettingItem[];
}

interface TagSuggestionsResponse {
  suggestions: string[];
}

interface LogsResponse {
  logs: LogEntry[];
}

interface DownloadCountResult {
  ok?: boolean;
  count?: number;
}

interface ExportAppDataResult {
  ok?: boolean;
  path?: string;
  error?: string;
}

interface JsCodeResult {
  ok?: boolean;
  result?: string;
  error?: string;
}

interface RemoveInvalidResult {
  ok?: boolean;
  count?: number;
  error?: string;
}

interface ImportLocalResult {
  ok?: boolean;
  error?: string;
}

export interface ComicHistoryStatus {
  ep: number;
  page: number;
}

export interface ComicTileStatusData {
  favoriteKeys: string[];
  history: Record<string, ComicHistoryStatus>;
}
