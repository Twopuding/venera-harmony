import { HdsTheme } from '../design/HdsTheme'

@Component
export struct ContentDialog {
  @Prop title: string = ''
  @Prop dismissible: boolean = true
  @BuilderParam content: () => void
  @BuilderParam actions: () => void = this._defaultActions
  @Prop show: boolean = false
  onClose: (() => void) | null = null

  @Builder
  _defaultActions() {
  }

  build() {
    if (this.show) {
      Column() {
        Column() {
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 24, right: 24, top: 24, bottom: 16 })

          Column() {
            this.content()
          }
          .padding({ left: 24, right: 24 })
          .layoutWeight(1)

          Row() {
            this.actions()
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width('90%')
        .maxHeight('80%')
        .borderRadius(24)
        .backgroundBlurStyle(HdsTheme.cardBlurStyle())
        .border({ width: 0.5, color: $r('app.color.card_border') })
        .shadow({ radius: 20, color: $r('app.color.overlay_background') })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.overlay_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onClick(() => {
        if (this.dismissible && this.onClose !== null) {
          this.onClose!()
        }
      })
    }
  }
}
