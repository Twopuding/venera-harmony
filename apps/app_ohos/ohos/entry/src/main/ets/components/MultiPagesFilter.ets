import { ContentDialogCustom } from './ContentDialog';
import { ComicSourceInfo } from '../service/DataService';

export interface PageOption {
  key: string;
  label: string;
}

export class PageOptionsBuilder {
  static explorePages(sources: ComicSourceInfo[]): PageOption[] {
    let result: PageOption[] = [];
    for (let i: number = 0; i < sources.length; i++) {
      let source: ComicSourceInfo = sources[i];
      for (let j: number = 0; j < source.explorePages.length; j++) {
        let title: string = source.explorePages[j];
        result.push({ key: title, label: `${title} (${source.name})` });
      }
    }
    return result;
  }

  static categoryPages(sources: ComicSourceInfo[]): PageOption[] {
    let result: PageOption[] = [];
    for (let i: number = 0; i < sources.length; i++) {
      let source: ComicSourceInfo = sources[i];
      if (source.categoryKey !== undefined && source.categoryKey.length > 0) {
        result.push({
          key: source.categoryKey,
          label: source.categoryTitle ?? source.categoryKey
        });
      }
    }
    return result;
  }

  static networkFavoritePages(sources: ComicSourceInfo[]): PageOption[] {
    let result: PageOption[] = [];
    for (let i: number = 0; i < sources.length; i++) {
      let source: ComicSourceInfo = sources[i];
      if (source.favoriteKey !== undefined && source.favoriteKey.length > 0 &&
        source.hasNetworkFavorite === true) {
        result.push({
          key: source.favoriteKey,
          label: source.favoriteTitle ?? source.favoriteKey
        });
      }
    }
    return result;
  }

  static searchSources(sources: ComicSourceInfo[]): PageOption[] {
    let result: PageOption[] = [];
    for (let i: number = 0; i < sources.length; i++) {
      let source: ComicSourceInfo = sources[i];
      if (source.hasSearch === true) {
        result.push({ key: source.key, label: source.name });
      }
    }
    return result;
  }

  static labelFor(options: PageOption[], key: string): string {
    for (let i: number = 0; i < options.length; i++) {
      if (options[i].key === key) {
        return options[i].label;
      }
    }
    return key;
  }
}

@Component
export struct MultiPagesFilterDialog {
  @Prop show: boolean = false
  @Prop title: string = ''
  @Prop options: PageOption[] = []
  @Prop selectedKeys: string[] = []
  onClose: (() => void) | null = null
  onSave: ((keys: string[]) => void) | null = null
  @State keys: string[] = []
  @State showAddDialog: boolean = false
  @State addSelection: string[] = []

  aboutToAppear(): void {
    this.keys = [...this.selectedKeys];
  }

  aboutToUpdate(): void {
    if (this.show && this.keys.length === 0 && this.selectedKeys.length > 0) {
      this.keys = [...this.selectedKeys];
    }
  }

  private availableToAdd(): PageOption[] {
    let result: PageOption[] = [];
    for (let i: number = 0; i < this.options.length; i++) {
      let opt: PageOption = this.options[i];
      if (this.keys.indexOf(opt.key) < 0) {
        result.push(opt);
      }
    }
    return result;
  }

  private toggleAddSelection(key: string): void {
    let idx = this.addSelection.indexOf(key);
    if (idx >= 0) {
      this.addSelection = this.addSelection.filter((k: string) => k !== key);
    } else {
      this.addSelection = [...this.addSelection, key];
    }
  }

  private confirmAdd(): void {
    this.keys = [...this.keys, ...this.addSelection];
    this.addSelection = [];
    this.showAddDialog = false;
  }

  private moveUp(index: number): void {
    if (index <= 0) {
      return;
    }
    let next: string[] = [...this.keys];
    let temp = next[index - 1];
    next[index - 1] = next[index];
    next[index] = temp;
    this.keys = next;
  }

  private moveDown(index: number): void {
    if (index >= this.keys.length - 1) {
      return;
    }
    let next: string[] = [...this.keys];
    let temp = next[index + 1];
    next[index + 1] = next[index];
    next[index] = temp;
    this.keys = next;
  }

  @Builder
  mainContent() {
    Column() {
      if (this.keys.length === 0) {
        Text('No items')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(16)
      } else {
        List() {
          ForEach(this.keys, (key: string, index: number) => {
            ListItem() {
              Row() {
                Text(PageOptionsBuilder.labelFor(this.options, key))
                  .fontSize(14)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                SymbolGlyph($r('sys.symbol.chevron_up'))
                  .fontSize(16)
                  .margin({ left: 4 })
                  .onClick(() => this.moveUp(index))
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(16)
                  .margin({ left: 4 })
                  .onClick(() => this.moveDown(index))
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(16)
                  .fontColor([$r('app.color.text_secondary')])
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.keys = this.keys.filter((k: string) => k !== key);
                  })
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 10, bottom: 10 })
            }
          }, (key: string) => key)
        }
        .width('100%')
        .height(240)
      }
      if (this.availableToAdd().length > 0) {
        Button('Add')
          .width('100%')
          .margin({ top: 8 })
          .onClick(() => {
            this.addSelection = [];
            this.showAddDialog = true;
          })
      }
    }
    .width('100%')
  }

  @Builder
  mainActions() {
    Button('Cancel')
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        if (this.onClose !== null) {
          this.onClose!();
        }
      })
    Button('Save')
      .margin({ left: 8 })
      .onClick(() => {
        if (this.onSave !== null) {
          this.onSave!(this.keys);
        }
      })
  }

  @Builder
  addDialogContent() {
    Scroll() {
      Column() {
        ForEach(this.availableToAdd(), (opt: PageOption) => {
          Row() {
            Checkbox({ name: opt.key, group: 'addPages' })
              .select(this.addSelection.indexOf(opt.key) >= 0)
              .onChange((checked: boolean) => {
                if (checked) {
                  if (this.addSelection.indexOf(opt.key) < 0) {
                    this.addSelection = [...this.addSelection, opt.key];
                  }
                } else {
                  this.toggleAddSelection(opt.key);
                }
              })
            Text(opt.label)
              .fontSize(14)
              .layoutWeight(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .onClick(() => this.toggleAddSelection(opt.key))
        }, (opt: PageOption) => opt.key)
      }
      .width('100%')
    }
    .width('100%')
    .height(200)
  }

  @Builder
  addDialogActions() {
    Button('Cancel')
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showAddDialog = false;
        this.addSelection = [];
      })
    Button('Add')
      .margin({ left: 8 })
      .enabled(this.addSelection.length > 0)
      .onClick(() => this.confirmAdd())
  }

  build() {
    Stack() {
      ContentDialogCustom({
        show: this.show,
        title: this.title,
        content: this.mainContent,
        actions: this.mainActions,
        onClose: () => {
          if (this.onClose !== null) {
            this.onClose!();
          }
        }
      })

      ContentDialogCustom({
        show: this.showAddDialog,
        title: 'Add',
        content: this.addDialogContent,
        actions: this.addDialogActions,
        onClose: () => {
          this.showAddDialog = false;
          this.addSelection = [];
        }
      })
    }
  }
}
