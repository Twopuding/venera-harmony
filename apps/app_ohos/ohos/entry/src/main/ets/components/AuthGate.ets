import { DataService } from '../service/DataService';
import { PlatformBiometricAuth } from '../bridge/PlatformBridge';
import { TranslationUtil } from '../utils/TranslationUtil';

@Component
export struct AuthGate {
  onAuthSuccess: () => void = () => {}
  @Prop @Watch('onPageShowTick') pageShowTick: number = 0
  @State isAuthenticating: boolean = false
  @State message: string = ''
  private context = getContext(this)

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
  }

  onPageShowTick(): void {
    if (this.pageShowTick > 0) {
      this.scheduleAuthenticate();
    }
  }

  private scheduleAuthenticate(): void {
    setTimeout(() => {
      this.authenticate();
    }, 100);
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async authenticate(): Promise<void> {
    if (this.isAuthenticating) {
      return;
    }
    this.isAuthenticating = true;
    this.message = '';
    let settings = await DataService.getInstance().getSettings();
    let useFace = DataService.settingIsTrue(settings, 'useFaceAuth');
    let useFp = DataService.settingIsTrue(settings, 'useFingerprintAuth');
    let reason = this.tl('Please authenticate to continue');
    let ok = await PlatformBiometricAuth.authenticate(reason, useFace, useFp);
    this.isAuthenticating = false;
    if (ok) {
      this.onAuthSuccess();
    } else {
      this.message = this.tl('Authentication failed');
    }
  }

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.lock_shield'))
        .fontSize(48)
        .fontColor([$r('app.color.color_emphasize')])
        .margin({ bottom: 16 })
      Text(this.tl('Authentication Required'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 16 })
      }
      Button(this.tl('Continue'))
        .enabled(!this.isAuthenticating)
        .width('60%')
        .onClick(() => this.authenticate())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.page_background'))
  }
}
