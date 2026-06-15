import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsBridge } from '../bridge/SettingsBridge';

const TAG: string = 'SettingsAbility';
const DOMAIN: number = 0x0000;

export default class SettingsAbility extends UIAbility {
  private settingsBridge: SettingsBridge = new SettingsBridge();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onCreate');
    this.settingsBridge.setContext(this);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onWindowStageCreate');
    windowStage.getMainWindow().then((win: window.Window) => {
      this.settingsBridge.setMainWindow(win);
      hilog.info(DOMAIN, TAG, 'MainWindow reference stored in SettingsBridge');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: ' + err.message);
    });
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onBackground');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'SettingsAbility onDestroy');
  }
}
