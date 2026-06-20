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
    } else if (call.method === 'authenticateWithFace') {
      this.handleAuthWithType(userAuth.UserAuthType.FACE, result);
    } else if (call.method === 'authenticateWithFingerprint') {
      this.handleAuthWithType(userAuth.UserAuthType.FINGERPRINT, result);
    } else if (call.method === 'authenticateWithPin') {
      this.handleAuthWithType(userAuth.UserAuthType.PIN, result);
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
    this.handleAuthWithType(userAuth.UserAuthType.FACE, result);
  }

  private handleAuthWithType(authType: userAuth.UserAuthType, result: MethodResult): void {
    let challenge: Uint8Array = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);
    let authTrustLevel: userAuth.AuthTrustLevel = userAuth.AuthTrustLevel.ATL2;
    if (authType === userAuth.UserAuthType.PIN) {
      authTrustLevel = userAuth.AuthTrustLevel.ATL1;
    }
    let authParam: userAuth.AuthParam = {
      challenge: challenge,
      authType: [authType],
      authTrustLevel: authTrustLevel
    };
    let widgetParam: userAuth.WidgetParam = {
      title: 'Please authenticate'
    };
    if (authType !== userAuth.UserAuthType.PIN) {
      widgetParam.navigationButtonText = 'Use password';
    }
    try {
      let authInstance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      let self: SettingsBridge = this;
      authInstance.on('result', {
        onResult(authResult: userAuth.UserAuthResult): void {
          if (authResult.result === userAuth.UserAuthResultCode.SUCCESS) {
            hilog.info(DOMAIN, TAG, 'Authentication succeeded');
            result.success(true);
          } else if (authResult.result === 12500011 && authType !== userAuth.UserAuthType.PIN) {
            hilog.info(DOMAIN, TAG, 'User switched to PIN fallback');
            self.startPinAuthFallback(result);
          } else {
            hilog.info(DOMAIN, TAG, 'Authentication failed: ' + authResult.result.toString());
            result.success(false);
          }
        }
      });
      authInstance.start();
      hilog.info(DOMAIN, TAG, 'Auth started, type: ' + authType.toString());
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Authentication exception: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private startPinAuthFallback(result: MethodResult): void {
    let challenge: Uint8Array = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);
    let authParam: userAuth.AuthParam = {
      challenge: challenge,
      authType: [userAuth.UserAuthType.PIN],
      authTrustLevel: userAuth.AuthTrustLevel.ATL1
    };
    let widgetParam: userAuth.WidgetParam = {
      title: 'Please authenticate'
    };
    try {
      let authInstance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      authInstance.on('result', {
        onResult(authResult: userAuth.UserAuthResult): void {
          if (authResult.result === userAuth.UserAuthResultCode.SUCCESS) {
            hilog.info(DOMAIN, TAG, 'PIN fallback succeeded');
            result.success(true);
          } else {
            hilog.info(DOMAIN, TAG, 'PIN fallback failed: ' + authResult.result.toString());
            result.success(false);
          }
        }
      });
      authInstance.start();
      hilog.info(DOMAIN, TAG, 'PIN fallback auth started');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'PIN fallback exception');
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
      let parsed: Record<string, Object> = JSON.parse(jsonStr);
      if (parsed['keepScreenOn'] !== undefined && parsed['keepScreenOn'] !== null) {
        result.keepScreenOn = parsed['keepScreenOn'] as boolean;
      } else if (parsed['on'] !== undefined && parsed['on'] !== null) {
        result.keepScreenOn = parsed['on'] as boolean;
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
      let parsed: SaveFileParsedParamsJson = JSON.parse(jsonStr);
      if (parsed.srcUri !== undefined && parsed.srcUri !== null) {
        result.srcUri = parsed.srcUri;
      } else if (parsed.sourcePath !== undefined && parsed.sourcePath !== null) {
        result.srcUri = parsed.sourcePath;
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

interface SaveFileParsedParamsJson {
  srcUri?: string;
  sourcePath?: string;
  fileName?: string;
}
