import { HdsTheme } from '../design/HdsTheme'

@Component
export struct BlurCard {
  @Prop useThickBlur: boolean = false
  @Prop cardRadius: number = 16
  @Prop cardPadding: number = 16
  @Prop cardBorderColor: ResourceColor = $r('app.color.card_border')
  @Prop cardBorderWidth: number = 0.5
  @BuilderParam content: () => void

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .borderRadius(this.cardRadius)
    .padding(this.cardPadding)
    .backgroundBlurStyle(this.useThickBlur ? HdsTheme.thickBlurStyle() : HdsTheme.cardBlurStyle())
    .border({ width: this.cardBorderWidth, color: this.cardBorderColor })
    .shadow({ radius: 8, color: $r('app.color.shadow_light'), offsetY: 2 })
  }
}
