@Component
export struct StarRating {
  @Prop value: number = 0
  @Prop starSize: number = 16

  build() {
    Row() {
      ForEach([0, 1, 2, 3, 4], (i: number) => {
        Stack() {
          SymbolGlyph($r('sys.symbol.star'))
            .fontSize(this.starSize)
            .fontColor([$r('app.color.icon_secondary')])

          if (this.value > i) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(this.starSize)
              .fontColor([$r('app.color.color_emphasize')])
          }
        }
        .width(this.starSize)
        .height(this.starSize)
        .margin({ right: i < 4 ? 2 : 0 })
      }, (i: number) => i.toString())
    }
  }
}
