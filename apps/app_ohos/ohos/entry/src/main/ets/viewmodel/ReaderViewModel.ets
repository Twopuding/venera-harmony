import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReaderBridge } from '../bridge/ReaderBridge';

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
  settings: ReaderSettings = { readerMode: ReaderMode.GALLERY_LR, landscape: false };
  private historyTimer: number = -1;
  private bridge: ReaderBridge = ReaderBridge.getInstance();

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
    hilog.info(0x0000, 'ReaderVM', 'Loading chapter: ' + chapter.id);
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
        hilog.error(0x0000, 'ReaderVM', 'Chapter images error: ' + parsed.error);
        this.onImagesLoaded([]);
        return;
      }
      this.onImagesLoaded(parsed.images ?? []);
    } catch (e) {
      hilog.error(0x0000, 'ReaderVM', 'Failed to load chapter images');
      this.onImagesLoaded([]);
    }
  }

  onImagesLoaded(imageUrls: string[]): void {
    this.images = imageUrls;
    this.totalPages = imageUrls.length;
    this.isLoading = false;
  }

  setCurrentPage(page: number): void {
    if (page >= 0 && page < this.totalPages) {
      this.currentPage = page;
      this.debouncedUpdateHistory();
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
    this.bridge.onUpdateHistory(
      this.comicId,
      this.sourceKey,
      this.currentChapter + 1,
      this.currentPage + 1
    );
    hilog.info(0x0000, 'ReaderVM',
      'Update history: comic=' + this.comicId +
      ' chapter=' + (this.currentChapter + 1).toString() +
      ' page=' + (this.currentPage + 1).toString());
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
