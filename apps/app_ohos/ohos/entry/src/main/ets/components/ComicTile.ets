import { Comic } from '../model/Comic'
import { HdsTheme } from '../design/HdsTheme'
import { ComicCoverImage } from './ComicCoverImage'
import { DisplaySettings } from '../utils/DisplaySettings'
import { ComicHistoryStatus } from '../service/DataService'

@Component
export struct ComicTile {
  @Prop comic: Comic = new Comic()
  @Prop mode: string = 'brief'
  @Prop badge: string = ''
  @Prop tileScale: number = 1
  @Prop isFavorite: boolean = false
  @Prop historyStatus: ComicHistoryStatus | null = null
  @Prop enableHero: boolean = true
  onTap: (() => void) | null = null
  onLongPress: (() => void) | null = null

  build() {
    Stack() {
      if (this.mode === 'detailed') {
        this._buildDetailedMode()
      } else {
        this._buildBriefMode()
      }
      if (this.isFavorite || this.historyStatus !== null) {
        Row() {
          if (this.isFavorite) {
            SymbolGlyph($r('sys.symbol.bookmark_fill'))
              .fontSize(14)
              .fontColor([Color.White])
              .width(24)
              .height(24)
              .backgroundColor('#4CAF50')
              .borderRadius(4)
          }
          if (this.historyStatus !== null) {
            Text(`${this.historyStatus.ep}-${this.historyStatus.page}`)
              .fontSize(10)
              .fontColor(Color.White)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor('#2196F3')
              .borderRadius(4)
              .margin({ left: this.isFavorite ? 4 : 0 })
          }
        }
        .position({ x: this.mode === 'detailed' ? 16 : 6, y: 8 })
      }
    }
    .width('100%')
    .scale({ x: this.tileScale, y: this.tileScale })
  }

  @Builder
  _buildBriefMode() {
    Column() {
      Stack() {
        ComicCoverImage({
          coverUrl: this.comic.cover,
          sourceKey: this.comic.sourceKey,
          comicId: this.comic.id,
          coverRadius: 8
        })
          .width('100%')
          .aspectRatio(0.64)
          .sharedTransition(this.enableHero ? `${this.comic.sourceKey}:${this.comic.id}` : '',
            { duration: 300, curve: Curve.EaseInOut })

        if (this.badge.length > 0) {
          Text(this.badge.charAt(0).toUpperCase() + this.badge.substring(1).toLowerCase())
            .fontSize(10)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .borderRadius(4)
            .backgroundColor($r('app.color.badge_bg'))
            .fontColor(Color.White)
            .position({ x: 4, y: 4 })
        }
      }
      .width('100%')

      Text(this.comic.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 4, right: 4, top: 4 })
        .width('100%')
    }
    .width('100%')
    .borderRadius(8)
    .backgroundBlurStyle(HdsTheme.thickBlurStyle())
    .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 1 })
    .onClick(() => {
      if (this.onTap !== null) {
        this.onTap!()
      }
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (this.onLongPress !== null) {
            this.onLongPress!()
          }
        })
    )
  }

  @Builder
  _buildDetailedMode() {
    Row() {
      ComicCoverImage({
        coverUrl: this.comic.cover,
        sourceKey: this.comic.sourceKey,
        comicId: this.comic.id,
        coverRadius: 8
      })
        .width(80)
        .height(112)
        .flexShrink(0)

      Column() {
        Text(this.comic.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.comic.subtitle.length > 0) {
          Text(this.comic.subtitle)
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .margin({ top: 2 })
        }

        if (this.comic.tags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.comic.tags.slice(0, 5), (tag: string) => {
              Text(this._getDisplayTag(tag))
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor($r('app.color.tag_bg'))
                .margin({ right: 4, top: 2 })
            }, (tag: string) => tag)
          }
          .margin({ top: 4 })
        }

        Blank()

        Row() {
          Text(this.comic.description)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.badge.length > 0) {
            Text(this.badge.charAt(0).toUpperCase() + this.badge.substring(1).toLowerCase())
              .fontSize(11)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor($r('app.color.badge_bg'))
              .fontColor(Color.White)
          }
        }
      }
      .layoutWeight(1)
      .padding({ left: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(8)
    .borderRadius(12)
    .backgroundBlurStyle(HdsTheme.cardBlurStyle())
    .border({ width: 0.5, color: $r('app.color.card_border') })
    .onClick(() => {
      if (this.onTap !== null) {
        this.onTap!()
      }
    })
  }

  private _getDisplayTag(tag: string): string {
    let parts: string[] = tag.split(':')
    if (parts.length > 1) {
      return parts[parts.length - 1]
    }
    return tag
  }
}
