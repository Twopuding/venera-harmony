import { DataService } from '../service/DataService';
import { ImmersivePageScaffold } from '../components/ImmersivePageScaffold';
import { NavigationMenus } from '../navigation/NavigationMenus';
import { RouterUtil } from '../navigation/RouterUtil';
import { TranslationUtil } from '../utils/TranslationUtil';
import { CodeEditor } from '../components/CodeEditor';
import { HdsTheme } from '../design/HdsTheme';
import { UiContextHolder } from '../utils/UiContextHolder';

@Entry
@Component
struct ComicSourceEditPage {
  @State sourceKey: string = ''
  @State content: string = ''
  @State isLoading: boolean = true
  @State isSaving: boolean = false
  private context = UiContextHolder.hostContext()

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.loadFile();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async loadFile(): Promise<void> {
    this.isLoading = true;
    let text: string | null = await DataService.getInstance().readComicSourceFile(this.sourceKey);
    this.content = text ?? '';
    this.isLoading = false;
  }

  private async saveFile(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    let ok: boolean = await DataService.getInstance().saveComicSourceFile(this.sourceKey, this.content);
    this.isSaving = false;
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: this.tl('Saved') });
      RouterUtil.back();
    } else {
      this.getUIContext().getPromptAction().showToast({ message: this.tl('Failed') });
    }
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingProgress()
        .width('100%')
        .layoutWeight(1)
    } else {
      CodeEditor({
        content: this.content,
        onChange: (v: string) => {
          this.content = v;
        }
      })
        .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl('Edit Script'),
        titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE,
        showBack: true,
        scrollable: false,
        onBack: () => RouterUtil.back(),
        menus: NavigationMenus.single($r('sys.symbol.checkmark'), this.tl('Save'), () => this.saveFile()),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
