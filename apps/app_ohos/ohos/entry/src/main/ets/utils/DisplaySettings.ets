import { DataService, ComicTileStatusData, ComicHistoryStatus } from '../service/DataService';
import { Comic } from '../model/Comic';

export class DisplaySettings {
  private static instance: DisplaySettings | null = null;
  comicDisplayMode: string = 'detailed';
  comicTileScale: number = 1;
  comicListDisplayMode: string = 'paging';
  showFavoriteStatusOnTile: boolean = true;
  showHistoryStatusOnTile: boolean = false;
  private favoriteKeySet: Set<string> = new Set();
  private historyMap: Map<string, ComicHistoryStatus> = new Map();
  private loaded: boolean = false;

  static getInstance(): DisplaySettings {
    if (DisplaySettings.instance === null) {
      DisplaySettings.instance = new DisplaySettings();
    }
    return DisplaySettings.instance;
  }

  async refresh(): Promise<void> {
    let service = DataService.getInstance();
    let settings = await service.getSettings();
    this.comicDisplayMode = settings['comicDisplayMode']?.toString() ?? 'detailed';
    let scale = settings['comicTileScale'];
    this.comicTileScale = typeof scale === 'number' ? scale :
      parseFloat(scale?.toString() ?? '1') || 1;
    this.comicListDisplayMode = settings['comicListDisplayMode']?.toString() ?? 'paging';
    this.showFavoriteStatusOnTile = settings['showFavoriteStatusOnTile'] === true;
    this.showHistoryStatusOnTile = settings['showHistoryStatusOnTile'] === true;
    if (this.showFavoriteStatusOnTile || this.showHistoryStatusOnTile) {
      let statuses: ComicTileStatusData = await service.getComicTileStatuses();
      this.favoriteKeySet = new Set(statuses.favoriteKeys);
      this.historyMap = new Map();
      let historyObj = statuses.history;
      let keys = Object.keys(historyObj);
      for (let i = 0; i < keys.length; i++) {
        let key = keys[i];
        this.historyMap.set(key, historyObj[key]);
      }
    }
    this.loaded = true;
  }

  isContinuousList(): boolean {
    return this.comicListDisplayMode === 'Continuous';
  }

  comicKey(comic: Comic): string {
    return `${comic.sourceKey}:${comic.id}`;
  }

  isFavorite(comic: Comic): boolean {
    if (!this.showFavoriteStatusOnTile) {
      return false;
    }
    return this.favoriteKeySet.has(this.comicKey(comic));
  }

  getHistory(comic: Comic): ComicHistoryStatus | null {
    if (!this.showHistoryStatusOnTile) {
      return null;
    }
    return this.historyMap.get(this.comicKey(comic)) ?? null;
  }

  get isReady(): boolean {
    return this.loaded;
  }
}
