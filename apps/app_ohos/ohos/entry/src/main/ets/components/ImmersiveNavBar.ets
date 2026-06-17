import { HdsTheme } from '../design/HdsTheme'

@Component
export struct ImmersiveNavBar {
  @Prop title: string = ''
  @BuilderParam rightContent: () => void = this._defaultRight
  @BuilderParam leftContent: () => void = this._defaultLeft

  @Builder
  _defaultRight() {
  }

  @Builder
  _defaultLeft() {
  }

  build() {
    Row() {
      Row() {
        this.leftContent()
      }
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .padding({ left: 16 })
      Row() {
        this.rightContent()
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundBlurStyle(HdsTheme.cardBlurStyle())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
