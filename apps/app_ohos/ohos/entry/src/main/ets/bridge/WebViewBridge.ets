import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility, Want } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_NAME: string = 'com.venera.webview';
const TAG: string = 'WebViewBridge';
const DOMAIN: number = 0x0000;
const STORAGE_KEY_URL: string = 'webview_target_url';

export class WebViewBridge implements MethodCallHandler {
  private static instance: WebViewBridge | null = null;
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;
  private controller: webview.WebviewController | null = null;
  private currentUrl: string = '';
  private closeCallback: (() => void) | null = null;

  static getInstance(): WebViewBridge {
    if (WebViewBridge.instance === null) {
      WebViewBridge.instance = new WebViewBridge();
    }
    return WebViewBridge.instance;
  }

  setContext(context: UIAbility): void {
    this.context = context;
  }

  registerSession(
    controller: webview.WebviewController,
    url: string,
    onClose: () => void
  ): void {
    this.controller = controller;
    this.currentUrl = url;
    this.closeCallback = onClose;
  }

  unregisterSession(): void {
    this.controller = null;
    this.currentUrl = '';
    this.closeCallback = null;
  }

  updateUrl(url: string): void {
    this.currentUrl = url;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'open') {
      this.handleOpen(call, result);
    } else if (call.method === 'evaluateJs') {
      this.handleEvaluateJs(call, result);
    } else if (call.method === 'getCurrentUrl') {
      result.success(this.currentUrl);
    } else if (call.method === 'getCookies') {
      this.handleGetCookies(call, result);
    } else if (call.method === 'loadUrl') {
      this.handleLoadUrl(call, result);
    } else if (call.method === 'evalJs') {
      this.handleEvalJs(call, result);
    } else if (call.method === 'clearCookies') {
      this.handleClearCookies(call, result);
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
    let want: Want = {
      bundleName: 'com.venera.ohos',
      abilityName: 'WebViewAbility'
    };
    this.context.context.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'WebViewAbility started successfully');
      result.success(null);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to start WebViewAbility: ' + err.message);
      result.error('ERROR', 'Failed to start WebViewAbility', err.message);
    });
  }

  private handleEvaluateJs(call: BridgeMethodCall, result: MethodResult): void {
    let jsCode: string = this.extractJsCode(call.args);
    if (this.controller === null || jsCode.length === 0) {
      result.error('ERROR', 'No active webview', null);
      return;
    }
    try {
      this.controller.runJavaScript(jsCode);
      result.success(null);
    } catch (e) {
      result.error('ERROR', 'evaluateJs failed', null);
    }
  }

  private handleEvalJs(call: BridgeMethodCall, result: MethodResult): void {
    let jsCode: string = this.extractJsCode(call.args);
    if (this.controller === null || jsCode.length === 0) {
      result.error('ERROR', 'No active webview', null);
      return;
    }
    try {
      this.controller.runJavaScriptExt(jsCode, (err, value) => {
        if (err !== null && err !== undefined) {
          result.error('ERROR', 'evalJs failed', null);
        } else {
          result.success(value);
        }
      });
    } catch (e) {
      result.error('ERROR', 'evalJs failed', null);
    }
  }

  private handleLoadUrl(call: BridgeMethodCall, result: MethodResult): void {
    let url: string = this.extractUrl(call.args);
    if (this.controller === null || url.length === 0) {
      result.error('ERROR', 'No active webview', null);
      return;
    }
    try {
      this.controller.loadUrl(url);
      this.currentUrl = url;
      result.success(null);
    } catch (e) {
      result.error('ERROR', 'loadUrl failed', null);
    }
  }

  private handleGetCookies(call: BridgeMethodCall, result: MethodResult): void {
    let url: string = this.extractUrl(call.args);
    if (url.length === 0) {
      url = this.currentUrl;
    }
    try {
      let cookieStr: string = webview.WebCookieManager.fetchCookieSync(url);
      result.success(this.parseCookieHeader(cookieStr, url));
    } catch (e) {
      result.success([]);
    }
  }

  private handleClearCookies(call: BridgeMethodCall, result: MethodResult): void {
    let url: string = this.extractUrl(call.args);
    try {
      if (url.length > 0) {
        webview.WebCookieManager.clearSessionCookieSync();
      } else {
        webview.WebCookieManager.clearAllCookiesSync();
      }
      result.success(null);
    } catch (e) {
      result.error('ERROR', 'clearCookies failed', null);
    }
  }

  private handleClose(result: MethodResult): void {
    if (this.closeCallback !== null) {
      this.closeCallback();
      result.success(null);
    } else {
      result.error('ERROR', 'No active webview', null);
    }
  }

  private extractUrl(args: Object | null): string {
    if (args === null) {
      return '';
    }
    if (typeof args === 'string') {
      return args;
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

  private extractJsCode(args: Object | null): string {
    if (args === null) {
      return '';
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: WebViewJsParams = JSON.parse(jsonStr);
      if (parsed.jsCode !== undefined) {
        return parsed.jsCode;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse jsCode from args');
    }
    return '';
  }

  parseCookieHeader(cookieStr: string, url: string): Array<CookieEntry> {
    let result: Array<CookieEntry> = [];
    if (cookieStr.length === 0) {
      return result;
    }
    let parts: string[] = cookieStr.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      let trimmed: string = parts[i].trim();
      let eq: number = trimmed.indexOf('=');
      if (eq > 0) {
        let entry: CookieEntry = {
          name: trimmed.substring(0, eq),
          value: trimmed.substring(eq + 1),
          domain: url
        };
        result.push(entry);
      }
    }
    return result;
  }

  onCookiesReceived(url: string, cookies: string): void {
    let parsed: Array<CookieEntry> = this.parseCookieHeader(cookies, url);
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCookiesReceived', parsed);
  }

  onCloudflareDetected(url: string): void {
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCloudflareDetected', url);
  }

  onCloudflareResolved(url: string, cookies: string): void {
    let parsed: Array<CookieEntry> = this.parseCookieHeader(cookies, url);
    this.bridge.invokeMethod(CHANNEL_NAME, 'onCloudflareResolved', parsed);
  }
}

interface WebViewOpenParams {
  url: string;
}

interface WebViewJsParams {
  jsCode?: string;
}

interface CookieEntry {
  name: string;
  value: string;
  domain: string;
}
