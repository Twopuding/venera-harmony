import router from '@ohos.router';
import {
  ComicSourceAccountConfig,
  DataService
} from '../service/DataService';
import { ImmersivePageScaffold } from '../components/ImmersivePageScaffold';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { RouterUtil } from '../navigation/RouterUtil';
import { TranslationUtil } from '../utils/TranslationUtil';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct ComicSourceLoginPage {
  @State sourceKey: string = ''
  @State sourceName: string = ''
  @State config: ComicSourceAccountConfig = { hasAccount: false }
  @State username: string = ''
  @State password: string = ''
  @State cookieValues: string[] = []
  @State isLoading: boolean = true
  @State isSubmitting: boolean = false
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? this.sourceKey;
    this.loadConfig();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async loadConfig(): Promise<void> {
    this.isLoading = true;
    this.config = await DataService.getInstance().getComicSourceAccountConfig(this.sourceKey);
    let fields = this.config.cookieFields ?? [];
    this.cookieValues = [];
    for (let i: number = 0; i < fields.length; i++) {
      this.cookieValues.push('');
    }
    this.isLoading = false;
  }

  private async submitLogin(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    let error: string | null = null;
    if (this.config.hasPasswordLogin === true) {
      error = await DataService.getInstance().comicSourceLogin(
        this.sourceKey, this.username, this.password
      );
    } else if (this.config.hasCookieLogin === true) {
      error = await DataService.getInstance().comicSourceLogin(
        this.sourceKey, undefined, undefined, this.cookieValues
      );
    } else {
      error = this.tl('Login with password is disabled');
    }
    this.isSubmitting = false;
    if (error !== null) {
      promptAction.showToast({ message: error });
      return;
    }
    promptAction.showToast({ message: this.tl('Success') });
    RouterUtil.back();
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else {
      Column() {
        Text(this.tl('Login'))
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 24 })

        if (this.config.hasPasswordLogin === true) {
          TextInput({ placeholder: this.tl('Username'), text: this.username })
            .width('100%')
            .margin({ bottom: 12 })
            .onChange((v: string) => { this.username = v; })
          TextInput({ placeholder: this.tl('Password'), text: this.password })
            .width('100%')
            .type(InputType.Password)
            .margin({ bottom: 16 })
            .onChange((v: string) => { this.password = v; })
            .onSubmit(() => this.submitLogin())
        }

        if (this.config.hasCookieLogin === true && this.config.cookieFields !== undefined) {
          ForEach(this.config.cookieFields, (field: string, index: number) => {
            TextInput({ placeholder: field, text: this.cookieValues[index] ?? '' })
              .width('100%')
              .type(InputType.Password)
              .margin({ bottom: 12 })
              .onChange((v: string) => {
                this.cookieValues[index] = v;
              })
          }, (field: string, index: number) => `${field}_${index}`)
        }

        if (this.config.hasPasswordLogin !== true && this.config.hasCookieLogin !== true) {
          Text(this.tl('Login with password is disabled'))
            .fontColor($r('app.color.text_secondary'))
        } else {
          Button(this.tl('Continue'))
            .width('100%')
            .enabled(!this.isSubmitting)
            .onClick(() => this.submitLogin())
        }

        if (this.config.loginWebsite !== undefined && this.config.loginWebsite.length > 0) {
          Button(this.tl('Login with webview'))
            .width('100%')
            .margin({ top: 16 })
            .type(ButtonType.Normal)
            .onClick(() => RouterUtil.openWebView(this.config.loginWebsite!))
        }

        if (this.config.registerWebsite !== undefined && this.config.registerWebsite.length > 0) {
          Button(this.tl('Create Account'))
            .width('100%')
            .margin({ top: 8 })
            .type(ButtonType.Normal)
            .onClick(() => RouterUtil.launchUrl(this.config.registerWebsite!))
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 400 })
      .padding(24)
    }
  }

  @Builder
  centeredContent() {
    Column() {
      this.pageContent()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: `${this.tl('Login')} - ${this.sourceName}`,
        showBack: true,
        scrollable: false,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.centeredContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
