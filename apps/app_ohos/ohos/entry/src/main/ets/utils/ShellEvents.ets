export class ShellEvents {
  static readonly EXPLORE_SCROLL_TOP: string = 'exploreScrollToTop';
  static readonly CATEGORIES_SCROLL_TOP: string = 'categoriesScrollToTop';
  static readonly EXPLORE_ADD_PAGE: string = 'exploreAddPage';
  static readonly CATEGORIES_ADD_PAGE: string = 'categoriesAddPage';
  static readonly HOME_RELOAD: string = 'homeReloadTick';
  static readonly HOME_HAS_SHOWN: string = 'homeHasShown';
  static readonly WEBDAV_AUTO_SYNC_KEY: string = 'webdavLastSyncCheck';

  static bumpCounter(key: string): void {    let current: number = AppStorage.get<number>(key) ?? 0;
    AppStorage.setOrCreate(key, current + 1);
  }
}
