import { Comic } from '../model/Comic'
import { ComicTile } from './ComicTile'

@Component
export struct ComicGrid {
  @Prop comics: Comic[] = []
  @Prop mode: string = 'brief'
  @Prop columns: number = 3
  onItemTap: ((comic: Comic, index: number) => void) | null = null
  onLastItemBuild: (() => void) | null = null

  build() {
    Grid() {
      ForEach(this.comics, (comic: Comic, index: number) => {
        GridItem() {
          ComicTile({
            comic: comic,
            mode: this.mode,
            badge: comic.language,
            onTap: () => {
              if (this.onItemTap !== null) {
                this.onItemTap!(comic, index)
              }
            }
          })
        }
      }, (comic: Comic) => comic.id + comic.sourceKey)
    }
    .columnsTemplate('1fr '.repeat(this.columns).trim())
    .rowsGap(8)
    .columnsGap(8)
    .width('100%')
  }
}
