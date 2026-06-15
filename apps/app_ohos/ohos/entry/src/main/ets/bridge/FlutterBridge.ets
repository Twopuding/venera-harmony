import { FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { HashMap } from '@kit.ArkTS';

const CHANNEL_READER: string = 'com.venera.reader';
const CHANNEL_WEBVIEW: string = 'com.venera.webview';
const CHANNEL_SETTINGS: string = 'com.venera.settings';
const CHANNEL_PLATFORM: string = 'venera/method_channel';

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
    this.channels.set(CHANNEL_READER, readerChannel);
    this.channels.set(CHANNEL_WEBVIEW, webviewChannel);
    this.channels.set(CHANNEL_SETTINGS, settingsChannel);
    this.channels.set(CHANNEL_PLATFORM, platformChannel);
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

  getFlutterEngine(): FlutterEngine | null {
    return this.flutterEngine;
  }

  getChannel(channelName: string): MethodChannel | undefined {
    return this.channels.get(channelName);
  }
}
