import {
  ChartEntryData,
  ComicSourceInfo,
  ComicSourcesResult,
  DataService,
  DownloadTaskInfo,
  FollowUpdatesSummary,
  HistoryItem,
  ImageFavoritesChartData,
  SyncStatus
} from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicTile } from '../../components/ComicTile';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { SearchBar } from '../../components/SearchBar';
import { ImportComicsDialog } from '../../components/ImportComicsDialog';
import { ContentDialog } from '../../components/ContentDialog';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { ShellEvents } from '../../utils/ShellEvents';
import promptAction from '@ohos.promptAction';

interface ChartEntry {
  label: string;
  count: number;
}

@Component
export struct HomePage {
  @State historyItems: HistoryItem[] = []
  @State historyCount: number = 0
  @State localComics: Comic[] = []
  @State localCount: number = 0
  @State downloadTasks: DownloadTaskInfo[] = []
  @State syncStatus: SyncStatus = { enabled: false, isUploading: false, isDownloading: false }
  @State followSummary: FollowUpdatesSummary = { folder: null, count: 0 }
  @State comicSources: ComicSourceInfo[] = []
  @State comicSourceUpdateCount: number = 0
  @State imageFavoriteCount: number = 0
  @State imageChartType: number = 0
  @State tagChart: ChartEntry[] = []
  @State authorChart: ChartEntry[] = []
  @State comicChart: ChartEntry[] = []
  @State isLoading: boolean = true
  @State isChartLoading: boolean = false
  @State isSyncBusy: boolean = false
  @State showImportDialog: boolean = false
  @State showSyncErrorDialog: boolean = false
  @StorageLink(ShellEvents.HOME_RELOAD) @Watch('onHomeReload') homeReloadTick: number = 0
  @StorageLink(TranslationUtil.I18N_TICK) i18nTick: number = 0
  private scroller: Scroller = new Scroller()
  private context = getContext(this) as Context
  private loadGeneration: number = 0

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadData();
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private trParams(key: string, paramKey: string, value: string | number): string {
    return TranslationUtil.tlParam(key, paramKey, value);
  }

  onHomeReload(): void {
    if (this.isLoading) {
      return;
    }
    this.loadData();
  }

  private async loadData(): Promise<void> {
    let generation: number = ++this.loadGeneration;
    this.isLoading = true;
    try {
      let service: DataService = DataService.getInstance();
      let settled: PromiseSettledResult<Object>[] = await Promise.allSettled([
        service.getHistory(),
        service.getLocalComics(),
        service.getDownloadTasks(),
        service.getSyncStatus(),
        service.getFollowUpdatesSummary(),
        service.getComicSourcesResult()
      ]);
      if (generation !== this.loadGeneration) {
        return;
      }
      let histories: HistoryItem[] = HomePage.settledValue(settled[0], [] as HistoryItem[]);
      let local: Comic[] = HomePage.settledValue(settled[1], [] as Comic[]);
      let tasks: DownloadTaskInfo[] = HomePage.settledValue(settled[2], [] as DownloadTaskInfo[]);
      let sync: SyncStatus = HomePage.settledValue(settled[3], {
        enabled: false,
        isUploading: false,
        isDownloading: false
      } as SyncStatus);
      let follow: FollowUpdatesSummary = HomePage.settledValue(settled[4], {
        folder: null,
        count: 0
      } as FollowUpdatesSummary);
      let sources: ComicSourcesResult = HomePage.settledValue(settled[5], {
        sources: [],
        updateCount: 0
      } as ComicSourcesResult);
      this.historyItems = histories.slice(0, 12);
      this.historyCount = histories.length;
      this.localComics = local.slice(0, 12);
      this.localCount = local.length;
      this.downloadTasks = tasks;
      this.syncStatus = sync;
      this.followSummary = follow;
      this.comicSources = sources.sources;
      this.comicSourceUpdateCount = sources.updateCount;
    } catch (e) {
      if (generation === this.loadGeneration) {
        promptAction.showToast({ message: this.tr('Failed to load') });
      }
    } finally {
      if (generation === this.loadGeneration) {
        this.isLoading = false;
      }
    }
    if (generation === this.loadGeneration) {
      this.loadImageFavoritesChart(generation);
    }
  }

