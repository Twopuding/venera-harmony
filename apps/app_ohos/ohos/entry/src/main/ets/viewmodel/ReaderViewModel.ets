import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReaderBridge } from '../bridge/ReaderBridge';
import { DataService, CommentInfo } from '../service/DataService';
import { PlatformUtil } from '../utils/PlatformUtil';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

export enum ReaderMode {
  GALLERY_LR = 0,
  GALLERY_RL = 1,
  GALLERY_TB = 2,
  CONTINUOUS_TB = 3,
  CONTINUOUS_LR = 4,
  CONTINUOUS_RL = 5
}

export interface ChapterInfo {
  id: string;
  name: string;
  order: number;
}

export interface ReaderSettings {
  readerMode: ReaderMode;
  landscape: boolean;
  enableTapToTurnPages: boolean;
  reverseTapToTurnPages: boolean;
  enablePageAnimation: boolean;
  showPageNumberInReader: boolean;
  enableClockAndBatteryInfoInReader: boolean;
  enableDoubleTapToZoom: boolean;
  enableLongPressToZoom: boolean;
  autoPageTurningInterval: number;
  showChapterComments: boolean;
  limitImageWidth: boolean;
  preloadImageCount: number;
  enableTurnPageByVolumeKey: boolean;
  quickCollectImage: string;
  readerScreenPicNumberForLandscape: number;
  readerScreenPicNumberForPortrait: number;
  showSingleImageOnFirstPage: boolean;
  enableCustomImageProcessing: boolean;
  showChapterCommentsAtEnd: boolean;
  readerScrollSpeed: number;
  longPressZoomPosition: string;
  showSystemStatusBar: boolean;
  comicSpecificEnabled: boolean;
}

function mapReaderModeKey(mode: string | undefined): ReaderMode {
  if (mode === 'galleryRightToLeft') {
    return ReaderMode.GALLERY_RL;
  }
  if (mode === 'galleryTopToBottom') {
    return ReaderMode.GALLERY_TB;
  }
  if (mode === 'continuousTopToBottom') {
    return ReaderMode.CONTINUOUS_TB;
  }
  if (mode === 'continuousLeftToRight') {
    return ReaderMode.CONTINUOUS_LR;
  }
  if (mode === 'continuousRightToLeft') {
    return ReaderMode.CONTINUOUS_RL;
  }
  return ReaderMode.GALLERY_LR;
}

@Observed
export class ReaderViewModel {
  comicId: string = '';
  sourceKey: string = '';
  comicName: string = '';
  author: string = '';
  tags: string = '';
  tagsList: string[] = [];
  chapters: ChapterInfo[] = [];
  currentPage: number = 0;
  totalPages: number = 0;
  currentChapter: number = 0;
  isLoading: boolean = false;
  isToolbarOpen: boolean = false;
  showChapterCommentsPanel: boolean = false;
  chapterComments: CommentInfo[] = [];
  chapterCommentsLoading: boolean = false;
  readerMode: ReaderMode = ReaderMode.GALLERY_LR;
  images: string[] = [];
  settings: ReaderSettings = {
    readerMode: ReaderMode.GALLERY_LR,
    landscape: false,
    enableTapToTurnPages: true,
    reverseTapToTurnPages: false,
    enablePageAnimation: true,
    showPageNumberInReader: true,
    enableClockAndBatteryInfoInReader: false,
    enableDoubleTapToZoom: true,
    enableLongPressToZoom: true,
    autoPageTurningInterval: 5,
    showChapterComments: false,
    limitImageWidth: false,
    preloadImageCount: 4,
    enableTurnPageByVolumeKey: true,
    quickCollectImage: 'No',
    readerScreenPicNumberForLandscape: 1,
    readerScreenPicNumberForPortrait: 1,
    showSingleImageOnFirstPage: false,
    enableCustomImageProcessing: false,
    showChapterCommentsAtEnd: false,
    readerScrollSpeed: 1,
    longPressZoomPosition: 'press',
    showSystemStatusBar: false,
    comicSpecificEnabled: false
  };
  private historyTimer: number = -1;
  private autoPageTimer: number = -1;
  private bridge: ReaderBridge = ReaderBridge.getInstance();

