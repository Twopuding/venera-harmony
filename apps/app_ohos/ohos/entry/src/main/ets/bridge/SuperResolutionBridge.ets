import { deviceInfo } from '@kit.BasicServicesKit';
import { ESRGANBridge } from './ESRGANBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SuperResolutionBridge';
const DOMAIN: number = 0xFF00;

type SRBackend = 'esrgan' | 'corevision' | 'none';

export class SuperResolutionBridge {
  private esrganBridge: ESRGANBridge = new ESRGANBridge();
  private backend: SRBackend = 'none';
  private detected: boolean = false;

  private detectBackend(): SRBackend {
    if (this.detected) {
      return this.backend;
    }
    if (deviceInfo.sdkApiVersion >= 26) {
      this.backend = 'corevision';
      hilog.info(DOMAIN, TAG, 'Using CoreVisionKit backend (API 26+)');
    } else {
      this.backend = 'esrgan';
      hilog.info(DOMAIN, TAG, 'Using ESRGAN backend (API < 26)');
    }
    this.detected = true;
    return this.backend;
  }

  getBackendType(): SRBackend {
    return this.detectBackend();
  }

  isAvailable(): boolean {
    let backend: SRBackend = this.detectBackend();
    if (backend === 'esrgan') {
      return true;
    }
    return false;
  }

  async initialize(modelBuffer: ArrayBuffer): Promise<boolean> {
    let backend: SRBackend = this.detectBackend();
    if (backend === 'esrgan') {
      return this.esrganBridge.initialize(modelBuffer);
    }
    return true;
  }

  async processImage(imageData: Uint8Array): Promise<Uint8Array | null> {
    let backend: SRBackend = this.detectBackend();
    if (backend === 'esrgan') {
      return this.esrganBridge.processImage(imageData);
    }
    return null;
  }

  release(): void {
    if (this.backend === 'esrgan') {
      this.esrganBridge.release();
    }
    this.detected = false;
    this.backend = 'none';
  }
}
