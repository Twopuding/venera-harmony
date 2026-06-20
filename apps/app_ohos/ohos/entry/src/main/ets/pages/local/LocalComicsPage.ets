import { common } from '@kit.AbilityKit';
import { DataService, ExportComicItem } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicTile } from '../../components/ComicTile';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
import { ContentDialog, ContentDialogCustom } from '../../components/ContentDialog';
import { RouterUtil } from '../../navigation/RouterUtil';
import { PlatformUtil } from '../../utils/PlatformUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct LocalComicsPage {
  @State comics: Comic[] = []
  @State allComics: Comic[] = []
  @State isLoading: boolean = true
  @State multiSelectMode: boolean = false
  @State selectedKeys: string[] = []
  @State statusMessage: string = ''
  @State showDeleteDialog: boolean = false
  @State searchMode: boolean = false
  @State searchKeyword: string = ''
  @State sortType: string = 'name'
  @State showImportDialog: boolean = false
  @State showExportDialog: boolean = false
  private pendingExportItems: ExportComicItem[] = []
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadComics();
  }

  private comicKey(comic: Comic): string {
    return `${comic.sourceKey}:${comic.id}`;
  }

  private isSelected(comic: Comic): boolean {
    return this.selectedKeys.indexOf(this.comicKey(comic)) >= 0;
  }

  private toggleSelection(comic: Comic): void {
    let key = this.comicKey(comic);
    let index = this.selectedKeys.indexOf(key);
    if (index >= 0) {
      this.selectedKeys.splice(index, 1);
      this.selectedKeys = [...this.selectedKeys];
    } else {
      this.selectedKeys.push(key);
      this.selectedKeys = [...this.selectedKeys];
    }
    if (this.selectedKeys.length === 0) {
      this.multiSelectMode = false;
    }
  }

  private async loadComics(): Promise<void> {
    this.isLoading = true;
    try {
      this.allComics = await DataService.getInstance().getLocalComics();
      this.applyFilterSort();
    } finally {
      this.isLoading = false;
    }
  }

  private applyFilterSort(): void {
    let list: Comic[] = this.allComics.slice();
    if (this.searchKeyword.trim().length > 0) {
      let kw = this.searchKeyword.trim().toLowerCase();
      list = list.filter((c: Comic) =>
        c.title.toLowerCase().includes(kw) || c.subtitle.toLowerCase().includes(kw));
    }
    if (this.sortType === 'name') {
      list.sort((a: Comic, b: Comic) => a.title.localeCompare(b.title));
    } else {
      list.reverse();
    }
    this.comics = list;
  }

  private cycleSort(): void {
    this.sortType = this.sortType === 'name' ? 'time' : 'name';
    this.applyFilterSort();
  }

  private exportSelected(): void {
    let items: ExportComicItem[] = [];
    for (let key of this.selectedKeys) {
      let parts = key.split(':');
      if (parts.length >= 2) {
        items.push({ sourceKey: parts[0], id: parts.slice(1).join(':') });
      }
    }
    if (items.length === 0) {
      return;
    }
    this.pendingExportItems = items;
    this.showExportDialog = true;
  }

  private async runExport(format: string): Promise<void> {
    this.showExportDialog = false;
    if (this.pendingExportItems.length === 0) {
      return;
    }
    let result = await DataService.getInstance().exportComics(this.pendingExportItems, format);
    this.statusMessage = result.error ?? `Exported ${result.count ?? 0} comic(s)`;
    this.pendingExportItems = [];
    this.multiSelectMode = false;
    this.selectedKeys = [];
  }

  private async importComic(): Promise<void> {
    this.showImportDialog = true;
  }

  private async runImport(mode: string): Promise<void> {
    this.showImportDialog = false;
    this.isLoading = true;
    let path: string = '';
    if (mode === 'file') {
      path = await PlatformUtil.pickFile(this.context);
      if (path.length === 0) {
        this.isLoading = false;
        return;
      }
    } else if (mode === 'directory' || mode === 'multipleCbz') {
      path = await PlatformUtil.pickDirectory(this.context);
      if (path.length === 0) {
        this.isLoading = false;
        return;
      }
    }
    let error: string | null = await DataService.getInstance().importLocalComic(mode, path.length > 0 ? path : undefined);
    this.isLoading = false;
    if (error !== null) {
      this.statusMessage = error;
    } else {
      this.statusMessage = 'Import successful';
      await this.loadComics();
    }
  }

  @Builder
  exportDialogContent() {
    Column({ space: 8 }) {
      Button('Export as CBZ')
        .width('100%')
        .onClick(() => this.runExport('cbz'))
      Button('Export as PDF')
        .width('100%')
        .onClick(() => this.runExport('pdf'))
      Button('Export as EPUB')
        .width('100%')
        .onClick(() => this.runExport('epub'))
    }
    .width('100%')
  }

  @Builder
  exportDialogActions() {
    Button('Cancel')
      .onClick(() => {
        this.showExportDialog = false;
        this.pendingExportItems = [];
      })
  }

  @Builder
  importDialogActions() {
    Button('Close')
      .onClick(() => {
        this.showImportDialog = false;
      })
  }

  @Builder
  importDialogContent() {
    Column({ space: 8 }) {
      Button('Import CBZ/ZIP file')
        .width('100%')
        .onClick(() => this.runImport('file'))
      Button('Import comic folder')
        .width('100%')
        .onClick(() => this.runImport('directory'))
      Button('Import multiple CBZ from folder')
        .width('100%')
        .onClick(() => this.runImport('multipleCbz'))
      Button('Scan local downloads')
        .width('100%')
        .onClick(() => this.runImport('localDownloads'))
      Button('Restore local database')
        .width('100%')
        .onClick(() => this.runImport('scan'))
    }
    .width('100%')
  }

  private async deleteSelected(): Promise<void> {
    for (let key of this.selectedKeys) {
      let parts = key.split(':');
      if (parts.length >= 2) {
        let sourceKey = parts[0];
        let id = parts.slice(1).join(':');
        await DataService.getInstance().deleteLocalComic(id, sourceKey);
      }
    }
    this.selectedKeys = [];
    this.multiSelectMode = false;
    this.showDeleteDialog = false;
    await this.loadComics();
  }

  private handleBack(): void {
    if (this.multiSelectMode) {
      this.multiSelectMode = false;
      this.selectedKeys = [];
    } else {
      RouterUtil.back();
    }
  }

  private pageMenus(): HdsNavigationMenuContentOptions | undefined {
    if (this.multiSelectMode) {
      return NavigationMenus.fromEntries([
        {
          icon: $r('sys.symbol.trash'),
          label: this.tr('Delete'),
          action: () => {
            if (this.selectedKeys.length > 0) {
              this.showDeleteDialog = true;
            }
          }
        },
        {
          icon: $r('sys.symbol.share'),
          label: this.tr('Export'),
          action: () => {
            if (this.selectedKeys.length > 0) {
              this.exportSelected();
            }
          }
        }
      ]);
    }
    return NavigationMenus.fromEntries([
      {
        icon: $r('sys.symbol.magnifyingglass'),
        label: this.tr('Search'),
        action: () => {
          this.searchMode = !this.searchMode;
        }
      },
      {
        icon: $r('sys.symbol.arrow_clockwise'),
        label: this.tr('Sort'),
        action: () => this.cycleSort()
      },
      {
        icon: $r('sys.symbol.plus'),
        label: this.tr('Import'),
        action: () => this.importComic()
      },
      {
        icon: $r('sys.symbol.arrow_down_circle'),
        label: this.tr('Downloading'),
        action: () => RouterUtil.openDownloading()
      },
      {
        icon: $r('sys.symbol.list_bullet'),
        label: this.tr('Select'),
        action: () => {
          this.multiSelectMode = true;
        }
      }
    ]);
  }

  @Builder
  pageContent() {
    Column() {
      if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(8)
        }

        if (this.searchMode) {
          Row() {
            TextInput({ placeholder: 'Search local comics', text: this.searchKeyword })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.searchKeyword = v;
                this.applyFilterSort();
              })
            Button('Close')
              .margin({ left: 8 })
              .onClick(() => {
                this.searchMode = false;
                this.searchKeyword = '';
                this.applyFilterSort();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }

        if (this.isLoading) {
          LoadingIndicator()
        } else if (this.comics.length === 0) {
          Column() {
            Text('No local comics')
              .fontColor($r('app.color.text_secondary'))
            Button('Import CBZ')
              .margin({ top: 16 })
              .onClick(() => this.importComic())
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.comics, (comic: Comic) => {
              ListItem() {
                Row() {
                  if (this.multiSelectMode) {
                    Checkbox()
                      .select(this.isSelected(comic))
                      .margin({ right: 8 })
                  }
                  ComicTile({
                    comic: comic,
                    mode: 'detailed',
                    onTap: () => {
                      if (this.multiSelectMode) {
                        this.toggleSelection(comic);
                      } else {
                        RouterUtil.openReader(comic.id, comic.sourceKey);
                      }
                    },
                    onLongPress: () => {
                      if (!this.multiSelectMode) {
                        this.multiSelectMode = true;
                        this.toggleSelection(comic);
                      }
                    }
                  })
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 8, right: 8, bottom: 8 })
              }
            }, (comic: Comic) => this.comicKey(comic))
          }
          .layoutWeight(1)
        }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.multiSelectMode ? `${this.selectedKeys.length}` : 'Local Comics',
        showBack: true,
        scrollable: false,
        onBack: () => this.handleBack(),
        menus: this.pageMenus(),
        content: () => {
          this.pageContent()
        }
      })

      ContentDialog({
        title: this.tr('Delete comics'),
        message: `Delete ${this.selectedKeys.length} local comic(s)?`,
        confirmLabel: 'Delete',
        show: this.showDeleteDialog,
        onClose: () => {
          this.showDeleteDialog = false;
        },
        onConfirm: () => this.deleteSelected()
      })

      ContentDialogCustom({
        title: this.tr('Import comics'),
        show: this.showImportDialog,
        content: this.importDialogContent,
        actions: this.importDialogActions,
        onClose: () => {
          this.showImportDialog = false;
        }
      })

      ContentDialogCustom({
        title: this.tr('Export comics'),
        show: this.showExportDialog,
        content: this.exportDialogContent,
        actions: this.exportDialogActions,
        onClose: () => {
          this.showExportDialog = false;
          this.pendingExportItems = [];
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
