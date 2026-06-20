import router from '@ohos.router';

import { common } from '@kit.AbilityKit';

import { util } from '@kit.ArkTS';

import promptAction from '@ohos.promptAction';

import { ComicCoverImage } from '../../components/ComicCoverImage';

import { RouterUtil } from '../../navigation/RouterUtil';

import { DataService } from '../../service/DataService';

import { PlatformUtil } from '../../utils/PlatformUtil';

import { TranslationUtil } from '../../utils/TranslationUtil';

import { LoadingIndicator } from '../../components/LoadingIndicator';

import { AuthSessionGuard } from '../../utils/AuthSessionGuard';



@Entry

@Component

struct CoverViewerPage {

  @State cover: string = ''

  @State sourceKey: string = ''

  @State comicId: string = ''

  @State isSaving: boolean = false

  @State authBlocked: boolean = false

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext



  aboutToAppear(): void {

    this.authBlocked = AuthSessionGuard.shouldBlock();

    if (this.authBlocked) {

      AuthSessionGuard.redirectIfNeeded();

      return;

    }

    TranslationUtil.ensureLoaded(this.context);

    let params = router.getParams() as Record<string, string>;

    this.cover = params['cover'] ?? '';

    this.sourceKey = params['sourceKey'] ?? '';

    this.comicId = params['comicId'] ?? '';

  }



  private tr(key: string): string {

    return TranslationUtil.tl(key, this.context);

  }



  private async saveCover(): Promise<void> {

    if (this.isSaving) {

      return;

    }

    this.isSaving = true;

    try {

      let base64: string | null = await DataService.getInstance().loadCoverImageBase64(

        this.cover, this.sourceKey, this.comicId, true

      );

      if (base64 === null || base64.length === 0) {

        promptAction.showToast({ message: this.tr('Error') });

        return;

      }

      let helper: util.Base64Helper = new util.Base64Helper();

      let bytes: Uint8Array = helper.decodeSync(base64);

      let fileName: string = `cover_${this.comicId}.jpg`;

      let ok: boolean = await PlatformUtil.saveBytes(this.context, bytes, fileName);

      promptAction.showToast({ message: ok ? this.tr('Saved') : this.tr('Error') });

    } finally {

      this.isSaving = false;

    }

  }



  build() {

    if (this.authBlocked) {

      LoadingIndicator()

    } else {

    Stack({ alignContent: Alignment.TopStart }) {

      ComicCoverImage({

        coverUrl: this.cover,

        sourceKey: this.sourceKey,

        comicId: this.comicId,

        coverRadius: 0

      })

        .width('100%')

        .height('100%')



      Row() {

        SymbolGlyph($r('sys.symbol.xmark'))

          .fontSize(28)

          .fontColor([Color.White])

          .margin({ right: 16 })

          .onClick(() => RouterUtil.back())

        SymbolGlyph($r('sys.symbol.square_and_arrow_down'))

          .fontSize(24)

          .fontColor([Color.White])

          .onClick(() => this.saveCover())

      }

      .margin({ left: 16, top: 48 })

    }

    .width('100%')

    .height('100%')

    .backgroundColor(Color.Black)

    }

  }

}


