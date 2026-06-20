import { Comic } from '../model/Comic';
import { DataService } from '../service/DataService';

export class BlockedWordsUtil {
  private static blockedWords: string[] = [];
  private static loaded: boolean = false;

  static async ensureLoaded(): Promise<void> {
    if (BlockedWordsUtil.loaded) {
      return;
    }
    let settings = await DataService.getInstance().getSettings();
    let raw = settings['blockedWords'];
    if (Array.isArray(raw)) {
      BlockedWordsUtil.blockedWords = raw as string[];
    } else {
      BlockedWordsUtil.blockedWords = [];
    }
    BlockedWordsUtil.loaded = true;
  }

  static invalidate(): void {
    BlockedWordsUtil.loaded = false;
  }

  static getBlockedWord(comic: Comic): string | null {
    let haystack = `${comic.title} ${comic.subtitle} ${comic.tags.join(' ')}`.toLowerCase();
    for (let i = 0; i < BlockedWordsUtil.blockedWords.length; i++) {
      let word = BlockedWordsUtil.blockedWords[i].trim().toLowerCase();
      if (word.length > 0 && haystack.indexOf(word) >= 0) {
        return BlockedWordsUtil.blockedWords[i];
      }
    }
    return null;
  }

  static filterComics(comics: Comic[]): Comic[] {
    return comics.filter((comic: Comic) => BlockedWordsUtil.getBlockedWord(comic) === null);
  }

  static async blockComic(comic: Comic): Promise<string | null> {
    let word = BlockedWordsUtil.getBlockedWord(comic);
    if (word !== null) {
      return word;
    }
    let candidate = comic.title.trim();
    if (candidate.length === 0) {
      return null;
    }
    let settings = await DataService.getInstance().getSettings();
    let raw = settings['blockedWords'];
    let words: string[] = Array.isArray(raw) ? [...(raw as string[])] : [];
    if (words.indexOf(candidate) < 0) {
      words.push(candidate);
      await DataService.getInstance().setSetting('blockedWords', words);
      BlockedWordsUtil.blockedWords = words;
      BlockedWordsUtil.loaded = true;
    }
    return candidate;
  }
}
