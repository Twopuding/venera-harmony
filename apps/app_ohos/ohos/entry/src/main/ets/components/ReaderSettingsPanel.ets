import { DataService } from '../service/DataService';
import { SettingsOptions } from '../utils/SettingsOptions';
import { ReaderBridge } from '../bridge/ReaderBridge';

@Component
export struct ReaderSettingsPanel {
  @Prop comicId: string = ''
  @Prop sourceKey: string = ''
  @State comicSpecificEnabled: boolean = false
  @State readerMode: string = 'galleryLeftToRight'
  @State enableTapToTurnPages: boolean = true
  @State reverseTapToTurnPages: boolean = false
  @State enablePageAnimation: boolean = true
  @State showChapterComments: boolean = false
  @State showChapterCommentsAtEnd: boolean = false
  @State enableTurnPageByVolumeKey: boolean = true
  @State enableDoubleTapToZoom: boolean = true
  @State enableLongPressToZoom: boolean = true
  @State showPageNumberInReader: boolean = true
  onClose: () => void = () => {}
  onChanged: () => void = () => {}

  aboutToAppear(): void {
    this.reloadFromBridge();
  }

  private async reloadFromBridge(): Promise<void> {
    let raw: Object | null = await ReaderBridge.getInstance().onGetSettings(
      this.comicId, this.sourceKey
    );
    if (raw === null) {
      return;
    }
    let parsed: Record<string, Object> = JSON.parse(JSON.stringify(raw));
    this.comicSpecificEnabled = parsed['comicSpecificEnabled'] === true;
    this.applyValues(parsed);
  }

  private applyValues(map: Record<string, Object>): void {
    if (map['readerMode'] !== undefined) {
      this.readerMode = map['readerMode'].toString();
    }
    this.enableTapToTurnPages = map['enableTapToTurnPages'] === true;
    this.reverseTapToTurnPages = map['reverseTapToTurnPages'] === true;
    this.enablePageAnimation = map['enablePageAnimation'] !== false;
    this.showChapterComments = map['showChapterComments'] === true;
    this.showChapterCommentsAtEnd = map['showChapterCommentsAtEnd'] === true;
    this.enableTurnPageByVolumeKey = map['enableTurnPageByVolumeKey'] !== false;
    this.enableDoubleTapToZoom = map['enableDoubleTapToZoom'] !== false;
    this.enableLongPressToZoom = map['enableLongPressToZoom'] !== false;
    this.showPageNumberInReader = map['showPageNumberInReader'] !== false;
  }

  private async setValue(key: string, value: Object | null): Promise<void> {
    if (this.comicSpecificEnabled) {
      await DataService.getInstance().setReaderSetting(
        this.comicId, this.sourceKey, key, value
      );
    } else {
      await DataService.getInstance().setSetting(key, value);
    }
    this.onChanged();
  }

  private async toggleComicSpecific(enabled: boolean): Promise<void> {
    await DataService.getInstance().setComicSpecificSettingsEnabled(
      this.comicId, this.sourceKey, enabled
    );
    this.comicSpecificEnabled = enabled;
    await this.reloadFromBridge();
    this.onChanged();
  }

  private cycleReaderMode(): void {
    let modes: string[] = [
      'galleryLeftToRight', 'galleryRightToLeft', 'galleryTopToBottom',
      'continuousLeftToRight', 'continuousRightToLeft', 'continuousTopToBottom'
    ];
    let idx = modes.indexOf(this.readerMode);
    let next = modes[(idx + 1) % modes.length];
    this.readerMode = next;
    this.setValue('readerMode', next);
  }

  private readerModeLabel(): string {
    let map = SettingsOptions.readerMode();
    return map.get(this.readerMode) ?? this.readerMode;
  }

  @Builder
  switchRow(label: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => onChange(isOn))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Text('Reader Settings')
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
      .padding(16)

      Scroll() {
        Column() {
          this.switchRow('Comic-specific settings', this.comicSpecificEnabled, (v: boolean) => {
            this.toggleComicSpecific(v);
          })

          Row() {
            Text('Reader mode')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Text(this.readerModeLabel())
              .fontSize(13)
              .fontColor($r('app.color.color_emphasize'))
              .onClick(() => this.cycleReaderMode())
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })

          this.switchRow('Tap to turn pages', this.enableTapToTurnPages, (v: boolean) => {
            this.enableTapToTurnPages = v;
            this.setValue('enableTapToTurnPages', v);
          })
          this.switchRow('Reverse tap direction', this.reverseTapToTurnPages, (v: boolean) => {
            this.reverseTapToTurnPages = v;
            this.setValue('reverseTapToTurnPages', v);
          })
          this.switchRow('Page animation', this.enablePageAnimation, (v: boolean) => {
            this.enablePageAnimation = v;
            this.setValue('enablePageAnimation', v);
          })
          this.switchRow('Show page number', this.showPageNumberInReader, (v: boolean) => {
            this.showPageNumberInReader = v;
            this.setValue('showPageNumberInReader', v);
          })
          this.switchRow('Chapter comments', this.showChapterComments, (v: boolean) => {
            this.showChapterComments = v;
            if (!v) {
              this.showChapterCommentsAtEnd = false;
              this.setValue('showChapterCommentsAtEnd', false);
            }
            this.setValue('showChapterComments', v);
          })
          if (this.showChapterComments &&
            (this.readerMode === 'galleryLeftToRight' || this.readerMode === 'galleryRightToLeft')) {
            this.switchRow('Comments at chapter end', this.showChapterCommentsAtEnd, (v: boolean) => {
              this.showChapterCommentsAtEnd = v;
              this.setValue('showChapterCommentsAtEnd', v);
            })
          }
          this.switchRow('Volume key paging', this.enableTurnPageByVolumeKey, (v: boolean) => {
            this.enableTurnPageByVolumeKey = v;
            this.setValue('enableTurnPageByVolumeKey', v);
          })
          this.switchRow('Double-tap zoom', this.enableDoubleTapToZoom, (v: boolean) => {
            this.enableDoubleTapToZoom = v;
            this.setValue('enableDoubleTapToZoom', v);
          })
          this.switchRow('Long-press zoom', this.enableLongPressToZoom, (v: boolean) => {
            this.enableLongPressToZoom = v;
            this.setValue('enableLongPressToZoom', v);
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
