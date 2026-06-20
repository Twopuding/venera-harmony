import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsMirror } from './SettingsMirror';

const TAG: string = 'PrivacyWindowUtil';
const DOMAIN: number = 0x0000;

export class PrivacyWindowUtil {
  private static windows: window.Window[] = [];
  private static privacyEnabled: boolean = false;

  static init(win: window.Window): void {
    PrivacyWindowUtil.registerWindow(win);
  }

  static registerWindow(win: window.Window): void {
    let exists: boolean = false;
    for (let i = 0; i < PrivacyWindowUtil.windows.length; i++) {
      if (PrivacyWindowUtil.windows[i] === win) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      PrivacyWindowUtil.windows.push(win);
    }
    if (PrivacyWindowUtil.privacyEnabled) {
      win.setWindowPrivacyMode(true).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setWindowPrivacyMode on register failed: %{public}s', err.message);
      });
    }
  }

  static setPrivacyEnabled(enabled: boolean): void {
    if (PrivacyWindowUtil.windows.length === 0) {
      PrivacyWindowUtil.privacyEnabled = enabled;
      return;
    }
    if (PrivacyWindowUtil.privacyEnabled === enabled) {
      return;
    }
    PrivacyWindowUtil.privacyEnabled = enabled;
    for (let i = 0; i < PrivacyWindowUtil.windows.length; i++) {
      let win: window.Window = PrivacyWindowUtil.windows[i];
      win.setWindowPrivacyMode(enabled).then(() => {
        hilog.info(DOMAIN, TAG, 'setWindowPrivacyMode=%{public}s window=%{public}d',
          enabled.toString(), i);
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setWindowPrivacyMode failed: %{public}s', err.message);
      });
    }
  }

  static syncFromAuthRequired(authRequired: boolean): void {
    PrivacyWindowUtil.setPrivacyEnabled(authRequired);
  }

  static syncFromCache(): void {
    let authRequired: boolean =
      SettingsMirror.resolveBool(SettingsMirror.readCache(), 'authorizationRequired');
    PrivacyWindowUtil.syncFromAuthRequired(authRequired);
  }
}
