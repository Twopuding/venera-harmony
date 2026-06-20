import { DataService, ExplorePageSource, ExploreLoadResult, ComicSourceInfo } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicGrid } from '../../components/ComicGrid';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { MultiPagesFilterDialog, PageOption, PageOptionsBuilder } from '../../components/MultiPagesFilter';
import { ShellEvents } from '../../utils/ShellEvents';
import { DisplaySettings } from '../../utils/DisplaySettings';

@Component
struct ExploreTabPanel {
  @Prop sourceKey: string = ''
  @Prop pageTitle: string = ''
  @Prop panelIndex: number = 0
  @Prop refreshCounter: number = 0
  @Prop refreshTargetIndex: number = -1
  @Prop scrollTopCounter: number = 0
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  @State nextCursor: string = ''
  onScroll: ((offset: number) => void) | null = null
  private scroller: Scroller = new Scroller()
  private lastRefreshCounter: number = 0
  private lastScrollTopCounter: number = 0

  aboutToAppear(): void {
    this.loadPage(1);
  }

  aboutToUpdate(): void {
    if (this.refreshCounter !== this.lastRefreshCounter &&
      this.refreshTargetIndex === this.panelIndex) {
      this.lastRefreshCounter = this.refreshCounter;
      this.loadPage(1);
    }
    if (this.scrollTopCounter !== this.lastScrollTopCounter) {
      this.lastScrollTopCounter = this.scrollTopCounter;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    }
  }

