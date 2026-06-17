import { DataBridge } from '../bridge/DataBridge';
import { Comic } from '../model/Comic';

export interface HistoryItem {
  id: string;
  title: string;
  subtitle: string;
  cover: string;
  ep: number;
  page: number;
  sourceKey: string;
  time: number;
  description: string;
}

export interface ExploreLoadResult {
  comics: Comic[];
  hasMore: boolean;
  error?: string;
}

export class DataService {
  private static instance: DataService | null = null;
  private bridge: DataBridge = DataBridge.getInstance();

  static getInstance(): DataService {
    if (DataService.instance === null) {
      DataService.instance = new DataService();
    }
    return DataService.instance;
  }

  async exploreLoadPage(
    sourceKey: string,
    pageTitle: string,
    page: number = 1
  ): Promise<ExploreLoadResult> {
    let raw: Object | null = await this.bridge.exploreLoadPage(sourceKey, pageTitle, page);
    return this.parseExploreResult(raw);
  }

  async getHistory(): Promise<HistoryItem[]> {
    let raw: Object | null = await this.bridge.getHistory();
    if (raw === null) {
      return [];
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      let parsed: HistoryResponse = JSON.parse(jsonStr);
      if (parsed.histories === undefined || parsed.histories === null) {
        return [];
      }
      return parsed.histories;
    } catch (e) {
      return [];
    }
  }

  async getSettings(): Promise<Record<string, Object>> {
    let raw: Object | null = await this.bridge.getSettings();
    if (raw === null) {
      return {};
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      return JSON.parse(jsonStr) as Record<string, Object>;
    } catch (e) {
      return {};
    }
  }

  async setSetting(key: string, value: Object | null): Promise<boolean> {
    let raw: Object | null = await this.bridge.setSetting(key, value);
    if (raw === null) {
      return false;
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      let parsed: SettingResult = JSON.parse(jsonStr);
      return parsed.ok === true;
    } catch (e) {
      return false;
    }
  }

  private parseExploreResult(raw: Object | null): ExploreLoadResult {
    let result: ExploreLoadResult = { comics: [], hasMore: false };
    if (raw === null) {
      result.error = 'Empty response';
      return result;
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      let parsed: ExploreRawResult = JSON.parse(jsonStr);
      if (parsed.error !== undefined && parsed.error !== null && parsed.error.length > 0) {
        result.error = parsed.error;
        return result;
      }
      if (parsed.comics !== undefined && parsed.comics !== null) {
        result.comics = parsed.comics.map((item: ComicJson) => this.toComic(item));
      }
      result.hasMore = parsed.hasMore === true;
      return result;
    } catch (e) {
      result.error = 'Failed to parse explore result';
      return result;
    }
  }

  private toComic(item: ComicJson): Comic {
    let comic: Comic = new Comic();
    comic.id = item.id ?? '';
    comic.title = item.title ?? '';
    comic.cover = item.cover ?? '';
    comic.subtitle = item.subTitle ?? item.subtitle ?? '';
    comic.tags = item.tags ?? [];
    comic.description = item.description ?? '';
    comic.sourceKey = item.sourceKey ?? '';
    comic.maxPage = item.maxPage ?? 0;
    comic.language = item.language ?? '';
    return comic;
  }
}

interface HistoryResponse {
  histories: HistoryItem[];
}

interface SettingResult {
  ok: boolean;
  error?: string;
}

interface ExploreRawResult {
  comics?: ComicJson[];
  hasMore?: boolean;
  error?: string;
}

interface ComicJson {
  id?: string;
  title?: string;
  cover?: string;
  subTitle?: string;
  subtitle?: string;
  tags?: string[];
  description?: string;
  sourceKey?: string;
  maxPage?: number;
  language?: string;
}
