import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';
import { DataService } from '../service/DataService';

export class TranslationUtil {
  static readonly I18N_TICK: string = 'i18nTick';

  private static allLocales: Map<string, Map<string, string>> | null = null;
  private static currentLocaleKey: string = '';
  private static loadPromise: Promise<void> | null = null;

  static async ensureLoaded(context: Context): Promise<void> {
    if (TranslationUtil.loadPromise !== null) {
      return TranslationUtil.loadPromise;
    }
    TranslationUtil.loadPromise = TranslationUtil.doLoad(context);
    return TranslationUtil.loadPromise;
  }

  private static async doLoad(context: Context): Promise<void> {
    try {
      if (TranslationUtil.allLocales === null) {
        let raw: Uint8Array = await context.resourceManager.getRawFileContent('translation.json');
        let decoder: util.TextDecoder = new util.TextDecoder('utf-8');
        let text: string = decoder.decodeWithStream(raw);
        let parsed = JSON.parse(text) as Record<string, Record<string, string>>;
        let locales: Map<string, Map<string, string>> = new Map();
        let localeKeys: string[] = Object.keys(parsed);
        for (let i: number = 0; i < localeKeys.length; i++) {
          let localeKey: string = localeKeys[i];
          let bucket: Record<string, string> = parsed[localeKey];
          let translations: Map<string, string> = new Map();
          let keys: string[] = Object.keys(bucket);
          for (let j: number = 0; j < keys.length; j++) {
            let k: string = keys[j];
            translations.set(k, bucket[k]);
          }
          locales.set(localeKey, translations);
        }
        TranslationUtil.allLocales = locales;
      }
      TranslationUtil.currentLocaleKey = await TranslationUtil.resolveLocaleKey();
      TranslationUtil.bumpTick();
    } catch (e) {
      TranslationUtil.allLocales = new Map();
      TranslationUtil.currentLocaleKey = '';
    }
  }

  static async reloadLocale(context: Context): Promise<void> {
    if (TranslationUtil.allLocales === null) {
      await TranslationUtil.ensureLoaded(context);
      return;
    }
    TranslationUtil.currentLocaleKey = await TranslationUtil.resolveLocaleKey();
    TranslationUtil.bumpTick();
  }

  private static bumpTick(): void {
    let current: number = AppStorage.get<number>(TranslationUtil.I18N_TICK) ?? 0;
    AppStorage.setOrCreate(TranslationUtil.I18N_TICK, current + 1);
  }

  private static async resolveLocaleKey(): Promise<string> {
    try {
      let settings: Record<string, Object> = await DataService.getInstance().getSettings();
      let lang: string = settings['language']?.toString() ?? 'system';
      if (lang !== 'system') {
        return lang.replace('-', '_');
      }
    } catch (e) {
      // fall through to system locale
    }
    return TranslationUtil.systemLocaleKey();
  }

  private static systemLocaleKey(): string {
    try {
      let locale: Intl.Locale = i18n.System.getSystemLocaleInstance();
      if (locale.language === 'zh') {
        if (locale.script === 'Hant' || locale.region === 'TW' || locale.region === 'HK') {
          return 'zh_TW';
        }
        return 'zh_CN';
      }
      if (locale.language === 'en') {
        return 'en_US';
      }
    } catch (e) {
      // fall through
    }
    return 'en_US';
  }

  static tl(key: string, context?: Context): string {
    if (TranslationUtil.allLocales === null && context !== undefined) {
      TranslationUtil.ensureLoaded(context);
    }
    if (TranslationUtil.currentLocaleKey.length === 0) {
      return key;
    }
    let bucket: Map<string, string> | undefined =
      TranslationUtil.allLocales?.get(TranslationUtil.currentLocaleKey);
    if (bucket === undefined && TranslationUtil.currentLocaleKey === 'en_US') {
      return key;
    }
    let value: string | undefined = bucket?.get(key);
    return value !== undefined ? value : key;
  }

  static tlParam(key: string, paramKey: string, value: string | number): string {
    let text: string = TranslationUtil.tl(key);
    return text.replace('@' + paramKey, value.toString());
  }
}