  private async loadPage(page: number): Promise<void> {
    if (page === 1) {
      this.isLoading = true;
      this.errorMessage = '';
      this.nextCursor = '';
    } else {
      this.isLoadingMore = true;
    }
    try {
      let cursor: string | undefined = page > 1 && this.nextCursor.length > 0 ?
        this.nextCursor : undefined;
      let result: ExploreLoadResult = await DataService.getInstance().exploreLoadPage(
        this.sourceKey, this.pageTitle, page, cursor
      );
      if (result.error !== undefined) {
        this.errorMessage = result.error;
        return;
      }
      if (page === 1) {
        this.comics = result.comics;
      } else {
        this.comics = this.comics.concat(result.comics);
      }
      this.currentPage = page;
      this.hasMore = result.hasMore;
      this.nextCursor = result.next ?? '';
    } catch (e) {
      this.errorMessage = 'Failed to load comics';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  build() {
    if (this.isLoading && this.comics.length === 0) {
      LoadingIndicator()
    } else if (this.errorMessage.length > 0) {
      NetworkError({
        message: this.errorMessage,
        onRetry: () => this.loadPage(1)
      })
    } else {
      Scroll(this.scroller) {
        Column() {
          ComicGrid({
            comics: this.comics,
            columns: 3,
            onItemTap: (comic: Comic) => {
              RouterUtil.openComicDetail(comic.id, comic.sourceKey);
            },
            onNearEnd: () => {
              if (this.hasMore && !this.isLoadingMore && DisplaySettings.getInstance().isContinuousList()) {
                this.loadPage(this.currentPage + 1);
              }
            }
          })
          if (this.hasMore && !DisplaySettings.getInstance().isContinuousList()) {
            Button(this.isLoadingMore ? 'Loading...' : 'Load more')
              .width('80%')
              .margin({ top: 16, bottom: 24 })
              .enabled(!this.isLoadingMore)
              .onClick(() => this.loadPage(this.currentPage + 1))
          }
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .onScroll((xOffset: number, yOffset: number) => {
        if (this.onScroll !== null) {
          this.onScroll!(yOffset);
        }
      })
    }
  }
}

@Component
export struct ExplorePage {
  @StorageLink(ShellEvents.EXPLORE_SCROLL_TOP) scrollTopCounter: number = 0;
  @StorageLink(ShellEvents.EXPLORE_ADD_PAGE) addPageCounter: number = 0;
  @State pages: ExplorePageSource[] = []
  @State currentIndex: number = 0
  @State isLoadingConfig: boolean = true
  @State hasSources: boolean = true
  @State showFab: boolean = true
  @State refreshCounter: number = 0
  @State refreshTargetIndex: number = -1
  @State lastScrollY: number = 0
  @State showExplorePagesDialog: boolean = false
  @State comicSources: ComicSourceInfo[] = []
  @State settings: Record<string, Object> = {}
  private tabsController: TabsController = new TabsController()
  private lastAddPageCounter: number = 0

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(getContext(this) as Context);
    DisplaySettings.getInstance().refresh();
    this.loadConfig();
  }

  aboutToUpdate(): void {
    if (this.addPageCounter !== this.lastAddPageCounter) {
      this.lastAddPageCounter = this.addPageCounter;
      this.showExplorePagesDialog = true;
    }
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key);
  }

  private async loadConfig(): Promise<void> {
    this.isLoadingConfig = true;
    try {
      let results: [ExplorePageSource[], ComicSourceInfo[], Record<string, Object>] = await Promise.all([
        DataService.getInstance().getExploreConfig(),
        DataService.getInstance().getComicSources(),
        DataService.getInstance().getSettings()
      ]);
      this.pages = results[0];
      this.hasSources = results[1].length > 0;
      this.comicSources = results[1];
      this.settings = results[2];
    } finally {
      this.isLoadingConfig = false;
    }
  }

  private refreshCurrentTab(): void {
    this.refreshTargetIndex = this.currentIndex;
    this.refreshCounter = this.refreshCounter + 1;
  }

  private onTabScroll(yOffset: number): void {
    if (yOffset > this.lastScrollY && yOffset > 0 && this.showFab) {
      this.showFab = false;
    } else if ((yOffset < this.lastScrollY - 50 || yOffset === 0) && !this.showFab) {
      this.showFab = true;
    }
    this.lastScrollY = yOffset;
  }

  private emptyMessage(): string {
    let msg: string = this.tr('No Explore Pages');
    msg += '\n';
    msg += this.hasSources ? this.tr('Please check your settings') : this.tr('Please add some sources');
    return msg;
  }

  private emptyAction(): void {
    if (this.hasSources) {
      RouterUtil.openSettings();
    } else {
      RouterUtil.openComicSource();
    }
  }

  private getExplorePageKeys(): string[] {
    let raw = this.settings['explore_pages'];
    if (Array.isArray(raw)) {
      return raw as string[];
    }
    return [];
  }

  private async saveExplorePages(keys: string[]): Promise<void> {
    await DataService.getInstance().setSetting('explore_pages', keys);
    await this.loadConfig();
  }

  build() {
    if (this.isLoadingConfig) {
      LoadingIndicator()
    } else if (this.pages.length === 0) {
      NetworkError({
        message: this.emptyMessage(),
        onRetry: () => this.emptyAction()
      })
    } else {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          Row() {
            Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
              ForEach(this.pages, (page: ExplorePageSource, index: number) => {
                TabContent() {
                  ExploreTabPanel({
                    sourceKey: page.sourceKey,
                    pageTitle: page.title,
                    panelIndex: index,
                    refreshCounter: this.refreshCounter,
                    refreshTargetIndex: this.refreshTargetIndex,
                    scrollTopCounter: this.scrollTopCounter,
                    onScroll: (offset: number) => {
                      if (this.currentIndex === index) {
                        this.onTabScroll(offset);
                      }
                    }
                  })
                }
                .tabBar(page.title)
              }, (page: ExplorePageSource) => page.title + page.sourceKey)
            }
            .barMode(BarMode.Scrollable)
            .layoutWeight(1)
            .onChange((index: number) => {
              this.currentIndex = index;
              this.lastScrollY = 0;
              this.showFab = true;
            })
            Button('+')
              .width(40)
              .height(40)
              .margin({ right: 8 })
              .onClick(() => {
                this.showExplorePagesDialog = true;
              })
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')

        if (this.showFab) {
          Column({ space: 12 }) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.gearshape'))
                .fontSize(22)
                .fontColor([Color.White])
            }
            .width(48)
            .height(48)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => RouterUtil.openSettings())
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(22)
                .fontColor([Color.White])
            }
            .width(56)
            .height(56)
            .backgroundColor($r('app.color.color_emphasize'))
            .onClick(() => this.refreshCurrentTab())
          }
          .margin({ right: 16, bottom: 16 })
        }

        MultiPagesFilterDialog({
          show: this.showExplorePagesDialog,
          title: this.tr('Explore Pages'),
          options: PageOptionsBuilder.explorePages(this.comicSources),
          selectedKeys: this.getExplorePageKeys(),
          onSave: (keys: string[]) => {
            this.saveExplorePages(keys);
            this.showExplorePagesDialog = false;
          },
          onClose: () => {
            this.showExplorePagesDialog = false;
          }
        })
      }
      .width('100%')
      .height('100%')
    }
  }
}
