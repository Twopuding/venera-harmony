import router from '@ohos.router';
import { DataService, AggregatedSearchResult } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicTile } from '../../components/ComicTile';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../../components/ImmersiveScrollTopInset';
import { HdsTheme } from '../../design/HdsTheme';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct AggregatedSearchPage {
  @State keyword: string = ''
  @State results: AggregatedSearchResult[] = []
  @State isLoading: boolean = true
  @State inputKeyword: string = ''
  private scroller: Scroller = new Scroller()
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.keyword = params['keyword'] ?? '';
    this.inputKeyword = this.keyword;
    this.loadResults();
  }

  private async loadResults(): Promise<void> {
    if (this.keyword.trim().length === 0) {
      this.results = [];
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    try {
      this.results = await DataService.getInstance().aggregatedSearch(this.keyword.trim(), 1);
    } finally {
      this.isLoading = false;
    }
  }

  private comicsFromResult(result: AggregatedSearchResult): Comic[] {
    if (result.comics === undefined) {
      return [];
    }
    return result.comics.map((item) => {
      let c: Comic = new Comic();
      c.id = item.id ?? '';
      c.title = item.title ?? item.name ?? '';
      c.cover = item.cover ?? item.coverPath ?? '';
      c.subtitle = item.subTitle ?? item.subtitle ?? item.author ?? '';
      c.sourceKey = item.sourceKey ?? result.sourceKey;
      return c;
    });
  }

  @Builder
  sourceSection(result: AggregatedSearchResult) {
    Column() {
      Row() {
        Text(result.sourceName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.icon_secondary')])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .onClick(() => {
        RouterUtil.openSearchResult(result.sourceKey, this.keyword);
      })

      if (result.error !== undefined && result.error.length > 0) {
        Row() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(16)
            .fontColor([$r('app.color.text_secondary')])
            .margin({ right: 8 })
          Text(result.error)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      } else {
        Scroll() {
          Row() {
            ForEach(this.comicsFromResult(result), (comic: Comic) => {
              ComicTile({
                comic: comic,
                mode: 'brief',
                onTap: () => {
                  RouterUtil.openComicDetail(comic.id, comic.sourceKey);
                }
              })
                .width(110)
                .margin({ right: 8 })
            }, (comic: Comic) => result.sourceKey + comic.id)
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(180)
        .margin({ bottom: 8 })
      }
    }
    .width('100%')
  }

  @Builder
  pageContent() {
    Column() {
      Row() {
        TextInput({ placeholder: 'Keyword', text: this.inputKeyword })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.inputKeyword = value;
          })
          .onSubmit(() => {
            this.keyword = this.inputKeyword.trim();
            this.loadResults();
          })
        Button('Search')
          .margin({ left: 8 })
          .onClick(() => {
            this.keyword = this.inputKeyword.trim();
            this.loadResults();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.isLoading) {
        LoadingIndicator()
      } else if (this.results.length === 0) {
        Text('No results')
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ top: 48 })
          .textAlign(TextAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column() {
            ImmersiveScrollTopInset()
            ForEach(this.results, (result: AggregatedSearchResult) => {
              this.sourceSection(result)
            }, (result: AggregatedSearchResult) => result.sourceKey)
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tr('Aggregated Search'),
        showBack: true,
        scrollable: false,
        pageScroller: this.scroller,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
