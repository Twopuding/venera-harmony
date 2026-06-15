import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL_NAME: string = 'com.venera.settings';
const TAG: string = 'SettingsBridge';
const DOMAIN: number = 0x0000;

export class SettingsBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;
  private mainWindow: window.Window | null = null;
  private keepScreenOn: boolean = false;

  setContext(context: UIAbility): void {
    this.context = context;
  }

  setMainWindow(win: window.Window): void {
    this.mainWindow = win;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'authenticate') {
      this.handleAuthenticate(result);
    } else if (call.method === 'pickDirectory') {
      this.handlePickDirectory(result);
    } else if (call.method === 'pickFile') {
      this.handlePickFile(result);
    } else if (call.method === 'setKeepScreenOn') {
      this.handleSetKeepScreenOn(call, result);
    } else if (call.method === 'getProxy') {
      this.handleGetProxy(result);
    } else if (call.method === 'saveFile') {
      this.handleSaveFile(call, result);
    } else {
      result.notImplemented();
    }
  }

  private handleAuthenticate(result: MethodResult): void {
    let challenge: Uint8Array = new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7]);
    let authType: number = userAuth.UserAuthType.PIN | userAuth.UserAuthType.FACE;
    let trustLevel: number = userAuth.AuthTrustLevel.ATL1;
    try {
      let authInstance: userAuth.AuthInstance = userAuth.getAuthInstance(challenge, authType, trustLevel);
      authInstance.on('result', {
        callback: (info: userAuth.AuthResultInfo) => {
          if (info.result === userAuth.UserAuthResultCode.SUCCESS) {
            result.success(true);
          } else {
            result.success(false);
          }
        }
      });
      authInstance.start();
      hilog.info(DOMAIN, TAG, 'Authentication started');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Authentication failed');
      result.success(false);
    }
  }

  private handlePickDirectory(result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    try {
      let documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.select(documentSelectOptions).then((selectResult: Array<string>) => {
        if (selectResult.length > 0) {
          hilog.info(DOMAIN, TAG, 'Directory selected: ' + selectResult[0]);
          result.success(selectResult[0]);
        } else {
          result.success('');
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Pick directory failed: ' + err.message);
        result.error('ERROR', 'Pick directory failed', err.message);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Pick directory exception');
      result.error('ERROR', 'Pick directory exception', null);
    }
  }

  private handlePickFile(result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    try {
      let documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.select(documentSelectOptions).then((selectResult: Array<string>) => {
        if (selectResult.length > 0) {
          hilog.info(DOMAIN, TAG, 'File selected: ' + selectResult[0]);
          result.success(selectResult[0]);
        } else {
          result.success('');
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Pick file failed: ' + err.message);
        result.error('ERROR', 'Pick file failed', err.message);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Pick file exception');
      result.error('ERROR', 'Pick file exception', null);
    }
  }

  private handleSetKeepScreenOn(call: BridgeMethodCall, result: MethodResult): void {
    if (this.mainWindow === null) {
      result.error('ERROR', 'MainWindow is null', null);
      return;
    }
    let isKeepScreenOn: boolean = this.keepScreenOn;
    if (call.args !== null) {
      let param: SetKeepScreenOnParams = this.parseKeepScreenOnArgs(call.args);
      isKeepScreenOn = param.keepScreenOn;
    }
    this.mainWindow.setWindowKeepScreenOn(isKeepScreenOn).then(() => {
      this.keepScreenOn = isKeepScreenOn;
      hilog.info(DOMAIN, TAG, 'Set keep screen on: ' + isKeepScreenOn.toString());
      result.success(true);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Set keep screen on failed: ' + err.message);
      result.error('ERROR', 'Set keep screen on failed', err.message);
    });
  }

  private parseKeepScreenOnArgs(args: Object): SetKeepScreenOnParams {
    let result: SetKeepScreenOnParams = {
      keepScreenOn: false
    };
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: SetKeepScreenOnParams = JSON.parse(jsonStr);
      if (parsed.keepScreenOn !== undefined && parsed.keepScreenOn !== null) {
        result.keepScreenOn = parsed.keepScreenOn;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse keepScreenOn args');
    }
    return result;
  }

  private handleGetProxy(result: MethodResult): void {
    let proxyInfo: ProxyInfoResult = {
      host: '',
      port: 0
    };
    result.success(proxyInfo);
  }

  private handleSaveFile(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let saveParams: SaveFileParsedParams = this.parseSaveFileArgs(call.args);
    try {
      let documentSaveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [saveParams.fileName];
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.save(documentSaveOptions).then((saveResult: Array<string>) => {
        if (saveResult.length > 0) {
          let destUri: string = saveResult[0];
          fileIo.copyFileSync(saveParams.srcUri, destUri);
          hilog.info(DOMAIN, TAG, 'File saved to: ' + destUri);
          result.success(destUri);
        } else {
          result.success('');
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Save file failed: ' + err.message);
        result.error('ERROR', 'Save file failed', err.message);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Save file exception');
      result.error('ERROR', 'Save file exception', null);
    }
  }

  private parseSaveFileArgs(args: Object | null): SaveFileParsedParams {
    let result: SaveFileParsedParams = {
      srcUri: '',
      fileName: 'download'
    };
    if (args === null) {
      return result;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: SaveFileParsedParams = JSON.parse(jsonStr);
      if (parsed.srcUri !== undefined && parsed.srcUri !== null) {
        result.srcUri = parsed.srcUri;
      }
      if (parsed.fileName !== undefined && parsed.fileName !== null) {
        result.fileName = parsed.fileName;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse saveFile args');
    }
    return result;
  }
}

interface ProxyInfoResult {
  host: string;
  port: number;
}

interface SetKeepScreenOnParams {
  keepScreenOn: boolean;
}

interface SaveFileParsedParams {
  srcUri: string;
  fileName: string;
}
