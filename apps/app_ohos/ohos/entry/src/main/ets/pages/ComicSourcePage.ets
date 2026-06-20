import {
  ComicSourceInfo,
  ComicSourceUpdatesResult,
  DataService,
  SourceSettingItem
} from '../service/DataService';
import { ContentDialog, ContentDialogCustom } from '../components/ContentDialog';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { RouterUtil } from '../navigation/RouterUtil';
import { TranslationUtil } from '../utils/TranslationUtil';
import { ImmersivePageScaffold } from '../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../components/ImmersiveScrollTopInset';
import { SettingTile } from '../components/SettingsList';
import { PlatformUtil } from '../utils/PlatformUtil';
import { COMIC_SOURCE_HELP_URL } from '../utils/SettingsConstants';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

interface SettingSelectOption {
  value: string;
}

@Entry
@Component
struct ComicSourcePage {
  @State sources: ComicSourceInfo[] = []
  @State isLoading: boolean = true
  @State sourceUrl: string = ''
  @State statusMessage: string = ''
  @State isAdding: boolean = false
  @State showSettingsDialog: boolean = false
  @State settingsSourceKey: string = ''
  @State sourceSettings: SourceSettingItem[] = []
  @State showDeleteDialog: boolean = false
  @State deleteSourceKey: string = ''
  @State deleteSourceName: string = ''
  @State showUpdateDialog: boolean = false
  @State pendingUpdates: ComicSourceUpdatesResult = { count: 0, updates: [] }
  @State isBatchUpdating: boolean = false
  @State showInputDialog: boolean = false
  @State inputSettingKey: string = ''
  @State inputSettingTitle: string = ''
  @State inputSettingValue: string = ''
  @State inputValidator: string = ''
  @State callbackLoadingKey: string = ''
  private scroller: Scroller = new Scroller()
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadSources();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async loadSources(): Promise<void> {
    this.isLoading = true;
    try {
      this.sources = await DataService.getInstance().getComicSources();
    } finally {
      this.isLoading = false;
    }
  }

  private async openSourceSettings(key: string): Promise<void> {
    this.settingsSourceKey = key;
    this.sourceSettings = await DataService.getInstance().getComicSourceSettings(key);
    this.showSettingsDialog = true;
  }

  private async saveSourceSetting(item: SourceSettingItem, value: Object | null): Promise<void> {
    await DataService.getInstance().setComicSourceSetting(this.settingsSourceKey, item.key, value);
    this.sourceSettings = await DataService.getInstance().getComicSourceSettings(this.settingsSourceKey);
  }

  private async addFromUrl(): Promise<void> {
    let url: string = this.sourceUrl.trim();
    if (url.length === 0) {
      return;
    }
    this.isAdding = true;
    this.statusMessage = this.tl('Loading...');
    let key: string | null = await DataService.getInstance().addComicSourceFromUrl(url);
    this.isAdding = false;
    this.statusMessage = key !== null ? this.tl('Added') : this.tl('Failed');
    if (key !== null) {
      this.sourceUrl = '';
      await this.loadSources();
    }
  }

