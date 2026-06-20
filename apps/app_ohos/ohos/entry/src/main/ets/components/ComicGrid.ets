import { Comic } from '../model/Comic'
import { ComicTile } from './ComicTile'
import { DisplaySettings } from '../utils/DisplaySettings'
import { ComicHistoryStatus } from '../service/DataService'
import { BlockedWordsUtil } from '../utils/BlockedWordsUtil'
import { TranslationUtil } from '../utils/TranslationUtil'
import promptAction from '@ohos.promptAction'

@Component
export struct ComicGrid {
  @Prop comics: Comic[] = []
  @Prop mode: string = ''
  @Prop columns: number = 3
  @Prop selectedKeys: string[] = []
  @Prop multiSelectMode: boolean = false
  @Prop useGlobalDisplaySettings: boolean = true
  @Prop filterBlocked: boolean = true
  onItemTap: ((comic: Comic, index: number) => void) | null = null
  onItemLongPress: ((comic: Comic, index: number) => void) | null = null
  onLastItemBuild: (() => void) | null = null
  onNearEnd: (() => void) | null = null
  @State displayComics: Comic[] = []
  @State displayMode: string = 'brief'
  @State tileScale: number = 1
  @State settingsReady: boolean = false
  private displaySettings: DisplaySettings = DisplaySettings.getInstance()

  aboutToAppear(): void {
    this.loadDisplaySettings();
    this.refreshDisplayComics();
  }

  aboutToUpdate(): void {
    if (this.useGlobalDisplaySettings && !this.displaySettings.isReady) {
      this.loadDisplaySettings();
    }
    this.refreshDisplayComics();
  }

  private async refreshDisplayComics(): Promise<void> {
    if (!this.filterBlocked) {
      this.displayComics = this.comics;
      return;
    }
    await BlockedWordsUtil.ensureLoaded();
    this.displayComics = BlockedWordsUtil.filterComics(this.comics);
  }

  private async blockComic(comic: Comic): Promise<void> {
    let word = await BlockedWordsUtil.blockComic(comic);
    if (word !== null) {
      promptAction.showToast({ message: TranslationUtil.tl('Blocked') });
      await this.refreshDisplayComics();
    }
  }

  private async loadDisplaySettings(): Promise<void> {
    if (!this.useGlobalDisplaySettings) {
      this.displayMode = this.mode.length > 0 ? this.mode : 'brief';
      this.settingsReady = true;
      return;
    }
    await this.displaySettings.refresh();
    this.displayMode = this.mode.length > 0 ? this.mode : this.displaySettings.comicDisplayMode;
    this.tileScale = this.displaySettings.comicTileScale;
    this.settingsReady = true;
  }

  private effectiveMode(): string {
    if (this.mode.length > 0) {
      return this.mode;
    }
    return this.settingsReady ? this.displayMode : 'brief';
  }

  private comicKey(comic: Comic): string {
    return comic.id + '@' + comic.sourceKey;
  }

  build() {
    Grid() {
      ForEach(this.displayComics, (comic: Comic, index: number) => {
        GridItem() {
          Stack() {
            ComicTile({
              comic: comic,
              mode: this.effectiveMode(),
              tileScale: this.useGlobalDisplaySettings ? this.tileScale : 1,
              badge: comic.language,
              isFavorite: this.useGlobalDisplaySettings ? this.displaySettings.isFavorite(comic) : false,
              historyStatus: this.useGlobalDisplaySettings ?
                this.displaySettings.getHistory(comic) : null,
              onTap: () => {
                if (this.onItemTap !== null) {
                  this.onItemTap!(comic, index)
                }
              },
              onLongPress: () => {
                if (this.onItemLongPress !== null) {
                  this.onItemLongPress!(comic, index)
                } else if (this.filterBlocked) {
                  this.blockComic(comic);
                }
              }
            })
            if (this.multiSelectMode && this.selectedKeys.indexOf(this.comicKey(comic)) >= 0) {
              Column() {}
                .width('100%')
                .height('100%')
                .borderRadius(8)
                .border({ width: 2, color: $r('app.color.color_emphasize') })
            }
          }
        }
        .onAppear(() => {
          if (index === this.displayComics.length - 1) {
            if (this.onLastItemBuild !== null) {
              this.onLastItemBuild!();
            }
            if (this.onNearEnd !== null &&
              this.useGlobalDisplaySettings &&
              this.displaySettings.isContinuousList()) {
              this.onNearEnd!();
            }
          }
        })
      }, (comic: Comic) => comic.id + comic.sourceKey)
    }
    .columnsTemplate('1fr '.repeat(this.columns).trim())
    .rowsGap(8)
    .columnsGap(8)
    .width('100%')
  }
}
