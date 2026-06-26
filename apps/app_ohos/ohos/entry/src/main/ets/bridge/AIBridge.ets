import { FlutterBridge } from './FlutterBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';

const TAG: string = 'AIBridge';
const DOMAIN: number = 0xFF00;
const SCALE_FACTOR: number = 2.0;

export class AIBridge {
  private bridge: FlutterBridge = FlutterBridge.getInstance();

  isAvailable(): boolean {
    return true;
  }

  async performSuperResolution(imageData: Uint8Array): Promise<Uint8Array | null> {
    let sourceImage: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;

    try {
      hilog.info(DOMAIN, TAG, 'Starting SR, input size: ' + imageData.byteLength.toString());
      
      let buffer: ArrayBuffer = imageData.buffer.slice(imageData.byteOffset, imageData.byteOffset + imageData.byteLength);
      sourceImage = image.createImageSource(buffer);
      hilog.info(DOMAIN, TAG, 'ImageSource created');
      
      let decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await sourceImage.createPixelMap(decodingOptions);
      hilog.info(DOMAIN, TAG, 'PixelMap created');
      
      await sourceImage.release();
      sourceImage = null;

      let imageInfo: image.ImageInfo = pixelMap.getImageInfoSync();
      hilog.info(DOMAIN, TAG, 'Original size: ' + imageInfo.size.width.toString() + 'x' + imageInfo.size.height.toString());

      try {
        hilog.info(DOMAIN, TAG, 'Trying scaleSync with HIGH');
        pixelMap.scaleSync(SCALE_FACTOR, SCALE_FACTOR, image.AntiAliasingLevel.HIGH);
        hilog.info(DOMAIN, TAG, 'scaleSync HIGH succeeded');
      } catch (e1) {
        hilog.warn(DOMAIN, TAG, 'scaleSync with HIGH failed: ' + (e1 as Error).message);
        try {
          hilog.info(DOMAIN, TAG, 'Trying scaleSync with LOW');
          pixelMap.scaleSync(SCALE_FACTOR, SCALE_FACTOR, image.AntiAliasingLevel.LOW);
          hilog.info(DOMAIN, TAG, 'scaleSync LOW succeeded');
        } catch (e2) {
          hilog.warn(DOMAIN, TAG, 'scaleSync with LOW failed: ' + (e2 as Error).message);
          hilog.info(DOMAIN, TAG, 'Using basic scale');
          await pixelMap.scale(SCALE_FACTOR, SCALE_FACTOR);
          hilog.info(DOMAIN, TAG, 'Basic scale succeeded');
        }
      }

      let scaledInfo: image.ImageInfo = pixelMap.getImageInfoSync();
      hilog.info(DOMAIN, TAG, 'Scaled size: ' + scaledInfo.size.width.toString() + 'x' + scaledInfo.size.height.toString());

      let packingOptions: image.PackingOption = {
        format: 'image/png',
        quality: 100
      };
      packer = image.createImagePacker();
      let packedBuffer: ArrayBuffer = await packer.packToData(pixelMap, packingOptions);
      await packer.release();
      packer = null;

      pixelMap.release();
      pixelMap = null;

      let result: Uint8Array = new Uint8Array(packedBuffer);
      hilog.info(DOMAIN, TAG, 'Super resolution completed, output size: ' + result.byteLength.toString());
      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Super resolution failed: ' + JSON.stringify(e));
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
      if (sourceImage !== null) {
        sourceImage.release();
      }
    }
  }
}
