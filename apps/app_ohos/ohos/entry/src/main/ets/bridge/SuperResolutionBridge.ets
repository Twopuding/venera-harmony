// SuperResolutionBridge.ets - top-level SR facade for the reader pipeline.
//
// Only the CoreVisionKit system built-in backend is used, which requires
// HarmonyOS 7 (API 26+). Keep this facade so the Flutter channel contract
// (srIsAvailable / srInitialize / srProcessFile) stays unchanged.
import { deviceInfo } from '@kit.BasicServicesKit';
import { CoreVisionBridge } from './CoreVisionBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SuperResolutionBridge';
const DOMAIN: number = 0xFF00;

const MIN_SDK_API_VERSION: number = 26;

export class SuperResolutionBridge {
  private coreVisionBridge: CoreVisionBridge = new CoreVisionBridge();

  getBackendType(): string {
    return 'corevision';
  }

  isAvailable(): boolean {
    // imageSuperResolution requires API 26+ (HarmonyOS 7).
    if (deviceInfo.sdkApiVersion < MIN_SDK_API_VERSION) {
      return false;
    }
    // The analyzer itself is created lazily by initialize(); report whether
    // creation has already succeeded so far.
    return this.coreVisionBridge.isInitialized();
  }

  async initialize(): Promise<boolean> {
    if (deviceInfo.sdkApiVersion < MIN_SDK_API_VERSION) {
      hilog.error(DOMAIN, TAG, 'Initialize skipped: sdkApiVersion < 26');
      return false;
    }
    return this.coreVisionBridge.initialize();
  }

  async processImage(imageData: Uint8Array): Promise<Uint8Array | null> {
    return this.coreVisionBridge.processImage(imageData);
  }

  release(): void {
    this.coreVisionBridge.release();
  }
}
