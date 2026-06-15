import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { FlutterBridge } from '../bridge/FlutterBridge';
import { ReaderBridge } from '../bridge/ReaderBridge';
import { WebViewBridge } from '../bridge/WebViewBridge';
import { SettingsBridge } from '../bridge/SettingsBridge';
import { PlatformBridge } from '../bridge/PlatformBridge';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0000;

export default class EntryAbility extends FlutterAbility {
  private readerBridge: ReaderBridge = new ReaderBridge();
  private webViewBridge: WebViewBridge = new WebViewBridge();
  private settingsBridge: SettingsBridge = new SettingsBridge();
  private platformBridge: PlatformBridge = new PlatformBridge();

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    bridge.configureFlutterEngine(flutterEngine);
    this.readerBridge.setContext(this);
    this.readerBridge.register();
    this.webViewBridge.setContext(this);
    this.webViewBridge.register();
    this.settingsBridge.setContext(this);
    this.settingsBridge.register();
    this.platformBridge.setContext(this);
    this.platformBridge.register();
    hilog.info(DOMAIN, TAG, 'All bridge channels registered');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
    windowStage.getMainWindow().then((win: window.Window) => {
      this.settingsBridge.setMainWindow(win);
      this.platformBridge.setMainWindow(win);
      hilog.info(DOMAIN, TAG, 'MainWindow reference stored');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: ' + err.message);
    });
  }
}
