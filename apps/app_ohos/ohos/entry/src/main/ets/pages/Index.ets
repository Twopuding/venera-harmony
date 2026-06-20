
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos';
import { MainShell } from './MainShell';
import { JsUiHost } from '../components/JsUiHost';
import { DataService, BackendPingResult } from '../service/DataService';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { SettingsMirror } from '../utils/SettingsMirror';
import { PrivacyWindowUtil } from '../utils/PrivacyWindowUtil';
import { AUTH_SESSION_VALID_KEY } from '../utils/AuthLifecycleUtil';
import { AuthGatePresenter } from '../utils/AuthGatePresenter';
import { ShellEvents } from '../utils/ShellEvents';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
const SETTINGS_RETRY_MS = 300
const SETTINGS_MAX_ATTEMPTS = 40

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";
  @State useNativeUi: boolean = true;
  @State settingsReady: boolean = false;
  @State authRequired: boolean = false;
  @StorageLink(AUTH_SESSION_VALID_KEY) @Watch('onAuthSessionChanged') authSessionValid: boolean = false;
  @StorageLink('settingsVersion') @Watch('onSettingsVersionChanged') settingsVersion: number = 0;
  private authRedirectStarted: boolean = false;

  aboutToAppear(): void {
    this.loadSettings(0);
  }

  private loadSettings(attempt: number): void {
    Promise.all([
      DataService.getInstance().getSettings(),
      DataService.getInstance().pingBackend()
    ]).then((results: [Record<string, Object>, BackendPingResult]) => {
      if (!results[1].ok && attempt < SETTINGS_MAX_ATTEMPTS) {
        setTimeout(() => {
          this.loadSettings(attempt + 1);
        }, SETTINGS_RETRY_MS);
        return;
      }
      let settings: Record<string, Object> = results[0];
      if (settings['useNativeUi'] === false) {
        this.useNativeUi = false;
      }
      SettingsMirror.syncFromSettings(settings);
      this.authRequired = SettingsMirror.resolveBool(settings, 'authorizationRequired');
      PrivacyWindowUtil.syncFromAuthRequired(this.authRequired);
      if (!this.authRequired) {
        AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, true);
      }
      this.settingsReady = true;
      this.maybePresentAuthGate();
    }).catch(() => {
      if (attempt < SETTINGS_MAX_ATTEMPTS) {
        setTimeout(() => {
          this.loadSettings(attempt + 1);
        }, SETTINGS_RETRY_MS);
      } else {
        this.settingsReady = true;
        AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, true);
      }
    });
  }

  onAuthSessionChanged(): void {
    if (this.authSessionValid) {
      this.authRedirectStarted = false;
      return;
    }
    if (!this.authRequired || !this.settingsReady) {
      return;
    }
    if (AuthGatePresenter.isOnAuthPage()) {
      return;
    }
    setTimeout(() => {
      if (!this.authSessionValid && this.authRequired && !AuthGatePresenter.isOnAuthPage()) {
        AuthGatePresenter.presentAuthGate();
      }
    }, 150);
  }

  private maybePresentAuthGate(): void {
    if (!this.settingsReady || this.authRedirectStarted) {
      return;
    }
    if (this.authRequired && !this.authSessionValid) {
      this.authRedirectStarted = true;
      AuthGatePresenter.presentAuthGate();
    }
  }

  onSettingsVersionChanged(): void {
    DataService.getInstance().getSettings().then((settings: Record<string, Object>) => {
      let wasRequired: boolean = this.authRequired;
      SettingsMirror.syncFromSettings(settings);
      this.authRequired = SettingsMirror.resolveBool(settings, 'authorizationRequired');
      PrivacyWindowUtil.syncFromAuthRequired(this.authRequired);
      if (this.authRequired && !wasRequired) {
        AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, false);
        this.authRedirectStarted = false;
        AuthGatePresenter.presentAuthGate();
      } else if (!this.authRequired) {
        AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, true);
        this.authRedirectStarted = false;
      }
    });
  }

  build() {
    Stack() {
      if (!this.settingsReady) {
        LoadingIndicator()
      } else if (this.authRequired && !this.authSessionValid) {
        LoadingIndicator()
      } else if (this.useNativeUi) {
        MainShell()
      } else {
        FlutterPage({ viewId: this.viewId })
          .width('100%')
          .height('100%')
      }

      JsUiHost()
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    if (this.authRequired && !this.authSessionValid) {
      let ctx = this.context;
      ctx.terminateSelf();
      return true;
    }
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }

  onPageShow(): void {
    let hasShown: boolean = AppStorage.get<boolean>(ShellEvents.HOME_HAS_SHOWN) ?? false;
    if (hasShown) {
      ShellEvents.bumpCounter(ShellEvents.HOME_RELOAD);
    } else {
      AppStorage.setOrCreate<boolean>(ShellEvents.HOME_HAS_SHOWN, true);
    }
    this.maybeAutoWebDavSync();
  }

  private maybeAutoWebDavSync(): void {
    let now: number = Date.now();
    let last: number = AppStorage.get<number>(ShellEvents.WEBDAV_AUTO_SYNC_KEY) ?? now;
    if (now - last < 10 * 60 * 1000) {
      return;
    }
    AppStorage.setOrCreate<number>(ShellEvents.WEBDAV_AUTO_SYNC_KEY, now);
    DataService.getInstance().getSyncStatus().then((status) => {
      if (status.enabled) {
        DataService.getInstance().webdavDownload();
      }
    });
  }
}
