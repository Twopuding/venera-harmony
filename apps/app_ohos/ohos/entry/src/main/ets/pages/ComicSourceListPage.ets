import {
  CatalogEntry,
  CatalogFetchResult,
  ComicSourceInfo,
  DataService
} from '../service/DataService';
import { ImmersivePageScaffold } from '../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../components/ImmersiveScrollTopInset';
import { LoadingIndicator } from '../components/LoadingIndicator';
import {
  ActionSettingTile,
  SettingTile
} from '../components/SettingsList';
import { HdsTheme } from '../design/HdsTheme';
import { RouterUtil } from '../navigation/RouterUtil';
import { TranslationUtil } from '../utils/TranslationUtil';
import {
  COMIC_SOURCE_HELP_URL,
  DEFAULT_COMIC_SOURCE_LIST_URL
} from '../utils/SettingsConstants';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct ComicSourceListPage {
  @State repoUrl: string = DEFAULT_COMIC_SOURCE_LIST_URL
  @State entries: CatalogEntry[] = []
  @State installedKeys: string[] = []
  @State isLoading: boolean = true
  @State urlChanged: boolean = false
  @State addingKey: string = ''
  private scroller: Scroller = new Scroller()
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.initAndLoad();
  }

  onPageShow(): void {
    this.refreshInstalledKeys();
  }

  aboutToDisappear(): void {
    this.persistRepoUrlIfNeeded();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private persistRepoUrlIfNeeded(): void {
    if (!this.urlChanged) {
      return;
    }
    DataService.getInstance().setSetting('comicSourceListUrl', this.repoUrl);
    this.urlChanged = false;
  }

  private async initAndLoad(): Promise<void> {
    let settings: Record<string, Object> = await DataService.getInstance().getSettings();
    let saved = settings['comicSourceListUrl'];
    if (saved !== undefined && saved !== null && saved.toString().length > 0) {
      this.repoUrl = saved.toString();
    } else {
      this.repoUrl = DEFAULT_COMIC_SOURCE_LIST_URL;
    }
    await this.loadCatalog();
  }

  private async refreshInstalledKeys(): Promise<void> {
    let sources: ComicSourceInfo[] = await DataService.getInstance().getComicSources();
    this.installedKeys = sources.map((s: ComicSourceInfo) => s.key);
  }

  private async loadCatalog(): Promise<void> {
    this.persistRepoUrlIfNeeded();
    let url = this.repoUrl.trim();
    if (url.length === 0) {
      this.entries = [];
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    try {
      await this.refreshInstalledKeys();
      let result: CatalogFetchResult =
        await DataService.getInstance().fetchComicSourceCatalogResult(url);
      if (result.error !== undefined && result.error.length > 0) {
        this.entries = [];
        promptAction.showToast({
          message: result.error === 'Network error'
            ? this.tl('Network error')
            : result.error
        });
      } else {
        this.entries = result.entries ?? [];
      }
    } finally {
      this.isLoading = false;
    }
  }

  private resolveDownloadUrl(entry: CatalogEntry): string {
    let direct = entry.url?.toString() ?? '';
    if (direct.length > 0 &&
      (direct.startsWith('http://') || direct.startsWith('https://'))) {
      return direct;
    }
    let fileName = entry.fileName?.toString() ?? '';
    if (fileName.length === 0) {
      return '';
    }
    let listUrl = this.repoUrl.trim();
    let stripped = listUrl.replace('https://', '').replace('http://', '');
    if (stripped.includes('/')) {
      return listUrl.substring(0, listUrl.lastIndexOf('/') + 1) + fileName;
    }
    return `${listUrl}/${fileName}`;
  }

  private async addEntry(entry: CatalogEntry): Promise<void> {
    if (this.addingKey.length > 0) {
      return;
    }
    let url = this.resolveDownloadUrl(entry);
    if (url.length === 0) {
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    this.addingKey = entry.key;
    let key: string | null = await DataService.getInstance().addComicSourceFromUrl(url);
    this.addingKey = '';
    if (key !== null) {
      await this.refreshInstalledKeys();
      promptAction.showToast({ message: this.tl('Added') });
    } else {
      promptAction.showToast({ message: this.tl('Failed') });
    }
  }

  private entrySubtitle(entry: CatalogEntry): string {
    let lines: string[] = [];
    if (entry.version !== undefined && entry.version.toString().length > 0) {
      lines.push(entry.version.toString());
    }
    if (entry.description !== undefined && entry.description.length > 0) {
      lines.push(entry.description);
    }
    return lines.join('\n');
  }

  private isInstalled(entry: CatalogEntry): boolean {
    return this.installedKeys.indexOf(entry.key) >= 0;
  }

  @Builder
  catalogTrailing(entry: CatalogEntry) {
    if (this.isInstalled(entry)) {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_emphasize')])
    } else if (this.addingKey === entry.key) {
      LoadingProgress().width(20).height(20)
    } else {
      Button(this.tl('Add'))
        .height(32)
        .fontSize(12)
        .enabled(this.addingKey.length === 0)
        .onClick(() => this.addEntry(entry))
    }
  }

  @Builder
  repoSection() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
        Text(this.tl('Repo URL'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      TextInput({ text: this.repoUrl, placeholder: 'URL' })
        .width('100%')
        .padding({ left: 16, right: 16 })
        .onChange((v: string) => {
          this.repoUrl = v;
          this.urlChanged = true;
        })

      Text(this.tl("The URL should point to a 'index.json' file"))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

      Text(this.tl('Do not report any issues related to sources to App repo.'))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      ActionSettingTile({
        title: this.tl('Help'),
        actionLabel: this.tl('Open'),
        onAction: () => RouterUtil.launchUrl(COMIC_SOURCE_HELP_URL)
      })
      ActionSettingTile({
        title: this.tl('Refresh'),
        actionLabel: '',
        showDivider: false,
        onAction: () => this.loadCatalog()
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .margin({ bottom: 12 })
  }

  @Builder
  catalogSection() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.entries.length === 0) {
      Text(this.tl('Empty'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(24)
    } else {
      Column() {
        ForEach(this.entries, (entry: CatalogEntry, index: number) => {
          SettingTile({
            title: entry.name,
            subtitle: this.entrySubtitle(entry),
            showDivider: index < this.entries.length - 1,
            trailing: () => {
              this.catalogTrailing(entry)
            }
          })
        }, (entry: CatalogEntry) => entry.key)
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(20)
      .margin({ bottom: 12 })
    }
  }

  @Builder
  pageContent() {
    Scroll(this.scroller) {
      Column() {
        ImmersiveScrollTopInset({ titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE })
        this.repoSection()
        this.catalogSection()
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl('Comic Source'),
        titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE,
        showBack: true,
        scrollable: false,
        pageScroller: this.scroller,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
