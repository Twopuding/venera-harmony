import { hilog } from '@kit.PerformanceAnalysisKit';
import { ImageDataSource } from './ImageDataSource';
import { ImageSizeCache } from './ImageSizeCache';

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
}

@Observed
export class ReaderViewModel {
  comicId: string = '';
  sourceKey: string = '';
  comicName: string = '';
  author: string = '';
  tags: string = '';
  chapters: ChapterInfo[] = [];
  currentPage: number = 0;
  totalPages: number = 0;
  currentChapter: number = 0;
  isLoading: boolean = false;
  isToolbarOpen: boolean = false;
  readerMode: ReaderMode = ReaderMode.GALLERY_LR;
  images: string[] = [];
  imageDataSource: ImageDataSource = new ImageDataSource([], new ImageSizeCache());
  settings: ReaderSettings = { readerMode: ReaderMode.GALLERY_LR, landscape: false };
  onChapterChanged: (() => void) | null = null;
  onPageChanged: ((page: number) => void) | null = null;
  private historyTimer: number = -1;
  private sizeCache: ImageSizeCache = new ImageSizeCache();
  private screenWidth: number = 360;

  setScreenWidth(width: number): void {
    this.screenWidth = width;
  }

  getEstimatedImageHeight(url: string): number {
    return this.sizeCache.getEstimatedHeight(url, this.screenWidth);
  }

  cacheImageSize(url: string, width: number, height: number): void {
    this.sizeCache.cacheSize(url, width, height);
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

  private toNextPageInternal(): void {
    if (this.currentPage < this.totalPages - 1) {
      this.currentPage = this.currentPage + 1;
      this.debouncedUpdateHistory();
      if (this.onPageChanged !== null) {
        this.onPageChanged(this.currentPage);
      }
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
      if (this.onPageChanged !== null) {
        this.onPageChanged(this.currentPage);
      }
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
    if (this.onChapterChanged !== null) {
      this.onChapterChanged();
    }
  }

  toggleToolbar(): void {
    this.isToolbarOpen = !this.isToolbarOpen;
  }

  loadChapterImages(): void {
    this.isLoading = true;
    const chapterId: string = this.chapters[this.currentChapter].id;
    hilog.info(0x0000, 'ReaderVM', 'Loading chapter: ' + chapterId);
  }

  onImagesLoaded(imageUrls: string[]): void {
    this.images = imageUrls;
    this.imageDataSource = new ImageDataSource(imageUrls, this.sizeCache);
    this.totalPages = imageUrls.length;
    this.isLoading = false;
  }

  setCurrentPage(page: number): void {
    if (page >= 0 && page < this.totalPages) {
      this.currentPage = page;
      this.debouncedUpdateHistory();
      if (this.onPageChanged !== null) {
        this.onPageChanged(this.currentPage);
      }
    }
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
    hilog.info(0x0000, 'ReaderVM',
      'Update history: comic=' + this.comicId +
      ' chapter=' + this.currentChapter.toString() +
      ' page=' + this.currentPage.toString());
  }

  cancelHistoryTimer(): void {
    if (this.historyTimer !== -1) {
      clearTimeout(this.historyTimer);
      this.historyTimer = -1;
    }
  }

  getCurrentChapterName(): string {
    if (this.chapters.length === 0) {
      return '';
    }
    return this.chapters[this.currentChapter].name;
  }

  getPageIndicator(): string {
    return (this.currentPage + 1).toString() + ' / ' + this.totalPages.toString();
  }
}
