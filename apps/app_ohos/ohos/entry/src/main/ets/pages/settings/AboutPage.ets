import { RouterUtil } from '../../navigation/RouterUtil';
import { DataService } from '../../service/DataService';
import { TranslationUtil } from '../../utils/TranslationUtil';
import { ContentDialogCustom } from '../../components/ContentDialog';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { HdsTheme } from '../../design/HdsTheme';
import { SettingsSection, ActionSettingTile } from '../../components/SettingsList';
import { PROJECT_REPO_URL } from '../../utils/SettingsConstants';
import { PlatformUtil } from '../../utils/PlatformUtil';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct AboutPage {
  @State appVersion: string = ''
  @State isCheckingUpdate: boolean = false
  @State showUpdateDialog: boolean = false
  @State latestVersion: string = ''
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.appVersion = PlatformUtil.getAppVersionName(this.context);
    DataService.getInstance().getAppInfo().then((info) => {
      let version = info.version ?? '';
      if (version.length > 0) {
        this.appVersion = version;
      }
    }).catch(() => {
    });
  }

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async checkForUpdate(): Promise<void> {
    if (this.isCheckingUpdate) {
      return;
    }
    this.isCheckingUpdate = true;
    try {
      let result = await DataService.getInstance().checkForUpdate();
      if (result.hasUpdate === true) {
        this.latestVersion = result.latestVersion ?? '';
        this.showUpdateDialog = true;
      } else {
        promptAction.showToast({ message: this.tr('No new version available') });
      }
    } finally {
      this.isCheckingUpdate = false;
    }
  }

  @Builder
  updateDialogActions() {
    Row() {
      Button(this.tr('Cancel'))
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showUpdateDialog = false;
        })
      Button(this.tr('Update'))
        .margin({ left: 8 })
        .onClick(() => {
          this.showUpdateDialog = false;
          RouterUtil.launchUrl('https://github.com/venera-app/venera/releases');
        })
    }
  }

  @Builder
  aboutIntroBlock() {
    Column() {
      Image($r('app.media.icon'))
        .width(80)
        .height(80)
        .borderRadius(16)
        .margin({ bottom: 12 })
      Text('Venera')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 4 })
      Text(`V${this.appVersion}`)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })
      Text(this.tr('Venera is a free and open-source app for comic reading.'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width('90%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  pageContent() {
    Column() {
      Blank().layoutWeight(2)

      this.aboutIntroBlock()

      Blank().layoutWeight(1)

      SettingsSection({
        content: () => {
          ActionSettingTile({
            title: this.isCheckingUpdate ? '...' : this.tr('Check for updates'),
            actionLabel: '',
            onAction: () => this.checkForUpdate()
          })
          ActionSettingTile({
            title: 'GitHub',
            actionLabel: this.tr('Open'),
            showDivider: false,
            onAction: () => RouterUtil.launchUrl(PROJECT_REPO_URL)
          })
        }
      })

      Blank().layoutWeight(3)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tr('About'),
        titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE,
        showBack: true,
        scrollable: false,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })

      ContentDialogCustom({
        title: this.tr('New version available'),
        show: this.showUpdateDialog,
        onClose: () => {
          this.showUpdateDialog = false;
        },
        content: () => {
          Text(this.tr('A new version is available. Do you want to update now?'))
            .fontSize(14)
            .width('100%')
        },
        actions: this.updateDialogActions
      })
    }
    .width('100%')
    .height('100%')
  }
}
