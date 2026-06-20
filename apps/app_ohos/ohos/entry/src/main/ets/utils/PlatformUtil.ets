import { picker, fileIo } from '@kit.CoreFileKit';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { APP_VERSION_FALLBACK } from './SettingsConstants';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

export class PlatformUtil {
  static getAppVersionName(_context: common.UIAbilityContext): string {
    try {
      let flags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      let info = bundleManager.getBundleInfoForSelfSync(flags);
      let name = info.versionName ?? '';
      return name.length > 0 ? name : APP_VERSION_FALLBACK;
    } catch (_) {
      return APP_VERSION_FALLBACK;
    }
  }

  static async pickDirectory(context: common.UIAbilityContext): Promise<string> {
    try {
      let documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FOLDER;
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      let selectResult: Array<string> = await documentPicker.select(documentSelectOptions);
      if (selectResult.length > 0) {
        return selectResult[0];
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static async pickFile(context: common.UIAbilityContext): Promise<string> {
    try {
      let documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      let selectResult: Array<string> = await documentPicker.select(documentSelectOptions);
      if (selectResult.length > 0) {
        return selectResult[0];
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static readTextFile(path: string): string {
    try {
      let file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      let stat = fileIo.statSync(path);
      let buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      let decoder = new util.TextDecoder('utf-8');
      return decoder.decodeWithStream(new Uint8Array(buf));
    } catch (e) {
      return '';
    }
  }

  static fileNameFromPath(path: string): string {
    let parts = path.split('/');
    return parts.length > 0 ? parts[parts.length - 1] : 'source.js';
  }

  static async saveFile(context: common.UIAbilityContext, sourcePath: string, fileName: string): Promise<boolean> {
    try {
      let saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [fileName];
      let documentPicker = new picker.DocumentViewPicker(context);
      let destUri: string | Array<string> = await documentPicker.save(saveOptions);
      let target: string = Array.isArray(destUri) ? destUri[0] : destUri;
      if (target === undefined || target.length === 0) {
        return false;
      }
      let srcFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      let stat = fileIo.statSync(sourcePath);
      let buf = new ArrayBuffer(stat.size);
      fileIo.readSync(srcFile.fd, buf);
      fileIo.closeSync(srcFile);
      let destFile = fileIo.openSync(target, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(destFile.fd, buf);
      fileIo.closeSync(destFile);
      return true;
    } catch (e) {
      return false;
    }
  }

  static async saveBytes(
    context: common.UIAbilityContext,
    data: Uint8Array,
    fileName: string
  ): Promise<boolean> {
    try {
      let tempPath: string = context.cacheDir + '/' + fileName;
      let file = fileIo.openSync(tempPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data.buffer);
      fileIo.closeSync(file);
      return PlatformUtil.saveFile(context, tempPath, fileName);
    } catch (e) {
      return false;
    }
  }

  static async shareText(context: common.UIAbilityContext, text: string): Promise<boolean> {
    if (text.length === 0) {
      return false;
    }
    try {
      let shareWant: Want = new Want();
      shareWant.action = 'ohos.want.action.sendData';
      shareWant.type = 'text/plain';
      shareWant.parameters = {
        'ohos.extra.param.key.content': text
      } as Record<string, Object>;
      await context.startAbility(shareWant);
      return true;
    } catch (err) {
      let error = err as BusinessError;
      return false;
    }
  }

  static async shareBytes(
    context: common.UIAbilityContext,
    data: Uint8Array,
    fileName: string,
    mimeType: string
  ): Promise<boolean> {
    if (data.length === 0) {
      return false;
    }
    try {
      let tempPath: string = context.cacheDir + '/' + fileName;
      let file = fileIo.openSync(tempPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data.buffer);
      fileIo.closeSync(file);
      let shareWant: Want = new Want();
      shareWant.action = 'ohos.want.action.sendData';
      shareWant.type = mimeType.length > 0 ? mimeType : 'image/jpeg';
      shareWant.parameters = {
        'ohos.extra.param.key.streamUri': 'file://' + tempPath
      } as Record<string, Object>;
      await context.startAbility(shareWant);
      return true;
    } catch (e) {
      return false;
    }
  }
}
