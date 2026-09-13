import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsBridge } from '../bridge/SettingsBridge';
import { UiContextHolder } from '../utils/UiContextHolder';

const TAG: string = 'SettingsAbility';
const DOMAIN: number = 0x0000;

export default class SettingsAbility extends UIAbility {
  private settingsBridge: SettingsBridge = new SettingsBridge();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onCreate');
    UiContextHolder.setHostContext(this.context);
    this.settingsBridge.setContext(this);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onWindowStageCreate');
    UiContextHolder.init(windowStage);
    windowStage.getMainWindow().then((win: window.Window) => {
      this.settingsBridge.setMainWindow(win);
      hilog.info(DOMAIN, TAG, 'MainWindow reference stored in SettingsBridge');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: ' + err.message);
    });
  }

  onForeground(): void {
    UiContextHolder.setHostContext(this.context);
    hilog.info(DOMAIN, TAG, 'SettingsAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onBackground');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onDestroy');
  }
}
