import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import {
  DataService,
  CommentInfo,
  CommentsLoadResult,
  AddFavoriteRequest
} from '../../service/DataService';
import { ComicCoverImage } from '../../components/ComicCoverImage';
import { ComicGrid } from '../../components/ComicGrid';
import { Comic, ComicChapters } from '../../model/Comic';
import { TranslationUtil } from '../../utils/TranslationUtil';
import promptAction from '@ohos.promptAction';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { ImmersiveScrollTopInset } from '../../components/ImmersiveScrollTopInset';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { ContentDialogCustom } from '../../components/ContentDialog';
import { RouterUtil } from '../../navigation/RouterUtil';
import { HdsTheme } from '../../design/HdsTheme';
import { PlatformUtil } from '../../utils/PlatformUtil';

@Entry
@Component
struct ComicDetailPage {
  @State comicId: string = ''
  @State sourceKey: string = ''
  @State title: string = ''
  @State subtitle: string = ''
  @State cover: string = ''
  @State description: string = ''
  @State tags: string[] = []
  @State chapterIds: string[] = []
  @State chapterTitles: string[] = []
  @State comments: CommentInfo[] = []
  @State hasComments: boolean = false
  @State isLoading: boolean = true
  @State errorMessage: string = ''
  @State showFavoriteDialog: boolean = false
  @State favoriteFolders: string[] = []
  @State selectedFolder: string = ''
  @State actionMessage: string = ''
  @State isLiked: boolean = false
  @State canLike: boolean = false
  @State thumbnails: string[] = []
  @State showDownloadDialog: boolean = false
  @State selectedChapterIndices: number[] = []
  @State inFavoriteFolder: string = ''
  @State recommendComics: Comic[] = []
  @State chapterModel: ComicChapters | null = null
  @State expandedGroups: string[] = []
  private scroller: Scroller = new Scroller()
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.comicId = params['comicId'] ?? '';
    this.sourceKey = params['sourceKey'] ?? '';
    this.loadComic();
  }

  private async loadComic(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      let result = await DataService.getInstance().loadComicInfo(this.sourceKey, this.comicId);
      if (result?.error !== undefined) {
        this.errorMessage = result.error;
        return;
      }
      let comicData = result?.comic;
      if (comicData === undefined) {
        this.errorMessage = 'Comic not found';
        return;
      }
      this.title = comicData.title ?? '';
      this.subtitle = comicData.subTitle ?? comicData.subtitle ?? '';
      this.cover = comicData.cover ?? '';
      this.description = comicData.description ?? '';
      this.tags = comicData.tags ?? [];
      if (comicData.chapters !== undefined) {
        this.chapterModel = this.parseChapters(comicData.chapters as Record<string, Object>);
        this.chapterIds = this.chapterModel.ids;
        this.chapterTitles = this.chapterModel.titles;
      }
      this.isLiked = comicData.isLiked === true;
      this.canLike = comicData.isLiked !== undefined;
      this.thumbnails = await DataService.getInstance().loadThumbnails(this.sourceKey, this.comicId);
      if (comicData.recommend !== undefined) {
        this.recommendComics = comicData.recommend.map((item) => {
          let c: Comic = new Comic();
          c.id = item.id ?? '';
          c.title = item.title ?? '';
          c.cover = item.cover ?? '';
          c.subtitle = item.subTitle ?? item.subtitle ?? '';
          c.sourceKey = item.sourceKey ?? this.sourceKey;
          c.tags = item.tags ?? [];
          return c;
        });
      }
      await this.loadCommentsPreview();
      await this.detectFavoriteFolder();
    } catch (e) {
      this.errorMessage = 'Failed to load comic';
    } finally {
      this.isLoading = false;
    }
  }

  private async loadCommentsPreview(): Promise<void> {
    let result: CommentsLoadResult = await DataService.getInstance().loadComments(
      this.sourceKey, this.comicId, 1
    );
    if (result.error === undefined && result.comments.length > 0) {
      this.comments = result.comments.slice(0, 5);
      this.hasComments = true;
    }
  }

  private async detectFavoriteFolder(): Promise<void> {
    let folders: string[] = await DataService.getInstance().getFavoriteFolders();
    for (let i: number = 0; i < folders.length; i++) {
      let comics = await DataService.getInstance().getFavorites(folders[i]);
      for (let j: number = 0; j < comics.length; j++) {
        if (comics[j].id === this.comicId && comics[j].sourceKey === this.sourceKey) {
          this.inFavoriteFolder = folders[i];
          return;
        }
      }
    }
    this.inFavoriteFolder = '';
  }

  private async toggleLike(): Promise<void> {
    let ok: boolean = await DataService.getInstance().likeComic(
      this.sourceKey, this.comicId, !this.isLiked
    );
    if (ok) {
      this.isLiked = !this.isLiked;
    }
  }

  private async removeFromFavorites(): Promise<void> {
    if (this.inFavoriteFolder.length === 0) {
      return;
    }
    let ok: boolean = await DataService.getInstance().removeFavorite(
      this.inFavoriteFolder, this.comicId, this.sourceKey
    );
    if (ok) {
      this.inFavoriteFolder = '';
      this.actionMessage = 'Removed from favorites';
    }
  }

  private openDownloadDialog(): void {
    this.selectedChapterIndices = [];
    for (let i: number = 0; i < this.chapterIds.length; i++) {
      this.selectedChapterIndices.push(i + 1);
    }
    this.showDownloadDialog = true;
  }

  private toggleChapterSelect(index: number): void {
    let ep: number = index + 1;
    let idx: number = this.selectedChapterIndices.indexOf(ep);
    if (idx >= 0) {
      this.selectedChapterIndices = this.selectedChapterIndices.filter((v: number) => v !== ep);
    } else {
      this.selectedChapterIndices = this.selectedChapterIndices.concat([ep]);
    }
  }

  private async downloadSelectedChapters(): Promise<void> {
    this.showDownloadDialog = false;
    let ok = await DataService.getInstance().startDownload(
      this.sourceKey, this.comicId, this.selectedChapterIndices
    );
    this.actionMessage = ok ? 'Download started' : 'Failed to start download';
  }

  private async startDownload(): Promise<void> {
    let ok = await DataService.getInstance().startDownload(this.sourceKey, this.comicId);
    this.actionMessage = ok ? 'Download started' : 'Failed to start download';
  }

  private async openFavoriteDialog(): Promise<void> {
    this.favoriteFolders = await DataService.getInstance().getFavoriteFolders();
    if (this.favoriteFolders.length === 0) {
      this.actionMessage = 'No favorite folders';
      return;
    }
    this.selectedFolder = this.favoriteFolders[0];
    this.showFavoriteDialog = true;
  }

  private async addFavorite(): Promise<void> {
    let params: AddFavoriteRequest = {
      folder: this.selectedFolder,
      sourceKey: this.sourceKey,
      id: this.comicId,
      title: this.title,
      cover: this.cover,
      author: this.subtitle,
      tags: this.tags
    };
    let ok = await DataService.getInstance().addFavorite(params);
    this.showFavoriteDialog = false;
    this.actionMessage = ok ? this.tr('Added to favorites') : this.tr('Failed to add favorite');
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private parseChapters(raw: Record<string, Object>): ComicChapters {
    let keys: string[] = Object.keys(raw);
    if (keys.length === 0) {
      return ComicChapters.fromFlatChapters({});
    }
    let firstVal: Object = raw[keys[0]];
    if (typeof firstVal === 'object' && firstVal !== null && !Array.isArray(firstVal)) {
      let groups: Record<string, Record<string, string>> = {};
      for (let i: number = 0; i < keys.length; i++) {
        let groupName: string = keys[i];
        let groupRaw: Record<string, Object> = raw[groupName] as Record<string, Object>;
        let flatGroup: Record<string, string> = {};
        let groupKeys: string[] = Object.keys(groupRaw);
        for (let j: number = 0; j < groupKeys.length; j++) {
          flatGroup[groupKeys[j]] = String(groupRaw[groupKeys[j]]);
        }
        groups[groupName] = flatGroup;
      }
      return ComicChapters.fromGroupedChapters(groups);
    }
    let flat: Record<string, string> = {};
    for (let i: number = 0; i < keys.length; i++) {
      flat[keys[i]] = String(raw[keys[i]]);
    }
    return ComicChapters.fromFlatChapters(flat);
  }

  private toggleGroup(groupName: string): void {
    let idx: number = this.expandedGroups.indexOf(groupName);
    if (idx >= 0) {
      this.expandedGroups.splice(idx, 1);
    } else {
      this.expandedGroups.push(groupName);
    }
    this.expandedGroups = [...this.expandedGroups];
  }

  private isGroupExpanded(groupName: string): boolean {
    return this.expandedGroups.indexOf(groupName) >= 0;
  }

  private groupChapterIds(groupName: string): string[] {
    if (this.chapterModel === null) {
      return [];
    }
    return Object.keys(this.chapterModel.getGroupChapters(groupName));
  }

  private shareComic(): void {
    let text: string = this.title;
    if (this.subtitle.length > 0) {
      text += '\n' + this.subtitle;
    }
    PlatformUtil.shareText(this.context, text);
  }

  @Builder
  commentCard(comment: CommentInfo) {
    Column() {
      Text(comment.userName)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(comment.content)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })
    }
    .width(200)
    .padding(12)
    .margin({ right: 8 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(8)
  }

  @Builder
  favoriteFolderList() {
    Column() {
      ForEach(this.favoriteFolders, (folder: string) => {
        Text(folder)
          .fontSize(14)
          .fontColor(this.selectedFolder === folder ?
            $r('app.color.color_emphasize') : $r('app.color.text_primary'))
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(this.selectedFolder === folder ?
            $r('app.color.badge_bg') : Color.Transparent)
          .borderRadius(8)
          .onClick(() => {
            this.selectedFolder = folder;
          })
      }, (folder: string) => folder)
    }
  }

  @Builder
  favoriteDialogActions() {
    Row() {
      Button('Cancel')
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => {
          this.showFavoriteDialog = false;
        })
      Button('Add')
        .margin({ left: 8 })
        .onClick(() => this.addFavorite())
    }
  }

  @Builder
  downloadChapterList() {
    Column() {
      ForEach(this.chapterIds, (id: string, index: number) => {
        Row() {
          Text(this.chapterTitles[index])
            .fontSize(14)
            .layoutWeight(1)
          Checkbox({ name: id, group: 'chapters' })
            .select(this.selectedChapterIndices.indexOf(index + 1) >= 0)
            .onChange((checked: boolean) => {
              this.toggleChapterSelect(index);
            })
        }
        .width('100%')
        .padding(8)
      }, (id: string) => id)
    }
  }

  @Builder
  downloadDialogActions() {
    Row() {
      Button('Cancel')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showDownloadDialog = false;
        })
      Button('Download')
        .margin({ left: 8 })
        .onClick(() => this.downloadSelectedChapters())
    }
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.errorMessage.length > 0) {
      NetworkError({
        message: this.errorMessage,
        onRetry: () => this.loadComic()
      })
    } else {
      Scroll(this.scroller) {
        Column() {
          ImmersiveScrollTopInset()
          ComicCoverImage({
                coverUrl: this.cover,
                sourceKey: this.sourceKey,
                comicId: this.comicId,
                coverRadius: 8
              })
                .width('60%')
                .aspectRatio(0.64)
                .margin({ bottom: 16 })
                .sharedTransition(`${this.sourceKey}:${this.comicId}`,
                  { duration: 300, curve: Curve.EaseInOut })
                .onClick(() => {
                  RouterUtil.openCoverViewer(this.cover, this.sourceKey, this.comicId);
                })

              if (this.canLike) {
                Button(this.isLiked ? 'Unlike' : 'Like')
                  .width('90%')
                  .margin({ bottom: 12 })
                  .onClick(() => this.toggleLike())
              }

              if (this.thumbnails.length > 0) {
                Text('Preview')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .width('90%')
                  .margin({ bottom: 8 })
                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.thumbnails, (thumb: string, index: number) => {
                      ComicCoverImage({
                        coverUrl: thumb,
                        sourceKey: this.sourceKey,
                        comicId: this.comicId,
                        coverRadius: 4
                      })
                        .width(80)
                        .height(120)
                    }, (thumb: string, index: number) => thumb + index.toString())
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
                .padding({ left: 16 })
                .margin({ bottom: 16 })
              }

              if (this.subtitle.length > 0) {
                Text(this.subtitle)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('90%')
                  .margin({ bottom: 8 })
              }

              if (this.tags.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tags.slice(0, 8), (tag: string) => {
                    Text(tag)
                      .fontSize(11)
                      .fontColor($r('app.color.text_secondary'))
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .margin(4)
                      .borderRadius(4)
                      .backgroundColor($r('app.color.tag_bg'))
                  }, (tag: string) => tag)
                }
                .width('90%')
                .margin({ bottom: 12 })
              }

              if (this.description.length > 0) {
                Text(this.description)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .width('90%')
                  .margin({ bottom: 16 })
              }

              Row() {
                Button('Read')
                  .layoutWeight(1)
                  .onClick(() => {
                    RouterUtil.openReader(this.comicId, this.sourceKey);
                  })
                Button('Download')
                  .layoutWeight(1)
                  .margin({ left: 8 })
                  .onClick(() => {
                    if (this.chapterIds.length > 1) {
                      this.openDownloadDialog();
                    } else {
                      this.startDownload();
                    }
                  })
                if (this.inFavoriteFolder.length > 0) {
                  Button('Unfavorite')
                    .layoutWeight(1)
                    .margin({ left: 8 })
                    .onClick(() => this.removeFromFavorites())
                } else {
                  Button('Favorite')
                    .layoutWeight(1)
                    .margin({ left: 8 })
                    .onClick(() => this.openFavoriteDialog())
                }
              }
              .width('90%')
              .margin({ bottom: 16 })

              if (this.actionMessage.length > 0) {
                Text(this.actionMessage)
                  .fontSize(12)
                  .fontColor($r('app.color.color_emphasize'))
                  .width('90%')
                  .margin({ bottom: 12 })
              }

              if (this.chapterModel !== null && this.chapterModel.length > 0) {
                Text(this.tr('Chapters'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .width('90%')
                  .margin({ bottom: 8 })

                if (this.chapterModel.isGrouped) {
                  ForEach(this.chapterModel.groups, (groupName: string) => {
                    Column() {
                      Row() {
                        Text(groupName)
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                          .layoutWeight(1)
                        SymbolGlyph(this.isGroupExpanded(groupName) ?
                          $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
                          .fontSize(16)
                          .fontColor([$r('app.color.icon_secondary')])
                      }
                      .width('90%')
                      .padding(12)
                      .backgroundColor($r('app.color.card_background'))
                      .borderRadius(8)
                      .onClick(() => this.toggleGroup(groupName))

                      if (this.isGroupExpanded(groupName)) {
                        ForEach(this.groupChapterIds(groupName), (id: string) => {
                          Row() {
                            Text(this.chapterModel!.getChapterTitle(id))
                              .fontSize(14)
                              .fontColor($r('app.color.text_primary'))
                              .layoutWeight(1)
                            SymbolGlyph($r('sys.symbol.chevron_right'))
                              .fontSize(16)
                              .fontColor([$r('app.color.icon_secondary')])
                          }
                          .width('90%')
                          .padding(12)
                          .backgroundColor($r('app.color.card_background'))
                          .borderRadius(8)
                          .margin({ bottom: 8 })
                          .onClick(() => {
                            RouterUtil.openReader(this.comicId, this.sourceKey, id, 1);
                          })
                        }, (id: string) => groupName + id)
                      }
                    }
                    .width('100%')
                    .margin({ bottom: 8 })
                  }, (groupName: string) => groupName)
                } else {
                  ForEach(this.chapterIds, (id: string, index: number) => {
                    Row() {
                      Text(this.chapterTitles[index])
                        .fontSize(14)
                        .fontColor($r('app.color.text_primary'))
                        .layoutWeight(1)
                      SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontSize(16)
                        .fontColor([$r('app.color.icon_secondary')])
                    }
                    .width('90%')
                    .padding(12)
                    .backgroundColor($r('app.color.card_background'))
                    .borderRadius(8)
                    .margin({ bottom: 8 })
                    .onClick(() => {
                      RouterUtil.openReader(this.comicId, this.sourceKey, id, 1);
                    })
                  }, (id: string) => id)
                }
              }

              if (this.recommendComics.length > 0) {
                Text('Related')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .width('90%')
                  .margin({ top: 8, bottom: 8 })
                ComicGrid({
                  comics: this.recommendComics,
                  mode: 'brief',
                  columns: 3,
                  onItemTap: (comic: Comic) => {
                    RouterUtil.openComicDetail(comic.id, comic.sourceKey);
                  }
                })
                  .width('90%')
                  .margin({ bottom: 16 })
              }

              if (this.hasComments) {
                Row() {
                  Text('Comments')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .layoutWeight(1)
                  Text('See all')
                    .fontSize(14)
                    .fontColor($r('app.color.color_emphasize'))
                    .onClick(() => {
                      RouterUtil.openComments(this.comicId, this.sourceKey);
                    })
                }
                .width('90%')
                .margin({ top: 8, bottom: 8 })

                Scroll() {
                  Row() {
                    ForEach(this.comments, (comment: CommentInfo) => {
                      this.commentCard(comment)
                    }, (comment: CommentInfo) => comment.id)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
                .padding({ left: 16 })
                .margin({ bottom: 16 })
              }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 32 })
      }
      .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.title,
        showBack: true,
        scrollable: false,
        pageScroller: this.scroller,
        onBack: () => RouterUtil.back(),
        menus: NavigationMenus.single($r('sys.symbol.share'), this.tr('Share'), () => this.shareComic()),
        content: () => {
          this.pageContent()
        }
      })

      if (this.showFavoriteDialog) {
        Row() {
          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showFavoriteDialog = false;
            })
          Column() {
            Row() {
              Text(this.tr('Add to favorites'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Text(this.tr('Close'))
                .fontSize(14)
                .fontColor($r('app.color.color_emphasize'))
                .onClick(() => {
                  this.showFavoriteDialog = false;
                })
            }
            .width('100%')
            .padding(16)
            this.favoriteFolderList()
            Row() {
              Button(this.tr('Cancel'))
                .backgroundColor(Color.Transparent)
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.showFavoriteDialog = false;
                })
              Button(this.tr('Add'))
                .margin({ left: 8 })
                .onClick(() => this.addFavorite())
            }
            .width('100%')
            .padding(16)
          }
          .width('75%')
          .height('100%')
          .backgroundColor($r('app.color.card_background'))
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }

      ContentDialogCustom({
        title: 'Download chapters',
        show: this.showDownloadDialog,
        onClose: () => {
          this.showDownloadDialog = false;
        },
        content: this.downloadChapterList,
        actions: this.downloadDialogActions
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
