import { DataService, ComicSourceInfo } from '../../service/DataService';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  SettingsSection,
  SwitchSettingTile,
  SelectSettingTile,
  SliderSettingTile,
  ActionSettingTile
} from '../../components/SettingsList';
import { MultiPagesFilterDialog, PageOptionsBuilder } from '../../components/MultiPagesFilter';
import { SettingsOptions } from '../../utils/SettingsOptions';
import { BlockedWordsUtil } from '../../utils/BlockedWordsUtil';
import { ContentDialogCustom } from '../../components/ContentDialog';
import { PlatformUtil } from '../../utils/PlatformUtil';
import { PlatformBiometricAuth } from '../../bridge/PlatformBridge';
import { SettingsMirror } from '../../utils/SettingsMirror';
import { PROJECT_REPO_URL } from '../../utils/SettingsConstants';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';

interface SheetInfo {
  title: string;
  action: () => void;
}

const SETTINGS_LOG_DOMAIN: number = 0x0000;
const SETTINGS_LOG_TAG: string = 'SettingsCategory';

@Component
export struct SettingsCategoryContent {
  @Prop categoryIndex: number = 0
  @Prop @Watch('onPageShowRefresh') pageShowVersion: number = 0
  @State settings: Record<string, Object> = {}
  @State syncMessage: string = ''
  @State isSyncing: boolean = false
  @State showBlockingWordsDialog: boolean = false
  @State showCommentBlockingDialog: boolean = false
  @State blockingWordsText: string = ''
  @State blockingCommentWordsText: string = ''
  @State showWebdavDialog: boolean = false
  @State showDnsDialog: boolean = false
  @State webdavUrl: string = ''
  @State webdavUser: string = ''
  @State webdavPass: string = ''
  @State dnsOverridesText: string = ''
  @State comicSources: ComicSourceInfo[] = []
  @State showExplorePagesDialog: boolean = false
  @State showCategoryPagesDialog: boolean = false
  @State showNetworkFavPagesDialog: boolean = false
  @State showSearchSourcesDialog: boolean = false
  @State showDisableSyncDialog: boolean = false
  @State showJsDialog: boolean = false
  @State disableSyncFieldsText: string = ''
  @State jsCodeText: string = ''
  @State jsResultText: string = ''
  @State favoriteFolders: string[] = []
  @State showCustomImageDialog: boolean = false
  @State customImageText: string = ''
  @State appVersion: string = ''
  @State settingsLoaded: boolean = false
  @StorageLink('settingsVersion') @Watch('onSettingsVersionChanged') settingsVersion: number = 0
  @StorageLink('settingMirror_authorizationRequired') authorizationRequiredOn: boolean = false
  @StorageLink('settingMirror_useFaceAuth') useFaceAuthOn: boolean = false
  @StorageLink('settingMirror_useFingerprintAuth') useFingerprintAuthOn: boolean = false
  private settingSaveInFlight: boolean = false
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.appVersion = PlatformUtil.getAppVersionName(this.context);
    this.loadSettings();
    DataService.getInstance().getAppInfo().then((info) => {
      let version = info.version ?? '';
      if (version.length > 0) {
        this.appVersion = version;
      }
    }).catch(() => {
    });
  }

  private async loadSettings(): Promise<void> {
    let results = await Promise.all([
      DataService.getInstance().getSettings(),
      DataService.getInstance().getComicSources()
    ]);
    this.settings = results[0];
    this.comicSources = results[1];
    this.settingsLoaded = true;
  }

  onSettingsVersionChanged(): void {
    if (this.settingSaveInFlight) {
      return;
    }
    this.loadSettings();
  }

  onPageShowRefresh(): void {
    if (this.pageShowVersion > 0) {
      this.loadSettings();
    }
  }

  private getStringArray(key: string): string[] {
    let v = this.settings[key];
    if (Array.isArray(v)) {
      return v as string[];
    }
    return [];
  }

  private pagesSummary(keys: string[]): string {
    if (keys.length === 0) {
      return this.tl('None');
    }
    return `${keys.length}`;
  }

  private async saveStringArray(key: string, keys: string[]): Promise<void> {
    await this.setValue(key, keys);
  }

  private isContinuousReaderMode(): boolean {
    return this.getString('readerMode', 'galleryLeftToRight').startsWith('continuous');
  }

  private async showQuickFavoriteSelect(): Promise<void> {
    this.favoriteFolders = await DataService.getInstance().getFavoriteFolders();
    let sheets: Array<SheetInfo> = [];
    for (let i: number = 0; i < this.favoriteFolders.length; i++) {
      let folder: string = this.favoriteFolders[i];
      sheets.push({
        title: folder,
        action: () => {
          this.setValue('quickFavorite', folder);
        }
      });
    }
    ActionSheet.show({
      title: this.tl('Quick Favorite'),
      message: '',
      sheets: sheets
    });
  }

  private openDisableSyncDialog(): void {
    this.disableSyncFieldsText = this.getString('disableSyncFields', '');
    this.showDisableSyncDialog = true;
  }

  private async saveDisableSyncFields(): Promise<void> {
    await this.setValue('disableSyncFields', this.disableSyncFieldsText);
    this.showDisableSyncDialog = false;
  }

  private async exportData(): Promise<void> {
    let path: string | null = await DataService.getInstance().exportAppData();
    if (path === null || path.length === 0) {
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    let saved: boolean = await PlatformUtil.saveFile(this.context, path, 'data.venera');
    promptAction.showToast({
      message: saved ? this.tl('Export complete') : this.tl('Failed')
    });
  }

  private async importData(): Promise<void> {
    let path: string = await PlatformUtil.pickFile(this.context);
    if (path.length === 0) {
      return;
    }
    let ok: boolean = await DataService.getInstance().importAppData(path);
    promptAction.showToast({
      message: ok ? this.tl('Import complete') : this.tl('Failed')
    });
    if (ok) {
      await this.loadSettings();
    }
  }

  private async runJsEvaluator(): Promise<void> {
    this.jsResultText = await DataService.getInstance().runJsCode(this.jsCodeText);
  }

  private async removeInvalidFavorites(): Promise<void> {
    let count: number = await DataService.getInstance().removeInvalidFavorites();
    promptAction.showToast({
      message: TranslationUtil.tlParam('Deleted @a favorite items', 'a', count)
    });
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private getString(key: string, fallback: string = ''): string {
    let v = this.settings[key];
    return v !== undefined && v !== null ? v.toString() : fallback;
  }

  private getBool(key: string): boolean {
    return SettingsMirror.resolveBool(this.settings, key);
  }

  private applyDefaultBiometricSettings(next: Record<string, Object>): void {
    if (PlatformBiometricAuth.canCheckFace()) {
      next['useFaceAuth'] = true;
      next['useFingerprintAuth'] = false;
    } else if (PlatformBiometricAuth.canCheckFingerprint()) {
      next['useFaceAuth'] = false;
      next['useFingerprintAuth'] = true;
    }
  }

  private async persistBiometricDefaults(): Promise<boolean> {
    let ok: boolean = true;
    if (PlatformBiometricAuth.canCheckFace()) {
      ok = await DataService.getInstance().setSetting('useFaceAuth', true) && ok;
      ok = await DataService.getInstance().setSetting('useFingerprintAuth', false) && ok;
    } else if (PlatformBiometricAuth.canCheckFingerprint()) {
      ok = await DataService.getInstance().setSetting('useFaceAuth', false) && ok;
      ok = await DataService.getInstance().setSetting('useFingerprintAuth', true) && ok;
    }
    return ok;
  }

  private getNumber(key: string, fallback: number): number {
    let v = this.settings[key];
    if (typeof v === 'number') {
      return v;
    }
    if (v !== undefined && v !== null) {
      let n = parseFloat(v.toString());
      return isNaN(n) ? fallback : n;
    }
    return fallback;
  }

  private async setValue(key: string, value: Object | null): Promise<void> {
    if (!this.settingsLoaded) {
      return;
    }
    if (key === 'authorizationRequired' && value === true) {
      if (!PlatformBiometricAuth.canCheckBiometrics() && !PlatformBiometricAuth.isDeviceSupported()) {
        promptAction.showToast({ message: this.tl('Biometrics not supported') });
        return;
      }
    }

    let next: Record<string, Object> = {};
    let settingKeys = Object.keys(this.settings);
    for (let i: number = 0; i < settingKeys.length; i++) {
      let k = settingKeys[i];
      next[k] = this.settings[k];
    }
    next[key] = value as Object;
    if (key === 'authorizationRequired' && value === true) {
      this.applyDefaultBiometricSettings(next);
    }
    this.settings = next;
    SettingsMirror.writeCache(next);
    SettingsMirror.syncFromSettings(next);

    this.settingSaveInFlight = true;
    let ok: boolean = false;
    try {
      ok = await DataService.getInstance().setSetting(key, value);
      if (ok && key === 'authorizationRequired' && value === true) {
        ok = await this.persistBiometricDefaults();
      }
    } catch (e) {
      hilog.error(SETTINGS_LOG_DOMAIN, SETTINGS_LOG_TAG,
        'setSetting failed for %{public}s: %{public}s', key, JSON.stringify(e));
    } finally {
      this.settingSaveInFlight = false;
    }
    if (!ok) {
      await this.loadSettings();
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    SettingsMirror.writeCache(this.settings);
    SettingsMirror.syncFromSettings(this.settings);
    let reloaded: Record<string, Object> = await DataService.getInstance().getSettings();
    if (Object.keys(reloaded).length > 0) {
      this.settings = reloaded;
    }
    if (key === 'language') {
      await TranslationUtil.reloadLocale(this.context);
    }
  }

  private labelForOption(options: Map<string, string>, value: string): string {
    return SettingsOptions.labelFor(options, value, (key: string) => this.tl(key));
  }

  private showSelect(key: string, options: Map<string, string>): void {
    let keys: string[] = SettingsOptions.keys(options);
    let sheets: Array<SheetInfo> = [];
    for (let i: number = 0; i < keys.length; i++) {
      let k: string = keys[i];
      let sheet: SheetInfo = {
        title: this.labelForOption(options, k),
        action: () => {
          this.setValue(key, k);
        }
      };
      sheets.push(sheet);
    }
    ActionSheet.show({
      title: this.tl(key),
      message: '',
      sheets: sheets
    });
  }

  private async showDefaultSearchTargetSelect(): Promise<void> {
    let sources: ComicSourceInfo[] = await DataService.getInstance().getComicSources();
    let sheets: Array<SheetInfo> = [];
    sheets.push({
      title: this.tl('Aggregated'),
      action: () => {
        this.setValue('defaultSearchTarget', '_aggregated_');
      }
    });
    for (let i: number = 0; i < sources.length; i++) {
      let source: ComicSourceInfo = sources[i];
      if (source.hasSearch === true) {
        sheets.push({
          title: source.name,
          action: () => {
            this.setValue('defaultSearchTarget', source.key);
          }
        });
      }
    }
    ActionSheet.show({
      title: this.tl('Default Search Target'),
      message: '',
      sheets: sheets
    });
  }

  private openBlockingWordsDialog(): void {
    let raw = this.settings['blockedWords'];
    if (Array.isArray(raw)) {
      this.blockingWordsText = (raw as string[]).join(', ');
    } else {
      this.blockingWordsText = '';
    }
    this.showBlockingWordsDialog = true;
  }

  private openCommentBlockingDialog(): void {
    let raw = this.settings['blockedCommentWords'];
    if (Array.isArray(raw)) {
      this.blockingCommentWordsText = (raw as string[]).join(', ');
    } else {
      this.blockingCommentWordsText = '';
    }
    this.showCommentBlockingDialog = true;
  }

  private async saveBlockingWords(): Promise<void> {
    let words: string[] = this.blockingWordsText.split(',')
      .map((w: string) => w.trim())
      .filter((w: string) => w.length > 0);
    await this.setValue('blockedWords', words);
    BlockedWordsUtil.invalidate();
    this.showBlockingWordsDialog = false;
  }

  private async saveBlockingCommentWords(): Promise<void> {
    let words: string[] = this.blockingCommentWordsText.split(',')
      .map((w: string) => w.trim())
      .filter((w: string) => w.length > 0);
    await this.setValue('blockedCommentWords', words);
    this.showCommentBlockingDialog = false;
  }

  private openWebdavDialog(): void {
    let webdav = this.settings['webdav'];
    if (Array.isArray(webdav) && (webdav as Object[]).length >= 3) {
      let arr = webdav as string[];
      this.webdavUrl = arr[0] ?? '';
      this.webdavUser = arr[1] ?? '';
      this.webdavPass = arr[2] ?? '';
    }
    this.showWebdavDialog = true;
  }

  private async saveWebdavConfig(): Promise<void> {
    await this.setValue('webdav', [this.webdavUrl, this.webdavUser, this.webdavPass]);
    this.showWebdavDialog = false;
  }

  private openDnsDialog(): void {
    let dns = this.settings['dnsOverrides'];
    if (dns !== undefined && dns !== null && typeof dns === 'object') {
      let entries: string[] = [];
      let keys = Object.keys(dns as Record<string, string>);
      for (let i: number = 0; i < keys.length; i++) {
        let k = keys[i];
        entries.push(`${k}=${(dns as Record<string, string>)[k]}`);
      }
      this.dnsOverridesText = entries.join('\n');
    } else {
      this.dnsOverridesText = '';
    }
    this.showDnsDialog = true;
  }

  private async saveDnsOverrides(): Promise<void> {
    let lines: string[] = this.dnsOverridesText.split('\n');
    let map: Record<string, string> = {};
    for (let i: number = 0; i < lines.length; i++) {
      let line = lines[i].trim();
      if (line.length === 0) continue;
      let idx = line.indexOf('=');
      if (idx > 0) {
        map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
      }
    }
    await this.setValue('dnsOverrides', map);
  }

  private defaultSearchTargetLabel(): string {
    let value = this.getString('defaultSearchTarget', '_aggregated_');
    if (value === '_aggregated_') {
      return this.tl('Aggregated');
    }
    for (let i: number = 0; i < this.comicSources.length; i++) {
      if (this.comicSources[i].key === value) {
        return this.comicSources[i].name;
      }
    }
    return value;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.categoryIndex === 0) {
        Column() {
          SettingsSection({ content: this.exploreSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 1) {
        Column() {
          SettingsSection({ content: this.readingSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 2) {
        Column() {
          SettingsSection({ content: this.appearanceSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 3) {
        Column() {
          SettingsSection({ content: this.localFavoritesSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 4) {
        Column() {
          SettingsSection({
            title: this.tl('Data'),
            content: this.appDataSectionContent
          })
          if (this.syncMessage.length > 0) {
            Text(this.syncMessage)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 16, bottom: 8 })
          }
          SettingsSection({
            title: this.tl('User'),
            content: this.appUserSectionContent
          })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 5) {
        Column() {
          SettingsSection({ content: this.networkSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      } else if (this.categoryIndex === 6) {
        Column() {
          Blank().layoutWeight(2)

          this.aboutIntroBlock()

          Blank().layoutWeight(1)

          SettingsSection({ content: this.aboutSectionContent })

          Blank().layoutWeight(3)
        }
        .width('100%')
        .height('100%')
      } else {
        Column() {
          SettingsSection({ content: this.debugSectionContent })
        }
        .width('100%')
        .padding({ bottom: 24 })
      }

      this.dialogsLayer()
    }
    .width('100%')
    .height(this.categoryIndex === 6 ? '100%' : 'auto')
  }

  @LocalBuilder
  exploreSectionContent() {
          ActionSettingTile({
            title: this.tl('Explore Pages'),
            actionLabel: this.pagesSummary(this.getStringArray('explore_pages')),
            onAction: () => {
              this.showExplorePagesDialog = true;
            }
          })
          ActionSettingTile({
            title: this.tl('Category Pages'),
            actionLabel: this.pagesSummary(this.getStringArray('categories')),
            onAction: () => {
              this.showCategoryPagesDialog = true;
            }
          })
          ActionSettingTile({
            title: this.tl('Network Favorite Pages'),
            actionLabel: this.pagesSummary(this.getStringArray('favorites')),
            onAction: () => {
              this.showNetworkFavPagesDialog = true;
            }
          })
          ActionSettingTile({
            title: this.tl('Search Sources'),
            actionLabel: this.pagesSummary(this.getStringArray('searchSources')),
            onAction: () => {
              this.showSearchSourcesDialog = true;
            }
          })
          SelectSettingTile({
            title: this.tl('Display mode of comic tile'),
            valueLabel: this.labelForOption(SettingsOptions.comicDisplay(),
              this.getString('comicDisplayMode', 'detailed')),
            onTap: () => this.showSelect('comicDisplayMode', SettingsOptions.comicDisplay())
          })
          SliderSettingTile({
            title: this.tl('Size of comic tile'),
            value: this.getNumber('comicTileScale', 1),
            min: 0.5, max: 1.5, step: 0.05,
            onChange: (v: number) => this.setValue('comicTileScale', v)
          })
          SwitchSettingTile({
            title: this.tl('Show favorite status on comic tile'),
            value: this.getBool('showFavoriteStatusOnTile'),
            onChange: (v: boolean) => this.setValue('showFavoriteStatusOnTile', v)
          })
          SwitchSettingTile({
            title: this.tl('Show history on comic tile'),
            value: this.getBool('showHistoryStatusOnTile'),
            onChange: (v: boolean) => this.setValue('showHistoryStatusOnTile', v)
          })
          SwitchSettingTile({
            title: this.tl('Reverse default chapter order'),
            value: this.getBool('reverseChapterOrder'),
            onChange: (v: boolean) => this.setValue('reverseChapterOrder', v)
          })
          SelectSettingTile({
            title: this.tl('Initial Page'),
            valueLabel: this.labelForOption(SettingsOptions.initialPage(),
              this.getString('initialPage', '0')),
            onTap: () => this.showSelect('initialPage', SettingsOptions.initialPage())
          })
          SelectSettingTile({
            title: this.tl('Display mode of comic list'),
            valueLabel: this.labelForOption(SettingsOptions.comicListDisplay(),
              this.getString('comicListDisplayMode', 'paging')),
            onTap: () => this.showSelect('comicListDisplayMode', SettingsOptions.comicListDisplay())
          })
          SelectSettingTile({
            title: this.tl('Default Search Target'),
            valueLabel: this.defaultSearchTargetLabel(),
            onTap: () => this.showDefaultSearchTargetSelect()
          })
          SelectSettingTile({
            title: this.tl('Auto Language Filters'),
            valueLabel: this.labelForOption(SettingsOptions.autoAddLanguageFilter(),
              this.getString('autoAddLanguageFilter', 'none')),
            onTap: () => this.showSelect('autoAddLanguageFilter', SettingsOptions.autoAddLanguageFilter())
          })
          ActionSettingTile({
            title: this.tl('Keyword blocking'),
            actionLabel: this.tl('Edit'),
            onAction: () => {
              this.openBlockingWordsDialog();
            }
          })
          ActionSettingTile({
            title: this.tl('Comment keyword blocking'),
            actionLabel: this.tl('Edit'),
            showDivider: false,
            onAction: () => {
              this.openCommentBlockingDialog();
            }
          })
        
  }


  @LocalBuilder
  readingSectionContent() {
          SwitchSettingTile({
            title: this.tl('Tap to turn Pages'),
            value: this.getBool('enableTapToTurnPages'),
            onChange: (v: boolean) => this.setValue('enableTapToTurnPages', v)
          })
          SwitchSettingTile({
            title: this.tl('Reverse tap to turn Pages'),
            value: this.getBool('reverseTapToTurnPages'),
            onChange: (v: boolean) => this.setValue('reverseTapToTurnPages', v)
          })
          SwitchSettingTile({
            title: this.tl('Page animation'),
            value: this.getBool('enablePageAnimation'),
            onChange: (v: boolean) => this.setValue('enablePageAnimation', v)
          })
          SelectSettingTile({
            title: this.tl('Reading mode'),
            valueLabel: this.labelForOption(SettingsOptions.readerMode(),
              this.getString('readerMode', 'galleryLeftToRight')),
            onTap: () => this.showSelect('readerMode', SettingsOptions.readerMode())
          })
          SliderSettingTile({
            title: this.tl('Auto page turning interval'),
            value: this.getNumber('autoPageTurningInterval', 5),
            min: 1, max: 20, step: 1,
            onChange: (v: number) => this.setValue('autoPageTurningInterval', v)
          })
          SwitchSettingTile({
            title: this.tl('Double tap to zoom'),
            value: this.getBool('enableDoubleTapToZoom'),
            onChange: (v: boolean) => this.setValue('enableDoubleTapToZoom', v)
          })
          SwitchSettingTile({
            title: this.tl('Long press to zoom'),
            value: this.getBool('enableLongPressToZoom'),
            onChange: (v: boolean) => this.setValue('enableLongPressToZoom', v)
          })
          if (this.getBool('enableLongPressToZoom')) {
            SelectSettingTile({
              title: this.tl('Long press zoom position'),
              valueLabel: this.labelForOption(SettingsOptions.longPressZoomPosition(),
                this.getString('longPressZoomPosition', 'press')),
              onTap: () => this.showSelect('longPressZoomPosition', SettingsOptions.longPressZoomPosition())
            })
          }
          SwitchSettingTile({
            title: this.tl('Limit image width'),
            subtitle: this.tl('When using Continuous(Top to Bottom) mode'),
            value: this.getBool('limitImageWidth'),
            onChange: (v: boolean) => this.setValue('limitImageWidth', v)
          })
          SwitchSettingTile({
            title: this.tl('Turn page by volume keys'),
            value: this.getBool('enableTurnPageByVolumeKey'),
            onChange: (v: boolean) => this.setValue('enableTurnPageByVolumeKey', v)
          })
          SelectSettingTile({
            title: this.tl('Quick collect image'),
            valueLabel: this.labelForOption(SettingsOptions.quickCollectImage(),
              this.getString('quickCollectImage', 'No')),
            onTap: () => this.showSelect('quickCollectImage', SettingsOptions.quickCollectImage())
          })
          if (this.isContinuousReaderMode()) {
            SliderSettingTile({
              title: this.tl('Mouse scroll speed'),
              value: this.getNumber('readerScrollSpeed', 1),
              min: 0.5, max: 3, step: 0.1,
              onChange: (v: number) => this.setValue('readerScrollSpeed', v)
            })
            SwitchSettingTile({
              title: this.tl('Show single image on first page'),
              value: this.getBool('showSingleImageOnFirstPage'),
              onChange: (v: boolean) => this.setValue('showSingleImageOnFirstPage', v)
            })
          }
          SliderSettingTile({
            title: this.tl('Screen pic number (landscape)'),
            value: this.getNumber('readerScreenPicNumberForLandscape', 1),
            min: 1, max: 4, step: 1,
            onChange: (v: number) => this.setValue('readerScreenPicNumberForLandscape', v)
          })
          SliderSettingTile({
            title: this.tl('Screen pic number (portrait)'),
            value: this.getNumber('readerScreenPicNumberForPortrait', 1),
            min: 1, max: 4, step: 1,
            onChange: (v: number) => this.setValue('readerScreenPicNumberForPortrait', v)
          })
          SwitchSettingTile({
            title: this.tl('Display time & battery info in reader'),
            value: this.getBool('enableClockAndBatteryInfoInReader'),
            onChange: (v: boolean) => this.setValue('enableClockAndBatteryInfoInReader', v)
          })
          SwitchSettingTile({
            title: this.tl('Show system status bar'),
            value: this.getBool('showSystemStatusBar'),
            onChange: (v: boolean) => this.setValue('showSystemStatusBar', v)
          })
          SliderSettingTile({
            title: this.tl('Number of images preloaded'),
            value: this.getNumber('preloadImageCount', 4),
            min: 1, max: 16, step: 1,
            onChange: (v: number) => this.setValue('preloadImageCount', v)
          })
          SwitchSettingTile({
            title: this.tl('Show Page Number'),
            value: this.getBool('showPageNumberInReader'),
            onChange: (v: boolean) => this.setValue('showPageNumberInReader', v)
          })
          SwitchSettingTile({
            title: this.tl('Show Chapter Comments'),
            value: this.getBool('showChapterComments'),
            onChange: (v: boolean) => this.setValue('showChapterComments', v)
          })
          SwitchSettingTile({
            title: this.tl('Show chapter comments at end'),
            value: this.getBool('showChapterCommentsAtEnd'),
            onChange: (v: boolean) => this.setValue('showChapterCommentsAtEnd', v)
          })
          SwitchSettingTile({
            title: this.tl('Custom Image Processing'),
            value: this.getBool('enableCustomImageProcessing'),
            onChange: (v: boolean) => this.setValue('enableCustomImageProcessing', v)
          })
          ActionSettingTile({
            title: this.tl('Edit image processing script'),
            actionLabel: this.tl('Edit'),
            showDivider: false,
            onAction: () => {
              this.customImageText = this.getString('customImageProcessing');
              this.showCustomImageDialog = true;
            }
          })
        
  }


  @LocalBuilder
  appearanceSectionContent() {
          SelectSettingTile({
            title: this.tl('Theme Mode'),
            valueLabel: this.labelForOption(SettingsOptions.themeMode(),
              this.getString('theme_mode', 'system')),
            onTap: () => this.showSelect('theme_mode', SettingsOptions.themeMode())
          })
          SelectSettingTile({
            title: this.tl('Theme Color'),
            valueLabel: this.labelForOption(SettingsOptions.color(),
              this.getString('color', 'system')),
            showDivider: false,
            onTap: () => this.showSelect('color', SettingsOptions.color())
          })
        
  }


  @LocalBuilder
  localFavoritesSectionContent() {
          SwitchSettingTile({
            title: this.tl('Show local favorites before network favorites'),
            value: this.getBool('localFavoritesFirst'),
            onChange: (v: boolean) => this.setValue('localFavoritesFirst', v)
          })
          SwitchSettingTile({
            title: this.tl('Auto close favorite panel after operation'),
            value: this.getBool('autoCloseFavoritePanel'),
            onChange: (v: boolean) => this.setValue('autoCloseFavoritePanel', v)
          })
          SelectSettingTile({
            title: this.tl('Add new favorite to'),
            valueLabel: this.labelForOption(SettingsOptions.favoriteAddTo(),
              this.getString('newFavoriteAddTo', 'end')),
            onTap: () => this.showSelect('newFavoriteAddTo', SettingsOptions.favoriteAddTo())
          })
          SelectSettingTile({
            title: this.tl('Move favorite after reading'),
            valueLabel: this.labelForOption(SettingsOptions.moveFavoriteAfterRead(),
              this.getString('moveFavoriteAfterRead', 'none')),
            onTap: () => this.showSelect('moveFavoriteAfterRead', SettingsOptions.moveFavoriteAfterRead())
          })
          SelectSettingTile({
            title: this.tl('Quick Favorite'),
            valueLabel: this.getString('quickFavorite', ''),
            onTap: () => this.showQuickFavoriteSelect()
          })
          ActionSettingTile({
            title: this.tl('Delete all unavailable local favorite items'),
            actionLabel: this.tl('Delete'),
            onAction: () => this.removeInvalidFavorites()
          })
          SelectSettingTile({
            title: this.tl('Click favorite'),
            valueLabel: this.labelForOption(SettingsOptions.onClickFavorite(),
              this.getString('onClickFavorite', 'viewDetail')),
            showDivider: false,
            onTap: () => this.showSelect('onClickFavorite', SettingsOptions.onClickFavorite())
          })
        
  }


  @LocalBuilder
  appDataSectionContent() {
    ActionSettingTile({
      title: this.tl('Clear Cache'),
      actionLabel: this.tl('Clear'),
      onAction: async () => {
        await DataService.getInstance().clearCache();
      }
    })
    SliderSettingTile({
      title: this.tl('Cache Size'),
      value: this.getNumber('cacheSize', 2048),
      min: 256, max: 8192, step: 256,
      onChange: (v: number) => this.setValue('cacheSize', v)
    })
    ActionSettingTile({
      title: this.tl('Export Data'),
      actionLabel: this.tl('Export'),
      onAction: () => this.exportData()
    })
    ActionSettingTile({
      title: this.tl('Import Data'),
      actionLabel: this.tl('Import'),
      onAction: () => this.importData()
    })
    ActionSettingTile({
      title: this.tl('WebDAV Configuration'),
      actionLabel: this.tl('Edit'),
      onAction: () => this.openWebdavDialog()
    })
    SwitchSettingTile({
      title: this.tl('WebDAV Auto Sync'),
      value: this.getBool('webdavAutoSync'),
      onChange: (v: boolean) => this.setValue('webdavAutoSync', v)
    })
    ActionSettingTile({
      title: this.tl('Disable Sync Fields'),
      actionLabel: this.tl('Edit'),
      onAction: () => this.openDisableSyncDialog()
    })
    ActionSettingTile({
      title: this.tl('WebDAV Upload'),
      actionLabel: this.tl('Upload'),
      onAction: async () => {
        this.isSyncing = true;
        this.syncMessage = '';
        this.syncMessage = await DataService.getInstance().webdavUpload() ?? this.tl('Upload complete');
        this.isSyncing = false;
      }
    })
    ActionSettingTile({
      title: this.tl('WebDAV Download'),
      actionLabel: this.tl('Download'),
      onAction: async () => {
        this.isSyncing = true;
        this.syncMessage = '';
        this.syncMessage = await DataService.getInstance().webdavDownload() ?? this.tl('Download complete');
        this.isSyncing = false;
      }
    })
    ActionSettingTile({
      title: this.tl('Comic Source'),
      actionLabel: this.tl('Open'),
      showDivider: false,
      onAction: () => RouterUtil.openComicSource()
    })
  }

  @LocalBuilder
  appUserSectionContent() {
    SelectSettingTile({
      title: this.tl('Language'),
      valueLabel: this.labelForOption(SettingsOptions.language(),
        this.getString('language', 'system')),
      onTap: () => this.showSelect('language', SettingsOptions.language())
    })
    SwitchSettingTile({
      title: this.tl('Authorization Required'),
      value: this.authorizationRequiredOn,
      onChange: (v: boolean) => this.setValue('authorizationRequired', v)
    })
    if (this.authorizationRequiredOn) {
      if (PlatformBiometricAuth.canCheckFace()) {
        SwitchSettingTile({
          title: this.tl('Face Recognition'),
          value: this.useFaceAuthOn,
          onChange: async (v: boolean) => {
            await this.setValue('useFaceAuth', v);
            if (v) {
              await this.setValue('useFingerprintAuth', false);
            }
          }
        })
      }
      if (PlatformBiometricAuth.canCheckFingerprint()) {
        SwitchSettingTile({
          title: this.tl('Fingerprint Recognition'),
          value: this.useFingerprintAuthOn,
          showDivider: false,
          onChange: async (v: boolean) => {
            await this.setValue('useFingerprintAuth', v);
            if (v) {
              await this.setValue('useFaceAuth', false);
            }
          }
        })
      }
    }
  }

  @LocalBuilder
  networkSectionContent() {
    SelectSettingTile({
      title: this.tl('Proxy'),
      valueLabel: this.labelForOption(SettingsOptions.proxy(),
        this.getString('proxy', 'direct')),
      onTap: () => this.showSelect('proxy', SettingsOptions.proxy())
    })
    SliderSettingTile({
      title: this.tl('Download Threads'),
      value: this.getNumber('downloadThreads', 4),
      min: 1, max: 16, step: 1,
      onChange: (v: number) => this.setValue('downloadThreads', v)
    })
    SwitchSettingTile({
      title: this.tl('Enable DNS Overrides'),
      value: this.getBool('enableDnsOverrides'),
      onChange: (v: boolean) => this.setValue('enableDnsOverrides', v)
    })
    SwitchSettingTile({
      title: this.tl('SNI'),
      value: this.getBool('sni'),
      onChange: (v: boolean) => this.setValue('sni', v)
    })
    ActionSettingTile({
      title: this.tl('DNS Overrides'),
      actionLabel: this.tl('Edit'),
      showDivider: false,
      onAction: () => this.openDnsDialog()
    })
  }

  @LocalBuilder
  aboutIntroBlock() {
    Column() {
      Image($r('app.media.icon'))
        .width(80)
        .height(80)
        .borderRadius(16)
        .margin({ bottom: 12 })
      Text('Venera')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 4 })
      Text(`V${this.appVersion}`)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })
      Text(this.tl('Venera is a free and open-source app for comic reading.'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width('90%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @LocalBuilder
  aboutSectionContent() {
    SwitchSettingTile({
      title: this.tl('Check for updates on startup'),
      value: this.getBool('checkUpdateOnStart'),
      onChange: (v: boolean) => this.setValue('checkUpdateOnStart', v)
    })
    ActionSettingTile({
      title: 'Github',
      actionLabel: this.tl('Open'),
      showDivider: false,
      onAction: () => RouterUtil.launchUrl(PROJECT_REPO_URL)
    })
  }

  @LocalBuilder
  debugSectionContent() {
    SwitchSettingTile({
      title: 'Native HDS UI',
      value: this.getBool('useNativeUi'),
      onChange: (v: boolean) => this.setValue('useNativeUi', v)
    })
    ActionSettingTile({
      title: this.tl('Reload Configs'),
      actionLabel: this.tl('Reload'),
      onAction: async () => {
        await DataService.getInstance().reloadJsEngine();
      }
    })
    ActionSettingTile({
      title: this.tl('Logs'),
      actionLabel: this.tl('Open'),
      onAction: () => RouterUtil.openLogs()
    })
    ActionSettingTile({
      title: this.tl('JS Evaluator'),
      actionLabel: this.tl('Open'),
      onAction: () => {
        this.jsResultText = '';
        this.showJsDialog = true;
      }
    })
    SwitchSettingTile({
      title: this.tl('Ignore Certificate Errors'),
      value: this.getBool('ignoreBadCertificate'),
      showDivider: false,
      onChange: (v: boolean) => this.setValue('ignoreBadCertificate', v)
    })
  }

  @Builder
  webdavDialogContent() {
    Column() {
      TextInput({ placeholder: 'URL', text: this.webdavUrl })
        .width('100%')
        .margin({ bottom: 8 })
        .onChange((v: string) => { this.webdavUrl = v; })
      TextInput({ placeholder: 'Username', text: this.webdavUser })
        .width('100%')
        .margin({ bottom: 8 })
        .onChange((v: string) => { this.webdavUser = v; })
      TextInput({ placeholder: 'Password', text: this.webdavPass })
        .width('100%')
        .onChange((v: string) => { this.webdavPass = v; })
    }
  }

  @Builder
  dnsDialogContent() {
    TextArea({ text: this.dnsOverridesText, placeholder: 'host=ip\nhost2=ip2' })
      .width('100%')
      .height(120)
      .onChange((v: string) => { this.dnsOverridesText = v; })
  }

  @Builder
  disableSyncDialogContent() {
    TextArea({ text: this.disableSyncFieldsText, placeholder: 'field1, field2' })
      .width('100%')
      .height(120)
      .onChange((v: string) => {
        this.disableSyncFieldsText = v;
      })
  }

  @Builder
  disableSyncDialogActions() {
    Button(this.tl('Cancel'))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showDisableSyncDialog = false;
      })
    Button(this.tl('Save'))
      .margin({ left: 8 })
      .onClick(() => this.saveDisableSyncFields())
  }

  @Builder
  jsDialogContent() {
    Column() {
      TextArea({ text: this.jsCodeText, placeholder: 'JavaScript code' })
        .width('100%')
        .height(100)
        .onChange((v: string) => {
          this.jsCodeText = v;
        })
      if (this.jsResultText.length > 0) {
        Text(this.jsResultText)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ top: 8 })
      }
    }
    .width('100%')
  }

  @Builder
  jsDialogActions() {
    Button(this.tl('Cancel'))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showJsDialog = false;
      })
    Button(this.tl('Run'))
      .margin({ left: 8 })
      .onClick(() => this.runJsEvaluator())
  }

  @Builder
  customImageDialogContent() {
    TextArea({ text: this.customImageText, placeholder: 'function process(image) { return image; }' })
      .width('100%')
      .height(160)
      .onChange((v: string) => {
        this.customImageText = v;
      })
  }

  @Builder
  customImageDialogActions() {
    Button(this.tl('Cancel'))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showCustomImageDialog = false;
      })
    Button(this.tl('Save'))
      .margin({ left: 8 })
      .onClick(async () => {
        await this.setValue('customImageProcessing', this.customImageText);
        this.showCustomImageDialog = false;
      })
  }

  @Builder
  dialogsLayer() {
    ContentDialogCustom({
      show: this.showBlockingWordsDialog,
      title: this.tl('Keyword blocking'),
      content: () => {
        TextArea({ text: this.blockingWordsText, placeholder: 'word1, word2' })
          .width('100%')
          .height(120)
          .onChange((v: string) => {
            this.blockingWordsText = v;
          })
      },
      actions: () => {
        Button(this.tl('Cancel'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showBlockingWordsDialog = false;
          })
        Button(this.tl('Save'))
          .margin({ left: 8 })
          .onClick(() => this.saveBlockingWords())
      },
      onClose: () => {
        this.showBlockingWordsDialog = false;
      }
    })

    ContentDialogCustom({
      show: this.showCommentBlockingDialog,
      title: this.tl('Comment keyword blocking'),
      content: () => {
        TextArea({ text: this.blockingCommentWordsText, placeholder: 'word1, word2' })
          .width('100%')
          .height(120)
          .onChange((v: string) => {
            this.blockingCommentWordsText = v;
          })
      },
      actions: () => {
        Button(this.tl('Cancel'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showCommentBlockingDialog = false;
          })
        Button(this.tl('Save'))
          .margin({ left: 8 })
          .onClick(() => this.saveBlockingCommentWords())
      },
      onClose: () => {
        this.showCommentBlockingDialog = false;
      }
    })

    ContentDialogCustom({
      show: this.showWebdavDialog,
      title: this.tl('WebDAV Configuration'),
      content: this.webdavDialogContent,
      actions: () => {
        Button(this.tl('Cancel'))
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.showWebdavDialog = false; })
        Button(this.tl('Save'))
          .margin({ left: 8 })
          .onClick(() => this.saveWebdavConfig())
      },
      onClose: () => { this.showWebdavDialog = false; }
    })

    ContentDialogCustom({
      show: this.showDnsDialog,
      title: this.tl('DNS Overrides'),
      content: this.dnsDialogContent,
      actions: () => {
        Button(this.tl('Cancel'))
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.showDnsDialog = false; })
        Button(this.tl('Save'))
          .margin({ left: 8 })
          .onClick(async () => {
            await this.saveDnsOverrides();
            this.showDnsDialog = false;
          })
      },
      onClose: () => { this.showDnsDialog = false; }
    })

    MultiPagesFilterDialog({
      show: this.showExplorePagesDialog,
      title: this.tl('Explore Pages'),
      options: PageOptionsBuilder.explorePages(this.comicSources),
      selectedKeys: this.getStringArray('explore_pages'),
      onClose: () => {
        this.showExplorePagesDialog = false;
      },
      onSave: (keys: string[]) => {
        this.saveStringArray('explore_pages', keys).then(() => {
          this.showExplorePagesDialog = false;
        });
      }
    })

    MultiPagesFilterDialog({
      show: this.showCategoryPagesDialog,
      title: this.tl('Category Pages'),
      options: PageOptionsBuilder.categoryPages(this.comicSources),
      selectedKeys: this.getStringArray('categories'),
      onClose: () => {
        this.showCategoryPagesDialog = false;
      },
      onSave: (keys: string[]) => {
        this.saveStringArray('categories', keys).then(() => {
          this.showCategoryPagesDialog = false;
        });
      }
    })

    MultiPagesFilterDialog({
      show: this.showNetworkFavPagesDialog,
      title: this.tl('Network Favorite Pages'),
      options: PageOptionsBuilder.networkFavoritePages(this.comicSources),
      selectedKeys: this.getStringArray('favorites'),
      onClose: () => {
        this.showNetworkFavPagesDialog = false;
      },
      onSave: (keys: string[]) => {
        this.saveStringArray('favorites', keys).then(() => {
          this.showNetworkFavPagesDialog = false;
        });
      }
    })

    MultiPagesFilterDialog({
      show: this.showSearchSourcesDialog,
      title: this.tl('Search Sources'),
      options: PageOptionsBuilder.searchSources(this.comicSources),
      selectedKeys: this.getStringArray('searchSources'),
      onClose: () => {
        this.showSearchSourcesDialog = false;
      },
      onSave: (keys: string[]) => {
        this.saveStringArray('searchSources', keys).then(() => {
          this.showSearchSourcesDialog = false;
        });
      }
    })

    ContentDialogCustom({
      show: this.showDisableSyncDialog,
      title: this.tl('Disable Sync Fields'),
      content: this.disableSyncDialogContent,
      actions: this.disableSyncDialogActions,
      onClose: () => {
        this.showDisableSyncDialog = false;
      }
    })

    ContentDialogCustom({
      show: this.showJsDialog,
      title: this.tl('JS Evaluator'),
      content: this.jsDialogContent,
      actions: this.jsDialogActions,
      onClose: () => {
        this.showJsDialog = false;
      }
    })

    ContentDialogCustom({
      show: this.showCustomImageDialog,
      title: this.tl('Custom Image Processing'),
      content: this.customImageDialogContent,
      actions: this.customImageDialogActions,
      onClose: () => {
        this.showCustomImageDialog = false;
      }
    })
  }
}
