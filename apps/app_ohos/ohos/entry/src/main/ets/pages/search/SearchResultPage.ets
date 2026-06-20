import router from '@ohos.router';
import { DataService, ExploreLoadResult } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicGrid } from '../../components/ComicGrid';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../../components/ImmersiveScrollTopInset';
import { HdsTheme } from '../../design/HdsTheme';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct SearchResultPage {
  @State keyword: string = ''
  @State sourceKey: string = ''
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  @State nextCursor: string = ''
  @State filterOptions: string[] = []
  @State filterLabels: string[] = []
  @State selectedOption: string = ''
  private scroller: Scroller = new Scroller()
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.keyword = params['keyword'] ?? '';
    this.sourceKey = params['sourceKey'] ?? '';
    this.loadOptions();
    this.search(1);
  }

  private async loadOptions(): Promise<void> {
    let opts: Record<string, string> = await DataService.getInstance().getSearchOptions(this.sourceKey);
    let keys: string[] = Object.keys(opts);
    this.filterOptions = keys;
    this.filterLabels = keys.map((k: string) => opts[k]);
    if (keys.length > 0) {
      this.selectedOption = keys[0];
    }
  }

  private async search(page: number): Promise<void> {
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
      let result: ExploreLoadResult = await DataService.getInstance().search(
        this.sourceKey, this.keyword, page, this.selectedOption, cursor
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
      this.errorMessage = 'Search failed';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  @Builder
  pageContent() {
    Column() {
      if (this.filterOptions.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.filterOptions, (opt: string, index: number) => {
              Text(this.filterLabels[index])
                .fontSize(13)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .fontColor(this.selectedOption === opt ?
                  $r('app.color.color_emphasize') : $r('app.color.text_primary'))
                .backgroundColor(this.selectedOption === opt ?
                  $r('app.color.badge_bg') : $r('app.color.card_background'))
                .onClick(() => {
                  this.selectedOption = opt;
                  this.search(1);
                })
            }, (opt: string) => opt)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      if (this.isLoading) {
        LoadingIndicator()
      } else if (this.errorMessage.length > 0) {
        NetworkError({
          message: this.errorMessage,
          onRetry: () => this.search(1)
        })
      } else {
        Scroll(this.scroller) {
          Column() {
            ImmersiveScrollTopInset()
            ComicGrid({
              comics: this.comics,
              mode: 'brief',
              columns: 3,
              onItemTap: (comic: Comic) => {
                RouterUtil.openComicDetail(comic.id, comic.sourceKey);
              }
            })
            if (this.hasMore) {
              Button(this.isLoadingMore ? 'Loading...' : 'Load more')
                .width('80%')
                .margin({ top: 16, bottom: 24 })
                .enabled(!this.isLoadingMore)
                .onClick(() => this.search(this.currentPage + 1))
            }
          }
        }
        .layoutWeight(1)
        .onScrollEdge((side: Edge) => {
          if (side === Edge.Bottom && this.hasMore && !this.isLoadingMore && !this.isLoading) {
            this.search(this.currentPage + 1);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: `"${this.keyword}"`,
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
