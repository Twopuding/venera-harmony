import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { batteryInfo } from '@kit.BasicServicesKit';
import { Want, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL_NAME: string = 'venera/method_channel';
const TAG: string = 'PlatformBridge';
const DOMAIN: number = 0x0000;

export class PlatformBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;
  private mainWindow: window.Window | null = null;

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
    } else if (call.method === 'isDeviceSupported') {
      this.handleIsDeviceSupported(result);
    } else if (call.method === 'authenticate') {
      this.handleAuthenticate(call, result);
    } else if (call.method === 'getBatteryLevel') {
      this.handleGetBatteryLevel(result);
    } else if (call.method === 'getBatteryState') {
      this.handleGetBatteryState(result);
    } else if (call.method === 'setScreenOn') {
      this.handleSetScreenOn(call, result);
    } else if (call.method === 'getProxy') {
      this.handleGetProxy(result);
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
    result.notImplemented();
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
    result.success(true);
  }

  private handleIsDeviceSupported(result: MethodResult): void {
    result.success(true);
  }

  private handleAuthenticate(call: BridgeMethodCall, result: MethodResult): void {
    result.notImplemented();
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
    result.success('No Proxy');
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

interface SaveFileParsedParams {
  sourceFilePath: string;
  suggestedName: string;
}

interface SetScreenOnParams {
  on: boolean;
}
