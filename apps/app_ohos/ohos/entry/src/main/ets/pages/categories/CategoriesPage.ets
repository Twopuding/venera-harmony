import {
  DataService,
  CategoryMeta,
  CategoryPart,
  CategoryPartItem,
  CategoryPartsResult,
  CategoryButton,
  ComicSourceInfo
} from '../../service/DataService';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { MultiPagesFilterDialog, PageOptionsBuilder } from '../../components/MultiPagesFilter';
import { ShellEvents } from '../../utils/ShellEvents';

@Component
struct CategoryTabContent {
  @Prop categoryKey: string = ''
  @Prop categoryTitle: string = ''
  @Prop randomSeed: number = 0
  @Prop scrollTopCounter: number = 0
  onRandomRefresh: (() => void) | null = null
  @State parts: CategoryPart[] = []
  @State categoryButtons: CategoryButton[] = []
  @State enableRankingPage: boolean = false
  @State isLoading: boolean = true
  @State errorMessage: string = ''
  private scroller: Scroller = new Scroller()
  private lastScrollTopCounter: number = 0

  aboutToAppear(): void {
    this.loadParts();
  }

  aboutToUpdate(): void {
    if (this.parts.length === 0 && !this.isLoading) {
      this.loadParts();
    }
    if (this.scrollTopCounter !== this.lastScrollTopCounter) {
      this.lastScrollTopCounter = this.scrollTopCounter;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    }
  }

  private async loadParts(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      let result: CategoryPartsResult | null =
        await DataService.getInstance().getCategoryParts(this.categoryKey);
      if (result === null) {
        this.errorMessage = 'Failed to load categories';
        return;
      }
      if (result.error !== undefined && result.error.length > 0) {
        this.errorMessage = result.error;
        return;
      }
      this.parts = result.parts ?? [];
      this.enableRankingPage = result.enableRankingPage === true;
      this.categoryButtons = result.buttons ?? [];
    } finally {
      this.isLoading = false;
    }
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key);
  }

  private shuffledItems(part: CategoryPart): CategoryPartItem[] {
    if (!part.enableRandom) {
      return part.items;
    }
    let items: CategoryPartItem[] = part.items.slice();
    let seed: number = this.randomSeed + part.title.length;
    for (let i: number = items.length - 1; i > 0; i--) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      let j: number = seed % (i + 1);
      let temp: CategoryPartItem = items[i];
      items[i] = items[j];
      items[j] = temp;
    }
    return items;
  }

  private openCategoryItem(item: CategoryPartItem): void {
    let param: string | undefined = undefined;
    if (item.target.attributes !== undefined) {
      let keys: string[] = Object.keys(item.target.attributes);
      if (keys.length > 0) {
        param = item.target.attributes[keys[0]];
      }
    }
    RouterUtil.openCategoryComics(this.categoryKey, item.label, param);
  }

  @Builder
  tagChip(label: string, onClick: () => void) {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .margin(6)
      .borderRadius(8)
      .backgroundColor($r('app.color.badge_bg'))
      .onClick(() => onClick())
  }

  build() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.errorMessage.length > 0) {
      NetworkError({
        message: this.errorMessage,
        onRetry: () => this.loadParts()
      })
    } else {
      Scroll(this.scroller) {
        Column() {
          if (this.enableRankingPage || this.categoryButtons.length > 0) {
            Text(this.categoryTitle)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ left: 16, top: 10, bottom: 10 })
            Flex({ wrap: FlexWrap.Wrap }) {
              if (this.enableRankingPage) {
                this.tagChip(this.tr('Ranking'), () => {
                  RouterUtil.openRanking(this.categoryKey);
                })
              }
              ForEach(this.categoryButtons, (btn: CategoryButton) => {
                this.tagChip(btn.label, () => {
                  RouterUtil.openCategoryComics(this.categoryKey, btn.label);
                })
              }, (btn: CategoryButton) => btn.label)
            }
            .padding({ left: 10, right: 10, bottom: 16 })
          }

          ForEach(this.parts, (part: CategoryPart) => {
            Column() {
              if (part.enableRandom) {
                Row() {
                  Text(part.title)
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                    .fontSize(20)
                    .fontColor([$r('app.color.icon_secondary')])
                    .onClick(() => {
                      if (this.onRandomRefresh !== null) {
                        this.onRandomRefresh!();
                      }
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              } else if (part.title.length > 0) {
                Text(part.title)
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                  .padding({ left: 16, top: 10, bottom: 10 })
              }
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.shuffledItems(part), (item: CategoryPartItem) => {
                  this.tagChip(item.label, () => this.openCategoryItem(item))
                }, (item: CategoryPartItem) => item.label + item.target.page + this.randomSeed.toString())
              }
              .padding({ left: 10, right: 10, bottom: 16 })
            }
          }, (part: CategoryPart) => part.title + this.randomSeed.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
    }
  }
}

