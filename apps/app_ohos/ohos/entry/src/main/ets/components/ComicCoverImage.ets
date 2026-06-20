import { DataService } from '../service/DataService';

@Component
export struct ComicCoverImage {
  @Prop coverUrl: string = ''
  @Prop sourceKey: string = ''
  @Prop comicId: string = ''
  @Prop fallbackLocal: boolean = true
  @Prop coverRadius: number = 8
  @State imageSrc: string = ''
  @State isLoading: boolean = true
  @State hasError: boolean = false

  aboutToAppear(): void {
    this.loadCover();
  }

  aboutToUpdate(): void {
    this.loadCover();
  }

  private async loadCover(): Promise<void> {
    if (this.coverUrl.length === 0) {
      this.isLoading = false;
      this.hasError = true;
      return;
    }
    if (this.coverUrl.startsWith('http://') || this.coverUrl.startsWith('https://')) {
      this.imageSrc = this.coverUrl;
      this.isLoading = false;
      this.hasError = false;
      return;
    }
    if (this.coverUrl.startsWith('file://')) {
      this.imageSrc = this.coverUrl;
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    let base64: string | null = await DataService.getInstance().loadCoverImageBase64(
      this.coverUrl,
      this.sourceKey.length > 0 ? this.sourceKey : undefined,
      this.comicId.length > 0 ? this.comicId : undefined,
      this.fallbackLocal
    );
    if (base64 !== null && base64.length > 0) {
      this.imageSrc = 'data:image/jpeg;base64,' + base64;
      this.hasError = false;
    } else {
      this.hasError = true;
    }
    this.isLoading = false;
  }

  build() {
    Stack() {
      if (this.isLoading) {
        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.placeholder_bg'))
      } else if (this.hasError || this.imageSrc.length === 0) {
        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.placeholder_bg'))
      } else {
        Image(this.imageSrc)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverRadius)
          .alt($r('app.color.placeholder_bg'))
          .onError(() => {
            this.hasError = true;
          })
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.coverRadius)
    .clip(true)
  }
}
