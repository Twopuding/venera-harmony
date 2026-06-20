import { SettingsMirror } from './SettingsMirror';
import { AUTH_SESSION_VALID_KEY } from './AuthLifecycleUtil';
import { AuthGatePresenter } from './AuthGatePresenter';

export class AuthSessionGuard {
  static shouldBlock(): boolean {
    let authRequired: boolean =
      SettingsMirror.resolveBool(SettingsMirror.readCache(), 'authorizationRequired');
    if (!authRequired) {
      return false;
    }
    let sessionValid: boolean = AppStorage.get<boolean>(AUTH_SESSION_VALID_KEY) ?? false;
    return !sessionValid;
  }

  static redirectIfNeeded(): void {
    if (AuthSessionGuard.shouldBlock()) {
      AuthGatePresenter.presentAuthGate();
    }
  }
}
