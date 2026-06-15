@Component
export struct NetworkError {
  @Prop message: string = ''
  onRetry: (() => void) | null = null

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.wifi_slash'))
        .fontSize(48)
        .fontColor([$r('app.color.icon_secondary')])
        .margin({ bottom: 16 })
      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ bottom: 16 })
      Button('Retry')
        .type(ButtonType.Normal)
        .borderRadius(20)
        .backgroundColor($r('app.color.color_emphasize'))
        .fontColor(Color.White)
        .onClick(() => {
          if (this.onRetry !== null) {
            this.onRetry!()
          }
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
