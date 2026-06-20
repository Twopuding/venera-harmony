import { DataService, ComicSourceInfo } from '../../service/DataService';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';

@Entry
@Component
struct SearchPage {
  @State sources: ComicSourceInfo[] = []
  @State searchHistory: string[] = []
  @State keyword: string = ''
  @State selectedSource: string = ''
  @State aggregatedSearch: boolean = false
  @State isLoading: boolean = true
  @State suggestions: string[] = []
  @State showSuggestions: boolean = false

  private suggestionTimer: number = -1
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadData();
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      let allSources = await DataService.getInstance().getComicSources();
      this.sources = allSources.filter((s: ComicSourceInfo) => s.hasSearch);
      if (this.sources.length > 0 && this.selectedSource.length === 0) {
        this.selectedSource = this.sources[0].key;
      }
      this.searchHistory = await DataService.getInstance().getSearchHistory();
    } finally {
      this.isLoading = false;
    }
  }

  private async doSearch(text?: string): Promise<void> {
    let q: string = (text ?? this.keyword).trim();
    if (q.length === 0) {
      return;
    }
    if (q.startsWith('http://') || q.startsWith('https://')) {
      let link = await DataService.getInstance().resolveComicLink(q);
      if (link?.found === true && link.comicId !== undefined && link.sourceKey !== undefined) {
        RouterUtil.openComicDetail(link.comicId, link.sourceKey);
        return;
      }
    }
    if (this.aggregatedSearch) {
      RouterUtil.openAggregatedSearch(q);
    } else if (this.selectedSource.length > 0) {
      RouterUtil.openSearchResult(this.selectedSource, q);
    }
  }

  private async clearHistory(): Promise<void> {
    await DataService.getInstance().clearSearchHistory();
    this.searchHistory = [];
  }

  private onKeywordChange(value: string): void {
    this.keyword = value;
    if (this.suggestionTimer >= 0) {
      clearTimeout(this.suggestionTimer);
    }
    if (value.trim().length === 0 || this.aggregatedSearch) {
      this.suggestions = [];
      this.showSuggestions = false;
      return;
    }
    this.suggestionTimer = setTimeout(async () => {
      if (this.selectedSource.length > 0) {
        this.suggestions = await DataService.getInstance().getSearchTagSuggestions(
          value.trim(), this.selectedSource
        );
        this.showSuggestions = this.suggestions.length > 0;
      }
    }, 200) as number;
  }

  private applySuggestion(tag: string): void {
    let parts = this.keyword.split(' ');
    parts[parts.length - 1] = tag;
    this.keyword = parts.join(' ');
    this.suggestions = [];
    this.showSuggestions = false;
  }

  private pageMenus(): HdsNavigationMenuContentOptions | undefined {
    if (this.searchHistory.length === 0) {
      return undefined;
    }
    return NavigationMenus.single($r('sys.symbol.trash'), this.tr('Clear history'), () => this.clearHistory());
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.sources.length === 0) {
      Column() {
        Text(this.tr('No search sources configured'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button(this.tr('Manage Sources'))
          .margin({ top: 16 })
          .onClick(() => RouterUtil.openComicSource())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 48 })
    } else {
      Column() {
        TextInput({ placeholder: this.tr('Enter keyword'), text: this.keyword })
          .width('100%')
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.onKeywordChange(value);
          })
          .onSubmit(() => this.doSearch())

        if (this.showSuggestions) {
          Column() {
            ForEach(this.suggestions, (tag: string) => {
              Text(tag)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .padding(10)
                .onClick(() => this.applySuggestion(tag))
            }, (tag: string) => tag)
          }
          .width('100%')
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(8)
          .margin({ bottom: 12 })
        }

        Row() {
          Text(this.tr('Aggregated search'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.aggregatedSearch })
            .onChange((isOn: boolean) => {
              this.aggregatedSearch = isOn;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })

        if (!this.aggregatedSearch) {
          Text(this.tr('Source'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ bottom: 4 })
          Scroll() {
            Row() {
              ForEach(this.sources, (source: ComicSourceInfo) => {
                Text(source.name)
                  .fontSize(14)
                  .fontColor(this.selectedSource === source.key ?
                    Color.White : $r('app.color.text_primary'))
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(this.selectedSource === source.key ?
                    $r('app.color.color_emphasize') : $r('app.color.card_background'))
                  .borderRadius(16)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.selectedSource = source.key;
                  })
              }, (source: ComicSourceInfo) => source.key)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .margin({ bottom: 16 })
        }

        Button('Search')
          .width('100%')
          .margin({ bottom: 24 })
          .onClick(() => this.doSearch())

        if (this.searchHistory.length > 0) {
          Text('Recent searches')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ bottom: 8 })
          List() {
            ForEach(this.searchHistory, (item: string) => {
              ListItem() {
                Row() {
                  SymbolGlyph($r('sys.symbol.clock'))
                    .fontSize(16)
                    .fontColor([$r('app.color.icon_secondary')])
                    .margin({ right: 8 })
                  Text(item)
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding(12)
                .onClick(() => this.doSearch(item))
              }
            }, (item: string, index: number) => `${item}_${index}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tr('Search'),
        showBack: true,
        onBack: () => RouterUtil.back(),
        menus: this.pageMenus(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
