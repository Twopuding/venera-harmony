// CoreVisionBridge.ets - HarmonyOS 7 (API 26+) system built-in image super resolution.
//
// Uses the system-level ImageSRAnalyzer (CoreVisionKit). The engine upscales
// the input 4x while enhancing detail; outputs are bounded to keep memory
// usage sane.
import { imageSuperResolution, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'CoreVisionBridge';
const DOMAIN: number = 0xFF00;

// Safety caps for comic pages: the system SR engine always outputs 4x pixels.
const MAX_INPUT_PIXELS: number = 4096 * 4096; // skip SR for already-huge inputs
const MAX_OUTPUT_LONG_EDGE: number = 4096;    // downscale output above this

export class CoreVisionBridge {
  private analyzer: imageSuperResolution.ImageSRAnalyzer | null = null;
  private initialized: boolean = false;

  isInitialized(): boolean {
    return this.initialized;
  }

  async initialize(): Promise<boolean> {
    if (this.initialized) {
      return true;
    }
    try {
      this.analyzer = await imageSuperResolution.ImageSRAnalyzer.create();
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'CoreVisionKit SR analyzer created');
      return true;
    } catch (e) {
      let err: Error = e as Error;
      hilog.error(DOMAIN, TAG, 'Failed to create analyzer: ' + err.message);
      return false;
    }
  }

  async processImage(imageData: Uint8Array): Promise<Uint8Array | null> {
    if (!this.initialized || this.analyzer === null) {
      return null;
    }
    let sourceImage: image.ImageSource | null = null;
    let inputPixelMap: image.PixelMap | null = null;
    let outputPixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      let buffer: ArrayBuffer = imageData.buffer.slice(imageData.byteOffset, imageData.byteOffset + imageData.byteLength);
      sourceImage = image.createImageSource(buffer);
      let decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      inputPixelMap = await sourceImage.createPixelMap(decodingOptions);

      // Skip SR when the input is already very large (memory guard).
      let info: image.ImageInfo = inputPixelMap.getImageInfoSync();
      let inputPixels: number = info.size.width * info.size.height;
      if (inputPixels > MAX_INPUT_PIXELS) {
        hilog.info(DOMAIN, TAG, 'Input too large, skip SR: ' + info.size.width.toString() + 'x' + info.size.height.toString());
        return null;
      }

      let imageDataWrapper: visionBase.ImageData = { pixelMap: inputPixelMap };
      let request: visionBase.Request = { inputData: imageDataWrapper };
      let response: imageSuperResolution.ISPResponse = await this.analyzer.process(request);
      outputPixelMap = response.pixelMap;

      // Bound the 4x output size before packing.
      let outInfo: image.ImageInfo = outputPixelMap.getImageInfoSync();
      let longEdge: number = Math.max(outInfo.size.width, outInfo.size.height);
      if (longEdge > MAX_OUTPUT_LONG_EDGE) {
        let ratio: number = MAX_OUTPUT_LONG_EDGE / longEdge;
        await outputPixelMap.scale(ratio, ratio);
      }

      let packingOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      };
      packer = image.createImagePacker();
      let packedBuffer: ArrayBuffer = await packer.packToData(outputPixelMap, packingOptions);
      await packer.release();
      packer = null;

      return new Uint8Array(packedBuffer);
    } catch (e) {
      let err: Error = e as Error;
      hilog.error(DOMAIN, TAG, 'Process image failed: ' + err.message);
      return null;
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (_) {
          // ignore
        }
      }
      if (outputPixelMap !== null) {
        outputPixelMap.release();
      }
      if (inputPixelMap !== null) {
        inputPixelMap.release();
      }
      if (sourceImage !== null) {
        sourceImage.release();
      }
    }
  }

  release(): void {
    if (this.analyzer !== null) {
      this.analyzer.destroy();
      this.analyzer = null;
    }
    this.initialized = false;
  }
}