  private async loadImageFavoritesChart(generation: number): Promise<void> {
    this.isChartLoading = true;
    try {
      let chart: ImageFavoritesChartData =
        await DataService.getInstance().computeImageFavoritesChart();
      if (generation !== this.loadGeneration) {
        return;
      }
      this.applyImageFavoritesChart(chart);
    } catch (e) {
      if (generation === this.loadGeneration) {
        this.applyImageFavoritesChart({ tags: [], authors: [], comics: [], totalImages: 0 });
      }
    } finally {
      if (generation === this.loadGeneration) {
        this.isChartLoading = false;
      }
    }
  }

  private static settledValue<T>(result: PromiseSettledResult<Object>, fallback: T): T {
    if (result.status === 'fulfilled') {
      return result.value as T;
    }
    return fallback;
  }

  private applyImageFavoritesChart(chart: ImageFavoritesChartData): void {
    this.imageFavoriteCount = chart.totalImages;
    this.tagChart = HomePage.mapChart(chart.tags);
    this.authorChart = HomePage.mapChart(chart.authors);
    this.comicChart = HomePage.mapChart(chart.comics);
  }

  private static mapChart(items: ChartEntryData[]): ChartEntry[] {
    let entries: ChartEntry[] = [];
    for (let i: number = 0; i < items.length; i++) {
      entries.push({ label: items[i].label, count: items[i].count });
    }
    return entries;
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

  private async syncUpload(): Promise<void> {
    this.isSyncBusy = true;
    let error: string | null = await DataService.getInstance().webdavUpload();
    this.syncStatus = await DataService.getInstance().getSyncStatus();
    this.isSyncBusy = false;
    if (error !== null) {
      promptAction.showToast({ message: error });
    }
  }

  private async syncDownload(): Promise<void> {
    this.isSyncBusy = true;
    let error: string | null = await DataService.getInstance().webdavDownload();
    this.syncStatus = await DataService.getInstance().getSyncStatus();
    this.isSyncBusy = false;
    if (error !== null) {
      promptAction.showToast({ message: error });
    }
  }

  @Builder
  sectionHeader(title: string, count?: number, showArrow: boolean = true, onNavigate?: () => void) {
    Row() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (count !== undefined) {
        Text(count.toString())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .margin({ left: 8 })
          .borderRadius(8)
          .backgroundColor($r('app.color.tag_bg'))
      }
      Blank()
      if (showArrow) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('app.color.icon_secondary')])
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      if (onNavigate !== undefined) {
        onNavigate();
      }
    })
  }

  @Builder
  horizontalComics(comics: Comic[]) {
    if (comics.length > 0) {
      List({ space: 8 }) {
        ForEach(comics, (comic: Comic) => {
          ListItem() {
            Column() {
              ComicTile({
                comic: comic,
                mode: 'brief',
                onTap: () => RouterUtil.openComicDetail(comic.id, comic.sourceKey)
              })
            }
            .width(88)
          }
        }, (comic: Comic) => comic.id + comic.sourceKey)
      }
      .listDirection(Axis.Horizontal)
      .height(136)
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 16 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  syncCardBody() {
    if (this.syncStatus.isUploading || this.syncStatus.isDownloading || this.isSyncBusy) {
      this.syncBusyRow()
    } else {
      this.syncIdleRow()
    }
  }

  @Builder
  syncCard() {
    if (this.syncStatus.enabled) {
      Column() {
        this.syncCardBody()
      }
      .width('100%')
      .margin({ left: 8, right: 8, top: 8, bottom: 8 })
      .borderRadius(8)
      .border({ width: 0.6, color: $r('app.color.card_border') })
    }
  }

  @Builder
  chartLine(entry: ChartEntry, maxCount: number) {
    Row() {
      Text(entry.label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(80)
        .onClick(() => RouterUtil.openImageFavorites(entry.label))
      Blank().width(8)
      Row() {
        Row()
          .width(`${Math.max(4, Math.round(entry.count / maxCount * 100))}%`)
          .height(18)
          .borderRadius(2)
          .backgroundColor($r('app.color.color_emphasize'))
      }
      .layoutWeight(1)
      .height(18)
      .backgroundColor($r('app.color.placeholder_bg'))
      .borderRadius(2)
      Blank().width(8)
      Text(entry.count.toString())
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width(30)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(28)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  syncBusyRow() {
    Row() {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontColor([$r('app.color.text_primary')])
      Text(this.tr('Syncing Data'))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
      Blank()
      LoadingProgress()
        .width(24)
        .height(24)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  syncIdleRow() {
    Row() {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontColor([$r('app.color.text_primary')])
      Text(this.tr('Sync Data'))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
      Blank()
      if (this.syncStatus.lastError !== undefined && this.syncStatus.lastError !== null &&
        this.syncStatus.lastError.length > 0) {
        Text(this.tr('Error'))
          .fontSize(12)
          .fontColor($r('app.color.color_emphasize'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor($r('app.color.badge_bg'))
          .margin({ right: 8 })
          .onClick(() => { this.showSyncErrorDialog = true; })
      }
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(18)
      }
      .width(40)
      .height(40)
      .enabled(!this.isSyncBusy)
      .onClick(() => this.syncUpload())
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(18)
      }
      .width(40)
      .height(40)
      .enabled(!this.isSyncBusy)
      .onClick(() => this.syncDownload())
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  imageFavoritesCardContent() {
    this.sectionHeader(this.tr('Image Favorites'),
      this.imageFavoriteCount > 0 ? this.imageFavoriteCount : undefined, true,
      () => RouterUtil.openImageFavorites())
    if (this.isChartLoading) {
      Row() {
        LoadingProgress()
          .width(24)
          .height(24)
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 16 })
    } else if (this.imageFavoriteCount > 0) {
      Row() {
        this.chartTypeButton(0, this.tr('Tags'))
        this.chartTypeButton(1, this.tr('Authors'))
        this.chartTypeButton(2, this.tr('Comics'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding({ bottom: 8 })
      Column() {
        ForEach(this.currentChart(), (entry: ChartEntry) => {
          this.chartLine(entry, this.chartMaxCount())
        }, (entry: ChartEntry) => entry.label + entry.count.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
  }

  @Builder
  imageFavoritesSection() {
    Column() {
      this.imageFavoritesCardContent()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: $r('app.color.card_border') })
  }

  @Builder
  chartTypeButton(type: number, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.imageChartType === type ?
        $r('app.color.color_emphasize') : $r('app.color.text_secondary'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(24)
      .border({ width: 0.6, color: $r('app.color.card_border') })
      .backgroundColor(this.imageChartType === type ? $r('app.color.badge_bg') : Color.Transparent)
      .onClick(() => {
        this.imageChartType = type;
      })
  }

  private currentChart(): ChartEntry[] {
    if (this.imageChartType === 0) {
      return this.tagChart;
    }
    if (this.imageChartType === 1) {
      return this.authorChart;
    }
    return this.comicChart;
  }

  private chartMaxCount(): number {
    let chart: ChartEntry[] = this.currentChart();
    if (chart.length === 0) {
      return 1;
    }
    let max: number = chart[0].count;
    for (let i: number = 1; i < chart.length; i++) {
      if (chart[i].count > max) {
        max = chart[i].count;
      }
    }
    return max;
  }

  @Builder
  historyCardBody() {
    this.sectionHeader(this.tr('History'), this.historyCount, true, () => RouterUtil.openHistory())
    this.horizontalComics(this.historyItems.map((h: HistoryItem) => this.historyToComic(h)))
  }

  @Builder
  localCardBody() {
    this.sectionHeader(this.tr('Local'), this.localCount, true, () => RouterUtil.openLocalComics())
    this.horizontalComics(this.localComics)
    Row() {
      if (this.downloadTasks.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Text(this.trParams('@a Tasks', 'a', this.downloadTasks.length))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
        }
        .borderRadius(20)
        .backgroundColor($r('app.color.card_background'))
        .onClick(() => RouterUtil.openDownloading())
      }
      Blank()
      Button({ type: ButtonType.Normal }) {
        Text(this.tr('Import'))
          .fontSize(14)
          .fontColor(Color.White)
      }
      .borderRadius(20)
      .backgroundColor($r('app.color.color_emphasize'))
      .onClick(() => { this.showImportDialog = true; })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  followUpdatesCardBody() {
    this.sectionHeader(this.tr('Follow Updates'), undefined, true, () => RouterUtil.openFollowUpdates())
    if (this.followSummary.count > 0) {
      Text(this.trParams('@c updates', 'c', this.followSummary.count))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 16, right: 16, bottom: 16 })
        .borderRadius(8)
        .backgroundColor($r('app.color.badge_bg'))
        .margin({ left: 16, right: 16, bottom: 16 })
    }
  }

  @Builder
  comicSourceCardBody() {
    this.sectionHeader(this.tr('Comic Source'), this.comicSources.length, true,
      () => RouterUtil.openComicSource())
    if (this.comicSources.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.comicSources, (source: ComicSourceInfo) => {
          Text(source.name)
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin(4)
            .borderRadius(8)
            .backgroundColor($r('app.color.badge_bg'))
        }, (source: ComicSourceInfo) => source.key)
      }
      .padding({ left: 12, right: 12, bottom: 8 })
    }
    if (this.comicSourceUpdateCount > 0) {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(16)
          .fontColor([$r('app.color.color_emphasize')])
        Text(this.trParams('@c updates', 'c', this.comicSourceUpdateCount))
          .fontSize(14)
          .fontColor($r('app.color.color_emphasize'))
          .margin({ left: 8 })
      }
      .padding({ left: 16, right: 16, bottom: 16 })
    }
  }

  @Builder
  historyCard() {
    Column() {
      this.historyCardBody()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: $r('app.color.card_border') })
  }

  @Builder
  localCard() {
    Column() {
      this.localCardBody()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: $r('app.color.card_border') })
  }

  @Builder
  followUpdatesCard() {
    Column() {
      this.followUpdatesCardBody()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: $r('app.color.card_border') })
  }

  @Builder
  comicSourceCard() {
    Column() {
      this.comicSourceCardBody()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: $r('app.color.card_border') })
  }

  build() {
    Stack() {
      if (this.isLoading) {
        LoadingIndicator()
      } else {
        Scroll(this.scroller) {
          Column() {
            SearchBar({
              placeholder: this.tr('Search'),
              onTap: () => RouterUtil.openSearch()
            })
              .margin({ left: 8, right: 8, top: 8 })

            this.syncCard()

            this.historyCard()

            this.localCard()

            this.followUpdatesCard()

            this.comicSourceCard()

            this.imageFavoritesSection()

            Blank().height(80)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
      }

      ImportComicsDialog({
        show: $showImportDialog,
        onImported: () => { this.loadData(); }
      })

      ContentDialog({
        show: this.showSyncErrorDialog,
        title: this.tr('Error'),
        message: this.syncStatus.lastError ?? '',
        showCancel: false,
        onClose: () => { this.showSyncErrorDialog = false; }
      })
    }
    .width('100%')
    .height('100%')
  }
}
