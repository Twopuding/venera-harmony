import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';

const TAG: string = 'ESRGANBridge';
const DOMAIN: number = 0xFF00;
const MODEL_SIZE: number = 640;
const SCALE_FACTOR: number = 4;

export class ESRGANBridge {
  private model: mindSporeLite.Model | null = null;
  private initialized: boolean = false;

  isInitialized(): boolean {
    return this.initialized;
  }

  async initialize(modelBuffer: ArrayBuffer): Promise<boolean> {
    if (this.initialized) {
      hilog.error(DOMAIN, TAG, 'ESRGAN already initialized');
      return true;
    }

    try {
      hilog.error(DOMAIN, TAG, 'Initializing ESRGAN model, buffer size: ' + modelBuffer.byteLength.toString());

      let context: mindSporeLite.Context = {};
      context.target = ['cpu'];
      context.cpu = {};
      context.cpu.threadNum = 4;
      context.cpu.precisionMode = 'preferred_fp16';
      hilog.error(DOMAIN, TAG, 'Context target: nnrt,cpu');

      this.model = await mindSporeLite.loadModelFromBuffer(modelBuffer, context);
      this.initialized = true;

      let inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
      hilog.error(DOMAIN, TAG, 'Model loaded, input count: ' + inputs.length.toString());

      if (inputs.length > 0) {
        let inputShape: number[] = inputs[0].shape;
        let inputFormat: mindSporeLite.Format = inputs[0].format;
        hilog.error(DOMAIN, TAG, 'Input shape: ' + inputShape.join(',') + ' format=' + inputFormat.toString());
      }

      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize ESRGAN: ' + JSON.stringify(e));
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
    let pixelMap: image.PixelMap | null = null;
    let outputPixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;

    try {
      hilog.error(DOMAIN, TAG, 'SR start: input bytes=' + imageData.byteLength.toString());

      let buffer: ArrayBuffer = imageData.buffer.slice(imageData.byteOffset, imageData.byteOffset + imageData.byteLength);
      sourceImage = image.createImageSource(buffer);

      let decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await sourceImage.createPixelMap(decodingOptions);
      await sourceImage.release();
      sourceImage = null;

      let imageInfo: image.ImageInfo = pixelMap.getImageInfoSync();
      let imgW: number = imageInfo.size.width;
      let imgH: number = imageInfo.size.height;
      hilog.error(DOMAIN, TAG, 'SR image: ' + imgW.toString() + 'x' + imgH.toString());

      let scale: number = MODEL_SIZE / Math.max(imgW, imgH);
      let scaledW: number = Math.floor(imgW * scale);
      let scaledH: number = Math.floor(imgH * scale);
      pixelMap.scaleSync(scale, scale, image.AntiAliasingLevel.HIGH);
      hilog.error(DOMAIN, TAG, 'SR scaled to: ' + scaledW.toString() + 'x' + scaledH.toString());

      let padX: number = Math.floor((MODEL_SIZE - scaledW) / 2);
      let padY: number = Math.floor((MODEL_SIZE - scaledH) / 2);

      let tileInput: Float32Array = new Float32Array(MODEL_SIZE * MODEL_SIZE * 3);
      let planeSize: number = MODEL_SIZE * MODEL_SIZE;

      let pixelBuffer: ArrayBuffer = new ArrayBuffer(scaledW * scaledH * 4);
      await pixelMap.readPixelsToBuffer(pixelBuffer);
      let pixels: Uint8Array = new Uint8Array(pixelBuffer);

      let rPlane: number = 0;
      let gPlane: number = planeSize;
      let bPlane: number = 2 * planeSize;

      for (let y: number = 0; y < MODEL_SIZE; y++) {
        for (let x: number = 0; x < MODEL_SIZE; x++) {
          let sx: number = x - padX;
          let sy: number = y - padY;
          let dstIdx: number = y * MODEL_SIZE + x;
          if (sx >= 0 && sx < scaledW && sy >= 0 && sy < scaledH) {
            let srcIdx: number = (sy * scaledW + sx) * 4;
            tileInput[rPlane + dstIdx] = pixels[srcIdx] / 255.0;
            tileInput[gPlane + dstIdx] = pixels[srcIdx + 1] / 255.0;
            tileInput[bPlane + dstIdx] = pixels[srcIdx + 2] / 255.0;
          }
        }
      }

      hilog.error(DOMAIN, TAG, 'SR running inference...');
      let inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
      inputs[0].setData(tileInput.buffer);

      let startTime: number = Date.now();
      let outputs: mindSporeLite.MSTensor[] = await this.model.predict(inputs);
      let elapsed: number = Date.now() - startTime;
      hilog.error(DOMAIN, TAG, 'SR inference done: ' + elapsed.toString() + 'ms');

      let outputData: ArrayBuffer = outputs[0].getData();
      let outputFloat: Float32Array = new Float32Array(outputData);

      let outSize: number = MODEL_SIZE * SCALE_FACTOR;
      let outPlaneSize: number = outSize * outSize;

      let outScaledW: number = scaledW * SCALE_FACTOR;
      let outScaledH: number = scaledH * SCALE_FACTOR;
      let outPadX: number = Math.floor((outSize - outScaledW) / 2);
      let outPadY: number = Math.floor((outSize - outScaledH) / 2);

      let outPixels: Uint8Array = new Uint8Array(outScaledW * outScaledH * 4);

      for (let y: number = 0; y < outScaledH; y++) {
        for (let x: number = 0; x < outScaledW; x++) {
          let tx: number = outPadX + x;
          let ty: number = outPadY + y;
          let srcIdx: number = ty * outSize + tx;
          let dstIdx: number = (y * outScaledW + x) * 4;

          outPixels[dstIdx] = Math.min(255, Math.max(0, Math.round(outputFloat[srcIdx] * 255)));
          outPixels[dstIdx + 1] = Math.min(255, Math.max(0, Math.round(outputFloat[outPlaneSize + srcIdx] * 255)));
          outPixels[dstIdx + 2] = Math.min(255, Math.max(0, Math.round(outputFloat[2 * outPlaneSize + srcIdx] * 255)));
          outPixels[dstIdx + 3] = 255;
        }
      }

      hilog.error(DOMAIN, TAG, 'SR output: ' + outScaledW.toString() + 'x' + outScaledH.toString());

      let outputOptions: image.InitializationOptions = {
        size: { width: outScaledW, height: outScaledH },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      };
      outputPixelMap = await image.createPixelMap(outPixels.buffer, outputOptions);

      let packingOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: 92
      };
      packer = image.createImagePacker();
      let packedBuffer: ArrayBuffer = await packer.packToData(outputPixelMap, packingOptions);
      await packer.release();
      packer = null;

      let result: Uint8Array = new Uint8Array(packedBuffer);
      hilog.error(DOMAIN, TAG, 'SR JPEG output: ' + result.byteLength.toString() + ' bytes');

      pixelMap.release();
      pixelMap = null;
      outputPixelMap.release();
      outputPixelMap = null;

      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'SR failed: ' + JSON.stringify(e));
      return null;
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'Failed to release packer');
        }
      }
      if (pixelMap !== null) {
        pixelMap.release();
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
    hilog.error(DOMAIN, TAG, 'ESRGAN released');
  }
}