@Component
export struct CategoriesPage {
  @StorageLink(ShellEvents.CATEGORIES_SCROLL_TOP) scrollTopCounter: number = 0;
  @StorageLink(ShellEvents.CATEGORIES_ADD_PAGE) addPageCounter: number = 0;
  @State categories: CategoryMeta[] = []
  @State currentIndex: number = 0
  @State isLoading: boolean = true
  @State hasSources: boolean = true
  @State randomSeeds: number[] = []
  @State showCategoryPagesDialog: boolean = false
  @State comicSources: ComicSourceInfo[] = []
  @State settings: Record<string, Object> = {}
  private tabsController: TabsController = new TabsController()
  private lastAddPageCounter: number = 0

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(getContext(this) as Context);
    this.loadConfig();
  }

  aboutToUpdate(): void {
    if (this.addPageCounter !== this.lastAddPageCounter) {
      this.lastAddPageCounter = this.addPageCounter;
      this.showCategoryPagesDialog = true;
    }
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key);
  }

  private async loadConfig(): Promise<void> {
    this.isLoading = true;
    try {
      let results: [CategoryMeta[], ComicSourceInfo[], Record<string, Object>] = await Promise.all([
        DataService.getInstance().getCategoryConfig(),
        DataService.getInstance().getComicSources(),
        DataService.getInstance().getSettings()
      ]);
      this.categories = results[0];
      this.hasSources = results[1].length > 0;
      this.comicSources = results[1];
      this.settings = results[2];
      this.randomSeeds = new Array(this.categories.length).fill(0);
    } finally {
      this.isLoading = false;
    }
  }

  private emptyMessage(): string {
    let msg: string = this.tr('No Category Pages');
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

  private async refreshRandomPart(index: number): Promise<void> {
    if (index < this.categories.length) {
      let cat: CategoryMeta = this.categories[index];
      await DataService.getInstance().randomCategoryRefresh(cat.key, cat.title);
      let seeds: number[] = this.randomSeeds.slice();
      seeds[index] = seeds[index] + 1;
      this.randomSeeds = seeds;
    }
  }

  private getCategoryKeys(): string[] {
    let raw = this.settings['categories'];
    if (Array.isArray(raw)) {
      return raw as string[];
    }
    return [];
  }

  private async saveCategoryPages(keys: string[]): Promise<void> {
    await DataService.getInstance().setSetting('categories', keys);
    await this.loadConfig();
  }

  build() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.categories.length === 0) {
      NetworkError({
        message: this.emptyMessage(),
        onRetry: () => this.emptyAction()
      })
    } else {
      Stack() {
        Column() {
          Row() {
            Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
              ForEach(this.categories, (cat: CategoryMeta, index: number) => {
                TabContent() {
                  CategoryTabContent({
                    categoryKey: cat.key,
                    categoryTitle: cat.title,
                    randomSeed: this.randomSeeds[index] ?? 0,
                    scrollTopCounter: this.scrollTopCounter,
                    onRandomRefresh: () => this.refreshRandomPart(index)
                  })
                }
                .tabBar(cat.title)
              }, (cat: CategoryMeta) => cat.key)
            }
            .barMode(BarMode.Scrollable)
            .layoutWeight(1)
            .onChange((index: number) => {
              this.currentIndex = index;
            })
            Button('+')
              .width(40)
              .height(40)
              .margin({ right: 8 })
              .onClick(() => {
                this.showCategoryPagesDialog = true;
              })
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')

        MultiPagesFilterDialog({
          show: this.showCategoryPagesDialog,
          title: this.tr('Category Pages'),
          options: PageOptionsBuilder.categoryPages(this.comicSources),
          selectedKeys: this.getCategoryKeys(),
          onSave: (keys: string[]) => {
            this.saveCategoryPages(keys);
            this.showCategoryPagesDialog = false;
          },
          onClose: () => {
            this.showCategoryPagesDialog = false;
          }
        })
      }
      .width('100%')
      .height('100%')
    }
  }
}
