import { ReaderBridge } from '../bridge/ReaderBridge';
import { util } from '@kit.ArkTS';

@Component
export struct ReaderImage {
  @Prop imageKey: string = ''
  @Prop ep: number = 1
  @Prop page: number = 1
  @Prop sourceKey: string = ''
  @Prop comicId: string = ''
  @Prop chapterId: string = ''
  @Prop enableDoubleTapZoom: boolean = true
  @Prop enableLongPressZoom: boolean = true
  @Prop limitWidth: boolean = false
  @Prop quickCollectMode: string = 'No'
  @Prop isActivePage: boolean = true
  @Prop shouldPreload: boolean = true
  onCollectImage: (() => void) | null = null
  @State imageSrc: string = ''
  @State isLoading: boolean = true
  @State hasError: boolean = false
  @State imageScale: number = 1
  @State offsetX: number = 0
  @State offsetY: number = 0

  aboutToAppear(): void {
    this.resolveImage();
  }

  aboutToUpdate(): void {
    this.resolveImage();
  }

  private isDirectUrl(key: string): boolean {
    return key.startsWith('http://') || key.startsWith('https://') ||
      key.startsWith('file://') || key.startsWith('data:');
  }

  private bytesToBase64(data: number[]): string {
    let helper = new util.Base64Helper();
    let uint8 = new Uint8Array(data);
    return helper.encodeToStringSync(uint8);
  }

  private parseImageBytes(raw: Object | null): string | null {
    if (raw === null) {
      return null;
    }
    if (typeof raw === 'string') {
      if (raw.startsWith('data:')) {
        return raw;
      }
      return raw.length > 0 ? raw : null;
    }
    try {
      let jsonStr: string = JSON.stringify(raw);
      let parsed: Object = JSON.parse(jsonStr);
      if (Array.isArray(parsed)) {
        let nums: number[] = parsed as number[];
        if (nums.length === 0) {
          return null;
        }
        return 'data:image/jpeg;base64,' + this.bytesToBase64(nums);
      }
      let obj = parsed as Record<string, Object>;
      if (obj['base64'] !== undefined && typeof obj['base64'] === 'string') {
        return 'data:image/jpeg;base64,' + (obj['base64'] as string);
      }
      if (obj['data'] !== undefined && Array.isArray(obj['data'])) {
        let nums: number[] = obj['data'] as number[];
        if (nums.length === 0) {
          return null;
        }
        return 'data:image/jpeg;base64,' + this.bytesToBase64(nums);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  private async resolveImage(): Promise<void> {
    if (this.imageKey.length === 0) {
      this.isLoading = false;
      this.hasError = true;
      return;
    }
    if (!this.shouldPreload && !this.isActivePage) {
      return;
    }
    if (this.isDirectUrl(this.imageKey)) {
      this.imageSrc = this.imageKey;
      this.isLoading = false;
      this.hasError = false;
      return;
    }
    this.isLoading = true;
    this.hasError = false;
    try {
      let raw: Object | null = await ReaderBridge.getInstance().onLoadImage(
        this.imageKey, this.ep, this.page,
        this.sourceKey.length > 0 ? this.sourceKey : undefined,
        this.comicId.length > 0 ? this.comicId : undefined,
        this.chapterId.length > 0 ? this.chapterId : undefined
      );
      let src: string | null = this.parseImageBytes(raw);
      if (src !== null && src.length > 0) {
        this.imageSrc = src;
        this.hasError = false;
      } else {
        this.hasError = true;
      }
    } catch (e) {
      this.hasError = true;
    } finally {
      this.isLoading = false;
    }
  }

  private toggleZoom(): void {
    if (this.imageScale > 1) {
      this.imageScale = 1;
      this.offsetX = 0;
      this.offsetY = 0;
    } else {
      this.imageScale = 2;
    }
  }

  private onDoubleTap(): void {
    if (this.quickCollectMode === 'DoubleTap' && this.isActivePage && this.onCollectImage !== null) {
      this.onCollectImage!();
      return;
    }
    if (this.enableDoubleTapZoom) {
      this.toggleZoom();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.isLoading) {
        Progress({ value: 40, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color('#99FFFFFF')
          .backgroundColor('#33FFFFFF')
      }
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color('#99FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.hasError || this.imageSrc.length === 0) {
        Text('!')
          .fontSize(24)
          .fontColor('#66FFFFFF')
      } else {
        Image(this.imageSrc)
          .width(this.limitWidth ? '90%' : '100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.Black)
          .scale({ x: this.imageScale, y: this.imageScale })
          .translate({ x: this.offsetX, y: this.offsetY })
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 })
                .onAction(() => {
                  this.onDoubleTap();
                }),
              LongPressGesture({ repeat: false })
                .onAction(() => {
                  if (this.enableLongPressZoom) {
                    this.toggleZoom();
                  }
                }),
              PanGesture({ direction: PanDirection.All, distance: 40 })
                .onActionEnd((event: GestureEvent) => {
                  if (this.quickCollectMode !== 'Swipe' || !this.isActivePage ||
                    this.onCollectImage === null) {
                    return;
                  }
                  if (event.offsetX !== undefined && Math.abs(event.offsetX) > 60) {
                    this.onCollectImage!();
                  } else if (event.offsetY !== undefined && Math.abs(event.offsetY) > 60) {
                    this.onCollectImage!();
                  }
                }),
              PinchGesture()
                .onActionUpdate((event: GestureEvent) => {
                  if (event.scale !== undefined) {
                    let next: number = this.imageScale * event.scale;
                    if (next < 1) {
                      next = 1;
                    } else if (next > 4) {
                      next = 4;
                    }
                    this.imageScale = next;
                  }
                })
            )
          )
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
