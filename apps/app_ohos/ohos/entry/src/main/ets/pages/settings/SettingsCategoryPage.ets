import router from '@ohos.router';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { HdsTheme } from '../../design/HdsTheme';
import { SETTING_CATEGORIES } from '../../utils/SettingsConstants';
import { SettingsCategoryContent } from './SettingsCategoryContent';
import { common } from '@kit.AbilityKit';

interface SettingsCategoryRouteParams {
  categoryIndex?: number;
}

@Entry
@Component
struct SettingsCategoryPage {
  @State categoryIndex: number = 0
  @State pageShowVersion: number = 0
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as SettingsCategoryRouteParams;
    if (params !== undefined && params.categoryIndex !== undefined) {
      let index = Number(params.categoryIndex);
      if (isNaN(index)) {
        index = 0;
      }
      if (index < 0) {
        index = 0;
      }
      if (index >= SETTING_CATEGORIES.length) {
        index = SETTING_CATEGORIES.length - 1;
      }
      this.categoryIndex = index;
    }
  }

  onPageShow(): void {
    this.pageShowVersion++;
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  @Builder
  pageContent() {
    if (this.categoryIndex === 6) {
      SettingsCategoryContent({ categoryIndex: this.categoryIndex, pageShowVersion: this.pageShowVersion })
        .width('100%')
        .height('100%')
    } else {
      SettingsCategoryContent({ categoryIndex: this.categoryIndex, pageShowVersion: this.pageShowVersion })
        .width('100%')
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl(SETTING_CATEGORIES[this.categoryIndex].key),
        titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE,
        showBack: true,
        scrollable: this.categoryIndex !== 6,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
