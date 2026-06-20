import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrivacyWindowUtil } from '../utils/PrivacyWindowUtil';
import { AuthGatePresenter } from '../utils/AuthGatePresenter';

const DOMAIN = 0x0000;
const TAG = 'ReaderAbility';

export default class ReaderAbility extends UIAbility {
  private win: window.Window | null = null;
  private safeAreaTop: number = 0;
  private safeAreaBottom: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'ReaderAbility onCreate');
    AuthGatePresenter.registerAbilityContext('ReaderAbility', this.context);

    const params = want.parameters;
    let comicId: string = '';
    let sourceKey: string = '';
    let initialEp: number = 0;
    let initialPage: number = 0;
    if (params !== undefined && params !== null) {
      const cid = params['comicId'];
      if (cid !== undefined && cid !== null) {
        comicId = cid.toString();
      }
      const sk = params['sourceKey'];
      if (sk !== undefined && sk !== null) {
        sourceKey = sk.toString();
      }
      const ep = params['initialEp'];
      if (ep !== undefined && ep !== null) {
        initialEp = Number(ep);
      }
      const pg = params['initialPage'];
      if (pg !== undefined && pg !== null) {
        initialPage = Number(pg);
      }
    }

    AppStorage.setOrCreate('reader_comicId', comicId);
    AppStorage.setOrCreate('reader_sourceKey', sourceKey);
    AppStorage.setOrCreate('reader_initialEp', initialEp);
    AppStorage.setOrCreate('reader_initialPage', initialPage);

    hilog.info(DOMAIN, TAG,
      'Reader params: comicId=' + comicId +
      ' sourceKey=' + sourceKey +
      ' ep=' + initialEp.toString() +
      ' page=' + initialPage.toString());
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'ReaderAbility onWindowStageCreate');

    windowStage.getMainWindow().then((win: window.Window) => {
      this.win = win;
      PrivacyWindowUtil.registerWindow(win);
      PrivacyWindowUtil.syncFromCache();
      win.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(DOMAIN, TAG, 'Set full screen success');
        const systemArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.safeAreaTop = px2vp(systemArea.topRect.height);
        const navArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        this.safeAreaBottom = px2vp(navArea.bottomRect.height);

        AppStorage.setOrCreate('reader_safeAreaTop', this.safeAreaTop);
        AppStorage.setOrCreate('reader_safeAreaBottom', this.safeAreaBottom);

        hilog.info(DOMAIN, TAG,
          'Safe area top=' + this.safeAreaTop.toString() +
          ' bottom=' + this.safeAreaBottom.toString());
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Set full screen failed: ' + err.message);
      });

      const sysBarProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        isStatusBarLightIcon: false
      };
      win.setWindowSystemBarProperties(sysBarProps);

      win.showWindow();
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Get main window failed: ' + err.message);
    });

    windowStage.loadContent('pages/ReaderPage', (err, data) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Load content failed');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Load content success');
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'ReaderAbility onDestroy');
    AuthGatePresenter.unregisterAbilityContext('ReaderAbility');
    this.win = null;
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'ReaderAbility onWindowStageDestroy');
  }

  onForeground(): void {
    AuthGatePresenter.setForegroundAbility('ReaderAbility');
    hilog.info(DOMAIN, TAG, 'ReaderAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'ReaderAbility onBackground');
  }
}