  async loadSettings(): Promise<void> {
    try {
      let raw: Object | null = await this.bridge.onGetSettings(this.comicId, this.sourceKey);
      if (raw === null) {
        return;
      }
      let jsonStr: string = JSON.stringify(raw);
      let parsed: ReaderSettingsJson = JSON.parse(jsonStr);
      if (parsed.readerMode !== undefined) {
        this.readerMode = mapReaderModeKey(parsed.readerMode);
        this.settings.readerMode = this.readerMode;
      }
      if (parsed.enableTapToTurnPages !== undefined) {
        this.settings.enableTapToTurnPages = parsed.enableTapToTurnPages;
      }
      if (parsed.reverseTapToTurnPages !== undefined) {
        this.settings.reverseTapToTurnPages = parsed.reverseTapToTurnPages;
      }
      if (parsed.enablePageAnimation !== undefined) {
        this.settings.enablePageAnimation = parsed.enablePageAnimation;
      }
      if (parsed.showPageNumberInReader !== undefined) {
        this.settings.showPageNumberInReader = parsed.showPageNumberInReader;
      }
      if (parsed.enableClockAndBatteryInfoInReader !== undefined) {
        this.settings.enableClockAndBatteryInfoInReader = parsed.enableClockAndBatteryInfoInReader;
      }
      if (parsed.enableDoubleTapToZoom !== undefined) {
        this.settings.enableDoubleTapToZoom = parsed.enableDoubleTapToZoom;
      }
      if (parsed.enableLongPressToZoom !== undefined) {
        this.settings.enableLongPressToZoom = parsed.enableLongPressToZoom;
      }
      if (parsed.autoPageTurningInterval !== undefined) {
        this.settings.autoPageTurningInterval = parsed.autoPageTurningInterval;
      }
      if (parsed.showChapterComments !== undefined) {
        this.settings.showChapterComments = parsed.showChapterComments;
      }
      if (parsed.showChapterCommentsAtEnd !== undefined) {
        this.settings.showChapterCommentsAtEnd = parsed.showChapterCommentsAtEnd;
      }
      if (parsed.limitImageWidth !== undefined) {
        this.settings.limitImageWidth = parsed.limitImageWidth;
      }
      if (parsed.preloadImageCount !== undefined) {
        this.settings.preloadImageCount = parsed.preloadImageCount;
      }
      if (parsed.enableTurnPageByVolumeKey !== undefined) {
        this.settings.enableTurnPageByVolumeKey = parsed.enableTurnPageByVolumeKey;
      }
      if (parsed.quickCollectImage !== undefined) {
        this.settings.quickCollectImage = parsed.quickCollectImage;
      }
      if (parsed.readerScreenPicNumberForLandscape !== undefined) {
        this.settings.readerScreenPicNumberForLandscape = parsed.readerScreenPicNumberForLandscape;
      }
      if (parsed.readerScreenPicNumberForPortrait !== undefined) {
        this.settings.readerScreenPicNumberForPortrait = parsed.readerScreenPicNumberForPortrait;
      }
      if (parsed.showSingleImageOnFirstPage !== undefined) {
        this.settings.showSingleImageOnFirstPage = parsed.showSingleImageOnFirstPage;
      }
      if (parsed.enableCustomImageProcessing !== undefined) {
        this.settings.enableCustomImageProcessing = parsed.enableCustomImageProcessing;
      }
      if (parsed.readerScrollSpeed !== undefined) {
        this.settings.readerScrollSpeed = parsed.readerScrollSpeed;
      }
      if (parsed.longPressZoomPosition !== undefined) {
        this.settings.longPressZoomPosition = parsed.longPressZoomPosition;
      }
      if (parsed.showSystemStatusBar !== undefined) {
        this.settings.showSystemStatusBar = parsed.showSystemStatusBar;
      }
      if (parsed.comicSpecificEnabled !== undefined) {
        this.settings.comicSpecificEnabled = parsed.comicSpecificEnabled;
      }
      if (parsed.landscape !== undefined) {
        this.settings.landscape = parsed.landscape;
      }
    } catch (e) {
      hilog.error(0x0000, 'ReaderVM', 'Failed to load reader settings');
    }
  }

