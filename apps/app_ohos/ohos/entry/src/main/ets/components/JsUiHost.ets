import promptAction from '@ohos.promptAction';
import { JsUiBridge } from '../bridge/JsUiBridge';
import { ContentDialogCustom } from './ContentDialog';

interface JsUiDialogPayload {
  id: number;
  title: string;
  content: string;
  actions: JsUiDialogAction[];
}

interface JsUiDialogAction {
  text: string;
  style: string;
}

interface JsUiInputPayload {
  id: number;
  title: string;
}

interface JsUiSelectPayload {
  id: number;
  title: string;
  options: string[];
  initialIndex: number;
}

interface JsUiLoadingPayload {
  id: number;
  cancellable: boolean;
}

@Component
export struct JsUiHost {
  @StorageLink('jsUiToastVersion') @Watch('onToastVersionChanged') jsUiToastVersion: number = 0;
  @StorageLink('jsUiDialogVersion') @Watch('onDialogVersionChanged') jsUiDialogVersion: number = 0;
  @StorageLink('jsUiInputVersion') @Watch('onInputVersionChanged') jsUiInputVersion: number = 0;
  @StorageLink('jsUiSelectVersion') @Watch('onSelectVersionChanged') jsUiSelectVersion: number = 0;
  @StorageLink('jsUiLoadingVersion') @Watch('onLoadingVersionChanged') jsUiLoadingVersion: number = 0;
  @State showDialog: boolean = false;
  @State dialogPayload: JsUiDialogPayload | null = null;
  @State showInput: boolean = false;
  @State inputPayload: JsUiInputPayload | null = null;
  @State inputText: string = '';
  @State showSelect: boolean = false;
  @State selectPayload: JsUiSelectPayload | null = null;
  @State selectedIndex: number = 0;
  @State showLoading: boolean = false;
  @State loadingPayload: JsUiLoadingPayload | null = null;

  aboutToAppear(): void {
    AppStorage.setOrCreate('jsUiToastVersion', 0);
    AppStorage.setOrCreate('jsUiDialogVersion', 0);
    AppStorage.setOrCreate('jsUiInputVersion', 0);
    AppStorage.setOrCreate('jsUiSelectVersion', 0);
    AppStorage.setOrCreate('jsUiLoadingVersion', 0);
  }

  onToastVersionChanged(): void {
    let message: string = AppStorage.get<string>('jsUiToast') ?? '';
    if (message.length > 0) {
      promptAction.showToast({ message: message });
    }
  }

  onDialogVersionChanged(): void {
    let raw: string = AppStorage.get<string>('jsUiDialog') ?? '';
    if (raw.length === 0) {
      this.showDialog = false;
      return;
    }
    try {
      this.dialogPayload = JSON.parse(raw) as JsUiDialogPayload;
      this.showDialog = true;
    } catch (e) {
      this.showDialog = false;
    }
  }

  onInputVersionChanged(): void {
    let raw: string = AppStorage.get<string>('jsUiInput') ?? '';
    if (raw.length === 0) {
      this.showInput = false;
      return;
    }
    try {
      this.inputPayload = JSON.parse(raw) as JsUiInputPayload;
      this.inputText = '';
      this.showInput = true;
    } catch (e) {
      this.showInput = false;
    }
  }

  onSelectVersionChanged(): void {
    let raw: string = AppStorage.get<string>('jsUiSelect') ?? '';
    if (raw.length === 0) {
      this.showSelect = false;
      return;
    }
    try {
      this.selectPayload = JSON.parse(raw) as JsUiSelectPayload;
      this.selectedIndex = this.selectPayload.initialIndex ?? 0;
      this.showSelect = true;
    } catch (e) {
      this.showSelect = false;
    }
  }

  onLoadingVersionChanged(): void {
    let raw: string = AppStorage.get<string>('jsUiLoading') ?? '';
    if (raw.length === 0) {
      this.showLoading = false;
      return;
    }
    try {
      this.loadingPayload = JSON.parse(raw) as JsUiLoadingPayload;
      this.showLoading = true;
    } catch (e) {
      this.showLoading = false;
    }
  }

  @Builder
  dialogActions() {
    Row() {
      if (this.dialogPayload !== null) {
        ForEach(this.dialogPayload.actions, (action: JsUiDialogAction, index: number) => {
          Button(action.text)
            .margin({ left: index > 0 ? 8 : 0 })
            .onClick(() => {
              if (this.dialogPayload !== null) {
                JsUiBridge.notifyDialogAction(this.dialogPayload.id, index);
              }
              this.showDialog = false;
            })
        }, (action: JsUiDialogAction, index: number) => action.text + index.toString())
      }
    }
  }

  @Builder
  inputDialogContent() {
    TextInput({ text: this.inputText, placeholder: '' })
      .width('100%')
      .onChange((v: string) => {
        this.inputText = v;
      })
  }

  @Builder
  inputDialogActions() {
    Row() {
      Button('Cancel')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.inputPayload !== null) {
            JsUiBridge.notifyInputResult(this.inputPayload.id, '');
          }
          this.showInput = false;
        })
      Button('OK')
        .margin({ left: 8 })
        .onClick(() => {
          if (this.inputPayload !== null) {
            JsUiBridge.notifyInputResult(this.inputPayload.id, this.inputText);
          }
          this.showInput = false;
        })
    }
  }

  @Builder
  dialogContent() {
    Text(this.dialogPayload?.content ?? '')
      .fontSize(14)
      .width('100%')
  }

  @Builder
  selectDialogContent() {
    if (this.selectPayload !== null) {
      Column() {
        ForEach(this.selectPayload.options, (option: string, index: number) => {
          Text(option)
            .fontSize(14)
            .width('100%')
            .padding(10)
            .backgroundColor(this.selectedIndex === index ?
              $r('app.color.badge_bg') : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              this.selectedIndex = index;
            })
        }, (option: string, index: number) => option + index.toString())
      }
    }
  }

  @Builder
  selectDialogActions() {
    Row() {
      Button('Cancel')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.selectPayload !== null) {
            JsUiBridge.notifySelectResult(this.selectPayload.id, null);
          }
          this.showSelect = false;
        })
      Button('OK')
        .margin({ left: 8 })
        .onClick(() => {
          if (this.selectPayload !== null) {
            JsUiBridge.notifySelectResult(this.selectPayload.id, this.selectedIndex);
          }
          this.showSelect = false;
        })
    }
  }

  build() {
    Stack() {
      if (this.showLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          if (this.loadingPayload?.cancellable === true) {
            Button('Cancel')
              .margin({ top: 12 })
              .onClick(() => {
                if (this.loadingPayload !== null) {
                  JsUiBridge.notifyLoadingCancel(this.loadingPayload.id);
                }
                this.showLoading = false;
              })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#88000000')
      }

      ContentDialogCustom({
        title: this.dialogPayload?.title ?? '',
        show: this.showDialog,
        onClose: () => {
          this.showDialog = false;
        },
        content: this.dialogContent,
        actions: this.dialogActions
      })

      ContentDialogCustom({
        title: this.inputPayload?.title ?? '',
        show: this.showInput,
        onClose: () => {
          this.showInput = false;
        },
        content: this.inputDialogContent,
        actions: this.inputDialogActions
      })

      ContentDialogCustom({
        title: this.selectPayload?.title ?? '',
        show: this.showSelect,
        onClose: () => {
          this.showSelect = false;
        },
        content: this.selectDialogContent,
        actions: this.selectDialogActions
      })
    }
    .width(0)
    .height(0)
  }
}
