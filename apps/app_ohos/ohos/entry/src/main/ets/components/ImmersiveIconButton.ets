import { HdsTheme } from '../design/HdsTheme';

@Component
export struct ImmersiveIconButton {
  @Prop icon: Resource = $r('sys.symbol.chevron_left')
  @Prop iconSize: number = 20
  @Prop buttonSize: number = 40
  onTap: (() => void) | null = null

  build() {
    Row() {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
        .fontColor([$r('app.color.text_primary')])
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(HdsTheme.iconButtonBlurStyle())
    .onClick(() => {
      if (this.onTap !== null) {
        this.onTap!();
      }
    })
  }
}