  private async importFromFile(): Promise<void> {
    let path: string = await PlatformUtil.pickFile(this.context);
    if (path.length === 0) {
      return;
    }
    let content: string = PlatformUtil.readTextFile(path);
    if (content.length === 0) {
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    let fileName: string = PlatformUtil.fileNameFromPath(path);
    this.isAdding = true;
    let key: string | null = await DataService.getInstance().importComicSourceFromContent(content, fileName);
    this.isAdding = false;
    if (key !== null) {
      await this.loadSources();
      promptAction.showToast({ message: this.tl('Added') });
    } else {
      promptAction.showToast({ message: this.tl('Failed') });
    }
  }

  private async checkUpdates(): Promise<void> {
    let result: ComicSourceUpdatesResult =
      await DataService.getInstance().checkComicSourceUpdates();
    if (result.count < 0) {
      this.statusMessage = this.tl('Network error');
      return;
    }
    if (result.count === 0) {
      this.statusMessage = this.tl('No updates');
      return;
    }
    this.pendingUpdates = result;
    this.showUpdateDialog = true;
  }

  private updateDialogMessage(): string {
    let lines: string[] = [];
    for (let i: number = 0; i < this.pendingUpdates.updates.length; i++) {
      let item = this.pendingUpdates.updates[i];
      lines.push(`${item.name}: ${item.remoteVersion ?? ''}`);
    }
    return lines.join('\n');
  }

  private async batchUpdate(): Promise<void> {
    this.showUpdateDialog = false;
    this.isBatchUpdating = true;
    for (let i: number = 0; i < this.pendingUpdates.updates.length; i++) {
      await DataService.getInstance().updateComicSource(this.pendingUpdates.updates[i].key);
    }
    this.isBatchUpdating = false;
    await this.loadSources();
    promptAction.showToast({ message: this.tl('Updated') });
  }

  private confirmDelete(source: ComicSourceInfo): void {
    this.deleteSourceKey = source.key;
    this.deleteSourceName = source.name;
    this.showDeleteDialog = true;
  }

  private async removeSource(): Promise<void> {
    this.showDeleteDialog = false;
    let ok = await DataService.getInstance().removeComicSource(this.deleteSourceKey);
    if (ok) {
      await this.loadSources();
    } else {
      promptAction.showToast({ message: this.tl('Failed') });
    }
  }

  private openInputSetting(item: SourceSettingItem): void {
    this.inputSettingKey = item.key;
    this.inputSettingTitle = item.title?.toString() ?? item.key;
    this.inputSettingValue = item.current?.toString() ?? '';
    this.inputValidator = item.validator?.toString() ?? '';
    this.showInputDialog = true;
  }

  private async saveInputSetting(): Promise<void> {
    if (this.inputValidator.length > 0) {
      try {
        let regex = new RegExp(this.inputValidator);
        if (!regex.test(this.inputSettingValue)) {
          promptAction.showToast({ message: this.tl('Failed') });
          return;
        }
      } catch (_) {
        // ignore invalid regex
      }
    }
    await this.saveSourceSetting(
      { key: this.inputSettingKey, type: 'input', title: this.inputSettingTitle },
      this.inputSettingValue
    );
    this.showInputDialog = false;
  }

  private async invokeCallback(item: SourceSettingItem): Promise<void> {
    this.callbackLoadingKey = item.key;
    let error = await DataService.getInstance().invokeComicSourceCallback(
      this.settingsSourceKey, item.key
    );
    this.callbackLoadingKey = '';
    if (error !== null) {
      promptAction.showToast({ message: error });
    }
  }

  private selectDisplayText(item: SourceSettingItem): string {
    if (item.options === undefined) {
      return item.current?.toString() ?? '';
    }
    for (let i: number = 0; i < item.options.length; i++) {
      if (item.options[i].value === item.current) {
        return item.options[i].text;
      }
    }
    return item.current?.toString() ?? '';
  }

  private settingSelectOptions(item: SourceSettingItem): SettingSelectOption[] {
    let options: SettingSelectOption[] = [];
    if (item.options === undefined) {
      return options;
    }
    for (let i: number = 0; i < item.options.length; i++) {
      options.push({ value: item.options[i].text });
    }
    return options;
  }

  @Builder
  sourceSettingsDialogContent() {
    Column() {
      ForEach(this.sourceSettings, (item: SourceSettingItem) => {
        this.sourceSettingRow(item)
      }, (item: SourceSettingItem) => item.key)
    }
  }

  @Builder
  sourceSettingRow(item: SourceSettingItem) {
    if (item.type === 'switch') {
      Row() {
        Text(item.title?.toString() ?? item.key)
          .fontSize(14)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: item.current === true })
          .onChange((v: boolean) => {
            this.saveSourceSetting(item, v);
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    } else if (item.type === 'select' && item.options !== undefined) {
      Column() {
        Text(item.title?.toString() ?? item.key)
          .fontSize(14)
          .width('100%')
        Select(this.settingSelectOptions(item))
          .selected(item.options.findIndex((o) => o.value === item.current))
          .value(this.selectDisplayText(item))
          .width('100%')
          .margin({ top: 4 })
          .onSelect((index: number) => {
            this.saveSourceSetting(item, item.options![index].value);
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    } else if (item.type === 'input') {
      Row() {
        Column() {
          Text(item.title?.toString() ?? item.key)
            .fontSize(14)
          Text(item.current?.toString() ?? '')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.tl('Edit'))
          .height(32)
          .fontSize(12)
          .onClick(() => this.openInputSetting(item))
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    } else if (item.type === 'callback') {
      Row() {
        Text(item.title?.toString() ?? item.key)
          .fontSize(14)
          .layoutWeight(1)
        Button(item.buttonText?.toString() ?? this.tl('Click'))
          .height(32)
          .fontSize(12)
          .enabled(this.callbackLoadingKey !== item.key)
          .onClick(() => this.invokeCallback(item))
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    } else {
      Text(item.title?.toString() ?? item.key)
        .fontSize(14)
        .width('100%')
        .padding({ top: 8 })
    }
  }

  @Builder
  sourceCard(source: ComicSourceInfo) {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(source.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            if (source.version !== undefined && source.version.length > 0) {
              Text(source.version)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .margin({ left: 6 })
                .borderRadius(8)
                .backgroundColor($r('app.color.tag_bg'))
            }
            if (source.hasUpdate === true) {
              Text(this.tl('New Version'))
                .fontSize(11)
                .fontColor($r('app.color.color_emphasize'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .margin({ left: 4 })
                .borderRadius(8)
                .backgroundColor($r('app.color.badge_bg'))
            }
          }
          Text(source.key)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button(this.tl('Settings'))
          .height(32)
          .fontSize(12)
          .margin({ right: 4 })
          .onClick(() => this.openSourceSettings(source.key))
        Button(this.tl('Edit'))
          .height(32)
          .fontSize(12)
          .margin({ right: 4 })
          .onClick(() => RouterUtil.openComicSourceEdit(source.key))
        Button(this.tl('Update'))
          .height(32)
          .fontSize(12)
          .margin({ right: 4 })
          .onClick(async () => {
            let ok = await DataService.getInstance().updateComicSource(source.key);
            if (ok) {
              await this.loadSources();
              promptAction.showToast({ message: this.tl('Updated') });
            } else {
              promptAction.showToast({ message: this.tl('Failed') });
            }
          })
        Button(this.tl('Delete'))
          .height(32)
          .fontSize(12)
          .backgroundColor($r('app.color.badge_bg'))
          .onClick(() => this.confirmDelete(source))
      }
      .width('100%')

      if (source.hasAccount === true) {
        Divider().margin({ top: 12, bottom: 4 })
        if (source.isLogged === true) {
          Text(this.tl('Logged in'))
            .fontSize(14)
            .fontColor($r('app.color.color_emphasize'))
            .width('100%')
        }
        SettingTile({
          title: source.isLogged === true ? this.tl('Re-login') : this.tl('Log in'),
          subtitle: this.tl('Click if login expired'),
          showDivider: false,
          trailing: () => {
            Button(this.tl('Open'))
              .height(32)
              .fontSize(12)
              .onClick(() => RouterUtil.openComicSourceLogin(source.key, source.name))
          },
          onTap: () => RouterUtil.openComicSourceLogin(source.key, source.name)
        })
        if (source.isLogged === true) {
          SettingTile({
            title: this.tl('Log out'),
            showDivider: false,
            onTap: async () => {
              await DataService.getInstance().comicSourceLogout(source.key);
              await this.loadSources();
            }
          })
        }
      }
    }
    .width('100%')
    .padding(16)
    .margin({ left: 16, right: 16, bottom: 8 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  @Builder
  pageContent() {
    Scroll(this.scroller) {
      Column() {
        ImmersiveScrollTopInset()
        Column() {
          Row() {
            SymbolGlyph($r('sys.symbol.square_grid_2x2'))
              .fontSize(20)
            Text(this.tl('Add comic source'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ bottom: 8 })

          TextInput({ placeholder: this.tl('Source URL'), text: this.sourceUrl })
            .width('100%')
            .enabled(!this.isAdding && !this.isBatchUpdating)
            .onChange((v: string) => { this.sourceUrl = v; })
            .onSubmit(() => this.addFromUrl())

          Row({ space: 8 }) {
            Button(this.tl('Comic Source list'))
              .layoutWeight(1)
              .fontSize(12)
              .onClick(() => RouterUtil.openComicSourceList())
            Button(this.tl('Use a config file'))
              .layoutWeight(1)
              .fontSize(12)
              .onClick(() => this.importFromFile())
          }
          .width('100%')
          .margin({ top: 8 })

          Row({ space: 8 }) {
            Button(this.tl('Help'))
              .layoutWeight(1)
              .fontSize(12)
              .onClick(() => RouterUtil.launchUrl(COMIC_SOURCE_HELP_URL))
            Button(this.tl('Check Updates'))
              .layoutWeight(1)
              .fontSize(12)
              .enabled(!this.isBatchUpdating)
              .onClick(() => this.checkUpdates())
          }
          .width('100%')
          .margin({ top: 8 })

          Row({ space: 8 }) {
            Button(this.tl('Add'))
              .layoutWeight(1)
              .enabled(!this.isAdding && !this.isBatchUpdating)
              .onClick(() => this.addFromUrl())
          }
          .width('100%')
          .margin({ top: 8 })

          if (this.isAdding || this.isBatchUpdating) {
            Row() {
              LoadingProgress().width(20).height(20)
              Text(this.isBatchUpdating ? this.tl('Updating') : this.tl('Loading...'))
                .fontSize(12)
                .margin({ left: 8 })
            }
            .margin({ top: 8 })
          }

          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .padding(16)
        .margin({ bottom: 8 })
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)

        if (this.isLoading) {
          LoadingIndicator()
        } else if (this.sources.length === 0) {
          Text(this.tl('No comic sources installed'))
            .fontColor($r('app.color.text_secondary'))
            .padding(24)
        } else {
          ForEach(this.sources, (source: ComicSourceInfo) => {
            this.sourceCard(source)
          }, (source: ComicSourceInfo) => source.key)
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl('Comic Source'),
        showBack: true,
        scrollable: false,
        pageScroller: this.scroller,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })

      ContentDialogCustom({
        show: this.showSettingsDialog,
        title: this.tl('Source Settings'),
        content: this.sourceSettingsDialogContent,
        actions: () => {
          Button(this.tl('Close'))
            .onClick(() => { this.showSettingsDialog = false; })
        },
        onClose: () => { this.showSettingsDialog = false; }
      })

      ContentDialog({
        show: this.showDeleteDialog,
        title: this.tl('Delete'),
        message: `${this.tl('Delete comic source')} "${this.deleteSourceName}" ?`,
        confirmLabel: this.tl('Delete'),
        onConfirm: () => this.removeSource(),
        onClose: () => { this.showDeleteDialog = false; }
      })

      ContentDialog({
        show: this.showUpdateDialog,
        title: this.tl('Updates'),
        message: this.updateDialogMessage(),
        confirmLabel: this.tl('Update'),
        cancelLabel: this.tl('Cancel'),
        onConfirm: () => this.batchUpdate(),
        onClose: () => { this.showUpdateDialog = false; }
      })

      ContentDialogCustom({
        show: this.showInputDialog,
        title: this.inputSettingTitle,
        content: () => {
          TextInput({ text: this.inputSettingValue })
            .width('100%')
            .onChange((v: string) => { this.inputSettingValue = v; })
        },
        actions: () => {
          Button(this.tl('Cancel'))
            .onClick(() => { this.showInputDialog = false; })
          Button(this.tl('OK'))
            .margin({ left: 8 })
            .onClick(() => this.saveInputSetting())
        },
        onClose: () => { this.showInputDialog = false; }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
