
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos';
import { MainShell } from './MainShell';
import { DataService } from '../service/DataService';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";
  @State useNativeUi: boolean = false;
  @State uiReady: boolean = false;

  aboutToAppear(): void {
    DataService.getInstance().getSettings().then((settings: Record<string, Object>) => {
      this.useNativeUi = settings['useNativeUi'] === true;
      this.uiReady = true;
    }).catch(() => {
      this.uiReady = true;
    });
  }

  build() {
    Stack() {
      if (!this.uiReady) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.useNativeUi) {
        MainShell()
      } else {
        Column() {
          FlutterPage({ viewId: this.viewId })
        }
        .width('100%')
        .height('100%')
      }

      if (this.useNativeUi) {
        FlutterPage({ viewId: this.viewId })
          .width(0)
          .height(0)
          .opacity(0)
      }
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
