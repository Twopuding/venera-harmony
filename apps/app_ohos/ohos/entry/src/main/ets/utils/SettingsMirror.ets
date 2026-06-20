import { DataService } from '../service/DataService';

export const SETTINGS_CACHE_KEY: string = 'settingsCacheJson';

const MIRRORED_BOOL_KEYS: string[] = [
  'authorizationRequired',
  'useFaceAuth',
  'useFingerprintAuth'
];

export class SettingsMirror {
  private static storageKey(settingKey: string): string {
    return `settingMirror_${settingKey}`;
  }

  static hasKey(settings: Record<string, Object>, settingKey: string): boolean {
    return settings[settingKey] !== undefined && settings[settingKey] !== null;
  }

  static setBool(settingKey: string, value: boolean): void {
    AppStorage.setOrCreate<boolean>(SettingsMirror.storageKey(settingKey), value);
  }

  static getBool(settingKey: string): boolean | undefined {
    return AppStorage.get<boolean>(SettingsMirror.storageKey(settingKey));
  }

  static resolveBool(settings: Record<string, Object>, settingKey: string): boolean {
    if (SettingsMirror.hasKey(settings, settingKey)) {
      return DataService.settingIsTrue(settings, settingKey);
    }
    let mirrored: boolean | undefined = SettingsMirror.getBool(settingKey);
    if (mirrored !== undefined) {
      return mirrored;
    }
    return false;
  }

  static syncBoolFromSettings(settings: Record<string, Object>, settingKey: string): void {
    if (SettingsMirror.hasKey(settings, settingKey)) {
      SettingsMirror.setBool(settingKey, DataService.settingIsTrue(settings, settingKey));
    }
  }

  static syncFromSettings(settings: Record<string, Object>): void {
    for (let i: number = 0; i < MIRRORED_BOOL_KEYS.length; i++) {
      SettingsMirror.syncBoolFromSettings(settings, MIRRORED_BOOL_KEYS[i]);
    }
  }

  static readCache(): Record<string, Object> {
    let cached: string | undefined = AppStorage.get<string>(SETTINGS_CACHE_KEY);
    if (cached === undefined || cached.length <= 2) {
      return {};
    }
    try {
      return JSON.parse(cached) as Record<string, Object>;
    } catch (e) {
      return {};
    }
  }

  static writeCache(settings: Record<string, Object>): void {
    if (Object.keys(settings).length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>(SETTINGS_CACHE_KEY, JSON.stringify(settings));
  }

  static shouldPersistCache(settings: Record<string, Object>): boolean {
    if (Object.keys(settings).length === 0) {
      return false;
    }
    if (SettingsMirror.hasKey(settings, 'authorizationRequired')) {
      return true;
    }
    return Object.keys(settings).length >= 15;
  }

  static applyPatch(settingKey: string, value: Object | null): void {
    let settings: Record<string, Object> = SettingsMirror.readCache();
    settings[settingKey] = value as Object;
    SettingsMirror.writeCache(settings);
    if (typeof value === 'boolean') {
      SettingsMirror.setBool(settingKey, value);
    } else if (value === 1 || value === 0) {
      SettingsMirror.setBool(settingKey, value === 1);
    }
  }

  static mergeFromCache(settings: Record<string, Object>): Record<string, Object> {
    let parsed: Record<string, Object> = SettingsMirror.readCache();
    if (Object.keys(parsed).length === 0) {
      return settings;
    }
    if (Object.keys(settings).length === 0) {
      return parsed;
    }
    let merged: Record<string, Object> = {};
    let cacheKeys: string[] = Object.keys(parsed);
    for (let i: number = 0; i < cacheKeys.length; i++) {
      let k: string = cacheKeys[i];
      merged[k] = parsed[k];
    }
    let settingKeys: string[] = Object.keys(settings);
    for (let i: number = 0; i < settingKeys.length; i++) {
      let k: string = settingKeys[i];
      merged[k] = settings[k];
    }
    return merged;
  }
}
