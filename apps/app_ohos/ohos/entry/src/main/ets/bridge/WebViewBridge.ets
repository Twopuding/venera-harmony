import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_NAME: string = 'com.venera.webview';
const TAG: string = 'WebViewBridge';
const DOMAIN: number = 0x0000;
const STORAGE_KEY_URL: string = 'webview_target_url';
const STORAGE_KEY_CLOSE: string = 'webview_should_close';
const BUNDLE_NAME: string = 'com.venera.ohos';
const WEBVIEW_ABILITY: string = 'WebViewAbility';

export class WebViewBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;

  setContext(context: UIAbility): void {
    this.context = context;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'open') {
      this.handleOpen(call, result);
    } else if (call.method === 'close') {
      this.handleClose(result);
    } else {
      result.notImplemented();
    }
  }

  private handleOpen(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      hilog.error(DOMAIN, TAG, 'Context is null, cannot launch WebViewAbility');
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let url: string = this.extractUrl(call.args);
    AppStorage.setOrCreate<string>(STORAGE_KEY_URL, url);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLOSE, false);
    let want: Want = {
      bundleName: BUNDLE_NAME,
      abilityName: WEBVIEW_ABILITY
    };
    this.context.context.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'WebViewAbility started successfully');
      result.success(null);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to start WebViewAbility: ' + err.message);
      result.error('ERROR', 'Failed to start WebViewAbility', err.message);
    });
  }

  private handleClose(result: MethodResult): void {
    // WebViewPage watches this flag and calls terminateSelf.
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLOSE, true);
    hilog.info(DOMAIN, TAG, 'Close flag set for WebViewAbility');
    result.success(null);
  }

  private extractUrl(args: Object | null): string {
    if (args === null) {
      return '';
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: WebViewOpenParams = JSON.parse(jsonStr);
      if (parsed.url !== undefined && parsed.url !== null) {
        return parsed.url;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse url from args');
    }
    return '';
  }

  onCookiesReceived(url: string, cookies: string): void {
    let params: WebViewCookiesParams = {
      url: url,
      cookies: cookies
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCookiesReceived', params);
  }

  onCloudflareDetected(url: string): void {
    let params: WebViewUrlParams = {
      url: url
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCloudflareDetected', params);
  }

  onCloudflareResolved(url: string, cookies: string, userAgent: string): void {
    let params: WebViewCloudflareParams = {
      url: url,
      cookies: cookies,
      userAgent: userAgent
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCloudflareResolved', params);
  }

  onLocalStorageReceived(localStorage: Record<string, string>): void {
    let params: WebViewLocalStorageParams = {
      localStorage: localStorage
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onLocalStorageReceived', params);
  }

  onUserAgentReceived(userAgent: string): void {
    let params: WebViewUserAgentParams = {
      userAgent: userAgent
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onUserAgentReceived', params);
  }

  onClosed(): void {
    this.bridge.invokeMethod(CHANNEL_NAME, 'onClosed', null);
  }
}

interface WebViewOpenParams {
  url: string;
}

interface WebViewCookiesParams {
  url: string;
  cookies: string;
}

interface WebViewUrlParams {
  url: string;
}

interface WebViewCloudflareParams {
  url: string;
  cookies: string;
  userAgent: string;
}

interface WebViewLocalStorageParams {
  localStorage: Record<string, string>;
}

interface WebViewUserAgentParams {
  userAgent: string;
}
