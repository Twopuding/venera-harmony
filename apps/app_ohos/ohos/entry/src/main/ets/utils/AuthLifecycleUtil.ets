import { UIAbility, ApplicationStateChangeCallback } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsMirror } from './SettingsMirror';
import { PrivacyWindowUtil } from './PrivacyWindowUtil';
import { AuthGatePresenter } from './AuthGatePresenter';
import { AuthResumeSnapshot } from './AuthResumeSnapshot';

const TAG: string = 'AuthLifecycleUtil';
const DOMAIN: number = 0x0000;
export const AUTH_SESSION_VALID_KEY: string = 'authSessionValid';
export const AUTH_RESUME_PENDING_KEY: string = 'authResumePending';

export class AuthLifecycleUtil {
  private static registered: boolean = false;

  static init(ability: UIAbility): void {
    if (AuthLifecycleUtil.registered) {
      return;
    }
    AuthLifecycleUtil.registered = true;

    let callback: ApplicationStateChangeCallback = {
      onApplicationForeground: () => {
        AuthLifecycleUtil.handleApplicationForeground();
      },
      onApplicationBackground: () => {
        AuthLifecycleUtil.handleApplicationBackground();
      }
    };

    try {
      let appContext = ability.context.getApplicationContext();
      appContext.on('applicationStateChange', callback);
      hilog.info(DOMAIN, TAG, 'applicationStateChange registered');
    } catch (paramError) {
      let err = paramError as BusinessError;
      hilog.error(DOMAIN, TAG, 'register failed: %{public}d %{public}s', err.code, err.message);
    }
  }

  private static handleApplicationBackground(): void {
    let authRequired: boolean =
      SettingsMirror.resolveBool(SettingsMirror.readCache(), 'authorizationRequired');
    if (authRequired) {
      AuthResumeSnapshot.save();
      AppStorage.setOrCreate<boolean>(AUTH_RESUME_PENDING_KEY, true);
      PrivacyWindowUtil.setPrivacyEnabled(true);
    }
    hilog.info(DOMAIN, TAG, 'application background, authRequired=%{public}s',
      authRequired.toString());
  }

  private static handleApplicationForeground(): void {
    let authRequired: boolean =
      SettingsMirror.resolveBool(SettingsMirror.readCache(), 'authorizationRequired');
    let pending: boolean = AppStorage.get<boolean>(AUTH_RESUME_PENDING_KEY) ?? false;
    if (authRequired && pending) {
      AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, false);
      AuthGatePresenter.resetPresenting();
      setTimeout(() => {
        AuthGatePresenter.presentAuthGate();
      }, 120);
    }
    AppStorage.setOrCreate<boolean>(AUTH_RESUME_PENDING_KEY, false);
    hilog.info(DOMAIN, TAG, 'application foreground, authRequired=%{public}s pending=%{public}s',
      authRequired.toString(), pending.toString());
  }
}
