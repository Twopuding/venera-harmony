import { DataService, FollowUpdatesSummary } from '../../service/DataService';
import { Comic } from '../../model/Comic';
import { ComicGrid } from '../../components/ComicGrid';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../../components/ImmersiveScrollTopInset';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { ContentDialogCustom } from '../../components/ContentDialog';
import { HdsTheme } from '../../design/HdsTheme';
import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct FollowUpdatesPage {
  @State comics: Comic[] = []
  @State summary: FollowUpdatesSummary = { folder: null, count: 0 }
  @State isLoading: boolean = true
  @State isChecking: boolean = false
  @State showFolderDialog: boolean = false
  @State folders: string[] = []
  @State selectedFolder: string = ''
  private scroller: Scroller = new Scroller()
  private context = getContext(this)

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadData();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      this.summary = await DataService.getInstance().getFollowUpdatesSummary();
      this.comics = await DataService.getInstance().getFollowUpdatesList();
    } finally {
      this.isLoading = false;
    }
  }

  private async openFolderSelector(): Promise<void> {
    this.folders = await DataService.getInstance().getFavoriteFolders();
    if (this.folders.length === 0) {
      promptAction.showToast({ message: this.tl('No folders available') });
      return;
    }
    this.selectedFolder = this.summary.folder ?? this.folders[0];
    this.showFolderDialog = true;
  }

  private async confirmFolder(): Promise<void> {
    if (this.selectedFolder.length === 0) {
      return;
    }
    let ok = await DataService.getInstance().setFollowUpdatesFolder(this.selectedFolder);
    this.showFolderDialog = false;
    if (!ok) {
      promptAction.showToast({ message: this.tl('Failed') });
      return;
    }
    await this.loadData();
  }

  private async disableFolder(): Promise<void> {
    await DataService.getInstance().setFollowUpdatesFolder(null);
    this.showFolderDialog = false;
    await this.loadData();
  }

  private async checkUpdates(): Promise<void> {
    if (this.isChecking) {
      return;
    }
    this.isChecking = true;
    await DataService.getInstance().checkFollowUpdates();
    this.isChecking = false;
    await this.loadData();
  }

  private async markRead(comic: Comic): Promise<void> {
    await DataService.getInstance().markFavoriteAsRead(comic.id, comic.sourceKey);
    await this.loadData();
  }

  private getUpdatedComics(): Comic[] {
    let result: Comic[] = [];
    for (let i: number = 0; i < this.comics.length; i++) {
      if (this.comics[i].hasNewUpdate) {
        result.push(this.comics[i]);
      }
    }
    return result;
  }

  private getAllComics(): Comic[] {
    let result: Comic[] = [...this.comics];
    result.sort((a: Comic, b: Comic) => {
      if (a.updateTime.length === 0 && b.updateTime.length === 0) {
        return 0;
      }
      if (a.updateTime.length === 0) {
        return 1;
      }
      if (b.updateTime.length === 0) {
        return -1;
      }
      return b.updateTime.localeCompare(a.updateTime);
    });
    return result;
  }

  private async markAllAsRead(): Promise<void> {
    let updated = this.getUpdatedComics();
    for (let i: number = 0; i < updated.length; i++) {
      await DataService.getInstance().markFavoriteAsRead(updated[i].id, updated[i].sourceKey);
    }
    await this.loadData();
  }

  private pageMenus(): HdsNavigationMenuContentOptions | undefined {
    if (this.summary.folder === null) {
      return undefined;
    }
    return NavigationMenus.single($r('sys.symbol.arrow_clockwise'), this.tl('Check'), () => this.checkUpdates());
  }

  @Builder
  folderDialogContent() {
    Column() {
      Text(this.tl('Folder'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })
      ForEach(this.folders, (folder: string) => {
        Row() {
          Radio({ value: folder, group: 'followFolder' })
            .checked(this.selectedFolder === folder)
            .onChange((checked: boolean) => {
              if (checked) {
                this.selectedFolder = folder;
              }
            })
          Text(folder)
            .fontSize(16)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.selectedFolder = folder;
        })
      }, (folder: string) => folder)
    }
    .width('100%')
  }

  @Builder
  folderDialogActions() {
    if (this.summary.folder !== null) {
      Button(this.tl('Disable'))
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => this.disableFolder())
    }
    Button(this.tl('Cancel'))
      .backgroundColor(Color.Transparent)
      .margin({ left: 8 })
      .onClick(() => {
        this.showFolderDialog = false;
      })
    Button(this.tl('Confirm'))
      .margin({ left: 8 })
      .enabled(this.selectedFolder.length > 0)
      .onClick(() => this.confirmFolder())
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else {
      Scroll(this.scroller) {
        Column() {
          ImmersiveScrollTopInset()

          if (this.summary.folder === null) {
            Column() {
              Text(this.tl('Not Configured'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 8 })
              Text(this.tl('Choose a folder to follow updates.'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .margin({ bottom: 12 })
              Button(this.tl('Choose Folder'))
                .onClick(() => this.openFolderSelector())
            }
            .width('100%')
            .padding(16)
            .margin({ left: 16, right: 16, bottom: 12 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
          } else {
            Column() {
              Row() {
                Text(this.summary.folder)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                Button(this.tl('Change'))
                  .height(28)
                  .fontSize(12)
                  .onClick(() => this.openFolderSelector())
              }
              .width('100%')
              Text(this.tl('Automatic update checking enabled.'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
              if (this.summary.count > 0) {
                Text(TranslationUtil.tlParam('@c updates', 'c', this.summary.count))
                  .fontSize(14)
                  .fontColor($r('app.color.color_emphasize'))
                  .margin({ top: 8 })
                  .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                  .backgroundColor($r('app.color.badge_bg'))
                  .borderRadius(8)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .margin({ left: 16, right: 16, bottom: 12 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
          }

          if (this.comics.length === 0) {
            Text(this.tl('No updates'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(32)
          } else {
            Column() {
              Row() {
                Text(this.tl('Updates'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                if (this.getUpdatedComics().length > 0) {
                  Button(this.tl('Mark all as read'))
                    .height(28)
                    .fontSize(12)
                    .onClick(() => this.markAllAsRead())
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 4 })

              if (this.getUpdatedComics().length === 0) {
                Text(this.tl('No updates found'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
              } else {
                ComicGrid({
                  comics: this.getUpdatedComics(),
                  mode: 'brief',
                  columns: 3,
                  onItemTap: (comic: Comic) => {
                    RouterUtil.openComicDetail(comic.id, comic.sourceKey);
                  },
                  onItemLongPress: (comic: Comic) => {
                    this.markRead(comic);
                  }
                })
              }

              Text(this.tl('All'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .padding({ left: 16, right: 16, top: 16, bottom: 8 })

              ComicGrid({
                comics: this.getAllComics(),
                mode: 'brief',
                columns: 3,
                onItemTap: (comic: Comic) => {
                  RouterUtil.openComicDetail(comic.id, comic.sourceKey);
                },
                onItemLongPress: (comic: Comic) => {
                  this.markRead(comic);
                }
              })
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl('Follow Updates'),
        showBack: true,
        scrollable: false,
        pageScroller: this.scroller,
        onBack: () => RouterUtil.back(),
        menus: this.pageMenus(),
        content: () => {
          this.pageContent()
        }
      })

      ContentDialogCustom({
        show: this.showFolderDialog,
        title: this.tl('Choose Folder'),
        content: this.folderDialogContent,
        actions: this.folderDialogActions,
        onClose: () => {
          this.showFolderDialog = false;
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
