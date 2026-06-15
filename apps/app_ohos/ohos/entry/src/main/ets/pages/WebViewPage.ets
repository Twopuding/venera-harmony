import { webview } from '@kit.ArkWeb';
import { WebViewBridge } from '../bridge/WebViewBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

const TAG: string = 'WebViewPage';
const DOMAIN: number = 0x0000;
const CF_CLEARANCE: string = 'cf_clearance';
const CF_CHALLENGE: string = 'cf-chl-bypass';
const STORAGE_KEY_URL: string = 'webview_target_url';

@Entry
@Component
struct WebViewPage {
  @State currentUrl: string = '';
  @State title: string = '';
  @State isLoading: boolean = false;
  @State canGoBack: boolean = false;
  @State canGoForward: boolean = false;
  @StorageLink(STORAGE_KEY_URL) initialUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: WebViewBridge = new WebViewBridge();

  aboutToAppear(): void {
    this.currentUrl = this.initialUrl;
    webview.WebviewController.setWebDebuggingAccess(true);
    hilog.info(DOMAIN, TAG, 'WebViewPage aboutToAppear, url: ' + this.initialUrl);
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
              this.checkCloudflare(event.url);
            }
          })
          .onPageEnd((event) => {
            if (event !== null && event.url !== undefined) {
              this.isLoading = false;
              this.updateNavigationState();
              hilog.info(DOMAIN, TAG, 'Page end: ' + event.url);
              this.extractCookies(event.url);
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
    this.canGoBack = this.controller.accessBackward();
    this.canGoForward = this.controller.accessForward();
  }

  private onGoBack(): void {
    if (this.controller.accessBackward()) {
      this.controller.backward();
    }
  }

  private onGoForward(): void {
    if (this.controller.accessForward()) {
      this.controller.forward();
    }
  }

  private onClose(): void {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.terminateSelf();
  }

  private checkCloudflare(url: string): void {
    try {
      let cookies: string = webview.WebCookieManager.fetchCookieSync(url);
      let hasCfChallenge: boolean = cookies.indexOf(CF_CHALLENGE) !== -1;
      let hasCfClearance: boolean = cookies.indexOf(CF_CLEARANCE) !== -1;
      if (hasCfChallenge && !hasCfClearance) {
        this.bridge.onCloudflareDetected(url);
        hilog.info(DOMAIN, TAG, 'Cloudflare challenge detected for: ' + url);
      } else if (hasCfClearance) {
        this.bridge.onCloudflareResolved(url, cookies);
        hilog.info(DOMAIN, TAG, 'Cloudflare resolved for: ' + url);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Cookie check failed');
    }
  }

  private extractCookies(url: string): void {
    try {
      let cookies: string = webview.WebCookieManager.fetchCookieSync(url);
      if (cookies.length > 0) {
        this.bridge.onCookiesReceived(url, cookies);
        hilog.info(DOMAIN, TAG, 'Cookies extracted for: ' + url);
        let hasCfClearance: boolean = cookies.indexOf(CF_CLEARANCE) !== -1;
        if (hasCfClearance) {
          this.bridge.onCloudflareResolved(url, cookies);
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Cookie extraction failed');
    }
  }
}
