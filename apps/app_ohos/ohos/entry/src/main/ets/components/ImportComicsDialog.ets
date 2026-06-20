import { DataService } from '../service/DataService';
import { ContentDialogCustom } from './ContentDialog';
import { PlatformUtil } from '../utils/PlatformUtil';
import { TranslationUtil } from '../utils/TranslationUtil';
import { IMPORT_COMIC_HELP_URL } from '../utils/SettingsConstants';
import { RouterUtil } from '../navigation/RouterUtil';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';

interface FolderSelectOption {
  value: string;
}

const IMPORT_TYPE_LABELS: string[] = [
  'Single Comic',
  'Multiple Comics',
  'An archive file',
  'Multiple archive files',
  'EhViewer downloads',
  'Restore local downloads'
];

const IMPORT_MODES: string[] = [
  'directory',
  'multipleDirectory',
  'file',
  'multipleCbz',
  'ehViewer',
  'scan'
];

@Component
export struct ImportComicsDialog {
  @Link show: boolean
  onImported: () => void = () => {}
  @State importType: number = 0
  @State isLoading: boolean = false
  @State folders: string[] = []
  @State selectedFolder: string = ''
  @State copyToLocal: boolean = true
  private context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    this.loadFolders();
  }

  private tl(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  private async loadFolders(): Promise<void> {
    this.folders = await DataService.getInstance().getLocalFavoriteFolderNames();
    if (this.folders.length > 0) {
      this.selectedFolder = this.folders[0];
    }
  }

  private folderSelectOptions(): FolderSelectOption[] {
    let options: FolderSelectOption[] = [];
    for (let i: number = 0; i < this.folders.length; i++) {
      options.push({ value: this.folders[i] });
    }
    return options;
  }

  private importInfo(): string {
    let infos: string[] = [
      'Select a directory which contains the comic files.',
      'Select a directory which contains the comic directories.',
      'Select an archive file (cbz, zip, 7z, cb7)',
      'Select a directory which contains multiple archive files.',
      'Select an EhViewer database and a download folder.',
      'Scan the current local path and restore the local database.'
    ];
    return this.tl(infos[this.importType] ?? '');
  }

  private async runImport(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    let mode = IMPORT_MODES[this.importType];
    let path: string = '';
    let downloadPath: string = '';
    let folder: string | undefined =
      this.selectedFolder.length > 0 ? this.selectedFolder : undefined;

    if (mode === 'scan') {
      let error = await DataService.getInstance().importLocalComic('scan');
      this.isLoading = false;
      if (error !== null) {
        promptAction.showToast({ message: error });
      } else {
        this.show = false;
        this.onImported();
      }
      return;
    }

    if (mode === 'ehViewer') {
      path = await PlatformUtil.pickFile(this.context);
      if (path.length === 0) {
        this.isLoading = false;
        return;
      }
      downloadPath = await PlatformUtil.pickDirectory(this.context);
      if (downloadPath.length === 0) {
        this.isLoading = false;
        return;
      }
    } else if (mode === 'directory' || mode === 'multipleDirectory' || mode === 'multipleCbz') {
      path = await PlatformUtil.pickDirectory(this.context);
      if (path.length === 0) {
        this.isLoading = false;
        return;
      }
    } else {
      path = await PlatformUtil.pickFile(this.context);
      if (path.length === 0) {
        this.isLoading = false;
        return;
      }
    }

    let error = await DataService.getInstance().importLocalComic(
      mode, path, downloadPath, folder, this.copyToLocal
    );
    this.isLoading = false;
    if (error !== null) {
      promptAction.showToast({ message: error });
    } else {
      this.show = false;
      this.onImported();
    }
  }

  @Builder
  typeOption(index: number) {
    Text(this.tl(IMPORT_TYPE_LABELS[index]))
      .fontSize(14)
      .fontColor(this.importType === index ?
        $r('app.color.color_emphasize') : $r('app.color.text_primary'))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(this.importType === index ? $r('app.color.badge_bg') : Color.Transparent)
      .onClick(() => { this.importType = index; })
  }

  @Builder
  dialogBody() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)
    } else {
      Column() {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(IMPORT_TYPE_LABELS, (_: string, index: number) => {
            this.typeOption(index)
          }, (_: string, index: number) => `import_type_${index}`)
        }
        .width('100%')
        .margin({ bottom: 12 })

        if (this.importType !== 4 && this.importType !== 5 && this.folders.length > 0) {
          Text(this.tl('Add to favorites'))
            .fontSize(14)
            .width('100%')
          Select(this.folderSelectOptions())
            .selected(this.folders.indexOf(this.selectedFolder))
            .value(this.selectedFolder)
            .width('100%')
            .margin({ bottom: 8 })
            .onSelect((index: number) => {
              this.selectedFolder = this.folders[index];
            })
        }

        if (this.importType !== 2 && this.importType !== 3 && this.importType !== 5) {
          Row() {
            Toggle({ type: ToggleType.Checkbox, isOn: this.copyToLocal })
              .onChange((v: boolean) => { this.copyToLocal = v; })
            Text(this.tl('Copy to app local path'))
              .fontSize(14)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ bottom: 8 })
        }

        Text(this.importInfo())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  dialogActions() {
    Button(this.tl('help'))
      .type(ButtonType.Normal)
      .onClick(() => RouterUtil.launchUrl(IMPORT_COMIC_HELP_URL))
    Blank()
    Button(this.tl('Select'))
      .onClick(() => this.runImport())
  }

  build() {
    ContentDialogCustom({
      show: this.show,
      title: this.tl('Import Comics'),
      content: () => { this.dialogBody() },
      actions: () => { this.dialogActions() },
      onClose: () => { this.show = false; }
    })
  }
}
