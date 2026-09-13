import { webview } from '@kit.ArkWeb';
import { WebViewBridge } from '../bridge/WebViewBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG: string = 'WebViewPage';
const DOMAIN: number = 0x0000;
const CF_CLEARANCE: string = 'cf_clearance';
const STORAGE_KEY_URL: string = 'webview_target_url';
const STORAGE_KEY_CLOSE: string = 'webview_should_close';

@Entry
@Component
struct WebViewPage {
  @State currentUrl: string = '';
  @State title: string = '';
  @State isLoading: boolean = false;
  @State canGoBack: boolean = false;
  @State canGoForward: boolean = false;
  @StorageLink(STORAGE_KEY_URL) initialUrl: string = '';
  @StorageLink(STORAGE_KEY_CLOSE) @Watch('onShouldCloseChanged') shouldClose: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: WebViewBridge = new WebViewBridge();
  private resolved: boolean = false;
  private closedNotified: boolean = false;

  aboutToAppear(): void {
    this.currentUrl = this.initialUrl;
    this.resolved = false;
    this.closedNotified = false;
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLOSE, false);
    webview.WebviewController.setWebDebuggingAccess(true);
    hilog.info(DOMAIN, TAG, 'WebViewPage aboutToAppear, url: ' + this.initialUrl);
  }

  aboutToDisappear(): void {
    this.notifyClosedIfNeeded();
  }

  onShouldCloseChanged(): void {
    if (this.shouldClose) {
      hilog.info(DOMAIN, TAG, 'Close requested via AppStorage');
      this.onClose();
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .enabled(this.canGoBack)
          .opacity(this.canGoBack ? 1.0 : 0.3)
          .onClick(() => {
            this.onGoBack();
          })

        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .margin({ left: 16 })
          .enabled(this.canGoForward)
          .opacity(this.canGoForward ? 1.0 : 0.3)
          .onClick(() => {
            this.onGoForward();
          })

        Text(this.title)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(Color.White)
          .fontSize(14)
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })
          .textAlign(TextAlign.Center)

        Image($r('sys.media.ohos_ic_public_cancel'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#80000000')

      Stack() {
        Web({ src: this.initialUrl, controller: this.controller })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .cacheMode(CacheMode.Default)
          .onPageBegin((event) => {
            if (event !== null && event.url !== undefined) {
              this.currentUrl = event.url;
              this.isLoading = true;
              this.updateNavigationState();
              hilog.info(DOMAIN, TAG, 'Page begin: ' + event.url);
            }
          })
          .onPageEnd((event) => {
            if (event !== null && event.url !== undefined) {
              this.isLoading = false;
              this.updateNavigationState();
              hilog.info(DOMAIN, TAG, 'Page end: ' + event.url);
              this.extractCookies(event.url);
              this.checkCloudflareResolved(event.url);
            }
          })
          .onTitleReceive((event) => {
            if (event !== null && event.title !== undefined) {
              this.title = event.title;
            }
          })
          .onErrorReceive((event) => {
            if (event !== null) {
              hilog.error(DOMAIN, TAG, 'Web error: ' + event.error.getErrorInfo());
            }
          })

        if (this.isLoading) {
          LoadingProgress()
            .color(Color.Blue)
            .width(40)
            .height(40)
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  private updateNavigationState(): void {
    try {
      this.canGoBack = this.controller.accessBackward();
      this.canGoForward = this.controller.accessForward();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'updateNavigationState failed');
    }
  }

  private onGoBack(): void {
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'onGoBack failed');
    }
  }

  private onGoForward(): void {
    try {
      if (this.controller.accessForward()) {
        this.controller.forward();
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'onGoForward failed');
    }
  }

  private onClose(): void {
    this.notifyClosedIfNeeded();
    try {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.terminateSelf();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'terminateSelf failed on close');
    }
  }

  private notifyClosedIfNeeded(): void {
    if (this.closedNotified || this.resolved) {
      return;
    }
    this.closedNotified = true;
    this.bridge.onClosed();
    hilog.info(DOMAIN, TAG, 'Notified Flutter: onClosed');
  }

  private async checkCloudflareResolved(url: string): Promise<void> {
    if (this.resolved) {
      return;
    }
    try {
      let cookies: string = webview.WebCookieManager.fetchCookieSync(url);
      if (!this.cookieHas(cookies, CF_CLEARANCE)) {
        return;
      }
      this.resolved = true;
      let ua: string = await this.getUserAgent();
      if (ua.length > 0) {
        this.bridge.onUserAgentReceived(ua);
      }
      this.bridge.onCloudflareResolved(url, cookies, ua);
      hilog.info(DOMAIN, TAG, 'Cloudflare resolved for: ' + url);
      // Auto-close after successful verification.
      setTimeout((): void => {
        this.onCloseAfterResolve();
      }, 300);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Cloudflare resolve check failed');
      this.resolved = false;
    }
  }

  private onCloseAfterResolve(): void {
    // Already resolved — skip onClosed so Flutter does not treat as cancel.
    this.closedNotified = true;
    try {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.terminateSelf();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'terminateSelf failed after resolve');
    }
  }

  private cookieHas(cookieHeader: string, name: string): boolean {
    let parts: string[] = cookieHeader.split(';');
    for (let i = 0; i < parts.length; i++) {
      let part: string = parts[i].trim();
      if (part === name || part.indexOf(name + '=') === 0) {
        return true;
      }
    }
    return false;
  }

  private extractCookies(url: string): void {
    try {
      let cookies: string = webview.WebCookieManager.fetchCookieSync(url);
      if (cookies.length > 0) {
        this.bridge.onCookiesReceived(url, cookies);
        hilog.info(DOMAIN, TAG, 'Cookies extracted for: ' + url);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Cookie extraction failed');
    }
  }

  async getLocalStorage(): Promise<Record<string, string>> {
    let jsCode: string = `
      (function() {
        var items = {};
        for (var i = 0; i < localStorage.length; i++) {
          var key = localStorage.key(i);
          if (key !== null) {
            items[key] = localStorage.getItem(key);
          }
        }
        return JSON.stringify(items);
      })()
    `;
    try {
      let result: string = await this.controller.runJavaScript(jsCode) as string;
      let parsed: Record<string, string> = JSON.parse(result);
      return parsed;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to get localStorage: ' + e);
      return {};
    }
  }

  async getUserAgent(): Promise<string> {
    let jsCode: string = 'navigator.userAgent';
    try {
      let result: string = await this.controller.runJavaScript(jsCode) as string;
      // ArkWeb may wrap the result in quotes.
      if (result.length >= 2 && result.charAt(0) === '"' && result.charAt(result.length - 1) === '"') {
        result = result.substring(1, result.length - 1);
      }
      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to get UserAgent: ' + e);
      return '';
    }
  }

  clearCache(): void {
    try {
      this.controller.clearHistory();
      webview.WebCookieManager.clearAllCookiesSync();
      hilog.info(DOMAIN, TAG, 'Cache cleared');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to clear cache: ' + e);
    }
  }
}
