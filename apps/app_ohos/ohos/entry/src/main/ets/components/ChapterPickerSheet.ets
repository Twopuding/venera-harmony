import { ChapterInfo } from '../viewmodel/ReaderViewModel';

@Component
export struct ChapterPickerSheet {
  @Prop chapters: ChapterInfo[] = []
  @Prop currentIndex: number = 0
  onSelect: (index: number) => void = () => {}
  onClose: () => void = () => {}

  build() {
    Column() {
      Row() {
        Text('Chapters')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('Close')
          .fontSize(14)
          .fontColor($r('app.color.color_emphasize'))
          .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      List() {
        ForEach(this.chapters, (chapter: ChapterInfo, index: number) => {
          ListItem() {
            Row() {
              Text(`E${index + 1}`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .width(40)
              Text(chapter.name)
                .fontSize(15)
                .fontColor(index === this.currentIndex ?
                  $r('app.color.color_emphasize') : $r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(index === this.currentIndex ?
              $r('app.color.badge_bg') : Color.Transparent)
            .borderRadius(8)
            .onClick(() => this.onSelect(index))
          }
        }, (chapter: ChapterInfo, index: number) => chapter.id + index.toString())
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
