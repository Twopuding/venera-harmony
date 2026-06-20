import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { FlutterBridge } from '../bridge/FlutterBridge';
import { ReaderBridge } from '../bridge/ReaderBridge';
import { WebViewBridge } from '../bridge/WebViewBridge';
import { SettingsBridge } from '../bridge/SettingsBridge';
import { PlatformBridge } from '../bridge/PlatformBridge';
import { DataBridge } from '../bridge/DataBridge';
import { JsUiBridge } from '../bridge/JsUiBridge';
import { RouterUtil } from '../navigation/RouterUtil';
import { DataService } from '../service/DataService';
import { Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SafeAreaUtil } from '../utils/SafeAreaUtil';
import { PrivacyWindowUtil } from '../utils/PrivacyWindowUtil';
import { AuthLifecycleUtil, AUTH_SESSION_VALID_KEY, AUTH_RESUME_PENDING_KEY } from '../utils/AuthLifecycleUtil';
import { AuthGatePresenter } from '../utils/AuthGatePresenter';
import { AuthSessionGuard } from '../utils/AuthSessionGuard';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0000;

export default class EntryAbility extends FlutterAbility {
  private readerBridge: ReaderBridge = ReaderBridge.getInstance();
  private webViewBridge: WebViewBridge = WebViewBridge.getInstance();
  private settingsBridge: SettingsBridge = new SettingsBridge();
  private platformBridge: PlatformBridge = new PlatformBridge();
  private dataBridge: DataBridge = DataBridge.getInstance();
  private jsUiBridge: JsUiBridge = new JsUiBridge();

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    bridge.configureFlutterEngine(flutterEngine);
    this.dataBridge.register();
    this.readerBridge.setContext(this);
    this.readerBridge.register();
    this.webViewBridge.setContext(this);
    this.webViewBridge.register();
    this.settingsBridge.setContext(this);
    this.settingsBridge.register();
    this.platformBridge.setContext(this);
    this.platformBridge.register();
    this.jsUiBridge.register();
    hilog.info(DOMAIN, TAG, 'All bridge channels registered');
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    AuthLifecycleUtil.init(this);
    AuthGatePresenter.registerAbilityContext('EntryAbility', this.context);
    AuthGatePresenter.setForegroundAbility('EntryAbility');
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
    AppStorage.setOrCreate<boolean>(AUTH_SESSION_VALID_KEY, false);
    AppStorage.setOrCreate<boolean>(AUTH_RESUME_PENDING_KEY, false);
    windowStage.getMainWindow().then((win: window.Window) => {
      SafeAreaUtil.init(win);
      PrivacyWindowUtil.init(win);
      AuthGatePresenter.registerMainWindow(win);
      win.setWindowBackgroundColor('#FFF1F3F5');
      this.settingsBridge.setMainWindow(win);
      this.platformBridge.setMainWindow(win);
      hilog.info(DOMAIN, TAG, 'MainWindow reference stored');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: ' + err.message);
    });
  }

  onForeground(): void {
    AuthGatePresenter.setForegroundAbility('EntryAbility');
    hilog.info(DOMAIN, TAG, 'App moved to foreground');
  }

  onDestroy(): void {
    AuthGatePresenter.unregisterAbilityContext('EntryAbility');
    AuthGatePresenter.unregisterMainWindow();
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }

  onNewWant(want: Want): void {
    if (AuthSessionGuard.shouldBlock()) {
      AuthGatePresenter.presentAuthGate();
      return;
    }
    let uri: string | undefined = want.uri;
    if (uri !== undefined && uri.length > 0) {
      DataService.getInstance().resolveComicLink(uri).then((link) => {
        if (link?.found === true && link.comicId !== undefined && link.sourceKey !== undefined) {
          RouterUtil.openComicDetail(link.comicId, link.sourceKey);
        }
      });
      return;
    }
    let params = want.parameters;
    if (params !== undefined) {
      let sharedText: string | undefined = params['ohos.extra.param.key.text'] as string;
      if (sharedText === undefined) {
        sharedText = params['ability.params.stream'] as string;
      }
      if (sharedText !== undefined && sharedText.length > 0) {
        RouterUtil.openAggregatedSearch(sharedText.trim());
      }
    }
  }
}
