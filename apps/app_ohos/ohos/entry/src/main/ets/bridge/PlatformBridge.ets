import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { AIBridge } from './AIBridge';
import { ESRGANBridge } from './ESRGANBridge';
import { UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { batteryInfo, BusinessError } from '@kit.BasicServicesKit';
import { Want, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { userAuth } from '@kit.UserAuthenticationKit';
import { connection } from '@kit.NetworkKit';

const CHANNEL_NAME: string = 'venera/method_channel';
const TAG: string = 'PlatformBridge';
const DOMAIN: number = 0xFF00;

export class PlatformBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;
  private mainWindow: window.Window | null = null;
  private aiBridge: AIBridge = new AIBridge();
  private esrganBridge: ESRGANBridge = new ESRGANBridge();

  setContext(context: UIAbility): void {
    this.context = context;
  }

  setMainWindow(win: window.Window): void {
    this.mainWindow = win;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
    hilog.info(DOMAIN, TAG, 'PlatformBridge registered on ' + CHANNEL_NAME);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'launchUrl') {
      this.handleLaunchUrl(call, result);
    } else if (call.method === 'shareText') {
      this.handleShareText(call, result);
    } else if (call.method === 'shareFile') {
      this.handleShareFile(call, result);
    } else if (call.method === 'shareFileFromData') {
      this.handleShareFileFromData(call, result);
    } else if (call.method === 'pickDirectory') {
      this.handlePickDirectory(result);
    } else if (call.method === 'pickFile') {
      this.handlePickFile(call, result);
    } else if (call.method === 'saveFile') {
      this.handleSaveFile(call, result);
    } else if (call.method === 'canCheckBiometrics') {
      this.handleCanCheckBiometrics(result);
    } else if (call.method === 'checkFaceAvailable') {
      this.handleCheckAuthAvailable(userAuth.UserAuthType.FACE, result);
    } else if (call.method === 'checkFingerprintAvailable') {
      this.handleCheckAuthAvailable(userAuth.UserAuthType.FINGERPRINT, result);
    } else if (call.method === 'isDeviceSupported') {
      this.handleIsDeviceSupported(result);
    } else if (call.method === 'authenticate') {
      this.handleAuthenticate(call, result);
    } else if (call.method === 'authenticateWithFace') {
      this.handleAuthWithType(call, userAuth.UserAuthType.FACE, result);
    } else if (call.method === 'authenticateWithFingerprint') {
      this.handleAuthWithType(call, userAuth.UserAuthType.FINGERPRINT, result);
    } else if (call.method === 'authenticateWithPin') {
      this.handleAuthWithType(call, userAuth.UserAuthType.PIN, result);
    } else if (call.method === 'getBatteryLevel') {
      this.handleGetBatteryLevel(result);
    } else if (call.method === 'getBatteryState') {
      this.handleGetBatteryState(result);
    } else if (call.method === 'setScreenOn') {
      this.handleSetScreenOn(call, result);
    } else if (call.method === 'getProxy') {
      this.handleGetProxy(result);
    } else if (call.method === 'setProxy') {
      this.handleSetProxy(call, result);
    } else if (call.method === 'clearProxy') {
      this.handleClearProxy(result);
    } else if (call.method === 'isAiSuperResolutionAvailable') {
      this.handleIsAiSuperResolutionAvailable(result);
    } else if (call.method === 'aiSuperResolution') {
      this.handleAiSuperResolution(call, result);
    } else if (call.method === 'esrganIsAvailable') {
      this.handleEsrganIsAvailable(result);
    } else if (call.method === 'esrganInitialize') {
      this.handleEsrganInitialize(call, result);
    } else if (call.method === 'esrganProcess') {
      this.handleEsrganProcess(call, result);
    } else {
      result.notImplemented();
    }
  }

  private handleLaunchUrl(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let params: LaunchUrlParams = this.parseLaunchUrlArgs(call.args);
    try {
      let launchWant: Want = new Want();
      launchWant.uri = params.url;
      launchWant.flags = 0x10000000;
      this.context.context.startAbility(launchWant).then(() => {
        hilog.info(DOMAIN, TAG, 'Launched URL: ' + params.url);
        result.success(true);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Launch URL failed: ' + err.message);
        result.success(false);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Launch URL exception');
      result.success(false);
    }
  }

  private parseLaunchUrlArgs(args: Object | null): LaunchUrlParams {
    let res: LaunchUrlParams = { url: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: LaunchUrlParams = JSON.parse(jsonStr);
      if (parsed.url !== undefined && parsed.url !== null) {
        res.url = parsed.url;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse launchUrl args');
    }
    return res;
  }

  private handleShareText(call: BridgeMethodCall, result: MethodResult): void {
    let params: ShareTextParams = this.parseShareTextArgs(call.args);
    try {
      let shareWant: Want = new Want();
      shareWant.action = 'ohos.want.action.sendData';
      shareWant.type = 'text/plain';
      shareWant.parameters = {
        'ohos.extra.param.key.content': params.text
      } as Record<string, Object>;
      let context: common.UIAbilityContext = this.context!.context;
      context.startAbility(shareWant).then(() => {
        result.success(true);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Share text failed: ' + err.message);
        result.error('ERROR', 'Share text failed', err.message);
      });
    } catch (e) {
      result.error('ERROR', 'Share text exception', null);
    }
  }

  private parseShareTextArgs(args: Object | null): ShareTextParams {
    let res: ShareTextParams = { text: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: ShareTextParams = JSON.parse(jsonStr);
      if (parsed.text !== undefined && parsed.text !== null) {
        res.text = parsed.text;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse shareText args');
    }
    return res;
  }

  private handleShareFile(call: BridgeMethodCall, result: MethodResult): void {
    let params: ShareFileParams = this.parseShareFileArgs(call.args);
    try {
      let shareWant: Want = new Want();
      shareWant.action = 'ohos.want.action.sendData';
      shareWant.type = params.mimeType;
      shareWant.parameters = {
        'ohos.extra.param.key.streamUri': params.filePath
      } as Record<string, Object>;
      let context: common.UIAbilityContext = this.context!.context;
      context.startAbility(shareWant).then(() => {
        result.success(true);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Share file failed: ' + err.message);
        result.error('ERROR', 'Share file failed', err.message);
      });
    } catch (e) {
      result.error('ERROR', 'Share file exception', null);
    }
  }

  private parseShareFileArgs(args: Object | null): ShareFileParams {
    let res: ShareFileParams = { filePath: '', mimeType: '*/*', fileNameOverride: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: ShareFileParams = JSON.parse(jsonStr);
      if (parsed.filePath !== undefined && parsed.filePath !== null) {
        res.filePath = parsed.filePath;
      }
      if (parsed.mimeType !== undefined && parsed.mimeType !== null) {
        res.mimeType = parsed.mimeType;
      }
      if (parsed.fileNameOverride !== undefined && parsed.fileNameOverride !== null) {
        res.fileNameOverride = parsed.fileNameOverride;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse shareFile args');
    }
    return res;
  }

  private handleShareFileFromData(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let params: ShareFileFromDataParams = this.parseShareFileFromDataArgs(call.args);
    if (params.data.length === 0) {
      result.error('ERROR', 'No data to share', null);
      return;
    }
    try {
      let cacheDir: string = this.context.context.cacheDir;
      let fileName: string = params.fileNameOverride.length > 0 ? params.fileNameOverride : 'shared_file';
      let tempFilePath: string = cacheDir + '/' + fileName;
      let file: fileIo.File = fileIo.openSync(tempFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, params.data);
      fileIo.closeSync(file);
      let shareWant: Want = new Want();
      shareWant.action = 'ohos.want.action.sendData';
      shareWant.type = params.mimeType;
      shareWant.parameters = {
        'ohos.extra.param.key.streamUri': tempFilePath
      } as Record<string, Object>;
      let context: common.UIAbilityContext = this.context.context;
      context.startAbility(shareWant).then(() => {
        hilog.info(DOMAIN, TAG, 'Share file from data succeeded');
        result.success(true);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Share file from data failed: ' + err.message);
        result.error('ERROR', 'Share file from data failed', err.message);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Share file from data exception: ' + JSON.stringify(e));
      result.error('ERROR', 'Share file from data exception', null);
    }
  }

  private parseShareFileFromDataArgs(args: Object | null): ShareFileFromDataParams {
    let res: ShareFileFromDataParams = { data: new Uint8Array(0), mimeType: '*/*', fileNameOverride: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: ShareFileFromDataParsedParams = JSON.parse(jsonStr);
      if (parsed.data !== undefined && parsed.data !== null && Array.isArray(parsed.data)) {
        res.data = new Uint8Array(parsed.data);
      }
      if (parsed.mimeType !== undefined && parsed.mimeType !== null) {
        res.mimeType = parsed.mimeType;
      }
      if (parsed.fileNameOverride !== undefined && parsed.fileNameOverride !== null) {
        res.fileNameOverride = parsed.fileNameOverride;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse shareFileFromData args');
    }
    return res;
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
      result.error('ERROR', 'Pick directory exception', null);
    }
  }

  private handlePickFile(call: BridgeMethodCall, result: MethodResult): void {
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
      result.error('ERROR', 'Pick file exception', null);
    }
  }

  private handleSaveFile(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let saveParams: SaveFileParsedParams = this.parseSaveFileArgs(call.args);
    try {
      let documentSaveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      if (saveParams.suggestedName.length > 0) {
        documentSaveOptions.newFileNames = [saveParams.suggestedName];
      }
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.save(documentSaveOptions).then((saveResult: Array<string>) => {
        if (saveResult.length > 0) {
          let destUri: string = saveResult[0];
          if (saveParams.sourceFilePath.length > 0) {
            fileIo.copyFileSync(saveParams.sourceFilePath, destUri);
          }
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
      result.error('ERROR', 'Save file exception', null);
    }
  }

  private parseSaveFileArgs(args: Object | null): SaveFileParsedParams {
    let res: SaveFileParsedParams = { sourceFilePath: '', suggestedName: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: SaveFileParsedParams = JSON.parse(jsonStr);
      if (parsed.sourceFilePath !== undefined && parsed.sourceFilePath !== null) {
        res.sourceFilePath = parsed.sourceFilePath;
      }
      if (parsed.suggestedName !== undefined && parsed.suggestedName !== null) {
        res.suggestedName = parsed.suggestedName;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse saveFile args');
    }
    return res;
  }

  private handleCanCheckBiometrics(result: MethodResult): void {
    let faceOK: boolean = this.checkAuthAvailable(userAuth.UserAuthType.FACE);
    let fpOK: boolean = this.checkAuthAvailable(userAuth.UserAuthType.FINGERPRINT);
    result.success(faceOK || fpOK);
  }

  private checkAuthAvailable(authType: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL2);
      return true;
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'Auth type ' + authType.toString() + ' not available at ATL2, trying ATL3');
    }
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL3);
      return true;
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'Auth type ' + authType.toString() + ' not available');
      return false;
    }
  }

  private handleCheckAuthAvailable(authType: userAuth.UserAuthType, result: MethodResult): void {
    result.success(this.checkAuthAvailable(authType));
  }

  private handleIsDeviceSupported(result: MethodResult): void {
    let authTypes: userAuth.UserAuthType[] = [
      userAuth.UserAuthType.FACE,
      userAuth.UserAuthType.FINGERPRINT,
      userAuth.UserAuthType.PIN
    ];
    for (let i: number = 0; i < authTypes.length; i++) {
      if (this.checkAuthAvailable(authTypes[i])) {
        result.success(true);
        return;
      }
    }
    result.success(false);
  }

  private handleAuthenticate(call: BridgeMethodCall, result: MethodResult): void {
    let params: AuthenticateParams = this.parseAuthenticateArgs(call.args);
    this.handleAuthWithType(call, userAuth.UserAuthType.FACE, result);
  }

  private handleAuthWithType(call: BridgeMethodCall, authType: userAuth.UserAuthType, result: MethodResult): void {
    let params: AuthenticateParams = this.parseAuthenticateArgs(call.args);
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
    let title: string = params.localizedReason.length > 0 ? params.localizedReason : 'Please authenticate';
    let widgetParam: userAuth.WidgetParam = {
      title: title
    };
    if (authType !== userAuth.UserAuthType.PIN) {
      widgetParam.navigationButtonText = 'Use password';
    }
    try {
      let authInstance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      let self: PlatformBridge = this;
      authInstance.on('result', {
        onResult(authResult: userAuth.UserAuthResult): void {
          if (authResult.result === userAuth.UserAuthResultCode.SUCCESS) {
            hilog.info(DOMAIN, TAG, 'Authentication succeeded');
            result.success(true);
          } else if (authResult.result === 12500011 && authType !== userAuth.UserAuthType.PIN) {
            hilog.info(DOMAIN, TAG, 'User switched to PIN fallback');
            self.startPinAuthFallback(params.localizedReason, result);
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

  private startPinAuthFallback(localizedReason: string, result: MethodResult): void {
    let challenge: Uint8Array = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);
    let authParam: userAuth.AuthParam = {
      challenge: challenge,
      authType: [userAuth.UserAuthType.PIN],
      authTrustLevel: userAuth.AuthTrustLevel.ATL1
    };
    let widgetParam: userAuth.WidgetParam = {
      title: localizedReason.length > 0 ? localizedReason : 'Please authenticate'
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

  private parseAuthenticateArgs(args: Object | null): AuthenticateParams {
    let res: AuthenticateParams = { localizedReason: '' };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: AuthenticateParams = JSON.parse(jsonStr);
      if (parsed.localizedReason !== undefined && parsed.localizedReason !== null) {
        res.localizedReason = parsed.localizedReason;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse authenticate args');
    }
    return res;
  }

  private handleGetBatteryLevel(result: MethodResult): void {
    try {
      let level: number = batteryInfo.batterySOC;
      result.success(level);
    } catch (e) {
      result.error('ERROR', 'Failed to get battery level', null);
    }
  }

  private handleGetBatteryState(result: MethodResult): void {
    try {
      let charging: number = batteryInfo.chargingStatus;
      let state: string = 'unknown';
      if (charging === 1) {
        state = 'charging';
      } else if (charging === 2) {
        state = 'discharging';
      } else if (charging === 3) {
        state = 'full';
      }
      result.success(state);
    } catch (e) {
      result.error('ERROR', 'Failed to get battery state', null);
    }
  }

  private handleSetScreenOn(call: BridgeMethodCall, result: MethodResult): void {
    if (this.mainWindow === null) {
      result.error('ERROR', 'MainWindow is null', null);
      return;
    }
    let params: SetScreenOnParams = this.parseSetScreenOnArgs(call.args);
    this.mainWindow.setWindowKeepScreenOn(params.on).then(() => {
      hilog.info(DOMAIN, TAG, 'Set screen on: ' + params.on.toString());
      result.success(true);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Set screen on failed: ' + err.message);
      result.error('ERROR', 'Set screen on failed', err.message);
    });
  }

  private parseSetScreenOnArgs(args: Object | null): SetScreenOnParams {
    let res: SetScreenOnParams = { on: false };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: SetScreenOnParams = JSON.parse(jsonStr);
      if (parsed.on !== undefined && parsed.on !== null) {
        res.on = parsed.on;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse setScreenOn args');
    }
    return res;
  }

  private handleGetProxy(result: MethodResult): void {
    connection.getDefaultHttpProxy().then((proxy: connection.HttpProxy) => {
      if (proxy.host.length > 0 && proxy.port > 0) {
        let proxyUrl: string = 'http://' + proxy.host + ':' + proxy.port.toString();
        hilog.info(DOMAIN, TAG, 'Current proxy: ' + proxyUrl);
        result.success(proxyUrl);
      } else {
        hilog.info(DOMAIN, TAG, 'No proxy configured');
        result.success('No Proxy');
      }
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Get proxy failed: ' + err.message);
      result.success('No Proxy');
    });
  }

  private handleSetProxy(call: BridgeMethodCall, result: MethodResult): void {
    let params: SetProxyParams = this.parseSetProxyArgs(call.args);
    if (params.host.length === 0 || params.port === 0) {
      hilog.error(DOMAIN, TAG, 'Invalid proxy parameters');
      result.success(false);
      return;
    }
    try {
      let httpProxy: connection.HttpProxy = {
        host: params.host,
        port: params.port,
        exclusionList: params.exclusionList
      };
      connection.setAppHttpProxy(httpProxy);
      hilog.info(DOMAIN, TAG, 'Proxy set: ' + params.host + ':' + params.port.toString());
      result.success(true);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Set proxy exception: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private parseSetProxyArgs(args: Object | null): SetProxyParams {
    let res: SetProxyParams = { host: '', port: 0, exclusionList: [] };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: SetProxyParsedParams = JSON.parse(jsonStr);
      if (parsed.host !== undefined && parsed.host !== null) {
        res.host = parsed.host;
      }
      if (parsed.port !== undefined && parsed.port !== null) {
        res.port = parsed.port;
      }
      if (parsed.exclusionList !== undefined && parsed.exclusionList !== null && Array.isArray(parsed.exclusionList)) {
        res.exclusionList = parsed.exclusionList;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse setProxy args');
    }
    return res;
  }

  private handleClearProxy(result: MethodResult): void {
    try {
      connection.setAppHttpProxy({
        host: '',
        port: 0,
        exclusionList: []
      });
      hilog.info(DOMAIN, TAG, 'Proxy cleared');
      result.success(true);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Clear proxy exception: ' + JSON.stringify(e));
      result.success(false);
    }
  }

  private handleIsAiSuperResolutionAvailable(result: MethodResult): void {
    let available: boolean = this.aiBridge.isAvailable();
    hilog.info(DOMAIN, TAG, 'AI SR available: ' + available.toString());
    result.success(available);
  }

  private handleAiSuperResolution(call: BridgeMethodCall, result: MethodResult): void {
    let imageData: Uint8Array = this.extractImageUint8Array(call.args);
    this.aiBridge.performSuperResolution(imageData).then((outputData: Uint8Array | null) => {
      if (outputData !== null) {
        result.success(outputData);
      } else {
        result.success(null);
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'AI SR exception: ' + err.message);
      result.success(null);
    });
  }

  private handleEsrganIsAvailable(result: MethodResult): void {
    let available: boolean = this.esrganBridge.isInitialized();
    hilog.info(DOMAIN, TAG, 'ESRGAN available: ' + available.toString());
    result.success(available);
  }

  private handleEsrganInitialize(call: BridgeMethodCall, result: MethodResult): void {
    let modelData: Uint8Array = this.extractModelUint8Array(call.args);
    if (modelData.byteLength === 0) {
      hilog.error(DOMAIN, TAG, 'ESRGAN initialize: no model data');
      result.success(false);
      return;
    }
    
    let modelBuffer: ArrayBuffer = modelData.buffer.slice(modelData.byteOffset, modelData.byteOffset + modelData.byteLength);
    this.esrganBridge.initialize(modelBuffer).then((success: boolean) => {
      hilog.info(DOMAIN, TAG, 'ESRGAN initialize result: ' + success.toString());
      result.success(success);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'ESRGAN initialize exception: ' + err.message);
      result.success(false);
    });
  }

  private handleEsrganProcess(call: BridgeMethodCall, result: MethodResult): void {
    let imageData: Uint8Array = this.extractImageUint8Array(call.args);
    if (imageData.byteLength === 0) {
      hilog.error(DOMAIN, TAG, 'ESRGAN process: no image data');
      result.success(null);
      return;
    }
    
    this.esrganBridge.processImage(imageData).then((outputData: Uint8Array | null) => {
      if (outputData !== null) {
        result.success(outputData);
      } else {
        result.success(null);
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'ESRGAN process exception: ' + err.message);
      result.success(null);
    });
  }

  private extractImageUint8Array(args: Object | null): Uint8Array {
    if (args === null) {
      hilog.error(DOMAIN, TAG, 'extractImageUint8Array: args is null');
      return new Uint8Array(0);
    }
    
    try {
      let params: AiSuperResolutionParams = args as AiSuperResolutionParams;
      if (params.imageData !== undefined && params.imageData !== null) {
        let arr: Array<number> = params.imageData;
        let result: Uint8Array = new Uint8Array(arr);
        hilog.info(DOMAIN, TAG, 'extractImageUint8Array: extracted, length=' + result.byteLength.toString());
        return result;
      }
      hilog.error(DOMAIN, TAG, 'extractImageUint8Array: imageData not found');
    } catch (e) {
      let err: Error = e as Error;
      hilog.error(DOMAIN, TAG, 'extractImageUint8Array exception: ' + err.message);
    }
    return new Uint8Array(0);
  }
  
  private extractModelUint8Array(args: Object | null): Uint8Array {
    if (args === null) {
      hilog.error(DOMAIN, TAG, 'extractModelUint8Array: args is null');
      return new Uint8Array(0);
    }
    
    try {
      let params: EsrganModelParams = args as EsrganModelParams;
      if (params.modelData !== undefined && params.modelData !== null) {
        let arr: Array<number> = params.modelData;
        let result: Uint8Array = new Uint8Array(arr);
        hilog.info(DOMAIN, TAG, 'extractModelUint8Array: extracted, length=' + result.byteLength.toString());
        return result;
      }
      hilog.error(DOMAIN, TAG, 'extractModelUint8Array: modelData not found');
    } catch (e) {
      let err: Error = e as Error;
      hilog.error(DOMAIN, TAG, 'extractModelUint8Array exception: ' + err.message);
    }
    return new Uint8Array(0);
  }
}

interface LaunchUrlParams {
  url: string;
}

interface ShareTextParams {
  text: string;
}

interface ShareFileParams {
  filePath: string;
  mimeType: string;
  fileNameOverride: string;
}

interface ShareFileFromDataParams {
  data: Uint8Array;
  mimeType: string;
  fileNameOverride: string;
}

interface ShareFileFromDataParsedParams {
  data: Array<number>;
  mimeType: string;
  fileNameOverride: string;
}

interface SaveFileParsedParams {
  sourceFilePath: string;
  suggestedName: string;
}

interface SetScreenOnParams {
  on: boolean;
}

interface SetProxyParams {
  host: string;
  port: number;
  exclusionList: Array<string>;
}

interface SetProxyParsedParams {
  host: string;
  port: number;
  exclusionList: Array<string>;
}

interface AuthenticateParams {
  localizedReason: string;
}

interface AiSuperResolutionParams {
  imageData: Array<number>;
}

interface EsrganModelParams {
  modelData: Array<number>;
}

interface EsrganImageParams {
  imageData: Array<number>;
}
