import { FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { HashMap } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_READER: string = 'com.venera.reader';
const FLUTTER_BRIDGE_DOMAIN: number = 0x0000;
const FLUTTER_BRIDGE_TAG: string = 'FlutterBridge';
const DATA_INVOKE_TIMEOUT_MS: number = 30000;
const CHANNEL_WEBVIEW: string = 'com.venera.webview';
const CHANNEL_SETTINGS: string = 'com.venera.settings';
const CHANNEL_PLATFORM: string = 'venera/method_channel';
const CHANNEL_DATA: string = 'com.venera.data';

export interface BridgeMethodCall {
  method: string;
  args: Object | null;
}

export interface MethodCallHandler {
  onMethodCall(call: BridgeMethodCall, result: MethodResult): void;
}

export class FlutterBridge {
  private static instance: FlutterBridge | null = null;
  private flutterEngine: FlutterEngine | null = null;
  private channels: HashMap<string, MethodChannel> = new HashMap<string, MethodChannel>();
  private handlers: HashMap<string, MethodCallHandler> = new HashMap<string, MethodCallHandler>();
  private dataInvokeChain: Promise<Object | null> = Promise.resolve(null);

  private constructor() {}

  static getInstance(): FlutterBridge {
    if (FlutterBridge.instance === null) {
      FlutterBridge.instance = new FlutterBridge();
    }
    return FlutterBridge.instance;
  }

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    this.flutterEngine = flutterEngine;
    this.channels.clear();
    let readerChannel: MethodChannel = new MethodChannel(flutterEngine.dartExecutor, CHANNEL_READER);
    let webviewChannel: MethodChannel = new MethodChannel(flutterEngine.dartExecutor, CHANNEL_WEBVIEW);
    let settingsChannel: MethodChannel = new MethodChannel(flutterEngine.dartExecutor, CHANNEL_SETTINGS);
    let platformChannel: MethodChannel = new MethodChannel(flutterEngine.dartExecutor, CHANNEL_PLATFORM);
    let dataChannel: MethodChannel = new MethodChannel(flutterEngine.dartExecutor, CHANNEL_DATA);
    this.channels.set(CHANNEL_READER, readerChannel);
    this.channels.set(CHANNEL_WEBVIEW, webviewChannel);
    this.channels.set(CHANNEL_SETTINGS, settingsChannel);
    this.channels.set(CHANNEL_PLATFORM, platformChannel);
    this.channels.set(CHANNEL_DATA, dataChannel);
    this.handlers.forEach((handler: MethodCallHandler, channelName: string) => {
      let channel: MethodChannel | undefined = this.channels.get(channelName);
      if (channel !== undefined) {
        this.attachHandler(channel, handler);
      }
    });
  }

  private attachHandler(channel: MethodChannel, handler: MethodCallHandler): void {
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        let bridgeCall: BridgeMethodCall = {
          method: call.method,
          args: call.args !== undefined ? call.args : null
        };
        handler.onMethodCall(bridgeCall, result);
      }
    });
  }

  setMethodCallHandler(channelName: string, handler: MethodCallHandler): void {
    this.handlers.set(channelName, handler);
    let channel: MethodChannel | undefined = this.channels.get(channelName);
    if (channel !== undefined) {
      this.attachHandler(channel, handler);
    }
  }

  invokeMethod(channelName: string, method: string, args: Object | null): void {
    let channel: MethodChannel | undefined = this.channels.get(channelName);
    if (channel !== undefined) {
      if (args !== null) {
        channel.invokeMethod(method, args);
      } else {
        channel.invokeMethod(method, null);
      }
    }
  }

  invokeMethodQueued(channelName: string, method: string, args: Object | null): Promise<void> {
    if (channelName === CHANNEL_DATA) {
      let pending: Promise<void> = this.dataInvokeChain.then(() => {
        this.invokeMethod(channelName, method, args);
      });
      this.dataInvokeChain = pending.then(() => null).catch(() => null);
      return pending;
    }
    this.invokeMethod(channelName, method, args);
    return Promise.resolve();
  }

  invokeMethodAsync(channelName: string, method: string, args: Object | null): Promise<Object | null> {
    if (channelName === CHANNEL_DATA) {
      let pending: Promise<Object | null> = this.dataInvokeChain.then(() => {
        return this.invokeMethodAsyncInternal(channelName, method, args);
      });
      this.dataInvokeChain = pending.catch(() => null);
      return pending;
    }
    return this.invokeMethodAsyncInternal(channelName, method, args);
  }

  private invokeMethodAsyncInternal(channelName: string, method: string, args: Object | null): Promise<Object | null> {
    let channelPromise: Promise<Object | null> = new Promise(
      (resolve: (value: Object | null) => void, reject: (reason: Error) => void) => {
        let channel: MethodChannel | undefined = this.channels.get(channelName);
        if (channel === undefined) {
          reject(new Error('Channel not configured: ' + channelName));
          return;
        }
        let settled: boolean = false;
        let resultHandler: MethodResult = {
          success: (result: Object | null) => {
            if (settled) {
              return;
            }
            settled = true;
            resolve(result);
          },
          error: (code: string, message: string, _detail: Object | null) => {
            if (settled) {
              return;
            }
            settled = true;
            reject(new Error(message));
          },
          notImplemented: () => {
            if (settled) {
              return;
            }
            settled = true;
            reject(new Error('Method not implemented: ' + method));
          }
        };
        if (args !== null) {
          channel.invokeMethod(method, args, resultHandler);
        } else {
          channel.invokeMethod(method, null, resultHandler);
        }
      });
    if (channelName !== CHANNEL_DATA) {
      return channelPromise;
    }
    let timeoutPromise: Promise<Object | null> = new Promise(
      (_resolve: (value: Object | null) => void, reject: (reason: Error) => void) => {
        setTimeout(() => {
          hilog.error(FLUTTER_BRIDGE_DOMAIN, FLUTTER_BRIDGE_TAG,
            'invoke timeout %{public}s %{public}dms', method, DATA_INVOKE_TIMEOUT_MS);
          reject(new Error(`Data bridge timeout: ${method}`));
        }, DATA_INVOKE_TIMEOUT_MS);
      });
    return Promise.race([channelPromise, timeoutPromise]);
  }

  getFlutterEngine(): FlutterEngine | null {
    return this.flutterEngine;
  }

  getChannel(channelName: string): MethodChannel | undefined {
    return this.channels.get(channelName);
  }
}

export const CHANNEL_DATA_NAME: string = CHANNEL_DATA;
