import router from '@ohos.router';
import { ReaderBridge } from '../bridge/ReaderBridge';
import { Want, common } from '@kit.AbilityKit';

interface CategoryRouteParams {
  categoryKey: string;
  category: string;
  param?: string;
  optionsJson?: string;
}

interface SettingsCategoryRouteParams {
  categoryIndex: number;
}

interface ComicRouteParams {
  comicId: string;
  sourceKey: string;
}

interface SearchResultRouteParams {
  sourceKey: string;
  keyword: string;
}

interface AggregatedSearchRouteParams {
  keyword: string;
}

interface RankingRouteParams {
  categoryKey: string;
}

interface CommentsRouteParams {
  comicId: string;
  sourceKey: string;
  replyTo?: string;
  replyUserName?: string;
}

interface WebViewRouteParams {
  url: string;
}

interface CoverViewerRouteParams {
  cover: string;
  sourceKey: string;
  comicId: string;
}

interface ImageFavoritesPhotoRouteParams {
  comicId: string;
  sourceKey: string;
  title: string;
}

interface ImageFavoritesRouteParams {
  initialKeyword?: string;
}

interface ComicSourceLoginRouteParams {
  sourceKey: string;
  sourceName: string;
}

interface ComicSourceEditRouteParams {
  sourceKey: string;
}

interface AuthRouteParams {
  mode: string;
}

export interface RouteTopTrack {
  url: string;
  params?: Object;
}

const STORAGE_KEY_URL: string = 'webview_target_url';
const BUNDLE_NAME: string = 'com.venera.ohos';
export const AUTH_ROUTE_TOP_KEY: string = 'authRouteTop';

export class RouterUtil {
  private static trackRouteTop(url: string, params?: Object): void {
    let track: RouteTopTrack = { url: url };
    if (params !== undefined) {
      track.params = params;
    }
    AppStorage.setOrCreate<string>(AUTH_ROUTE_TOP_KEY, JSON.stringify(track));
  }

  static readRouteTop(): RouteTopTrack | null {
    let raw: string | undefined = AppStorage.get<string>(AUTH_ROUTE_TOP_KEY);
    if (raw === undefined || raw.length === 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as RouteTopTrack;
    } catch (e) {
      return null;
    }
  }

  private static pushUrlTracked(url: string, params?: Object): void {
    RouterUtil.trackRouteTop(url, params);
    if (params !== undefined) {
      router.pushUrl({ url: url, params: params });
    } else {
      router.pushUrl({ url: url });
    }
  }

  static openComicDetail(comicId: string, sourceKey: string): void {
    let params: ComicRouteParams = { comicId: comicId, sourceKey: sourceKey };
    RouterUtil.pushUrlTracked('pages/comic/ComicDetailPage', params);
  }

  static openCoverViewer(cover: string, sourceKey: string, comicId: string): void {
    let params: CoverViewerRouteParams = { cover: cover, sourceKey: sourceKey, comicId: comicId };
    RouterUtil.pushUrlTracked('pages/comic/CoverViewerPage', params);
  }

  static openSearch(): void {
    RouterUtil.pushUrlTracked('pages/search/SearchPage');
  }

  static openSearchResult(sourceKey: string, keyword: string): void {
    let params: SearchResultRouteParams = { sourceKey: sourceKey, keyword: keyword };
    RouterUtil.pushUrlTracked('pages/search/SearchResultPage', params);
  }

  static openAggregatedSearch(keyword: string): void {
    let params: AggregatedSearchRouteParams = { keyword: keyword };
    RouterUtil.pushUrlTracked('pages/search/AggregatedSearchPage', params);
  }

  static openSettings(): void {
    RouterUtil.pushUrlTracked('pages/settings/SettingsPage');
  }

  static openSettingsCategory(categoryIndex: number): void {
    let params: SettingsCategoryRouteParams = { categoryIndex: categoryIndex };
    RouterUtil.pushUrlTracked('pages/settings/SettingsCategoryPage', params);
  }

  static openHistory(): void {
    RouterUtil.pushUrlTracked('pages/history/HistoryPage');
  }

  static openLocalComics(): void {
    RouterUtil.pushUrlTracked('pages/local/LocalComicsPage');
  }

  static openDownloading(): void {
    RouterUtil.pushUrlTracked('pages/local/DownloadingPage');
  }

