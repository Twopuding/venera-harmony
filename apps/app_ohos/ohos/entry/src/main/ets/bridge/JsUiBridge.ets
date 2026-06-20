import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_NAME: string = 'com.venera.jsui';
const TAG: string = 'JsUiBridge';
const DOMAIN: number = 0x0000;

export class JsUiBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
    hilog.info(DOMAIN, TAG, 'JsUiBridge registered');
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'showMessage') {
      this.handleShowMessage(call, result);
    } else if (call.method === 'showDialog') {
      this.handleShowDialog(call, result);
    } else if (call.method === 'showInputDialog') {
      this.handleShowInputDialog(call, result);
    } else if (call.method === 'showSelectDialog') {
      this.handleShowSelectDialog(call, result);
    } else if (call.method === 'showLoading') {
      this.handleShowLoading(call, result);
    } else if (call.method === 'cancelLoading') {
      this.handleCancelLoading(call, result);
    } else {
      result.notImplemented();
    }
  }

  private handleShowMessage(call: BridgeMethodCall, result: MethodResult): void {
    let message: string = '';
    if (call.args !== null) {
      try {
        let parsed: Record<string, Object> = JSON.parse(JSON.stringify(call.args));
        if (typeof parsed['message'] === 'string') {
          message = parsed['message'] as string;
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to parse showMessage args');
      }
    }
    AppStorage.setOrCreate('jsUiToast', message);
    AppStorage.setOrCreate('jsUiToastVersion', Date.now());
    result.success(null);
  }

  private handleShowDialog(call: BridgeMethodCall, result: MethodResult): void {
    let payload: JsUiDialogPayload = this.parseDialogArgs(call.args);
    AppStorage.setOrCreate('jsUiDialog', JSON.stringify(payload));
    AppStorage.setOrCreate('jsUiDialogVersion', Date.now());
    result.success(null);
  }

  private handleShowInputDialog(call: BridgeMethodCall, result: MethodResult): void {
    let payload: JsUiInputPayload = { id: 0, title: '' };
    if (call.args !== null) {
      try {
        payload = JSON.parse(JSON.stringify(call.args)) as JsUiInputPayload;
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to parse showInputDialog args');
      }
    }
    AppStorage.setOrCreate('jsUiInput', JSON.stringify(payload));
    AppStorage.setOrCreate('jsUiInputVersion', Date.now());
    result.success(null);
  }

  private handleShowSelectDialog(call: BridgeMethodCall, result: MethodResult): void {
    let payload: JsUiSelectPayload = { id: 0, title: '', options: [], initialIndex: 0 };
    if (call.args !== null) {
      try {
        payload = JSON.parse(JSON.stringify(call.args)) as JsUiSelectPayload;
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to parse showSelectDialog args');
      }
    }
    AppStorage.setOrCreate('jsUiSelect', JSON.stringify(payload));
    AppStorage.setOrCreate('jsUiSelectVersion', Date.now());
    result.success(null);
  }

  private handleShowLoading(call: BridgeMethodCall, result: MethodResult): void {
    let payload: JsUiLoadingPayload = { id: 0, cancellable: false };
    if (call.args !== null) {
      try {
        payload = JSON.parse(JSON.stringify(call.args)) as JsUiLoadingPayload;
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to parse showLoading args');
      }
    }
    AppStorage.setOrCreate('jsUiLoading', JSON.stringify(payload));
    AppStorage.setOrCreate('jsUiLoadingVersion', Date.now());
    result.success(null);
  }

  private handleCancelLoading(call: BridgeMethodCall, result: MethodResult): void {
    AppStorage.setOrCreate('jsUiLoading', '');
    AppStorage.setOrCreate('jsUiLoadingVersion', Date.now());
    result.success(null);
  }

  private parseDialogArgs(args: Object | null): JsUiDialogPayload {
    let payload: JsUiDialogPayload = {
      id: 0,
      title: '',
      content: '',
      actions: []
    };
    if (args === null) {
      return payload;
    }
    try {
      payload = JSON.parse(JSON.stringify(args)) as JsUiDialogPayload;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse showDialog args');
    }
    return payload;
  }

  static notifyDialogAction(id: number, actionIndex: number): void {
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    let params: JsUiDialogActionParams = { id: id, actionIndex: actionIndex };
    bridge.invokeMethodAsync(CHANNEL_NAME, 'onDialogAction', params);
  }

  static notifyInputResult(id: number, value: string): void {
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    let params: JsUiInputResultParams = { id: id, value: value };
    bridge.invokeMethodAsync(CHANNEL_NAME, 'onInputResult', params);
  }

  static notifySelectResult(id: number, index: number | null): void {
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    let params: JsUiSelectResultParams = { id: id, index: index };
    bridge.invokeMethodAsync(CHANNEL_NAME, 'onSelectResult', params);
  }

  static notifyLoadingCancel(id: number): void {
    let bridge: FlutterBridge = FlutterBridge.getInstance();
    let params: JsUiLoadingCancelParams = { id: id };
    bridge.invokeMethodAsync(CHANNEL_NAME, 'onLoadingCancel', params);
  }
}

interface JsUiDialogPayload {
  id: number;
  title: string;
  content: string;
  actions: JsUiDialogAction[];
}

interface JsUiDialogAction {
  text: string;
  style: string;
}

interface JsUiInputPayload {
  id: number;
  title: string;
}

interface JsUiSelectPayload {
  id: number;
  title: string;
  options: string[];
  initialIndex: number;
}

interface JsUiLoadingPayload {
  id: number;
  cancellable: boolean;
}

interface JsUiDialogActionParams {
  id: number;
  actionIndex: number;
}

interface JsUiInputResultParams {
  id: number;
  value: string;
}

interface JsUiSelectResultParams {
  id: number;
  index: number | null;
}

interface JsUiLoadingCancelParams {
  id: number;
}
