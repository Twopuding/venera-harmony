import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_NAME: string = 'com.venera.reader';
const TAG: string = 'ReaderBridge';
const DOMAIN: number = 0x0000;

export class ReaderBridge implements MethodCallHandler {
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;

  setContext(context: UIAbility): void {
    this.context = context;
  }

  register(): void {
    this.bridge.setMethodCallHandler(CHANNEL_NAME, this);
  }

  onMethodCall(call: BridgeMethodCall, result: MethodResult): void {
    if (call.method === 'open') {
      this.handleOpen(call, result);
    } else {
      result.notImplemented();
    }
  }

  private handleOpen(call: BridgeMethodCall, result: MethodResult): void {
    if (this.context === null) {
      hilog.error(DOMAIN, TAG, 'Context is null, cannot launch ReaderAbility');
      result.error('ERROR', 'Context is null', null);
      return;
    }
    let params: ReaderOpenParams = this.extractOpenParams(call.args);
    let want: Want = {
      bundleName: 'com.twopuding.veneraoh',
      abilityName: 'ReaderAbility',
      parameters: {
        comicId: params.comicId,
        sourceKey: params.sourceKey,
        initialEp: params.initialEp,
        initialPage: params.initialPage
      }
    };
    this.context.context.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'ReaderAbility started successfully');
      result.success(null);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to start ReaderAbility: ' + err.message);
      result.error('ERROR', 'Failed to start ReaderAbility', err.message);
    });
  }

  private extractOpenParams(args: Object | null): ReaderOpenParams {
    let result: ReaderOpenParams = {
      comicId: '',
      sourceKey: '',
      initialEp: '',
      initialPage: 0
    };
    if (args === null) {
      return result;
    }
    try {
      let jsonStr: string = JSON.stringify(args);
      let parsed: ReaderOpenParams = JSON.parse(jsonStr);
      if (parsed.comicId !== undefined && parsed.comicId !== null) {
        result.comicId = parsed.comicId;
      }
      if (parsed.sourceKey !== undefined && parsed.sourceKey !== null) {
        result.sourceKey = parsed.sourceKey;
      }
      if (parsed.initialEp !== undefined && parsed.initialEp !== null) {
        result.initialEp = parsed.initialEp;
      }
      if (parsed.initialPage !== undefined && parsed.initialPage !== null) {
        result.initialPage = parsed.initialPage;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse open params');
    }
    return result;
  }

  loadData(comicId: string, sourceKey: string): void {
    let params: ReaderLoadDataParams = {
      comicId: comicId,
      sourceKey: sourceKey
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'loadData', params);
  }

  loadChapterImages(comicId: string, sourceKey: string, chapterId: string): void {
    let params: ReaderChapterParams = {
      comicId: comicId,
      sourceKey: sourceKey,
      chapterId: chapterId
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'loadChapterImages', params);
  }

  loadImage(url: string): void {
    let params: ReaderImageUrlParams = {
      imageUrl: url
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'loadImage', params);
  }

  updateHistory(comicId: string, ep: string, page: number): void {
    let params: ReaderHistoryParams = {
      comicId: comicId,
      ep: ep,
      page: page
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'updateHistory', params);
  }

  getSettings(): void {
    this.bridge.invokeMethod(CHANNEL_NAME, 'getSettings', null);
  }
}

interface ReaderOpenParams {
  comicId: string;
  sourceKey: string;
  initialEp: string;
  initialPage: number;
}

interface ReaderLoadDataParams {
  comicId: string;
  sourceKey: string;
}

interface ReaderChapterParams {
  comicId: string;
  sourceKey: string;
  chapterId: string;
}

interface ReaderImageUrlParams {
  imageUrl: string;
}

interface ReaderHistoryParams {
  comicId: string;
  ep: string;
  page: number;
}
