import router from '@ohos.router';
import { DataService, ImageFavoriteImage } from '../../service/DataService';
import { ReaderImage } from '../../components/ReaderImage';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { NavigationMenus } from '../../navigation/NavigationMenus';
import { RouterUtil } from '../../navigation/RouterUtil';

@Entry
@Component
struct ImageFavoritesPhotoPage {
  @State comicId: string = ''
  @State sourceKey: string = ''
  @State title: string = ''
  @State images: ImageFavoriteImage[] = []
  @State currentIndex: number = 0
  @State isLoading: boolean = true
  private swiperController: SwiperController = new SwiperController()

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    this.comicId = params['comicId'] ?? '';
    this.sourceKey = params['sourceKey'] ?? '';
    this.title = params['title'] ?? '';
    this.loadImages();
  }

  private async loadImages(): Promise<void> {
    this.isLoading = true;
    this.images = await DataService.getInstance().getImageFavoriteImages(
      this.comicId, this.sourceKey
    );
    this.isLoading = false;
  }

  private openReaderAtCurrent(): void {
    if (this.images.length === 0) {
      return;
    }
    let img: ImageFavoriteImage = this.images[this.currentIndex];
    RouterUtil.openReader(this.comicId, this.sourceKey, img.ep.toString(), img.page);
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
    } else if (this.images.length === 0) {
      Text('No images')
        .layoutWeight(1)
        .fontColor($r('app.color.text_secondary'))
    } else {
      Swiper(this.swiperController) {
        ForEach(this.images, (img: ImageFavoriteImage, index: number) => {
          ReaderImage({
            imageKey: img.url,
            ep: img.ep,
            page: img.page
          })
        }, (img: ImageFavoriteImage, index: number) => img.url + index.toString())
      }
      .index(this.currentIndex)
      .indicator(true)
      .loop(false)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .onClick(() => this.openReaderAtCurrent())
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.title.length > 0 ? this.title : 'Images',
        showBack: true,
        scrollable: false,
        onBack: () => RouterUtil.back(),
        menus: NavigationMenus.single($r('sys.symbol.book'), 'Read', () => this.openReaderAtCurrent()),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
