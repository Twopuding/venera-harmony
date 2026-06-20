import {
  CatalogEntry,
  ComicSourceInfo,
  DataService
} from '../service/DataService';
import { ImmersivePageScaffold } from '../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../components/ImmersiveScrollTopInset';
import { LoadingIndicator } from '../components/LoadingIndicator';
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

  aboutToDisappear(): void {
    if (this.urlChanged) {
      DataService.getInstance().setSetting('comicSourceListUrl', this.repoUrl);
    }
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
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

  private async loadCatalog(): Promise<void> {
    this.isLoading = true;
    try {
      let sources: ComicSourceInfo[] = await DataService.getInstance().getComicSources();
      this.installedKeys = sources.map((s: ComicSourceInfo) => s.key);
      this.entries = await DataService.getInstance().fetchComicSourceCatalog(this.repoUrl);
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
    let listUrl = this.repoUrl;
    let stripped = listUrl.replace('https://', '').replace('http://', '');
    if (stripped.includes('/')) {
      return listUrl.substring(0, listUrl.lastIndexOf('/') + 1) + fileName;
    }
    return `${listUrl}/${fileName}`;
  }

  private async addEntry(entry: CatalogEntry): Promise<void> {
    let url = this.resolveDownloadUrl(entry);
    if (url.length === 0) {
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    this.addingKey = entry.key;
    let key: string | null = await DataService.getInstance().addComicSourceFromUrl(url);
    this.addingKey = '';
    if (key !== null) {
      this.installedKeys = [...this.installedKeys, entry.key];
      promptAction.showToast({ message: this.tl('Added') });
    } else {
      promptAction.showToast({ message: this.tl('Failed') });
    }
  }

  private entrySubtitle(entry: CatalogEntry): string {
    let lines: string[] = [];
    if (entry.version !== undefined) {
      lines.push(entry.version.toString());
    }
    if (entry.description !== undefined && entry.description.length > 0) {
      lines.push(entry.description);
    }
    return lines.join('\n');
  }

  @Builder
  repoCard() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
        Text(this.tl('Repo URL'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      TextInput({ text: this.repoUrl })
        .width('100%')
        .margin({ left: 16, right: 16, top: 8 })
        .onChange((v: string) => {
          this.repoUrl = v;
          this.urlChanged = true;
        })

      Text(this.tl("The URL should point to a 'index.json' file"))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

      Text(this.tl('Do not report any issues related to sources to App repo.'))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 })

      Row() {
        Blank()
        Button(this.tl('Help'))
          .type(ButtonType.Normal)
          .fontSize(14)
          .onClick(() => RouterUtil.launchUrl(COMIC_SOURCE_HELP_URL))
        Button(this.tl('Refresh'))
          .type(ButtonType.Capsule)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => this.loadCatalog())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    }
    .width('100%')
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    .borderRadius(12)
    .border({ width: 0.6, color: $r('app.color.card_border') })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  pageContent() {
    Scroll(this.scroller) {
      Column() {
        ImmersiveScrollTopInset()
        this.repoCard()
        if (this.isLoading) {
          LoadingIndicator()
        } else if (this.entries.length === 0) {
          Text(this.tl('No comic sources installed'))
            .fontColor($r('app.color.text_secondary'))
            .padding(24)
        } else {
          ForEach(this.entries, (entry: CatalogEntry) => {
            Row() {
              Column() {
                Text(entry.name)
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                if (this.entrySubtitle(entry).length > 0) {
                  Text(this.entrySubtitle(entry))
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 4 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.installedKeys.indexOf(entry.key) >= 0) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(20)
                  .fontColor([$r('app.color.color_emphasize')])
              } else {
                Button(this.tl('Add'))
                  .height(32)
                  .fontSize(12)
                  .enabled(this.addingKey.length === 0)
                  .onClick(() => this.addEntry(entry))
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }, (entry: CatalogEntry) => entry.key)
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
    }
    .width('100%')
    .height('100%')
  }
}
