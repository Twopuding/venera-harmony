import { DataService, ExploreLoadResult, ExportComicItem } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicGrid } from '../../components/ComicGrid';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { ContentDialogCustom } from '../../components/ContentDialog';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import promptAction from '@ohos.promptAction';

const LOCAL_ALL_FOLDER: string = '^_^[%local_all%]^_^';
const TWO_PANEL_WIDTH: number = 720;
const SIDEBAR_WIDTH: number = 256;

interface FolderEntry {
  key: string;
  label: string;
  count: number;
  isNetwork: boolean;
}

@Component
export struct FavoritesPage {
  @State localFolders: string[] = []
  @State networkSources: string[] = []
  @State folderCounts: Record<string, number> = {}
  @State selectedFolder: string = ''
  @State isNetworkMode: boolean = false
  @State comics: Comic[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  @State showFolderDrawer: boolean = false
  @State screenWidth: number = 360
  @State multiSelectMode: boolean = false
  @State selectedKeys: string[] = []
  @State networkSubfolder: string = ''
  @State remoteFolders: string[] = []
  @State showNewFolderDialog: boolean = false
  @State newFolderName: string = ''
  @State showMoveDialog: boolean = false
  @State moveTargetFolder: string = ''
  @State onClickFavoriteMode: string = 'viewDetail'
  @State readFilterSelect: string = 'All'
  @State showReorderDialog: boolean = false
  @State showExportDialog: boolean = false
  private pendingExportItems: ExportComicItem[] = []
  @State reorderComicIds: string[] = []
  @State networkUpdatePageNum: number = 9999999
  private scroller: Scroller = new Scroller()

  private comicKey(comic: Comic): string {
    return comic.id + '@' + comic.sourceKey;
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(getContext(this) as Context);
    DataService.getInstance().getSettings().then((settings: Record<string, Object>) => {
      let mode = settings['onClickFavorite'];
      if (mode !== undefined && mode !== null) {
        this.onClickFavoriteMode = mode.toString();
      }
    });
    this.loadFolders();
  }

  private trParam(key: string, paramKey: string, value: string | number): string {
    return TranslationUtil.tlParam(key, paramKey, value);
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key);
  }

