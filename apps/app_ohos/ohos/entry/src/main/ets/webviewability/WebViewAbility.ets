import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'WebViewAbility';
const DOMAIN: number = 0x0000;
const STORAGE_KEY_URL: string = 'webview_target_url';

export default class WebViewAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'WebViewAbility onCreate');
    let storedUrl: string | undefined = AppStorage.get<string>(STORAGE_KEY_URL);
    let url: string = storedUrl !== undefined ? storedUrl : '';
    hilog.info(DOMAIN, TAG, 'Target URL from AppStorage: ' + url);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'WebViewAbility onWindowStageCreate');
    windowStage.loadContent('pages/WebViewPage', (err, data) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load WebViewPage: ' + err.message);
        return;
      }
      hilog.info(DOMAIN, TAG, 'WebViewPage loaded successfully');
    });
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      hilog.info(DOMAIN, TAG, 'WebView window set to full screen');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: ' + err.message);
    });
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'WebViewAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'WebViewAbility onBackground');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'WebViewAbility onDestroy');
  }
}
