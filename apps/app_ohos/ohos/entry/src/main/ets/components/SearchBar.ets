import { HdsTheme } from '../design/HdsTheme'

@Component
export struct SearchBar {
  @Prop placeholder: string = 'Search'
  @State searchText: string = ''
  onSearch: ((query: string) => void) | null = null
  onTap: (() => void) | null = null

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(20)
        .fontColor([$r('app.color.icon_secondary')])
        .margin({ right: 8 })
      Text(this.placeholder)
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .borderRadius(28)
    .backgroundBlurStyle(HdsTheme.thickBlurStyle())
    .border({ width: 0.5, color: $r('app.color.card_border') })
    .onClick(() => {
      if (this.onTap !== null) {
        this.onTap!()
      }
    })
  }
}
