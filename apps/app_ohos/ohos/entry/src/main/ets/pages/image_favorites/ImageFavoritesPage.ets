import router from '@ohos.router';
import { DataService, ImageFavoriteSummary } from '../../service/DataService';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';

@Entry
@Component
struct ImageFavoritesPage {
  @State items: ImageFavoriteSummary[] = []
  @State keyword: string = ''
  @State isLoading: boolean = true
  @State multiSelectMode: boolean = false
  @State selectedIds: string[] = []
  @State allItems: ImageFavoriteSummary[] = []
  @State sortType: string = 'title'
  @State minImageCount: number = 0
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    let keyword = params['initialKeyword'];
    if (keyword !== undefined && keyword.length > 0) {
      this.keyword = keyword;
    }
    this.loadItems();
  }

  private itemKey(item: ImageFavoriteSummary): string {
    return `${item.sourceKey}:${item.id}`;
  }

  private isSelected(item: ImageFavoriteSummary): boolean {
    return this.selectedIds.indexOf(this.itemKey(item)) >= 0;
  }

  private selectAll(): void {
    this.selectedIds = this.items.map((item: ImageFavoriteSummary) => this.itemKey(item));
  }

  private toggleSelection(item: ImageFavoriteSummary): void {
    let key = this.itemKey(item);
    let index = this.selectedIds.indexOf(key);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
      this.selectedIds = [...this.selectedIds];
    } else {
      this.selectedIds.push(key);
      this.selectedIds = [...this.selectedIds];
    }
    if (this.selectedIds.length === 0) {
      this.multiSelectMode = false;
    }
  }

  private async loadItems(): Promise<void> {
    this.isLoading = true;
    try {
      let kw = this.keyword.trim();
      this.allItems = await DataService.getInstance().getImageFavorites(
        kw.length > 0 ? kw : undefined
      );
      this.applySortFilter();
    } finally {
      this.isLoading = false;
    }
  }

  private applySortFilter(): void {
    let list: ImageFavoriteSummary[] = this.allItems.slice();
    if (this.minImageCount > 0) {
      list = list.filter((item: ImageFavoriteSummary) => item.imageCount >= this.minImageCount);
    }
    if (this.sortType === 'title') {
      list.sort((a: ImageFavoriteSummary, b: ImageFavoriteSummary) => a.title.localeCompare(b.title));
    } else if (this.sortType === 'count') {
      list.sort((a: ImageFavoriteSummary, b: ImageFavoriteSummary) => b.imageCount - a.imageCount);
    } else {
      list.reverse();
    }
    this.items = list;
  }

  private cycleSort(): void {
    if (this.sortType === 'title') {
      this.sortType = 'count';
    } else if (this.sortType === 'count') {
      this.sortType = 'time';
    } else {
      this.sortType = 'title';
    }
    this.applySortFilter();
  }

  private async deleteSelected(): Promise<void> {
    let bySource: Record<string, string[]> = {};
    for (let key of this.selectedIds) {
      let parts = key.split(':');
      if (parts.length >= 2) {
        let sourceKey = parts[0];
        let id = parts.slice(1).join(':');
        if (bySource[sourceKey] === undefined) {
          bySource[sourceKey] = [];
        }
        bySource[sourceKey].push(id);
      }
    }
    let keys = Object.keys(bySource);
    for (let i: number = 0; i < keys.length; i++) {
      await DataService.getInstance().deleteImageFavorites(bySource[keys[i]], keys[i]);
    }
    this.selectedIds = [];
    this.multiSelectMode = false;
    await this.loadItems();
  }

  private handleBack(): void {
    if (this.multiSelectMode) {
      this.multiSelectMode = false;
      this.selectedIds = [];
    } else {
      RouterUtil.back();
    }
  }

  private pageMenus(): HdsNavigationMenuContentOptions | undefined {
    if (this.multiSelectMode) {
      return NavigationMenus.fromEntries([
        {
          icon: $r('sys.symbol.checkmark_circle'),
          label: this.tr('Select all'),
          action: () => this.selectAll()
        },
        {
          icon: $r('sys.symbol.xmark_circle'),
          label: this.tr('Clear selection'),
          action: () => {
            this.selectedIds = [];
            this.multiSelectMode = false;
          }
        },
        {
          icon: $r('sys.symbol.trash'),
          label: this.tr('Delete'),
          action: () => {
            if (this.selectedIds.length > 0) {
              this.deleteSelected();
            }
          }
        }
      ]);
    }
    return NavigationMenus.fromEntries([
      {
        icon: $r('sys.symbol.arrow_clockwise'),
        label: this.tr('Sort'),
        action: () => this.cycleSort()
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
      Row() {
        TextInput({ placeholder: 'Search', text: this.keyword })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => this.loadItems())
        Button('Go')
          .margin({ left: 8 })
          .onClick(() => this.loadItems())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.isLoading) {
        LoadingIndicator()
      } else if (this.items.length === 0) {
        Text('No image favorites')
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.items, (item: ImageFavoriteSummary) => {
            ListItem() {
              Row() {
                if (this.multiSelectMode) {
                  Checkbox()
                    .select(this.isSelected(item))
                    .margin({ right: 8 })
                }
                Column() {
                  Text(item.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (item.subTitle.length > 0) {
                    Text(item.subTitle)
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 4 })
                  }
                  Text(`${item.imageCount} images`)
                    .fontSize(11)
                    .fontColor($r('app.color.color_emphasize'))
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(8)
              .margin({ bottom: 8 })
              .onClick(() => {
                if (this.multiSelectMode) {
                  this.toggleSelection(item);
                } else {
                  RouterUtil.openImageFavoritesPhoto(item.id, item.sourceKey, item.title);
                }
              })
            }
          }, (item: ImageFavoriteSummary) => this.itemKey(item))
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.multiSelectMode ? `${this.selectedIds.length}` : this.tr('Image Favorites'),
        showBack: true,
        scrollable: false,
        onBack: () => this.handleBack(),
        menus: this.pageMenus(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