  supportsChapterCommentsAtEnd(): boolean {
    if (!this.settings.showChapterComments || !this.settings.showChapterCommentsAtEnd) {
      return false;
    }
    return this.readerMode === ReaderMode.GALLERY_LR ||
      this.readerMode === ReaderMode.GALLERY_RL;
  }

  isChapterCommentsEndPage(): boolean {
    if (!this.supportsChapterCommentsAtEnd()) {
      return false;
    }
    return this.currentPage === this.getImageGalleryPageCount();
  }

  isChapterCommentsEndPageAt(page: number): boolean {
    if (!this.supportsChapterCommentsAtEnd()) {
      return false;
    }
    return page === this.getImageGalleryPageCount();
  }

  async shareCurrentPageImage(context: common.UIAbilityContext): Promise<boolean> {
    let imageKey: string = this.getCurrentImageKey();
    if (imageKey.length === 0 || this.isChapterCommentsEndPage()) {
      return false;
    }
    try {
      let raw: Object | null = await this.bridge.onLoadImage(
        imageKey,
        this.currentChapter + 1,
        this.getPrimaryImageIndex() + 1,
        this.sourceKey,
        this.comicId,
        this.getCurrentChapterId()
      );
      if (raw === null) {
        return false;
      }
      let data: Uint8Array | null = this.parseImageData(raw);
      if (data === null || data.length === 0) {
        return false;
      }
      let fileName: string = `${this.comicName}_EP${this.currentChapter + 1}_P${this.getPrimaryImageIndex() + 1}.jpg`;
      return PlatformUtil.shareBytes(context, data, fileName, 'image/jpeg');
    } catch (e) {
      return false;
    }
  }