  private async loadFolders(): Promise<void> {
    this.isLoading = true;
    try {
      let service: DataService = DataService.getInstance();
      let results: [string[], Record<string, number>, string[]] = await Promise.all([
        service.getFavoriteFolders(),
        service.getFavoriteFolderCounts(),
        service.getNetworkFavoriteSources()
      ]);
      this.localFolders = results[0];
      this.folderCounts = results[1];
      this.networkSources = results[2];
      if (this.selectedFolder.length === 0) {
        if (this.localFolders.length > 0 || this.networkSources.length === 0) {
          this.isNetworkMode = false;
          this.selectedFolder = LOCAL_ALL_FOLDER;
        } else if (this.networkSources.length > 0) {
          this.isNetworkMode = true;
          this.selectedFolder = this.networkSources[0];
        }
      }
      await this.loadComics(1);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadComics(page: number): Promise<void> {
    if (this.selectedFolder.length === 0) {
      this.comics = [];
      return;
    }
    if (page === 1) {
      this.isLoading = true;
      this.errorMessage = '';
    } else {
      this.isLoadingMore = true;
    }
    try {
      let service: DataService = DataService.getInstance();
      if (this.isNetworkMode) {
        let folder: string | undefined = this.networkSubfolder.length > 0 ? this.networkSubfolder : undefined;
        let result: ExploreLoadResult = await service.loadNetworkFavorites(this.selectedFolder, page, folder);
        if (result.error !== undefined) {
          this.errorMessage = result.error;
          return;
        }
        if (page === 1) {
          this.comics = result.comics;
        } else {
          this.comics = this.comics.concat(result.comics);
        }
        this.hasMore = result.hasMore;
      } else {
        this.comics = await service.getFavorites(this.selectedFolder, this.readFilterSelect);
        this.hasMore = false;
      }
      this.currentPage = page;
    } catch (e) {
      this.errorMessage = 'Failed to load favorites';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  private selectFolder(isNetwork: boolean, folder: string): void {
    this.isNetworkMode = isNetwork;
    this.selectedFolder = folder;
    this.networkSubfolder = '';
    this.remoteFolders = [];
    this.showFolderDrawer = false;
    this.multiSelectMode = false;
    this.selectedKeys = [];
    this.currentPage = 1;
    if (isNetwork) {
      this.loadRemoteFolders();
    }
    this.loadComics(1);
  }

  private async loadRemoteFolders(): Promise<void> {
    if (!this.isNetworkMode || this.selectedFolder.length === 0) {
      return;
    }
    this.remoteFolders = await DataService.getInstance().loadFavoriteFoldersRemote(this.selectedFolder);
  }

  private selectNetworkSubfolder(folder: string): void {
    this.networkSubfolder = folder;
    this.currentPage = 1;
    this.loadComics(1);
  }

  private toggleSelect(comic: Comic): void {
    let key: string = this.comicKey(comic);
    let idx: number = this.selectedKeys.indexOf(key);
    if (idx >= 0) {
      this.selectedKeys = this.selectedKeys.filter((k: string) => k !== key);
    } else {
      this.selectedKeys = this.selectedKeys.concat([key]);
    }
  }

  private getSelectedComics(): Comic[] {
    return this.comics.filter((c: Comic) => this.selectedKeys.indexOf(this.comicKey(c)) >= 0);
  }

  private async deleteSelected(): Promise<void> {
    if (this.isNetworkMode || this.selectedFolder === LOCAL_ALL_FOLDER) {
      promptAction.showToast({ message: this.tr('Select a folder first') });
      return;
    }
    let selected: Comic[] = this.getSelectedComics();
    let service: DataService = DataService.getInstance();
    for (let i: number = 0; i < selected.length; i++) {
      await service.removeFavorite(this.selectedFolder, selected[i].id, selected[i].sourceKey);
    }
    this.multiSelectMode = false;
    this.selectedKeys = [];
    await this.loadFolders();
  }

  private async createFolder(): Promise<void> {
    let name: string = this.newFolderName.trim();
    if (name.length === 0) {
      return;
    }
    let folder: string | null = await DataService.getInstance().createFavoriteFolder(name);
    this.showNewFolderDialog = false;
    this.newFolderName = '';
    if (folder !== null) {
      await this.loadFolders();
      this.selectFolder(false, folder);
    }
  }

  private async deleteCurrentFolder(): Promise<void> {
    if (this.isNetworkMode || this.selectedFolder === LOCAL_ALL_FOLDER) {
      return;
    }
    let ok: boolean = await DataService.getInstance().deleteFavoriteFolder(this.selectedFolder);
    if (ok) {
      this.selectedFolder = LOCAL_ALL_FOLDER;
      await this.loadFolders();
    }
  }

  private async moveSelectedToFolder(): Promise<void> {
    if (this.moveTargetFolder.length === 0 || this.selectedFolder === LOCAL_ALL_FOLDER) {
      return;
    }
    let ok: boolean = await DataService.getInstance().moveFavoritesToFolder(
      this.selectedFolder, this.moveTargetFolder, this.getSelectedComics()
    );
    this.showMoveDialog = false;
    this.multiSelectMode = false;
    this.selectedKeys = [];
    if (ok) {
      await this.loadFolders();
    }
  }

  private cycleReadFilter(): void {
    if (this.readFilterSelect === 'All') {
      this.readFilterSelect = 'UnCompleted';
    } else if (this.readFilterSelect === 'UnCompleted') {
      this.readFilterSelect = 'Completed';
    } else {
      this.readFilterSelect = 'All';
    }
    this.loadComics(1);
  }

  private openReorderDialog(): void {
    if (this.isNetworkMode || this.selectedFolder === LOCAL_ALL_FOLDER) {
      return;
    }
    this.reorderComicIds = this.comics.map((c: Comic) => c.id);
    this.showReorderDialog = true;
  }

  private moveReorderUp(index: number): void {
    if (index <= 0) {
      return;
    }
    let next: string[] = [...this.reorderComicIds];
    let temp = next[index - 1];
    next[index - 1] = next[index];
    next[index] = temp;
    this.reorderComicIds = next;
  }

  private comicTitleForId(id: string): string {
    for (let i: number = 0; i < this.comics.length; i++) {
      if (this.comics[i].id === id) {
        return this.comics[i].title;
      }
    }
    return id;
  }

  private async saveReorder(): Promise<void> {
    await DataService.getInstance().reorderFavorites(this.selectedFolder, this.reorderComicIds);
    this.showReorderDialog = false;
    await this.loadComics(1);
  }

  private async reorderSelectedUp(): Promise<void> {
    if (this.isNetworkMode || this.selectedFolder === LOCAL_ALL_FOLDER) {
      return;
    }
    let ids: string[] = this.comics.map((c: Comic) => c.id);
    let service: DataService = DataService.getInstance();
    await service.reorderFavorites(this.selectedFolder, ids);
    await this.loadComics(1);
  }

  private buildExportItems(): ExportComicItem[] {
    let items: ExportComicItem[] = [];
    let selected = this.getSelectedComics();
    for (let i: number = 0; i < selected.length; i++) {
      let item: ExportComicItem = {
        id: selected[i].id,
        sourceKey: selected[i].sourceKey
      };
      items.push(item);
    }
    return items;
  }

  private async downloadSelected(): Promise<void> {
    let items: ExportComicItem[] = this.buildExportItems();
    if (items.length === 0) {
      return;
    }
    let count = await DataService.getInstance().downloadFavoriteComics(items);
    promptAction.showToast({ message: this.trParam('Added @c comics to download queue.', 'c', count) });
    this.multiSelectMode = false;
    this.selectedKeys = [];
  }

  private async updateSelectedInfo(): Promise<void> {
    if (this.isNetworkMode || this.selectedFolder === LOCAL_ALL_FOLDER) {
      return;
    }
    let selected = this.getSelectedComics();
    for (let i: number = 0; i < selected.length; i++) {
      await DataService.getInstance().updateFavoriteInfo(
        this.selectedFolder, selected[i].id, selected[i].sourceKey
      );
    }
    promptAction.showToast({ message: this.tr('Updated') });
    this.multiSelectMode = false;
    this.selectedKeys = [];
    await this.loadComics(1);
  }

  private exportSelected(): void {
    let items: ExportComicItem[] = this.buildExportItems();
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
    if (result.error !== undefined) {
      promptAction.showToast({ message: result.error });
    } else {
      promptAction.showToast({ message: this.trParam('Exported @c comics', 'c', result.count ?? 0) });
    }
    this.pendingExportItems = [];
    this.multiSelectMode = false;
    this.selectedKeys = [];
  }

  private onComicTap(comic: Comic): void {
    if (this.multiSelectMode) {
      this.toggleSelect(comic);
    } else if (this.onClickFavoriteMode === 'read') {
      RouterUtil.openReader(comic.id, comic.sourceKey);
    } else {
      RouterUtil.openComicDetail(comic.id, comic.sourceKey);
    }
  }

  private onComicLongPress(comic: Comic): void {
    if (!this.multiSelectMode) {
      this.multiSelectMode = true;
      this.selectedKeys = [this.comicKey(comic)];
    } else {
      this.toggleSelect(comic);
    }
  }

  private folderLabel(key: string, isNetwork: boolean): string {
    if (!isNetwork && key === LOCAL_ALL_FOLDER) {
      return this.tr('All');
    }
    return key;
  }

  private folderCount(key: string, isNetwork: boolean): number {
    if (isNetwork) {
      return 0;
    }
    if (key === LOCAL_ALL_FOLDER) {
      let total: number = 0;
      let keys: string[] = Object.keys(this.folderCounts);
      for (let i: number = 0; i < keys.length; i++) {
        total += this.folderCounts[keys[i]];
      }
      return total;
    }
    return this.folderCounts[key] ?? 0;
  }

  private buildFolderEntries(): FolderEntry[] {
    let entries: FolderEntry[] = [];
    entries.push({
      key: LOCAL_ALL_FOLDER,
      label: this.tr('All'),
      count: this.folderCount(LOCAL_ALL_FOLDER, false),
      isNetwork: false
    });
    for (let i: number = 0; i < this.localFolders.length; i++) {
      let folder: string = this.localFolders[i];
      entries.push({
        key: folder,
        label: folder,
        count: this.folderCount(folder, false),
        isNetwork: false
      });
    }
    for (let i: number = 0; i < this.networkSources.length; i++) {
      let source: string = this.networkSources[i];
      entries.push({
        key: source,
        label: source,
        count: 0,
        isNetwork: true
      });
    }
    return entries;
  }

  private selectedTitle(): string {
    if (this.selectedFolder.length === 0) {
      return this.tr('Unselected');
    }
    return this.folderLabel(this.selectedFolder, this.isNetworkMode);
  }

  @Builder
  folderSidebar() {
    Column() {
      Text(this.tr('Local'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })

      this.folderRow(LOCAL_ALL_FOLDER, this.tr('All'), this.folderCount(LOCAL_ALL_FOLDER, false), false)
      ForEach(this.localFolders, (folder: string) => {
        this.folderRow(folder, folder, this.folderCount(folder, false), false)
      }, (folder: string) => 'local_' + folder)

      if (this.networkSources.length > 0) {
        Text(this.tr('Network'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 16, top: 16, bottom: 8 })
          .border({ width: { top: 0.6 }, color: $r('app.color.card_border') })
        ForEach(this.networkSources, (source: string) => {
          this.folderRow(source, source, 0, true)
        }, (source: string) => 'network_' + source)
      }
    }
    .width(SIDEBAR_WIDTH)
    .height('100%')
    .border({ width: { right: 0.6 }, color: $r('app.color.card_border') })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  folderRow(key: string, label: string, count: number, isNetwork: boolean) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.selectedFolder === key && this.isNetworkMode === isNetwork ?
          $r('app.color.color_emphasize') : $r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (!isNetwork) {
        Text(count.toString())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor($r('app.color.badge_bg'))
      }
    }
    .width('100%')
    .height(42)
    .padding({ left: 16, right: 8 })
    .backgroundColor(this.selectedFolder === key && this.isNetworkMode === isNetwork ?
      $r('app.color.badge_bg') : Color.Transparent)
    .border({
      width: { left: 2 },
      color: this.selectedFolder === key && this.isNetworkMode === isNetwork ?
        $r('app.color.color_emphasize') : Color.Transparent
    })
    .onClick(() => this.selectFolder(isNetwork, key))
  }

  @Builder
  folderChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.buildFolderEntries(), (entry: FolderEntry) => {
          Row() {
            Text(entry.label)
              .fontSize(13)
              .fontColor(this.selectedFolder === entry.key && this.isNetworkMode === entry.isNetwork ?
                $r('app.color.color_emphasize') : $r('app.color.text_primary'))
            if (!entry.isNetwork && entry.count > 0) {
              Text(entry.count.toString())
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 4 })
            }
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(16)
          .backgroundColor(this.selectedFolder === entry.key && this.isNetworkMode === entry.isNetwork ?
            $r('app.color.badge_bg') : $r('app.color.card_background'))
          .onClick(() => this.selectFolder(entry.isNetwork, entry.key))
        }, (entry: FolderEntry) => (entry.isNetwork ? 'n_' : 'l_') + entry.key)
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  moveFolderList() {
    Column() {
      ForEach(this.localFolders, (folder: string) => {
        Row() {
          Text(folder)
            .fontSize(15)
            .fontColor(this.moveTargetFolder === folder ?
              $r('app.color.color_emphasize') : $r('app.color.text_primary'))
        }
        .width('100%')
        .padding(12)
        .onClick(() => {
          this.moveTargetFolder = folder;
        })
      }, (folder: string) => folder)
    }
  }

  @Builder
  moveDialogActions() {
    Row() {
      Button(this.tr('Cancel'))
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showMoveDialog = false;
        })
      Button(this.tr('Move'))
        .margin({ left: 8 })
        .onClick(() => this.moveSelectedToFolder())
    }
  }

  @Builder
  favoritesBody() {
    Column() {
      Row() {
        if (this.screenWidth <= TWO_PANEL_WIDTH) {
          SymbolGlyph($r('sys.symbol.line_3_horizontal'))
            .fontSize(22)
            .fontColor([$r('app.color.color_emphasize')])
            .margin({ right: 8 })
            .onClick(() => {
              this.showFolderDrawer = true;
            })
        }
        Text(this.selectedTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.isNetworkMode) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(20)
            .fontColor([$r('app.color.icon_secondary')])
            .onClick(() => this.loadComics(1))
        } else if (!this.multiSelectMode) {
          SymbolGlyph($r('sys.symbol.folder_badge_plus'))
            .fontSize(20)
            .fontColor([$r('app.color.icon_secondary')])
            .margin({ right: 8 })
            .onClick(() => {
              this.showNewFolderDialog = true;
            })
          if (this.selectedFolder !== LOCAL_ALL_FOLDER) {
            SymbolGlyph($r('sys.symbol.funnel'))
              .fontSize(20)
              .fontColor([this.readFilterSelect !== 'All' ?
                $r('app.color.color_emphasize') : $r('app.color.icon_secondary')])
              .margin({ right: 8 })
              .onClick(() => this.cycleReadFilter())
            SymbolGlyph($r('sys.symbol.sort'))
              .fontSize(20)
              .fontColor([$r('app.color.icon_secondary')])
              .margin({ right: 8 })
              .onClick(() => this.openReorderDialog())
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(20)
              .fontColor([$r('app.color.icon_secondary')])
              .onClick(() => {
                this.multiSelectMode = true;
              })
          }
        } else {
          Text(this.tr('Cancel'))
            .fontSize(14)
            .fontColor($r('app.color.color_emphasize'))
            .onClick(() => {
              this.multiSelectMode = false;
              this.selectedKeys = [];
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      if (this.screenWidth <= TWO_PANEL_WIDTH) {
        this.folderChips()
      }

      if (this.isNetworkMode && this.remoteFolders.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            Row() {
              Text(this.tr('All'))
                .fontSize(13)
                .fontColor(this.networkSubfolder.length === 0 ?
                  $r('app.color.color_emphasize') : $r('app.color.text_primary'))
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.networkSubfolder.length === 0 ?
              $r('app.color.badge_bg') : $r('app.color.card_background'))
            .onClick(() => this.selectNetworkSubfolder(''))
            ForEach(this.remoteFolders, (folder: string) => {
              Row() {
                Text(folder)
                  .fontSize(13)
                  .fontColor(this.networkSubfolder === folder ?
                    $r('app.color.color_emphasize') : $r('app.color.text_primary'))
              }
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.networkSubfolder === folder ?
                $r('app.color.badge_bg') : $r('app.color.card_background'))
              .onClick(() => this.selectNetworkSubfolder(folder))
            }, (folder: string) => 'sub_' + folder)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      if (this.multiSelectMode && this.selectedKeys.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            Button(this.tr('Delete'))
              .height(32)
              .fontSize(12)
              .onClick(() => this.deleteSelected())
            if (!this.isNetworkMode) {
              Button(this.tr('Move'))
                .height(32)
                .fontSize(12)
                .onClick(() => {
                  this.moveTargetFolder = this.localFolders.length > 0 ? this.localFolders[0] : '';
                  this.showMoveDialog = true;
                })
              Button(this.tr('Download'))
                .height(32)
                .fontSize(12)
                .onClick(() => this.downloadSelected())
              Button(this.tr('Update Info'))
                .height(32)
                .fontSize(12)
                .onClick(() => this.updateSelectedInfo())
              if (this.selectedFolder !== LOCAL_ALL_FOLDER) {
                Button(this.tr('Reorder'))
                  .height(32)
                  .fontSize(12)
                  .onClick(() => this.reorderSelectedUp())
              }
              Button(this.tr('Export'))
                .height(32)
                .fontSize(12)
                .onClick(() => this.exportSelected())
            }
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      if (this.selectedFolder.length === 0) {
        Column() {
          Text(this.tr('Unselected'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.isLoading) {
        LoadingIndicator()
      } else if (this.errorMessage.length > 0) {
        NetworkError({
          message: this.errorMessage,
          onRetry: () => this.loadComics(1)
        })
      } else if (this.comics.length === 0) {
        Column() {
          Text(this.tr('Folder is empty'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column() {
            ComicGrid({
              comics: this.comics,
              mode: 'brief',
              columns: this.screenWidth > TWO_PANEL_WIDTH ? 4 : 3,
              multiSelectMode: this.multiSelectMode,
              selectedKeys: this.selectedKeys,
              onItemTap: (comic: Comic) => this.onComicTap(comic),
              onItemLongPress: (comic: Comic) => this.onComicLongPress(comic)
            })
            if (this.isNetworkMode && this.hasMore) {
              Button(this.isLoadingMore ? this.tr('Loading...') : this.tr('Load more'))
                .width('80%')
                .margin({ top: 16, bottom: 24 })
                .enabled(!this.isLoadingMore)
                .onClick(() => this.loadComics(this.currentPage + 1))
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .layoutWeight(1)
    .height('100%')
  }

  @Builder
  reorderDialogContent() {
    List() {
      ForEach(this.reorderComicIds, (id: string, index: number) => {
        ListItem() {
          Row() {
            Text(this.comicTitleForId(id))
              .fontSize(14)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_up'))
              .fontSize(16)
              .onClick(() => this.moveReorderUp(index))
          }
          .width('100%')
          .padding(8)
        }
      }, (id: string) => id)
    }
    .width('100%')
    .height(240)
  }

  @Builder
  reorderDialogActions() {
    Button(this.tr('Cancel'))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showReorderDialog = false;
      })
    Button(this.tr('Save'))
      .margin({ left: 8 })
      .onClick(() => this.saveReorder())
  }

  @Builder
  exportDialogContent() {
    Column({ space: 8 }) {
      Button(this.tr('Export as CBZ'))
        .width('100%')
        .onClick(() => this.runExport('cbz'))
      Button(this.tr('Export as PDF'))
        .width('100%')
        .onClick(() => this.runExport('pdf'))
      Button(this.tr('Export as EPUB'))
        .width('100%')
        .onClick(() => this.runExport('epub'))
    }
    .width('100%')
  }

  @Builder
  exportDialogActions() {
    Button(this.tr('Cancel'))
      .onClick(() => {
        this.showExportDialog = false;
        this.pendingExportItems = [];
      })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        if (this.screenWidth > TWO_PANEL_WIDTH) {
          this.folderSidebar()
        }
        this.favoritesBody()
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_old: Area, now: Area) => {
        this.screenWidth = now.width as number;
      })

      if (this.showFolderDrawer && this.screenWidth <= TWO_PANEL_WIDTH) {
        Column() {
          Row() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(22)
              .onClick(() => {
                this.showFolderDrawer = false;
              })
            Text(this.tr('Folders'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding(16)
          Scroll() {
            Column() {
              this.folderSidebar()
            }
          }
          .layoutWeight(1)
        }
        .width(Math.min(300, this.screenWidth - 16))
        .height('100%')
        .backgroundColor($r('app.color.page_background'))
        .shadow({ radius: 12, color: $r('app.color.shadow_light'), offsetX: 4 })
      }

      ContentDialogCustom({
        show: this.showNewFolderDialog,
        title: this.tr('New Folder'),
        content: () => {
          TextInput({ placeholder: this.tr('Folder name'), text: this.newFolderName })
            .width('100%')
            .onChange((v: string) => {
              this.newFolderName = v;
            })
        },
        actions: () => {
          Button(this.tr('Cancel'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showNewFolderDialog = false;
            })
          Button(this.tr('Create'))
            .margin({ left: 8 })
            .onClick(() => this.createFolder())
        },
        onClose: () => {
          this.showNewFolderDialog = false;
        }
      })

      ContentDialogCustom({
        show: this.showMoveDialog,
        title: this.tr('Move to'),
        content: this.moveFolderList,
        actions: this.moveDialogActions,
        onClose: () => {
          this.showMoveDialog = false;
        }
      })

      ContentDialogCustom({
        show: this.showReorderDialog,
        title: this.tr('Reorder'),
        content: this.reorderDialogContent,
        actions: this.reorderDialogActions,
        onClose: () => {
          this.showReorderDialog = false;
        }
      })

      ContentDialogCustom({
        show: this.showExportDialog,
        title: this.tr('Export'),
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
  }
}
