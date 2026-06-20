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
struct CategoryComicsPage {
  @State categoryKey: string = ''
  @State category: string = ''
  @State param: string = ''
  @State options: string[] = []
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  private scroller: Scroller = new Scroller()
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.categoryKey = params['categoryKey'] ?? '';
    this.category = params['category'] ?? '';
    this.param = params['param'] ?? '';
    let optionsJson = params['optionsJson'] ?? '';
    if (optionsJson.length > 0) {
      try {
        this.options = JSON.parse(optionsJson) as string[];
      } catch (e) {
        this.options = [];
      }
    }
    this.loadPage(1);
  }

  private async loadPage(page: number): Promise<void> {
    if (page === 1) {
      this.isLoading = true;
      this.errorMessage = '';
    } else {
      this.isLoadingMore = true;
    }
    try {
      let result: ExploreLoadResult = await DataService.getInstance().categoryLoadPage(
        this.categoryKey,
        this.category,
        page,
        this.param.length > 0 ? this.param : undefined,
        this.options
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
    } catch (e) {
      this.errorMessage = 'Failed to load category comics';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  @Builder
  pageContent() {
    Column() {
      if (this.options.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.options, (option: string, index: number) => {
              Text(option)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 6 })
                .borderRadius(12)
                .backgroundColor($r('app.color.card_background'))
            }, (option: string, index: number) => `${option}_${index}`)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
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
          onRetry: () => this.loadPage(1)
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
                .onClick(() => this.loadPage(this.currentPage + 1))
            }
          }
        }
        .layoutWeight(1)
        .onScrollEdge((side: Edge) => {
          if (side === Edge.Bottom && this.hasMore && !this.isLoadingMore && !this.isLoading) {
            this.loadPage(this.currentPage + 1);
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
        title: this.category,
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
