import { DataService, LogEntry } from '../../service/DataService';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { HdsTheme } from '../../design/HdsTheme';
import {
  SettingsSection,
  SettingsListDivider,
  SETTINGS_TITLE_FONT_SIZE,
  SETTINGS_SUBTITLE_FONT_SIZE,
  SETTINGS_ROW_HEIGHT_MULTI
} from '../../components/SettingsList';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct LogsPage {
  @State logs: LogEntry[] = []
  @State isLoading: boolean = true
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadLogs();
  }

  private async loadLogs(): Promise<void> {
    this.isLoading = true;
    try {
      this.logs = await DataService.getInstance().getAppLogs();
    } finally {
      this.isLoading = false;
    }
  }

  @Builder
  logRow(log: LogEntry, showDivider: boolean) {
    Column() {
      Column() {
        Text(`${log.level.toUpperCase()} · ${log.title}`)
          .fontSize(SETTINGS_TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
        Text(log.content)
          .fontSize(SETTINGS_SUBTITLE_FONT_SIZE)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .constraintSize({ minHeight: SETTINGS_ROW_HEIGHT_MULTI })

      if (showDivider) {
        SettingsListDivider()
      }
    }
    .width('100%')
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
        .width('100%')
        .padding({ top: 48 })
    } else if (this.logs.length === 0) {
      Text(this.tr('No logs'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 48 })
    } else {
      SettingsSection({
        content: () => {
          ForEach(this.logs, (log: LogEntry, index: number) => {
            this.logRow(log, index < this.logs.length - 1)
          }, (log: LogEntry, index: number) => `${log.time}_${index}`)
        }
      })
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tr('Logs'),
        titleMode: HdsTheme.SETTINGS_SUBPAGE_TITLE_MODE,
        showBack: true,
        onBack: () => RouterUtil.back(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
