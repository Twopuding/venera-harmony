import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { SuperResolutionBridge } from './SuperResolutionBridge';
import { UIAbility, application, common, contextConstant, Want } from '@kit.AbilityKit';
import { hilog, hidebug } from '@kit.PerformanceAnalysisKit';
import { picker, fileIo, fileUri, storageStatistics } from '@kit.CoreFileKit';
import { batteryInfo, BusinessError, deviceInfo } from '@kit.BasicServicesKit';
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
  private srBridge: SuperResolutionBridge = new SuperResolutionBridge();

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
    } else if (call.method === 'srIsAvailable') {
      this.handleSrIsAvailable(result);
    } else if (call.method === 'srInitialize') {
      this.handleSrInitialize(result);
    } else if (call.method === 'srProcessFile') {
      this.handleSrProcessFile(call, result);
    } else if (call.method === 'getFreeMemory') {
      this.handleGetFreeMemory(result);
    } else if (call.method === 'getCacheSize') {
      this.handleGetCacheSize(result);
    } else if (call.method === 'clearAppCache') {
      this.handleClearAppCache(result);
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
    let pickParams: PickFileParsedParams = this.parsePickFileArgs(call.args);
    try {
      let documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      if (pickParams.extensions.length > 0) {
        let suffixes: Array<string> = [];
        for (let i: number = 0; i < pickParams.extensions.length; i++) {
          let ext: string = pickParams.extensions[i];
          if (ext.length === 0) {
            continue;
          }
          if (ext.startsWith('.')) {
            suffixes.push(ext);
          } else {
            suffixes.push('.' + ext);
          }
        }
        if (suffixes.length > 0) {
          documentSelectOptions.fileSuffixFilters = [suffixes.join(',')];
        }
      }
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.select(documentSelectOptions).then((selectResult: Array<string>) => {
        if (selectResult.length === 0) {
          result.success('');
          return;
        }
        let srcUri: string = selectResult[0];
        try {
          let cachePath: string = this.copyUriToCache(srcUri);
          hilog.info(DOMAIN, TAG, 'File selected and copied to: ' + cachePath);
          result.success(cachePath);
        } catch (copyErr) {
          let errMsg: string = 'Copy picked file failed';
          try {
            errMsg = JSON.stringify(copyErr);
          } catch (e) {
            // keep default
          }
          hilog.error(DOMAIN, TAG, 'Pick file copy failed: ' + errMsg);
          result.error('ERROR', 'Pick file copy failed', errMsg);
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
    hilog.info(DOMAIN, TAG,
      'saveFile request source=' + saveParams.sourceFilePath +
        ' suggested=' + saveParams.suggestedName);
    try {
      if (saveParams.sourceFilePath.length > 0 &&
        !fileIo.accessSync(saveParams.sourceFilePath)) {
        result.error('ERROR', 'Source file not accessible', saveParams.sourceFilePath);
        return;
      }
      let documentSaveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      let saveName: string = saveParams.suggestedName;
      if (saveName.length === 0 && saveParams.sourceFilePath.length > 0) {
        saveName = this.fileNameFromUri(saveParams.sourceFilePath);
      }
      if (saveName.length > 0) {
        documentSaveOptions.newFileNames = [saveName];
      }
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context.context);
      documentPicker.save(documentSaveOptions).then((saveResult: Array<string>) => {
        if (saveResult.length === 0) {
          hilog.info(DOMAIN, TAG, 'Save file cancelled');
          result.success('');
          return;
        }
        let destUri: string = saveResult[0];
        if (saveParams.sourceFilePath.length === 0) {
          result.success(destUri);
          return;
        }
        try {
          this.copySandboxFileToUri(saveParams.sourceFilePath, destUri);
          hilog.info(DOMAIN, TAG, 'File saved to: ' + destUri);
          result.success(destUri);
        } catch (copyErr) {
          let errMsg: string = 'Copy to save destination failed';
          try {
            errMsg = JSON.stringify(copyErr);
          } catch (e) {
            // keep default
          }
          hilog.error(DOMAIN, TAG, 'Save file copy failed: ' + errMsg);
          result.error('ERROR', 'Save file copy failed', errMsg);
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Save file failed: ' + err.code + ' ' + err.message);
        result.error('ERROR', 'Save file failed', err.message);
      });
    } catch (e) {
      let errMsg: string = 'Save file exception';
      try {
        errMsg = JSON.stringify(e);
      } catch (ex) {
        // keep default
      }
      hilog.error(DOMAIN, TAG, errMsg);
      result.error('ERROR', 'Save file exception', errMsg);
    }
  }

  private copySandboxFileToUri(sourcePath: string, destUri: string): void {
    let srcFile: fileIo.File | null = null;
    let destFile: fileIo.File | null = null;
    try {
      srcFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      destFile = fileIo.openSync(destUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(srcFile.fd, destFile.fd, 0);
    } finally {
      if (destFile !== null) {
        fileIo.closeSync(destFile);
      }
      if (srcFile !== null) {
        fileIo.closeSync(srcFile);
      }
    }
  }

  private copyUriToCache(srcUri: string): string {
    if (this.context === null) {
      throw new Error('Context is null');
    }
    let displayName: string = this.fileNameFromUri(srcUri);
    if (displayName.length === 0) {
      displayName = 'picked_file_' + Date.now().toString();
    }
    let cachePath: string = this.context.context.cacheDir + '/' + displayName;
    try {
      fileIo.unlinkSync(cachePath);
    } catch (e) {
      // ignore if file does not exist
    }
    let srcFile: fileIo.File | null = null;
    let destFile: fileIo.File | null = null;
    try {
      srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
      destFile = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(srcFile.fd, destFile.fd, 0);
    } finally {
      if (destFile !== null) {
        fileIo.closeSync(destFile);
      }
      if (srcFile !== null) {
        fileIo.closeSync(srcFile);
      }
    }
    return cachePath;
  }

  private fileNameFromUri(uri: string): string {
    try {
      let uriObj: fileUri.FileUri = new fileUri.FileUri(uri);
      if (uriObj.name !== undefined && uriObj.name !== null && uriObj.name.length > 0) {
        return uriObj.name;
      }
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'FileUri name unavailable, fallback to path parse');
    }
    let decoded: string = uri;
    try {
      decoded = decodeURIComponent(uri);
    } catch (e) {
      // keep original
    }
    let slash: number = decoded.lastIndexOf('/');
    if (slash >= 0 && slash < decoded.length - 1) {
      return decoded.substring(slash + 1);
    }
    return decoded;
  }

  private parsePickFileArgs(args: Object | null): PickFileParsedParams {
    let res: PickFileParsedParams = { extensions: [] };
    if (args === null) {
      return res;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: PickFileParsedParams = JSON.parse(jsonStr);
      if (parsed.extensions !== undefined && parsed.extensions !== null && Array.isArray(parsed.extensions)) {
        res.extensions = parsed.extensions;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse pickFile args');
    }
    return res;
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

  private handleSrIsAvailable(result: MethodResult): void {
    let available: boolean = this.srBridge.isAvailable();
    hilog.info(DOMAIN, TAG, 'SR isAvailable: backend=' + this.srBridge.getBackendType() + ' available=' + available.toString());
    result.success(available);
  }

  private handleSrInitialize(result: MethodResult): void {
    hilog.info(DOMAIN, TAG, 'SR initialize: creating CoreVisionKit analyzer');
    this.srBridge.initialize().then((success: boolean) => {
      hilog.info(DOMAIN, TAG, 'SR initialize result: ' + success.toString());
      result.success(success);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'SR initialize exception: ' + err.message);
      result.success(false);
    });
  }

  private handleSrProcessFile(call: BridgeMethodCall, result: MethodResult): void {
    if (call.args === null || call.rawCall === undefined) {
      hilog.error(DOMAIN, TAG, 'SR processFile: args or rawCall is null');
      result.success('');
      return;
    }
    try {
      let filePath: Object | null = call.rawCall.argument('filePath');
      if (filePath === null) {
        hilog.error(DOMAIN, TAG, 'SR processFile: filePath is null');
        result.success('');
        return;
      }
      let pathStr: string = String(filePath);
      if (pathStr.length === 0) {
        hilog.error(DOMAIN, TAG, 'SR processFile: filePath is empty');
        result.success('');
        return;
      }
      hilog.info(DOMAIN, TAG, 'SR processFile: reading from ' + pathStr);
      let imageFile: fileIo.File = fileIo.openSync(pathStr, fileIo.OpenMode.READ_ONLY);
      let fileStat: fileIo.Stat = fileIo.statSync(pathStr);
      let imageData: ArrayBuffer = new ArrayBuffer(fileStat.size);
      fileIo.readSync(imageFile.fd, imageData);
      fileIo.closeSync(imageFile);
      let imageBytes: Uint8Array = new Uint8Array(imageData);

      this.srBridge.processImage(imageBytes).then((outputData: Uint8Array | null) => {
        if (outputData !== null) {
          let outputPath: string = pathStr + '_sr_result';
          let outFile: fileIo.File = fileIo.openSync(outputPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
          let outBuffer: ArrayBuffer = outputData.buffer.slice(outputData.byteOffset, outputData.byteOffset + outputData.byteLength);
          fileIo.writeSync(outFile.fd, outBuffer);
          fileIo.closeSync(outFile);
          hilog.info(DOMAIN, TAG, 'SR processFile: wrote result to ' + outputPath + ' size=' + outputData.byteLength.toString());
          result.success(outputPath);
        } else {
          hilog.error(DOMAIN, TAG, 'SR processFile: output is null');
          result.success('');
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'SR processFile exception: ' + err.message);
        result.success('');
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'SR processFile: exception ' + JSON.stringify(e));
      result.success('');
    }
  }

  private handleGetFreeMemory(result: MethodResult): void {
    try {
      let memInfo: hidebug.SystemMemInfo = hidebug.getSystemMemInfo();
      let freeMemBytes: number = Number(memInfo.freeMem);
      hilog.info(DOMAIN, TAG, 'Free memory: ' + freeMemBytes.toString() + ' bytes');
      result.success(freeMemBytes);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to get free memory: ' + JSON.stringify(e));
      result.success(null);
    }
  }

  private handleGetCacheSize(result: MethodResult): void {
    storageStatistics.getCurrentBundleStats().then((bundleStats: storageStatistics.BundleStats) => {
      hilog.info(DOMAIN, TAG, 'cacheSize: ' + bundleStats.cacheSize.toString());
      result.success(bundleStats.cacheSize);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'getCurrentBundleStats failed: ' + JSON.stringify(err));
      result.success(0);
    });
  }

  private async collectCacheDirs(): Promise<Array<string>> {
    let paths: Array<string> = [];
    if (this.context === null) {
      return paths;
    }
    let uiContext: common.UIAbilityContext = this.context.context;
    let moduleContext: common.Context = await application.createModuleContext(uiContext, 'entry');

    // el2: base/cache + haps/entry/cache
    paths.push(moduleContext.cacheDir);
    paths.push(uiContext.cacheDir);

    // el1: base/cache + haps/entry/cache
    moduleContext.area = contextConstant.AreaMode.EL1;
    uiContext.area = contextConstant.AreaMode.EL1;
    paths.push(moduleContext.cacheDir);
    paths.push(uiContext.cacheDir);

    // restore EL2
    moduleContext.area = contextConstant.AreaMode.EL2;
    uiContext.area = contextConstant.AreaMode.EL2;
    return paths;
  }

  private clearDirectoryContents(dirPath: string): void {
    let filenames: string[] = [];
    try {
      filenames = fileIo.listFileSync(dirPath);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'listFile failed for ' + dirPath + ': ' + JSON.stringify(err));
      return;
    }
    for (let i = 0; i < filenames.length; i++) {
      let childPath: string = dirPath + '/' + filenames[i];
      let isDirectory: boolean = false;
      try {
        isDirectory = fileIo.statSync(childPath).isDirectory();
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'stat failed for ' + childPath + ': ' + JSON.stringify(err));
        continue;
      }
      try {
        if (isDirectory) {
          fileIo.rmdirSync(childPath);
        } else {
          fileIo.unlinkSync(childPath);
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'remove failed for ' + childPath + ': ' + JSON.stringify(err));
      }
    }
  }

  private handleClearAppCache(result: MethodResult): void {
    this.collectCacheDirs().then((paths: Array<string>) => {
      for (let i = 0; i < paths.length; i++) {
        hilog.info(DOMAIN, TAG, 'Clearing cache dir: ' + paths[i]);
        this.clearDirectoryContents(paths[i]);
      }
      result.success(true);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'clearAppCache failed: ' + JSON.stringify(err));
      result.success(false);
    });
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

interface PickFileParsedParams {
  extensions: Array<string>;
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

interface SrProcessFileParams {
  filePath: string;
}
