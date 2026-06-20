import { DataService, DownloadTaskInfo } from '../../service/DataService';
import { ComicCoverImage } from '../../components/ComicCoverImage';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { RouterUtil } from '../../navigation/RouterUtil';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct DownloadingPage {
  @State tasks: DownloadTaskInfo[] = []
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  @StorageLink('dataEventVersion') @Watch('onDataEventChanged') dataEventVersion: number = 0
  private pollTimer: number = -1
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  onDataEventChanged(): void {
    this.refreshTasks();
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadTasks();
    this.pollTimer = setInterval(() => {
      this.refreshTasks();
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async loadTasks(): Promise<void> {
    this.isLoading = true;
    try {
      this.tasks = await DataService.getInstance().getDownloadTasks();
    } finally {
      this.isLoading = false;
    }
  }

  private async refreshTasks(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      this.tasks = await DataService.getInstance().getDownloadTasks();
    } finally {
      this.isRefreshing = false;
    }
  }

  private async pauseTask(index: number): Promise<void> {
    await DataService.getInstance().pauseDownload(index);
    await this.refreshTasks();
  }

  private async resumeTask(index: number): Promise<void> {
    await DataService.getInstance().resumeDownload(index);
    await this.refreshTasks();
  }

  private async cancelTask(index: number): Promise<void> {
    await DataService.getInstance().cancelDownload(index);
    await this.refreshTasks();
  }

  private async moveToFirst(index: number): Promise<void> {
    await DataService.getInstance().moveDownloadToFirst(index);
    await this.refreshTasks();
  }

  private formatSpeed(bytesPerSec: number): string {
    if (bytesPerSec >= 1048576) {
      return (bytesPerSec / 1048576).toFixed(1) + ' MB/s';
    }
    if (bytesPerSec >= 1024) {
      return (bytesPerSec / 1024).toFixed(1) + ' KB/s';
    }
    return bytesPerSec.toString() + ' B/s';
  }

  @Builder
  taskActions(index: number, task: DownloadTaskInfo) {
    Row() {
      if (task.isPaused || task.isError) {
        Button('Resume')
          .fontSize(12)
          .height(28)
          .onClick(() => this.resumeTask(index))
      } else {
        Button('Pause')
          .fontSize(12)
          .height(28)
          .onClick(() => this.pauseTask(index))
      }
      Button('Top')
        .fontSize(12)
        .height(28)
        .margin({ left: 4 })
        .onClick(() => this.moveToFirst(index))
      Button('Cancel')
        .fontSize(12)
        .height(28)
        .margin({ left: 4 })
        .fontColor($r('app.color.color_emphasize'))
        .backgroundColor(Color.Transparent)
        .onClick(() => this.cancelTask(index))
    }
  }

  @Builder
  pageContent() {
    if (this.isLoading) {
      LoadingIndicator()
        .width('100%')
        .padding({ top: 48 })
    } else if (this.tasks.length === 0) {
      Text('No active downloads')
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 48 })
    } else {
      List() {
        ForEach(this.tasks, (task: DownloadTaskInfo, index: number) => {
          ListItem() {
            Row() {
              if (task.cover !== undefined && task.cover.length > 0) {
                ComicCoverImage({
                  coverUrl: task.cover,
                  coverRadius: 8
                })
                  .width(72)
                  .height(100)
                  .margin({ right: 12 })
              } else {
                Column() {}
                  .width(72)
                  .height(100)
                  .margin({ right: 12 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.placeholder_bg'))
              }

              Column() {
                Text(task.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(task.isError ? 'Error' : (task.isPaused ? 'Paused' : task.message))
                  .fontSize(12)
                  .fontColor(task.isError ? $r('app.color.color_emphasize') :
                    $r('app.color.text_secondary'))
                  .width('100%')
                  .margin({ top: 4 })
                  .maxLines(2)

                Progress({ value: task.progress * 100, total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .margin({ top: 8 })

                if (task.speed !== undefined && task.speed > 0 && !task.isPaused && !task.isError) {
                  Text(this.formatSpeed(task.speed))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 4 })
                }

                this.taskActions(index, task)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(8)
            .margin({ bottom: 8 })
          }
        }, (task: DownloadTaskInfo) => task.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })
      .height('100%')
    }
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.tr('Downloading'),
        showBack: true,
        scrollable: false,
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
