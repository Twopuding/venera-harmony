import { DataService, HistoryItem } from '../../service/DataService';
import { ComicTile } from '../../components/ComicTile';
import { Comic } from '../../model/Comic';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { ContentDialog } from '../../components/ContentDialog';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';

@Entry
@Component
struct HistoryPage {
  @State histories: HistoryItem[] = []
  @State isLoading: boolean = true
  @State multiSelectMode: boolean = false
  @State selectedKeys: string[] = []
  @State showClearDialog: boolean = false
  @State refreshingKey: string = ''
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadHistory();
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private historyKey(item: HistoryItem): string {
    return `${item.sourceKey}:${item.id}`;
  }

  private isSelected(item: HistoryItem): boolean {
    return this.selectedKeys.indexOf(this.historyKey(item)) >= 0;
  }

  private toggleSelection(item: HistoryItem): void {
    let key = this.historyKey(item);
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

  private async loadHistory(): Promise<void> {
    this.isLoading = true;
    try {
      this.histories = await DataService.getInstance().getHistory();
    } finally {
      this.isLoading = false;
    }
  }

  private historyToComic(h: HistoryItem): Comic {
    let c: Comic = new Comic();
    c.id = h.id;
    c.title = h.title;
    c.subtitle = h.subtitle;
    c.cover = h.cover;
    c.sourceKey = h.sourceKey;
    c.description = this.formatProgress(h);
    return c;
  }

  private formatProgress(h: HistoryItem): string {
    let parts: string[] = [];
    if (h.ep >= 1) {
      parts.push(`Ch.${h.ep}`);
    }
    if (h.page >= 1) {
      parts.push(`P.${h.page}`);
    }
    return parts.join(' · ');
  }

  private openHistoryItem(item: HistoryItem): void {
    let ep: string = item.ep >= 1 ? String(item.ep) : '1';
    RouterUtil.openReader(item.id, item.sourceKey, ep, item.page >= 1 ? item.page : 1);
  }

  private async refreshHistoryItem(item: HistoryItem): Promise<void> {
    let key: string = this.historyKey(item);
    this.refreshingKey = key;
    try {
      let ok: boolean = await DataService.getInstance().refreshHistory(item.id, item.sourceKey);
      if (ok) {
        promptAction.showToast({ message: this.tr('Refresh Success') });
        await this.loadHistory();
      } else {
        promptAction.showToast({ message: this.tr('Refresh Failed') });
      }
    } finally {
      this.refreshingKey = '';
    }
  }

  private async deleteSelected(): Promise<void> {
    for (let key of this.selectedKeys) {
      let parts = key.split(':');
      if (parts.length >= 2) {
        let sourceKey = parts[0];
        let id = parts.slice(1).join(':');
        await DataService.getInstance().deleteHistory(id, sourceKey);
      }
    }
    this.selectedKeys = [];
    this.multiSelectMode = false;
    await this.loadHistory();
  }

  private async clearAll(): Promise<void> {
    await DataService.getInstance().clearAllHistory();
    this.showClearDialog = false;
    await this.loadHistory();
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
      return NavigationMenus.single($r('sys.symbol.trash'), this.tr('Delete'), () => {
        if (this.selectedKeys.length > 0) {
          this.deleteSelected();
        }
      });
    }
    return NavigationMenus.fromEntries([
      {
        icon: $r('sys.symbol.list_bullet'),
        label: this.tr('Select'),
        action: () => {
          this.multiSelectMode = true;
        }
      },
      {
        icon: $r('sys.symbol.trash'),
        label: this.tr('Clear history'),
        action: () => {
          this.showClearDialog = true;
        }
      }
    ]);
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.histories.length === 0) {
      Text(this.tr('No history'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ top: 48 })
        .textAlign(TextAlign.Center)
    } else {
      List() {
        ForEach(this.histories, (item: HistoryItem) => {
          ListItem() {
            Row() {
              if (this.multiSelectMode) {
                Checkbox()
                  .select(this.isSelected(item))
                  .margin({ right: 8 })
              }
              ComicTile({
                comic: this.historyToComic(item),
                mode: 'detailed',
                onTap: () => {
                  if (this.multiSelectMode) {
                    this.toggleSelection(item);
                  } else {
                    this.openHistoryItem(item);
                  }
                },
                onLongPress: () => {
                  if (!this.multiSelectMode) {
                    this.multiSelectMode = true;
                    this.toggleSelection(item);
                  }
                }
              })
                .layoutWeight(1)
              if (!this.multiSelectMode) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(20)
                  .fontColor([$r('app.color.icon_secondary')])
                  .margin({ left: 8 })
                  .opacity(this.refreshingKey === this.historyKey(item) ? 0.4 : 1)
                  .onClick(() => this.refreshHistoryItem(item))
              }
            }
            .width('100%')
            .padding({ left: 8, right: 8, bottom: 8 })
          }
        }, (item: HistoryItem) => this.historyKey(item))
      }
      .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.multiSelectMode ? `${this.selectedKeys.length}` : this.tr('History'),
        showBack: true,
        scrollable: false,
        onBack: () => this.handleBack(),
        menus: this.pageMenus(),
        content: () => {
          this.pageContent()
        }
      })

      ContentDialog({
        title: this.tr('Clear history'),
        message: this.tr('Are you sure you want to clear all history?'),
        confirmLabel: this.tr('Clear'),
        show: this.showClearDialog,
        onClose: () => {
          this.showClearDialog = false;
        },
        onConfirm: () => this.clearAll()
      })
    }
    .width('100%')
    .height('100%')
  }
}