  static openCategoryComics(
    categoryKey: string,
    category: string,
    param?: string,
    options?: string[]
  ): void {
    let params: CategoryRouteParams = {
      categoryKey: categoryKey,
      category: category
    };
    if (param !== undefined) {
      params.param = param;
    }
    if (options !== undefined && options.length > 0) {
      params.optionsJson = JSON.stringify(options);
    }
    RouterUtil.pushUrlTracked('pages/categories/CategoryComicsPage', params);
  }

  static openRanking(categoryKey: string): void {
    let params: RankingRouteParams = { categoryKey: categoryKey };
    RouterUtil.pushUrlTracked('pages/categories/RankingPage', params);
  }

  static openFollowUpdates(): void {
    RouterUtil.pushUrlTracked('pages/follow_updates/FollowUpdatesPage');
  }

  static openImageFavorites(initialKeyword?: string): void {
    if (initialKeyword !== undefined && initialKeyword.length > 0) {
      let params: ImageFavoritesRouteParams = { initialKeyword: initialKeyword };
      RouterUtil.pushUrlTracked('pages/image_favorites/ImageFavoritesPage', params);
    } else {
      RouterUtil.pushUrlTracked('pages/image_favorites/ImageFavoritesPage');
    }
  }

  static openImageFavoritesPhoto(comicId: string, sourceKey: string, title: string): void {
    let params: ImageFavoritesPhotoRouteParams = { comicId: comicId, sourceKey: sourceKey, title: title };
    RouterUtil.pushUrlTracked('pages/image_favorites/ImageFavoritesPhotoPage', params);
  }

  static openComments(
    comicId: string,
    sourceKey: string,
    replyTo?: string,
    replyUserName?: string
  ): void {
    let params: CommentsRouteParams = { comicId: comicId, sourceKey: sourceKey };
    if (replyTo !== undefined) {
      params.replyTo = replyTo;
    }
    if (replyUserName !== undefined) {
      params.replyUserName = replyUserName;
    }
    RouterUtil.pushUrlTracked('pages/comic/CommentsPage', params);
  }

  static openAuth(): void {
    let params: AuthRouteParams = { mode: 'manual' };
    RouterUtil.pushUrlTracked('pages/AuthPage', params);
  }

  static openReader(comicId: string, sourceKey: string, initialEp?: string, initialPage?: number): void {
    ReaderBridge.getInstance().openReader({
      id: comicId,
      sourceKey: sourceKey,
      initialEp: initialEp ?? '1',
      initialPage: initialPage ?? 1
    });
  }

  static openComicSource(): void {
    RouterUtil.pushUrlTracked('pages/ComicSourcePage');
  }

  static openComicSourceList(): void {
    RouterUtil.pushUrlTracked('pages/ComicSourceListPage');
  }

  static openComicSourceLogin(sourceKey: string, sourceName: string): void {
    let params: ComicSourceLoginRouteParams = { sourceKey: sourceKey, sourceName: sourceName };
    RouterUtil.pushUrlTracked('pages/ComicSourceLoginPage', params);
  }

  static openComicSourceEdit(sourceKey: string): void {
    let params: ComicSourceEditRouteParams = { sourceKey: sourceKey };
    RouterUtil.pushUrlTracked('pages/ComicSourceEditPage', params);
  }

  static openAbout(): void {
    RouterUtil.pushUrlTracked('pages/settings/AboutPage');
  }

  static openLogs(): void {
    RouterUtil.pushUrlTracked('pages/settings/LogsPage');
  }

  static openWebView(url: string): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_URL, url);
    try {
      let context = getContext() as common.UIAbilityContext;
      let want: Want = {
        bundleName: BUNDLE_NAME,
        abilityName: 'WebViewAbility'
      };
      context.startAbility(want);
    } catch (e) {
      let params: WebViewRouteParams = { url: url };
      RouterUtil.pushUrlTracked('pages/WebViewPage', params);
    }
  }

  static launchUrl(url: string): void {
    try {
      let context = getContext() as common.UIAbilityContext;
      let want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url
      };
      context.startAbility(want);
    } catch (e) {
      RouterUtil.openWebView(url);
    }
  }

  static back(): void {
    AppStorage.delete(AUTH_ROUTE_TOP_KEY);
    router.back();
  }
}
