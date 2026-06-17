import { ReaderViewModel, ReaderMode } from '../viewmodel/ReaderViewModel';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ReaderPage';

@Entry
@Component
struct ReaderPage {
  @StorageLink('reader_comicId') comicId: string = '';
  @StorageLink('reader_sourceKey') sourceKey: string = '';
  @StorageLink('reader_initialEp') initialEp: number = 0;
  @StorageLink('reader_initialPage') initialPage: number = 0;
  @StorageLink('reader_safeAreaTop') safeAreaTop: number = 0;
  @StorageLink('reader_safeAreaBottom') safeAreaBottom: number = 0;

  private viewModel: ReaderViewModel = new ReaderViewModel();
  private swiperController: SwiperController = new SwiperController();
  private listScroller: Scroller = new Scroller();
  private currentClock: string = '';

  aboutToAppear(): void {
    this.viewModel.comicId = this.comicId;
    this.viewModel.sourceKey = this.sourceKey;
    this.viewModel.currentChapter = this.initialEp;
    this.viewModel.currentPage = this.initialPage;
    this.viewModel.readerMode = this.viewModel.settings.readerMode;
    this.viewModel.loadComicData();
    this.updateClock();
    setInterval(() => {
      this.updateClock();
    }, 30000);
    hilog.info(DOMAIN, TAG, 'ReaderPage appeared');
  }

  aboutToDisappear(): void {
    this.viewModel.cancelHistoryTimer();
    this.viewModel.updateHistory();
    hilog.info(DOMAIN, TAG, 'ReaderPage disappeared');
  }

  private updateClock(): void {
    const now: Date = new Date();
    const hours: number = now.getHours();
    const minutes: number = now.getMinutes();
    const h: string = hours < 10 ? '0' + hours.toString() : hours.toString();
    const m: string = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    this.currentClock = h + ':' + m;
  }

  private onContentTap(): void {
    this.viewModel.toggleToolbar();
  }

  private onBack(): void {
    let ctx = this.getUIContext().getHostContext();
    if (ctx !== null) {
      let abilityContext: common.UIAbilityContext = ctx as common.UIAbilityContext;
      abilityContext.terminateSelf();
    }
  }

  private onSliderChange(value: number, mode: SliderChangeMode): void {
    if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
      this.viewModel.setCurrentPage(Math.floor(value));
    }
  }

  private onSwiperChange(index: number): void {
    this.viewModel.setCurrentPage(index);
  }

  build() {
    Stack() {
      this.buildReaderContent()

      if (this.viewModel.isToolbarOpen) {
        this.buildTopBar()
        this.buildBottomBar()
        this.buildClockBatteryWidget()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction(() => {
            hilog.info(DOMAIN, TAG, 'Double tap zoom');
          }),
        LongPressGesture({ repeat: false })
          .onAction(() => {
            hilog.info(DOMAIN, TAG, 'Long press zoom');
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            this.onContentTap();
          })
      )
    )
  }

  @Builder
  buildReaderContent() {
    if (this.viewModel.isLoading) {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(Color.White)
        Text('Loading...')
          .fontSize(14)
          .fontColor(Color.White)
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      if (this.viewModel.isGalleryMode()) {
        this.buildGalleryReader()
      } else {
        this.buildContinuousReader()
      }
    }
  }

  @Builder
  buildGalleryReader() {
    Swiper(this.swiperController) {
      ForEach(this.viewModel.images, (url: string, index: number) => {
        Image(url)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.Black)
      }, (url: string, index: number) => url + index.toString())
    }
    .index(this.viewModel.currentPage)
    .indicator(false)
    .loop(false)
    .vertical(this.viewModel.isVerticalMode())
    .cachedCount(3)
    .onChange((index: number) => {
      this.onSwiperChange(index);
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  buildContinuousReader() {
    List({ scroller: this.listScroller }) {
      ForEach(this.viewModel.images, (url: string, index: number) => {
        ListItem() {
          Image(url)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .backgroundColor(Color.Black)
        }
      }, (url: string, index: number) => url + index.toString())
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .cachedCount(3)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('<')
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
      .onClick(() => {
        this.onBack();
      })

      Text(this.viewModel.getCurrentChapterName())
        .fontSize(16)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8, right: 8 })

      Button({ type: ButtonType.Circle }) {
        Text('...')
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  buildBottomBar() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('Prev')
            .fontSize(12)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.viewModel.toPrevPage();
        })

        Slider({
          value: this.viewModel.currentPage,
          min: 0,
          max: Math.max(this.viewModel.totalPages - 1, 0),
          step: 1,
          style: SliderStyle.InSet
        })
          .layoutWeight(1)
          .blockColor(Color.White)
          .trackColor('#33FFFFFF')
          .selectedColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.onSliderChange(value, mode);
          })
          .margin({ left: 8, right: 8 })

        Button({ type: ButtonType.Circle }) {
          Text('Next')
            .fontSize(12)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.viewModel.toNextPage();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(this.viewModel.getPageIndicator())
          .fontSize(14)
          .fontColor(Color.White)
          .margin({ left: 44 })
          .layoutWeight(1)

        Row() {
          Text('Mode')
            .fontSize(12)
            .fontColor(Color.White)
            .margin({ right: 4 })
          Button({ type: ButtonType.Normal }) {
            Text(this.getModeLabel())
              .fontSize(11)
              .fontColor(Color.White)
          }
          .height(28)
          .backgroundColor('#33FFFFFF')
          .borderRadius(4)
          .onClick(() => {
            this.cycleReaderMode();
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 4, bottom: 4 })
    }
    .width('100%')
    .padding({ left: 8, right: 8, bottom: this.safeAreaBottom > 0 ? this.safeAreaBottom : 8 })
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildClockBatteryWidget() {
    Row() {
      Text(this.currentClock)
        .fontSize(12)
        .fontColor('#99FFFFFF')
    }
    .position({ x: '50%', y: 4 })
    .translate({ x: '-50%' })
  }

  private getModeLabel(): string {
    if (this.viewModel.readerMode === ReaderMode.GALLERY_LR) {
      return 'G-LR';
    } else if (this.viewModel.readerMode === ReaderMode.GALLERY_RL) {
      return 'G-RL';
    } else if (this.viewModel.readerMode === ReaderMode.GALLERY_TB) {
      return 'G-TB';
    } else if (this.viewModel.readerMode === ReaderMode.CONTINUOUS_TB) {
      return 'C-TB';
    } else if (this.viewModel.readerMode === ReaderMode.CONTINUOUS_LR) {
      return 'C-LR';
    } else if (this.viewModel.readerMode === ReaderMode.CONTINUOUS_RL) {
      return 'C-RL';
    } else {
      return 'G-LR';
    }
  }

  private cycleReaderMode(): void {
    const currentMode: ReaderMode = this.viewModel.readerMode;
    const nextMode: ReaderMode = (currentMode + 1) % 6;
    this.viewModel.readerMode = nextMode;
    this.viewModel.settings.readerMode = nextMode;
    hilog.info(DOMAIN, TAG, 'Reader mode changed to: ' + nextMode.toString());
  }

  onBackPress(): boolean {
    if (this.viewModel.isToolbarOpen) {
      this.viewModel.isToolbarOpen = false;
      return true;
    }
    return false;
  }
}
