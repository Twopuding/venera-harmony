import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RouterUtil } from '../navigation/RouterUtil';
import { AuthGate } from '../components/AuthGate';
import { AUTH_SESSION_VALID_KEY } from '../utils/AuthLifecycleUtil';
import { AuthGatePresenter } from '../utils/AuthGatePresenter';
import {
  AuthResumeSnapshot,
  AuthSnapshotData,
  SHELL_RESTORE_TAB_KEY
} from '../utils/AuthResumeSnapshot';

const TAG: string = 'AuthPage';
const DOMAIN: number = 0x0000;
const INDEX_PAGE_URL: string = 'pages/Index';

interface AuthPageParams {
  mode?: string;
}

@Entry
@Component
struct AuthPage {
  @State mode: string = 'resume';
  @State pageShowTick: number = 0;

  aboutToAppear(): void {
    AuthGatePresenter.markPresenting();

    let params = this.getUIContext().getRouter().getParams() as AuthPageParams;
    if (params?.mode !== undefined && params.mode.length > 0) {
      this.mode = params.mode;
    }
    let sessionValid: boolean = AppStorage.get<boolean>(AUTH_SESSION_VALID_KEY) ?? false;
    if (sessionValid && this.mode === 'resume') {
      this.restoreAfterAuth();
    }
  }

  onPageShow(): void {
    this.pageShowTick++;
  }

  private onAuthSuccess(): void {
    AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, true);
    AuthGatePresenter.resetPresenting();
    if (this.mode === 'manual') {
      RouterUtil.back();
      return;
    }
    this.restoreAfterAuth();
  }

  private restoreAfterAuth(): void {
    let snapshot: AuthSnapshotData | null = AuthResumeSnapshot.consume();
    let bound = this.getUIContext().getRouter();

    if (snapshot !== null && snapshot.kind === 'router') {
      let routerUrl: string = snapshot.url;
      let fallbackTab: number = snapshot.shellTab ?? 0;
      if (snapshot.shellTab !== undefined) {
        AppStorage.setOrCreate<number>(SHELL_RESTORE_TAB_KEY, snapshot.shellTab);
      }
      bound.replaceUrl({
        url: routerUrl,
        params: snapshot.params
      }, router.RouterMode.Standard, (err: BusinessError) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'restore router failed: %{public}d %{public}s', err.code, err.message);
          this.replaceIndex(fallbackTab);
          return;
        }
        hilog.info(DOMAIN, TAG, 'restored router url=%{public}s', routerUrl);
      });
      return;
    }

    let shellTab: number = 0;
    if (snapshot !== null && snapshot.kind === 'shell') {
      shellTab = snapshot.shellTab;
    }
    this.replaceIndex(shellTab);
  }

  private replaceIndex(shellTab: number): void {
    AppStorage.setOrCreate<number>(SHELL_RESTORE_TAB_KEY, shellTab);
    this.getUIContext().getRouter().replaceUrl({
      url: INDEX_PAGE_URL
    }, router.RouterMode.Standard, (err: BusinessError) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'replaceUrl Index failed: %{public}d %{public}s', err.code, err.message);
        return;
      }
      hilog.info(DOMAIN, TAG, 'restored Index shellTab=%{public}d', shellTab);
    });
  }

  build() {
    Column() {
      AuthGate({
        pageShowTick: this.pageShowTick,
        onAuthSuccess: () => {
          this.onAuthSuccess();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
