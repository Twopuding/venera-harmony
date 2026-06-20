import router from '@ohos.router';
import { DataService, RankingLoadResult } from '../../service/DataService';
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
struct RankingPage {
  @State categoryKey: string = ''
  @State optionKeys: string[] = []
  @State optionLabels: string[] = []
  @State selectedOption: string = ''
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  private scroller: Scroller = new Scroller()
  private context = getContext(this)

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.categoryKey = params['categoryKey'] ?? '';
    this.loadPage(1);
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private setupOptions(options?: Record<string, string>): void {
    if (options === undefined) {
      return;
    }
    this.optionKeys = Object.keys(options);
    this.optionLabels = this.optionKeys.map((key: string) => options[key]);
    if (this.selectedOption.length === 0 && this.optionKeys.length > 0) {
      this.selectedOption = this.optionKeys[0];
    }
  }

  private async loadPage(page: number): Promise<void> {
    if (page === 1) {
      this.isLoading = true;
      this.errorMessage = '';
    } else {
      this.isLoadingMore = true;
    }
    try {
      let option = this.selectedOption.length > 0 ? this.selectedOption : '';
      let result: RankingLoadResult = await DataService.getInstance().loadRanking(
        this.categoryKey, option, page
      );
      if (result.error !== undefined) {
        this.errorMessage = result.error;
        return;
      }
      this.setupOptions(result.options);
      if (page === 1) {
        this.comics = result.comics;
      } else {
        this.comics = this.comics.concat(result.comics);
      }
      this.currentPage = page;
      this.hasMore = result.hasMore;
    } catch (e) {
      this.errorMessage = 'Failed to load ranking';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  @Builder
  pageContent() {
    Column() {
      if (this.optionKeys.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.optionKeys, (key: string, index: number) => {
              Text(this.tl(this.optionLabels[index]))
                .fontSize(14)
                .fontColor(this.selectedOption === key ?
                  Color.White : $r('app.color.text_primary'))
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor(this.selectedOption === key ?
                  $r('app.color.color_emphasize') : $r('app.color.card_background'))
                .borderRadius(16)
                .margin({ right: 8 })
                .onClick(() => {
                  if (this.selectedOption !== key) {
                    this.selectedOption = key;
                    this.loadPage(1);
                  }
                })
            }, (key: string) => key)
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
              Button(this.isLoadingMore ? this.tl('Loading...') : this.tl('Load more'))
                .width('80%')
                .margin({ top: 16, bottom: 24 })
                .enabled(!this.isLoadingMore)
                .onClick(() => this.loadPage(this.currentPage + 1))
            }
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
        title: this.tl('Ranking'),
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
