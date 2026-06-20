import { HdsTheme } from '../design/HdsTheme'

@Component
export struct ContentDialog {
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop confirmLabel: string = 'OK'
  @Prop cancelLabel: string = 'Cancel'
  @Prop show: boolean = false
  @Prop showCancel: boolean = true
  onClose: (() => void) | null = null
  onConfirm: (() => void) | null = null

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

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ left: 24, right: 24, bottom: 16 })
          }

          Row() {
            if (this.showCancel) {
              Button(this.cancelLabel)
                .backgroundColor(Color.Transparent)
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  if (this.onClose !== null) {
                    this.onClose!();
                  }
                })
            }
            Button(this.confirmLabel)
              .margin({ left: 8 })
              .fontColor(Color.White)
              .backgroundColor($r('app.color.color_emphasize'))
              .onClick(() => {
                if (this.onConfirm !== null) {
                  this.onConfirm!();
                } else if (this.onClose !== null) {
                  this.onClose!();
                }
              })
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width('90%')
        .height('40%')
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
    }
  }
}

@Component
export struct ContentDialogCustom {
  @Prop title: string = ''
  @Prop show: boolean = false
  @BuilderParam content: () => void = this._emptyContent
  @BuilderParam actions: () => void = this._emptyActions
  onClose: (() => void) | null = null

  @Builder
  _emptyContent() {
  }

  @Builder
  _emptyActions() {
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
        .height('80%')
        .borderRadius(24)
        .backgroundBlurStyle(HdsTheme.cardBlurStyle())
        .border({ width: 0.5, color: $r('app.color.card_border') })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.overlay_background'))
    }
  }
}
