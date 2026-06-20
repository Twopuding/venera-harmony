import { ReaderViewModel, ReaderMode } from '../viewmodel/ReaderViewModel';
import { ReaderImage } from '../components/ReaderImage';
import { ReaderBridge } from '../bridge/ReaderBridge';
import { CommentInfo } from '../service/DataService';
import { ChapterPickerSheet } from '../components/ChapterPickerSheet';
import { ReaderSettingsPanel } from '../components/ReaderSettingsPanel';
import { RichCommentContent } from '../components/RichCommentContent';
import { common } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { AuthSessionGuard } from '../utils/AuthSessionGuard';
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
  @StorageLink('settingsVersion') @Watch('onSettingsVersionChanged') settingsVersion: number = 0;

  private viewModel: ReaderViewModel = new ReaderViewModel();
  private bridge: ReaderBridge = ReaderBridge.getInstance();
  private swiperController: SwiperController = new SwiperController();
  private listScroller: Scroller = new Scroller();
  @State currentClock: string = '';
  @State autoPageOn: boolean = false;
  @State newChapterComment: string = '';
  @State chapterReplyTo: string = '';
  @State chapterReplyUser: string = '';
  @State isPostingChapterComment: boolean = false;
  @State showChapterPicker: boolean = false;
  @State showSettingsPanel: boolean = false;
  @State authBlocked: boolean = false;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.authBlocked = AuthSessionGuard.shouldBlock();
    if (this.authBlocked) {
      AuthSessionGuard.redirectIfNeeded();
      return;
    }
    let hostCtx = this.getUIContext().getHostContext();
    if (hostCtx !== null) {
      this.context = hostCtx as common.UIAbilityContext;
    }
    this.updateOrientation();
    this.viewModel.comicId = this.comicId;
    this.viewModel.sourceKey = this.sourceKey;
    this.viewModel.currentChapter = this.initialEp;
    this.viewModel.currentPage = this.initialPage;
    this.viewModel.loadSettings().then(() => {
      this.viewModel.readerMode = this.viewModel.settings.readerMode;
      this.viewModel.loadComicData();
    });
    this.updateClock();
    setInterval(() => {
      this.updateClock();
    }, 30000);
    let ctx = this.getUIContext().getHostContext();
    if (ctx !== null) {
      window.getLastWindow(ctx as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowKeepScreenOn(true);
      });
    }
    hilog.info(DOMAIN, TAG, 'ReaderPage appeared');
  }

  private async shareCurrentPage(): Promise<void> {
    if (this.context === null) {
      return;
    }
    await this.viewModel.shareCurrentPageImage(this.context);
  }

  private updateOrientation(): void {
    try {
      let d = display.getDefaultDisplaySync();
      this.viewModel.setLandscape(d.width > d.height);
    } catch (e) {
      this.viewModel.setLandscape(false);
    }
  }

  private onSettingsChanged(): void {
    this.updateOrientation();
    this.viewModel.loadSettings().then(() => {
      this.viewModel.readerMode = this.viewModel.settings.readerMode;
      if (this.viewModel.images.length > 0) {
        this.viewModel.totalPages = this.viewModel.isGalleryMode() ?
          this.viewModel.getGalleryPageCount() : this.viewModel.images.length;
      }
    });
  }

  onSettingsVersionChanged(): void {
    this.onSettingsChanged();
  }

  aboutToDisappear(): void {
    this.viewModel.cancelHistoryTimer();
    this.viewModel.updateHistory();
    this.bridge.onRead(this.comicId, this.sourceKey);
    this.bridge.onClosed();
    let ctx = this.getUIContext().getHostContext();
    if (ctx !== null) {
      window.getLastWindow(ctx as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowKeepScreenOn(false);
      });
    }
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
    if (this.viewModel.isChapterCommentsEndPage()) {
      this.viewModel.showChapterCommentsPanel = true;
      this.viewModel.loadChapterComments();
    } else if (this.viewModel.showChapterCommentsPanel) {
      this.chapterReplyTo = '';
      this.chapterReplyUser = '';
      this.viewModel.loadChapterComments();
    }
  }

  private shouldPreloadImage(galleryPage: number, imageIndex: number): boolean {
    let distance: number = Math.abs(galleryPage - this.viewModel.currentPage);
    return distance <= this.viewModel.settings.preloadImageCount;
  }

  @Builder
  galleryPageImages(galleryPage: number) {
    if (this.viewModel.getImagesPerPage() <= 1) {
      ReaderImage({
        imageKey: this.viewModel.images[galleryPage] ?? '',
        ep: this.viewModel.currentChapter + 1,
        page: galleryPage + 1,
        sourceKey: this.viewModel.sourceKey,
        comicId: this.viewModel.comicId,
        chapterId: this.viewModel.getCurrentChapterId(),
        enableDoubleTapZoom: this.viewModel.settings.enableDoubleTapToZoom,
        enableLongPressZoom: this.viewModel.settings.enableLongPressToZoom,
        limitWidth: this.viewModel.settings.limitImageWidth,
        quickCollectMode: this.viewModel.settings.quickCollectImage,
        isActivePage: galleryPage === this.viewModel.currentPage,
        shouldPreload: this.shouldPreloadImage(galleryPage, galleryPage),
        onCollectImage: () => {
          if (galleryPage === this.viewModel.currentPage) {
            this.viewModel.addCurrentImageFavorite();
          }
        }
      })
    } else if (this.viewModel.isVerticalMode()) {
      Column() {
        ForEach(this.viewModel.getImagesForGalleryPage(galleryPage), (url: string, idx: number) => {
          ReaderImage({
            imageKey: url,
            ep: this.viewModel.currentChapter + 1,
            page: this.viewModel.getImageStartIndex(galleryPage) + idx + 1,
            sourceKey: this.viewModel.sourceKey,
            comicId: this.viewModel.comicId,
            chapterId: this.viewModel.getCurrentChapterId(),
            enableDoubleTapZoom: this.viewModel.settings.enableDoubleTapToZoom,
            enableLongPressZoom: this.viewModel.settings.enableLongPressToZoom,
            limitWidth: this.viewModel.settings.limitImageWidth,
            quickCollectMode: this.viewModel.settings.quickCollectImage,
            isActivePage: galleryPage === this.viewModel.currentPage && idx === 0,
            shouldPreload: this.shouldPreloadImage(galleryPage, idx),
            onCollectImage: () => {
              if (galleryPage === this.viewModel.currentPage && idx === 0) {
                this.viewModel.addCurrentImageFavorite();
              }
            }
          })
            .layoutWeight(1)
        }, (url: string, idx: number) => url + idx.toString())
      }
      .width('100%')
      .height('100%')
    } else {
      Row() {
        ForEach(this.viewModel.getImagesForGalleryPage(galleryPage), (url: string, idx: number) => {
          ReaderImage({
            imageKey: url,
            ep: this.viewModel.currentChapter + 1,
            page: this.viewModel.getImageStartIndex(galleryPage) + idx + 1,
            sourceKey: this.viewModel.sourceKey,
            comicId: this.viewModel.comicId,
            chapterId: this.viewModel.getCurrentChapterId(),
            enableDoubleTapZoom: this.viewModel.settings.enableDoubleTapToZoom,
            enableLongPressZoom: this.viewModel.settings.enableLongPressToZoom,
            limitWidth: this.viewModel.settings.limitImageWidth,
            quickCollectMode: this.viewModel.settings.quickCollectImage,
            isActivePage: galleryPage === this.viewModel.currentPage && idx === 0,
            shouldPreload: this.shouldPreloadImage(galleryPage, idx),
            onCollectImage: () => {
              if (galleryPage === this.viewModel.currentPage && idx === 0) {
                this.viewModel.addCurrentImageFavorite();
              }
            }
          })
            .layoutWeight(1)
        }, (url: string, idx: number) => url + idx.toString())
      }
      .width('100%')
      .height('100%')
    }
  }

  build() {
    if (this.authBlocked) {
      LoadingIndicator()
    } else {
    Stack() {
      Row() {
        Column()
          .layoutWeight(1)
          .height('100%')
          .onClick(() => {
            if (this.viewModel.settings.enableTapToTurnPages) {
              this.viewModel.tapToPrevPage();
            } else {
              this.onContentTap();
            }
          })
        Column() {
          this.buildReaderContent()
        }
        .layoutWeight(2)
        Column()
          .layoutWeight(1)
          .height('100%')
          .onClick(() => {
            if (this.viewModel.settings.enableTapToTurnPages) {
              this.viewModel.tapToNextPage();
            } else {
              this.onContentTap();
            }
          })
      }
      .width('100%')
      .height('100%')

      if (this.viewModel.isToolbarOpen) {
        this.buildTopBar()
        this.buildBottomBar()
        if (this.viewModel.settings.enableClockAndBatteryInfoInReader) {
          this.buildClockBatteryWidget()
        }
      }

      if (this.viewModel.showChapterCommentsPanel) {
        this.buildChapterCommentsPanel()
      }

      if (this.showChapterPicker) {
        Column() {
          ChapterPickerSheet({
            chapters: this.viewModel.chapters,
            currentIndex: this.viewModel.currentChapter,
            onSelect: (index: number) => {
              this.showChapterPicker = false;
              this.viewModel.toChapter(index);
            },
            onClose: () => {
              this.showChapterPicker = false;
            }
          })
        }
        .width('100%')
        .height('55%')
        .position({ x: 0, y: '45%' })
      }

      if (this.showSettingsPanel) {
        Column() {
          ReaderSettingsPanel({
            comicId: this.comicId,
            sourceKey: this.sourceKey,
            onClose: () => {
              this.showSettingsPanel = false;
            },
            onChanged: () => {
              this.onSettingsChanged();
            }
          })
        }
        .width('85%')
        .height('100%')
        .position({ x: '15%', y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onKeyEvent((event: KeyEvent) => {
      if (!this.viewModel.settings.enableTurnPageByVolumeKey) {
        return;
      }
      if (event.type === KeyType.Down) {
        if (event.keyCode === 2012 || event.keyCode === 2054) {
          this.viewModel.toNextPage();
        } else if (event.keyCode === 2013 || event.keyCode === 2055) {
          this.viewModel.toPrevPage();
        }
      }
    })
    .focusable(true)
    .defaultFocus(true)
    }
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
      ForEach(this.viewModel.getGalleryPageIndices(), (galleryPage: number) => {
        if (this.viewModel.isChapterCommentsEndPageAt(galleryPage)) {
          Column() {
            Text('Chapter Comments')
              .fontSize(16)
              .fontColor(Color.White)
              .margin({ bottom: 12 })
            if (this.viewModel.chapterCommentsLoading) {
              LoadingProgress().width(32).height(32).color(Color.White)
            } else if (this.viewModel.chapterComments.length === 0) {
              Text('No comments')
                .fontSize(14)
                .fontColor('#99FFFFFF')
            } else {
              Text(`${this.viewModel.chapterComments.length} comments`)
                .fontSize(14)
                .fontColor('#99FFFFFF')
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.viewModel.showChapterCommentsPanel = true;
            this.viewModel.loadChapterComments();
          })
        } else {
          this.galleryPageImages(galleryPage)
        }
      }, (galleryPage: number) => 'gp_' + galleryPage.toString())
    }
    .index(this.viewModel.currentPage)
    .indicator(false)
    .loop(false)
    .vertical(this.viewModel.isVerticalMode())
    .cachedCount(this.viewModel.settings.preloadImageCount + 1)
    .duration(this.viewModel.settings.enablePageAnimation ? 300 : 0)
    .curve(Curve.EaseOut)
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
          ReaderImage({
            imageKey: url,
            ep: this.viewModel.currentChapter + 1,
            page: index + 1,
            sourceKey: this.viewModel.sourceKey,
            comicId: this.viewModel.comicId,
            chapterId: this.viewModel.getCurrentChapterId(),
            enableDoubleTapZoom: this.viewModel.settings.enableDoubleTapToZoom,
            enableLongPressZoom: this.viewModel.settings.enableLongPressToZoom,
            limitWidth: this.viewModel.settings.limitImageWidth,
            quickCollectMode: this.viewModel.settings.quickCollectImage,
            isActivePage: index === this.viewModel.currentPage,
            shouldPreload: Math.abs(index - this.viewModel.currentPage) <=
              this.viewModel.settings.preloadImageCount,
            onCollectImage: () => {
              if (index === this.viewModel.currentPage) {
                this.viewModel.addCurrentImageFavorite();
              }
            }
          })
        }
      }, (url: string, index: number) => url + index.toString())
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .cachedCount(this.viewModel.settings.preloadImageCount + 1)
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
        Text('Ch')
          .fontSize(12)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
      .margin({ left: 4 })
      .onClick(() => {
        this.showChapterPicker = true;
      })

      Button({ type: ButtonType.Circle }) {
        Text('S')
          .fontSize(14)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
      .margin({ left: 4 })
      .onClick(() => {
        this.showSettingsPanel = true;
      })

      Button({ type: ButtonType.Circle }) {
        Text('Sh')
          .fontSize(11)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
      .margin({ left: 4 })
      .onClick(() => {
        this.shareCurrentPage();
      })

      Button({ type: ButtonType.Circle }) {
        Text('...')
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)
      .backgroundColor('#00000000')
      .margin({ left: 4 })
      .onClick(() => {
        this.viewModel.addCurrentImageFavorite();
      })

      if (this.viewModel.settings.showChapterComments) {
        Button({ type: ButtonType.Circle }) {
          Text('C')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor('#00000000')
        .margin({ left: 4 })
        .onClick(() => {
          this.viewModel.toggleChapterComments();
        })
      }
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
          Text('Ch')
            .fontSize(11)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.showChapterPicker = true;
        })

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
          Button({ type: ButtonType.Normal }) {
            Text(this.autoPageOn ? 'Auto ON' : 'Auto')
              .fontSize(11)
              .fontColor(Color.White)
          }
          .height(28)
          .backgroundColor(this.autoPageOn ? '#66FFFFFF' : '#33FFFFFF')
          .borderRadius(4)
          .margin({ left: 8 })
          .onClick(() => {
            this.autoPageOn = !this.autoPageOn;
            if (this.autoPageOn) {
              this.viewModel.startAutoPageTurning();
            } else {
              this.viewModel.stopAutoPageTurning();
            }
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

  @Builder
  buildChapterCommentsPanel() {
    Column() {
      Row() {
        Text(this.chapterReplyTo.length > 0 ? `Reply to ${this.chapterReplyUser}` : 'Chapter Comments')
          .fontSize(16)
          .fontColor(Color.White)
          .layoutWeight(1)
        if (this.chapterReplyTo.length > 0) {
          Text('Cancel')
            .fontSize(14)
            .fontColor('#99FFFFFF')
            .margin({ right: 12 })
            .onClick(() => {
              this.chapterReplyTo = '';
              this.chapterReplyUser = '';
              this.viewModel.loadChapterComments();
            })
        }
        Text('Close')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .onClick(() => {
            this.viewModel.showChapterCommentsPanel = false;
            this.chapterReplyTo = '';
            this.chapterReplyUser = '';
          })
      }
      .width('100%')
      .padding(12)

      if (this.viewModel.chapterCommentsLoading) {
        LoadingProgress().width(32).height(32).color(Color.White)
      } else if (this.viewModel.chapterComments.length === 0) {
        Text('No comments')
          .fontSize(14)
          .fontColor('#99FFFFFF')
      } else {
        List() {
          ForEach(this.viewModel.chapterComments, (comment: CommentInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Text(comment.userName)
                    .fontSize(13)
                    .fontColor('#CCFFFFFF')
                    .layoutWeight(1)
                  if (comment.replyCount > 0) {
                    Text(`${comment.replyCount} replies`)
                      .fontSize(11)
                      .fontColor('#88FFFFFF')
                      .onClick(() => {
                        this.chapterReplyTo = comment.id;
                        this.chapterReplyUser = comment.userName;
                        this.viewModel.loadChapterComments(comment.id);
                      })
                  }
                }
                .width('100%')
                RichCommentContent({ text: comment.content, useLightText: true })
                  .margin({ top: 4 })
                Row() {
                  Text('Like')
                    .fontSize(12)
                    .fontColor('#99FFFFFF')
                    .onClick(async () => {
                      await this.viewModel.likeComment(comment.id, true);
                      await this.viewModel.loadChapterComments(this.chapterReplyTo.length > 0 ?
                        this.chapterReplyTo : undefined);
                    })
                  Text('Reply')
                    .fontSize(12)
                    .fontColor('#99FFFFFF')
                    .margin({ left: 16 })
                    .onClick(() => {
                      this.chapterReplyTo = comment.id;
                      this.chapterReplyUser = comment.userName;
                    })
                }
                .margin({ top: 6 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(8)
            }
          }, (comment: CommentInfo) => comment.id)
        }
        .layoutWeight(1)
      }

      Row() {
        TextInput({ placeholder: 'Write a comment...', text: this.newChapterComment })
          .layoutWeight(1)
          .fontColor(Color.White)
          .onChange((v: string) => {
            this.newChapterComment = v;
          })
        Button(this.isPostingChapterComment ? '...' : 'Post')
          .margin({ left: 8 })
          .enabled(!this.isPostingChapterComment)
          .onClick(async () => {
            if (this.newChapterComment.trim().length === 0) {
              return;
            }
            this.isPostingChapterComment = true;
            let replyTo: string | undefined = this.chapterReplyTo.length > 0 ?
              this.chapterReplyTo : undefined;
            let ok: boolean = await this.viewModel.postChapterComment(
              this.newChapterComment, replyTo
            );
            this.isPostingChapterComment = false;
            if (ok) {
              this.newChapterComment = '';
              this.chapterReplyTo = '';
              this.chapterReplyUser = '';
            }
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%')
    .height('50%')
    .backgroundColor('#CC000000')
    .position({ x: 0, y: '50%' })
  }

  onBackPress(): boolean {
    if (this.showSettingsPanel) {
      this.showSettingsPanel = false;
      return true;
    }
    if (this.showChapterPicker) {
      this.showChapterPicker = false;
      return true;
    }
    if (this.viewModel.isToolbarOpen) {
      this.viewModel.isToolbarOpen = false;
      return true;
    }
    return false;
  }
}
