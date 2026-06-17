import { DataService, HistoryItem } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicGrid } from '../../components/ComicGrid';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';

@Component
export struct HomePage {
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State errorMessage: string = ''
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.loadHistory();
  }

  private async loadHistory(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      let histories: HistoryItem[] = await DataService.getInstance().getHistory();
      this.comics = histories.map((h: HistoryItem) => this.historyToComic(h));
    } catch (e) {
      this.errorMessage = 'Failed to load history';
    } finally {
      this.isLoading = false;
    }
  }

  private historyToComic(h: HistoryItem): Comic {
    let comic: Comic = new Comic();
    comic.id = h.id;
    comic.title = h.title;
    comic.subtitle = h.subtitle;
    comic.cover = h.cover;
    comic.description = h.description;
    comic.sourceKey = h.sourceKey;
    return comic;
  }

  build() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.errorMessage.length > 0) {
      NetworkError({
        message: this.errorMessage,
        onRetry: () => {
          this.loadHistory();
        }
      })
    } else {
      Scroll(this.scroller) {
        Column() {
          Text('History')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          if (this.comics.length === 0) {
            Text('No reading history yet')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(32)
          } else {
            ComicGrid({
              comics: this.comics,
              mode: 'brief',
              columns: 3
            })
          }
        }
        .width('100%')
      }
      .clipContent(ContentClipMode.SAFE_AREA)
      .width('100%')
      .height('100%')
    }
  }
}
