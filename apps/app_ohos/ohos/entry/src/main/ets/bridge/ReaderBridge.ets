import { MethodResult } from '@ohos/flutter_ohos';
import { FlutterBridge, BridgeMethodCall, MethodCallHandler } from './FlutterBridge';
import { UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CHANNEL_NAME: string = 'com.venera.reader';
const TAG: string = 'ReaderBridge';
const DOMAIN: number = 0x0000;

export class ReaderBridge implements MethodCallHandler {
  private static instance: ReaderBridge | null = null;
  private bridge: FlutterBridge = FlutterBridge.getInstance();
  private context: UIAbility | null = null;

  static getInstance(): ReaderBridge {
    if (ReaderBridge.instance === null) {
      ReaderBridge.instance = new ReaderBridge();
    }
    return ReaderBridge.instance;
  }

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
      bundleName: 'com.venera.ohos',
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
      let parsed: ReaderOpenParamsJson = JSON.parse(jsonStr);
      if (parsed.comicId !== undefined && parsed.comicId !== null) {
        result.comicId = parsed.comicId;
      } else if (parsed.id !== undefined && parsed.id !== null) {
        result.comicId = parsed.id;
      }
      if (parsed.sourceKey !== undefined && parsed.sourceKey !== null) {
        result.sourceKey = parsed.sourceKey;
      }
      if (parsed.initialEp !== undefined && parsed.initialEp !== null) {
        result.initialEp = parsed.initialEp.toString();
      }
      if (parsed.initialPage !== undefined && parsed.initialPage !== null) {
        result.initialPage = parsed.initialPage;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse open params');
    }
    return result;
  }

  onLoadData(comicId: string, sourceKey: string): Promise<Object | null> {
    let params: ReaderLoadDataParams = {
      id: comicId,
      sourceKey: sourceKey
    };
    return this.bridge.invokeMethodAsync(CHANNEL_NAME, 'onLoadData', params);
  }

  onLoadChapterImages(
    comicId: string,
    sourceKey: string,
    chapterId: string,
    chapterIndex: number
  ): Promise<Object | null> {
    let params: ReaderChapterParams = {
      comicId: comicId,
      sourceKey: sourceKey,
      chapterId: chapterId,
      chapterIndex: chapterIndex
    };
    return this.bridge.invokeMethodAsync(CHANNEL_NAME, 'onLoadChapterImages', params);
  }

  onLoadImage(key: string, ep: number, page: number): Promise<Object | null> {
    let params: ReaderImageParams = {
      key: key,
      ep: ep,
      page: page
    };
    return this.bridge.invokeMethodAsync(CHANNEL_NAME, 'onLoadImage', params);
  }

  onUpdateHistory(comicId: string, sourceKey: string, ep: number, page: number): void {
    let params: ReaderHistoryParams = {
      comicId: comicId,
      sourceKey: sourceKey,
      ep: ep,
      page: page
    };
    this.bridge.invokeMethod(CHANNEL_NAME, 'onUpdateHistory', params);
  }

  onGetSettings(): Promise<Object | null> {
    return this.bridge.invokeMethodAsync(CHANNEL_NAME, 'onGetSettings', null);
  }
}

interface ReaderOpenParams {
  comicId: string;
  sourceKey: string;
  initialEp: string;
  initialPage: number;
}

interface ReaderOpenParamsJson {
  comicId?: string;
  id?: string;
  sourceKey?: string;
  initialEp?: string | number;
  initialPage?: number;
}

interface ReaderLoadDataParams {
  id: string;
  sourceKey: string;
}

interface ReaderChapterParams {
  comicId: string;
  sourceKey: string;
  chapterId: string;
  chapterIndex: number;
}

interface ReaderImageParams {
  key: string;
  ep: number;
  page: number;
}

interface ReaderHistoryParams {
  comicId: string;
  sourceKey: string;
  ep: number;
  page: number;
}
