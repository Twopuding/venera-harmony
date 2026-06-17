import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler, CHANNEL_DATA_NAME } from './FlutterBridge';

export class DataBridge implements MethodCallHandler {
  private static instance: DataBridge | null = null;
  private bridge: FlutterBridge = FlutterBridge.getInstance();

  static getInstance(): DataBridge {
    if (DataBridge.instance === null) {
      DataBridge.instance = new DataBridge();
    }
    return DataBridge.instance;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_DATA_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'notifySettingsChanged') {
      AppStorage.setOrCreate<number>('settingsVersion', Date.now());
      result.success(null);
      return;
    }
    result.notImplemented();
  }

  exploreLoadPage(sourceKey: string, pageTitle: string, page: number): Promise<Object | null> {
    let params: ExploreLoadPageParams = {
      sourceKey: sourceKey,
      pageTitle: pageTitle,
      page: page
    };
    return this.bridge.invokeMethodAsync(CHANNEL_DATA_NAME, 'exploreLoadPage', params);
  }

  getHistory(): Promise<Object | null> {
    return this.bridge.invokeMethodAsync(CHANNEL_DATA_NAME, 'getHistory', null);
  }

  getSettings(): Promise<Object | null> {
    return this.bridge.invokeMethodAsync(CHANNEL_DATA_NAME, 'getSettings', null);
  }

  setSetting(key: string, value: Object | null): Promise<Object | null> {
    let params: SetSettingParams = {
      key: key,
      value: value
    };
    return this.bridge.invokeMethodAsync(CHANNEL_DATA_NAME, 'setSetting', params);
  }
}

interface ExploreLoadPageParams {
  sourceKey: string;
  pageTitle: string;
  page: number;
}

interface SetSettingParams {
  key: string;
  value: Object | null;
}
