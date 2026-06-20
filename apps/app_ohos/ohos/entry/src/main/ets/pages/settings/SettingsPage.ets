import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { SETTING_CATEGORIES, SettingCategory } from '../../utils/SettingsConstants';
import { CategoryNavTile } from '../../components/SettingsList';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { HdsTheme } from '../../design/HdsTheme';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct SettingsPage {
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  @Builder
  pageContent() {
    Column() {
      ForEach(SETTING_CATEGORIES, (category: SettingCategory, index: number) => {
        CategoryNavTile({
          title: this.tl(category.key),
          icon: category.icon,
          iconColor: category.iconColor,
          showDivider: index < SETTING_CATEGORIES.length - 1,
          onTap: () => RouterUtil.openSettingsCategory(index)
        })
      }, (category: SettingCategory, index: number) => `${category.key}_${index}`)
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .backgroundBlurStyle(HdsTheme.cardBlurStyle())
    .margin({ top: 0, bottom: 12 })
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tl('Settings'),
        titleMode: HdsTheme.SETTINGS_TITLE_MODE,
        showBack: true,
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