  private parseImageData(raw: Object): Uint8Array | null {
    if (Array.isArray(raw)) {
      return new Uint8Array(raw as number[]);
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      let parsed: Record<string, Object> = JSON.parse(jsonStr);
      if (parsed['data'] !== undefined && Array.isArray(parsed['data'])) {
        return new Uint8Array(parsed['data'] as number[]);
      }
      if (parsed['base64'] !== undefined && typeof parsed['base64'] === 'string') {
        let helper = new util.Base64Helper();
        return helper.decodeSync(parsed['base64'] as string);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  isGalleryMode(): boolean {
    return this.readerMode === ReaderMode.GALLERY_LR ||
      this.readerMode === ReaderMode.GALLERY_RL ||
      this.readerMode === ReaderMode.GALLERY_TB;
  }

  isVerticalMode(): boolean {
    return this.readerMode === ReaderMode.GALLERY_TB ||
      this.readerMode === ReaderMode.CONTINUOUS_TB;
  }

  isRtlMode(): boolean {
    return this.readerMode === ReaderMode.GALLERY_RL ||
      this.readerMode === ReaderMode.CONTINUOUS_RL;
  }

  setLandscape(landscape: boolean): void {
    this.settings.landscape = landscape;
  }

  getImagesPerPage(): number {
    if (!this.isGalleryMode()) {
      return 1;
    }
    if (this.settings.landscape) {
      return Math.max(1, this.settings.readerScreenPicNumberForLandscape);
    }
    return Math.max(1, this.settings.readerScreenPicNumberForPortrait);
  }

  getGalleryPageCount(): number {
    let count: number = this.images.length;
    if (!this.isGalleryMode() || count === 0) {
      return count;
    }
    let ipp: number = this.getImagesPerPage();
    let pages: number;
    if (ipp <= 1) {
      pages = count;
    } else if (this.settings.showSingleImageOnFirstPage) {
      if (count <= 1) {
        pages = count;
      } else {
        pages = 1 + Math.ceil((count - 1) / ipp);
      }
    } else {
      pages = Math.ceil(count / ipp);
    }
    if (this.supportsChapterCommentsAtEnd()) {
      pages = pages + 1;
    }
    return pages;
  }

  getImageGalleryPageCount(): number {
    let total: number = this.getGalleryPageCount();
    if (this.supportsChapterCommentsAtEnd()) {
      return Math.max(0, total - 1);
    }
    return total;
  }

  getGalleryPageIndices(): number[] {
    let total: number = this.getGalleryPageCount();
    let result: number[] = [];
    for (let i: number = 0; i < total; i++) {
      result.push(i);
    }
    return result;
  }

  getImageStartIndex(galleryPage: number): number {
    let ipp: number = this.getImagesPerPage();
    if (ipp <= 1) {
      return galleryPage;
    }
    if (this.settings.showSingleImageOnFirstPage) {
      if (galleryPage === 0) {
        return 0;
      }
      return 1 + (galleryPage - 1) * ipp;
    }
    return galleryPage * ipp;
  }

  getImagesForGalleryPage(galleryPage: number): string[] {
    if (this.isChapterCommentsEndPage()) {
      return [];
    }
    if (!this.isGalleryMode() || this.getImagesPerPage() <= 1) {
      if (galleryPage >= 0 && galleryPage < this.images.length) {
        return [this.images[galleryPage]];
      }
      return [];
    }
    if (galleryPage === 0 && this.settings.showSingleImageOnFirstPage) {
      return this.images.slice(0, 1);
    }
    let start: number = this.getImageStartIndex(galleryPage);
    return this.images.slice(start, start + this.getImagesPerPage());
  }

  getPrimaryImageIndex(): number {
    return this.getImageStartIndex(this.currentPage);
  }

  toNextPage(): void {
    if (this.isRtlMode()) {
      this.toPrevPageInternal();
    } else {
      this.toNextPageInternal();
    }
  }

  toPrevPage(): void {
    if (this.isRtlMode()) {
      this.toNextPageInternal();
    } else {
      this.toPrevPageInternal();
    }
  }

  tapToNextPage(): void {
    if (this.settings.reverseTapToTurnPages) {
      this.toPrevPage();
    } else {
      this.toNextPage();
    }
  }

  tapToPrevPage(): void {
    if (this.settings.reverseTapToTurnPages) {
      this.toNextPage();
    } else {
      this.toPrevPage();
    }
  }

  private toNextPageInternal(): void {
    if (this.currentPage < this.totalPages - 1) {
      this.currentPage = this.currentPage + 1;
      this.debouncedUpdateHistory();
    } else {
      if (this.currentChapter < this.chapters.length - 1) {
        this.toChapter(this.currentChapter + 1);
      }
    }
  }

  private toPrevPageInternal(): void {
    if (this.currentPage > 0) {
      this.currentPage = this.currentPage - 1;
      this.debouncedUpdateHistory();
    } else {
      if (this.currentChapter > 0) {
        this.toChapter(this.currentChapter - 1);
      }
    }
  }

  toChapter(index: number): void {
    if (index < 0 || index >= this.chapters.length) {
      return;
    }
    this.currentChapter = index;
    this.currentPage = 0;
    this.loadChapterImages();
  }

  toggleToolbar(): void {
    this.isToolbarOpen = !this.isToolbarOpen;
  }

  startAutoPageTurning(): void {
    this.stopAutoPageTurning();
    let interval: number = this.settings.autoPageTurningInterval;
    if (interval <= 0) {
      return;
    }
    this.autoPageTimer = setInterval(() => {
      this.toNextPage();
    }, interval * 1000) as number;
  }

  stopAutoPageTurning(): void {
    if (this.autoPageTimer !== -1) {
      clearInterval(this.autoPageTimer);
      this.autoPageTimer = -1;
    }
  }

  async loadComicData(): Promise<void> {
    if (this.comicId.length === 0 || this.sourceKey.length === 0) {
      return;
    }
    this.isLoading = true;
    try {
      let raw: Object | null = await this.bridge.onLoadData(this.comicId, this.sourceKey);
      if (raw === null) {
        return;
      }
      let jsonStr: string = JSON.stringify(raw);
      let parsed: ReaderLoadDataResult = JSON.parse(jsonStr);
      if (parsed.error !== undefined && parsed.error !== null) {
        hilog.error(0x0000, 'ReaderVM', 'Load data error: ' + parsed.error);
        return;
      }
      this.comicName = parsed.comicName ?? '';
      this.author = parsed.author ?? '';
      this.tags = parsed.tags ?? '';
      if (this.tags.length > 0) {
        this.tagsList = this.tags.split(',').map((t: string) => t.trim());
      }
      this.chapters = parsed.chapters ?? [];
      if (this.chapters.length > 0) {
        await this.loadChapterImages();
      }
    } catch (e) {
      hilog.error(0x0000, 'ReaderVM', 'Failed to load comic data');
    } finally {
      this.isLoading = false;
    }
  }

  async loadChapterImages(): Promise<void> {
    if (this.chapters.length === 0) {
      return;
    }
    this.isLoading = true;
    const chapter: ChapterInfo = this.chapters[this.currentChapter];
    try {
      let raw: Object | null = await this.bridge.onLoadChapterImages(
        this.comicId,
        this.sourceKey,
        chapter.id,
        this.currentChapter + 1
      );
      if (raw === null) {
        this.onImagesLoaded([]);
        return;
      }
      let jsonStr: string = JSON.stringify(raw);
      let parsed: ReaderChapterImagesResult = JSON.parse(jsonStr);
      if (parsed.error !== undefined && parsed.error !== null) {
        this.onImagesLoaded([]);
        return;
      }
      this.onImagesLoaded(parsed.images ?? []);
    } catch (e) {
      this.onImagesLoaded([]);
    }
  }

  onImagesLoaded(imageUrls: string[]): void {
    this.images = imageUrls;
    this.totalPages = this.isGalleryMode() ? this.getGalleryPageCount() : imageUrls.length;
    if (this.currentPage >= this.totalPages) {
      this.currentPage = Math.max(0, this.totalPages - 1);
    }
    this.isLoading = false;
  }

  setCurrentPage(page: number): void {
    if (page >= 0 && page < this.totalPages) {
      this.currentPage = page;
      this.debouncedUpdateHistory();
    }
  }

  getCurrentChapterId(): string {
    if (this.chapters.length === 0) {
      return '';
    }
    return this.chapters[this.currentChapter].id;
  }

  getCurrentImageKey(): string {
    let idx: number = this.getPrimaryImageIndex();
    if (idx < 0 || idx >= this.images.length) {
      return '';
    }
    return this.images[idx];
  }

  async postChapterComment(content: string, replyTo?: string): Promise<boolean> {
    let chapterId: string = this.getCurrentChapterId();
    if (chapterId.length === 0 || content.trim().length === 0) {
      return false;
    }
    let ok: boolean = await DataService.getInstance().postComment(
      this.sourceKey, this.comicId, content.trim(), chapterId, replyTo
    );
    if (ok) {
      await this.loadChapterComments(replyTo);
    }
    return ok;
  }

  async likeComment(commentId: string, isLiking: boolean, subId?: string): Promise<boolean> {
    let chapterId: string = subId ?? this.getCurrentChapterId();
    return DataService.getInstance().likeComment(
      this.sourceKey, this.comicId, chapterId, commentId, isLiking
    );
  }

  async voteComment(commentId: string, isUp: boolean, isCancel: boolean, subId?: string): Promise<boolean> {
    let chapterId: string = subId ?? this.getCurrentChapterId();
    return DataService.getInstance().voteComment(
      this.sourceKey, this.comicId, chapterId, commentId, isUp, isCancel
    );
  }

  async toggleChapterComments(): Promise<void> {
    if (!this.settings.showChapterComments) {
      return;
    }
    this.showChapterCommentsPanel = !this.showChapterCommentsPanel;
    if (this.showChapterCommentsPanel) {
      await this.loadChapterComments();
    }
  }

  async loadChapterComments(replyTo?: string): Promise<void> {
    this.chapterCommentsLoading = true;
    try {
      let chapterId = this.getCurrentChapterId();
      let result = await DataService.getInstance().loadChapterComments(
        this.sourceKey, this.comicId, chapterId, 1, replyTo
      );
      this.chapterComments = result.comments;
    } finally {
      this.chapterCommentsLoading = false;
    }
  }

  async addCurrentImageFavorite(): Promise<void> {
    let imageKey = this.getCurrentImageKey();
    if (imageKey.length === 0) {
      return;
    }
    let chapter = this.chapters[this.currentChapter];
    let imageIndex: number = this.getPrimaryImageIndex();
    await DataService.getInstance().addImageFavorite({
      comicId: this.comicId,
      sourceKey: this.sourceKey,
      title: this.comicName,
      author: this.author,
      tags: this.tagsList,
      ep: this.currentChapter + 1,
      page: imageIndex + 1,
      imageKey: imageKey,
      eid: chapter?.id ?? '',
      epName: chapter?.name ?? '',
      maxPage: this.totalPages
    });
  }

  private debouncedUpdateHistory(): void {
    if (this.historyTimer !== -1) {
      clearTimeout(this.historyTimer);
    }
    this.historyTimer = setTimeout(() => {
      this.updateHistory();
      this.historyTimer = -1;
    }, 2000) as number;
  }

  updateHistory(): void {
    let imagePage: number = this.isGalleryMode() && this.getImagesPerPage() > 1 ?
      this.getPrimaryImageIndex() + 1 : this.currentPage + 1;
    this.bridge.onUpdateHistory(
      this.comicId,
      this.sourceKey,
      this.currentChapter + 1,
      imagePage
    );
  }

  cancelHistoryTimer(): void {
    if (this.historyTimer !== -1) {
      clearTimeout(this.historyTimer);
      this.historyTimer = -1;
    }
    this.stopAutoPageTurning();
  }

  getCurrentChapterName(): string {
    if (this.chapters.length === 0) {
      return '';
    }
    return this.chapters[this.currentChapter].name;
  }

  getPageIndicator(): string {
    if (!this.settings.showPageNumberInReader) {
      return '';
    }
    return (this.currentPage + 1).toString() + ' / ' + this.totalPages.toString();
  }
}

interface ReaderLoadDataResult {
  comicName?: string;
  author?: string;
  tags?: string;
  chapters?: ChapterInfo[];
  error?: string;
}

interface ReaderChapterImagesResult {
  images?: string[];
  error?: string;
}

interface ReaderSettingsJson {
  readerMode?: string;
  enableTapToTurnPages?: boolean;
  reverseTapToTurnPages?: boolean;
  enablePageAnimation?: boolean;
  showPageNumberInReader?: boolean;
  enableClockAndBatteryInfoInReader?: boolean;
  enableDoubleTapToZoom?: boolean;
  enableLongPressToZoom?: boolean;
  autoPageTurningInterval?: number;
  showChapterComments?: boolean;
  limitImageWidth?: boolean;
  preloadImageCount?: number;
  enableTurnPageByVolumeKey?: boolean;
  quickCollectImage?: string;
  readerScreenPicNumberForLandscape?: number;
  readerScreenPicNumberForPortrait?: number;
  showSingleImageOnFirstPage?: boolean;
  enableCustomImageProcessing?: boolean;
  showChapterCommentsAtEnd?: boolean;
  readerScrollSpeed?: number;
  longPressZoomPosition?: string;
  showSystemStatusBar?: boolean;
  comicSpecificEnabled?: boolean;
  landscape?: boolean;
}
