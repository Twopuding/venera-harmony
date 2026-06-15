@Component
export struct LoadingIndicator {
  build() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color($r('sys.color.ohos_id_color_activated'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
