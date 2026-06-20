@Component
export struct CodeEditor {
  @Prop content: string = ''
  onChange: (value: string) => void = () => {}
  @State lineNumbers: number[] = [1]

  aboutToAppear(): void {
    this.refreshLineNumbers();
  }

  aboutToUpdate(): void {
    this.refreshLineNumbers();
  }

  private refreshLineNumbers(): void {
    let lines: number = Math.max(1, this.content.split('\n').length);
    let nums: number[] = [];
    for (let i: number = 1; i <= lines; i++) {
      nums.push(i);
    }
    this.lineNumbers = nums;
  }

  build() {
    Row() {
      Column() {
        ForEach(this.lineNumbers, (num: number) => {
          Text(num.toString())
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width(40)
            .textAlign(TextAlign.End)
            .padding({ right: 8, top: 2, bottom: 2 })
        }, (num: number) => num.toString())
      }
      .padding({ top: 8, bottom: 8, left: 4 })
      .backgroundColor($r('app.color.card_background'))

      TextArea({ text: this.content })
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .fontFamily('monospace')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.page_background'))
        .onChange((value: string) => {
          this.onChange(value);
          this.refreshLineNumbers();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }
}
