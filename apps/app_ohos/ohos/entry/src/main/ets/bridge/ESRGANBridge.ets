import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';

const TAG: string = 'ESRGANBridge';
const DOMAIN: number = 0xFF00;

export class ESRGANBridge {
  private model: mindSporeLite.Model | null = null;
  private initialized: boolean = false;

  isInitialized(): boolean {
    return this.initialized;
  }

  async initialize(modelBuffer: ArrayBuffer): Promise<boolean> {
    if (this.initialized) {
      hilog.info(DOMAIN, TAG, 'ESRGAN already initialized');
      return true;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Initializing ESRGAN model, buffer size: ' + modelBuffer.byteLength.toString());

      let context: mindSporeLite.Context = {};
      context.target = ['cpu'];
      context.cpu = {};
      context.cpu.threadNum = 4;
      context.cpu.precisionMode = 'enforce_fp16';

      this.model = await mindSporeLite.loadModelFromBuffer(modelBuffer, context);
      this.initialized = true;

      let inputs = this.model.getInputs();
      hilog.info(DOMAIN, TAG, 'Model loaded, input count: ' + inputs.length.toString());
      
      if (inputs.length > 0) {
        let inputShape = inputs[0].shape;
        hilog.info(DOMAIN, TAG, 'Input shape: ' + inputShape.join(','));
      }

      return true;
    } catch (e) {
      let err = e as Error;
      hilog.error(DOMAIN, TAG, 'Failed to initialize ESRGAN: ' + err.message);
      this.initialized = false;
      return false;
    }
  }

  async processImage(imageData: Uint8Array): Promise<Uint8Array | null> {
    if (!this.initialized || this.model === null) {
      hilog.error(DOMAIN, TAG, 'ESRGAN not initialized');
      return null;
    }

    let sourceImage: image.ImageSource | null = null;
    let inputPixelMap: image.PixelMap | null = null;
    let outputPixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;

    try {
      hilog.info(DOMAIN, TAG, 'Processing image, input size: ' + imageData.byteLength.toString());

      let buffer: ArrayBuffer = imageData.buffer.slice(imageData.byteOffset, imageData.byteOffset + imageData.byteLength);
      sourceImage = image.createImageSource(buffer);

      let decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      inputPixelMap = await sourceImage.createPixelMap(decodingOptions);
      await sourceImage.release();
      sourceImage = null;

      let imageInfo: image.ImageInfo = inputPixelMap.getImageInfoSync();
      let width: number = imageInfo.size.width;
      let height: number = imageInfo.size.height;
      hilog.info(DOMAIN, TAG, 'Input image size: ' + width.toString() + 'x' + height.toString());

      let inputBuffer: ArrayBuffer = new ArrayBuffer(width * height * 3);
      let pixelBuffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
      await inputPixelMap.readPixelsToBuffer(pixelBuffer);

      let pixels: Uint8Array = new Uint8Array(pixelBuffer);
      let inputFloat: Float32Array = new Float32Array(inputBuffer);
      
      for (let i: number = 0; i < width * height; i++) {
        inputFloat[i * 3] = pixels[i * 4] / 255.0;
        inputFloat[i * 3 + 1] = pixels[i * 4 + 1] / 255.0;
        inputFloat[i * 3 + 2] = pixels[i * 4 + 2] / 255.0;
      }

      let inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
      inputs[0].setData(inputFloat.buffer);

      hilog.info(DOMAIN, TAG, 'Running inference...');
      let startTime: number = Date.now();
      let outputs: mindSporeLite.MSTensor[] = await this.model.predict(inputs);
      let endTime: number = Date.now();
      hilog.info(DOMAIN, TAG, 'Inference completed in ' + (endTime - startTime).toString() + 'ms');

      let outputData: ArrayBuffer = outputs[0].getData();
      let outputFloat: Float32Array = new Float32Array(outputData);

      let outputWidth: number = width * 4;
      let outputHeight: number = height * 4;
      hilog.info(DOMAIN, TAG, 'Output size: ' + outputWidth.toString() + 'x' + outputHeight.toString());

      let outputPixels: Uint8Array = new Uint8Array(outputWidth * outputHeight * 4);
      for (let i: number = 0; i < outputWidth * outputHeight; i++) {
        let r: number = Math.min(255, Math.max(0, Math.round(outputFloat[i * 3] * 255)));
        let g: number = Math.min(255, Math.max(0, Math.round(outputFloat[i * 3 + 1] * 255)));
        let b: number = Math.min(255, Math.max(0, Math.round(outputFloat[i * 3 + 2] * 255)));
        outputPixels[i * 4] = r;
        outputPixels[i * 4 + 1] = g;
        outputPixels[i * 4 + 2] = b;
        outputPixels[i * 4 + 3] = 255;
      }

      let outputOptions: image.InitializationOptions = {
        size: { width: outputWidth, height: outputHeight },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      };
      outputPixelMap = await image.createPixelMap(outputPixels.buffer, outputOptions);

      let packingOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      };
      packer = image.createImagePacker();
      let packedBuffer: ArrayBuffer = await packer.packToData(outputPixelMap, packingOptions);
      await packer.release();
      packer = null;

      let result: Uint8Array = new Uint8Array(packedBuffer);
      hilog.info(DOMAIN, TAG, 'Output image size: ' + result.byteLength.toString() + ' bytes');

      inputPixelMap.release();
      inputPixelMap = null;
      outputPixelMap.release();
      outputPixelMap = null;

      return result;
    } catch (e) {
      let err = e as Error;
      hilog.error(DOMAIN, TAG, 'Process image failed: ' + err.message);
      return null;
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'Failed to release packer');
        }
      }
      if (inputPixelMap !== null) {
        inputPixelMap.release();
      }
      if (outputPixelMap !== null) {
        outputPixelMap.release();
      }
      if (sourceImage !== null) {
        sourceImage.release();
      }
    }
  }

  release(): void {
    this.model = null;
    this.initialized = false;
    hilog.info(DOMAIN, TAG, 'ESRGAN released');
  }
}
