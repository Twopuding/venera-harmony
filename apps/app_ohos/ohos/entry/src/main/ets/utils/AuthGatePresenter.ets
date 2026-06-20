import { router, window } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'AuthGatePresenter';
const DOMAIN: number = 0x0000;
const AUTH_PAGE_URL: string = 'pages/AuthPage';
export const FOREGROUND_ABILITY_KEY: string = 'foregroundAbilityName';

export interface BoundRouterState {
  path?: string;
  name?: string;
  params?: Object;
  index?: number;
}

export class AuthGatePresenter {
  private static abilityContexts: Map<string, common.UIAbilityContext> = new Map();
  private static mainWindow: window.Window | null = null;
  private static presenting: boolean = false;
  private static navigateScheduled: boolean = false;

  static registerAbilityContext(name: string, ctx: common.UIAbilityContext): void {
    AuthGatePresenter.abilityContexts.set(name, ctx);
  }

  static unregisterAbilityContext(name: string): void {
    AuthGatePresenter.abilityContexts.delete(name);
  }

  static registerMainWindow(win: window.Window): void {
    AuthGatePresenter.mainWindow = win;
  }

  static unregisterMainWindow(): void {
    AuthGatePresenter.mainWindow = null;
  }

  static setForegroundAbility(name: string): void {
    AppStorage.setOrCreate<string>(FOREGROUND_ABILITY_KEY, name);
  }

  static resetPresenting(): void {
    AuthGatePresenter.presenting = false;
    AuthGatePresenter.navigateScheduled = false;
  }

  static markPresenting(): void {
    AuthGatePresenter.presenting = true;
  }

  static isPresenting(): boolean {
    return AuthGatePresenter.presenting;
  }

  static readRouterState(): BoundRouterState | null {
    if (AuthGatePresenter.mainWindow === null) {
      return null;
    }
    try {
      return AuthGatePresenter.mainWindow.getUIContext().getRouter().getState() as BoundRouterState;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'readRouterState failed: %{public}s', JSON.stringify(err));
      return null;
    }
  }

  static isOnAuthPage(): boolean {
    let state: BoundRouterState | null = AuthGatePresenter.readRouterState();
    if (state === null) {
      return false;
    }
    return state.path === AUTH_PAGE_URL;
  }

  static navigateToAuthPage(mode: string = 'resume'): void {
    if (AuthGatePresenter.navigateScheduled) {
      return;
    }
    AuthGatePresenter.navigateScheduled = true;

    setTimeout(() => {
      AuthGatePresenter.navigateScheduled = false;
      if (AuthGatePresenter.isOnAuthPage()) {
        AuthGatePresenter.markPresenting();
        hilog.info(DOMAIN, TAG, 'already on AuthPage, skip replaceUrl');
        return;
      }

      if (AuthGatePresenter.mainWindow === null) {
        hilog.error(DOMAIN, TAG, 'no main window for AuthPage navigation');
        return;
      }

      AuthGatePresenter.mainWindow.getUIContext().getRouter().replaceUrl({
        url: AUTH_PAGE_URL,
        params: { mode: mode }
      }, router.RouterMode.Standard, (err: BusinessError) => {
        if (err) {
          AuthGatePresenter.resetPresenting();
          hilog.error(DOMAIN, TAG, 'replaceUrl AuthPage failed: %{public}d %{public}s',
            err.code, err.message);
          return;
        }
        AuthGatePresenter.markPresenting();
        hilog.info(DOMAIN, TAG, 'replaceUrl AuthPage mode=%{public}s', mode);
      });
    }, 0);
  }

  static presentAuthGate(): void {
    if (AuthGatePresenter.isOnAuthPage()) {
      hilog.info(DOMAIN, TAG, 'presentAuthGate skipped, already on AuthPage');
      return;
    }
    if (AuthGatePresenter.presenting) {
      hilog.info(DOMAIN, TAG, 'presentAuthGate skipped, already presenting');
      return;
    }

    let foreground: string = AppStorage.get<string>(FOREGROUND_ABILITY_KEY) ?? 'EntryAbility';
    if (foreground === 'ReaderAbility' || foreground === 'WebViewAbility') {
      let ctx: common.UIAbilityContext | undefined = AuthGatePresenter.abilityContexts.get(foreground);
      if (ctx !== undefined) {
        ctx.terminateSelf();
        hilog.info(DOMAIN, TAG, 'terminateSelf %{public}s for auth gate', foreground);
        AuthGatePresenter.navigateToAuthPage('resume');
        return;
      }
    }
    AuthGatePresenter.navigateToAuthPage('resume');
  }
}
