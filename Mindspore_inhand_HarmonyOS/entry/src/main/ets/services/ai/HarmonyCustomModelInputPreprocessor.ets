import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  customModelDecodeOptions,
  customModelInputSize,
  CustomModelInputPreprocessor,
  rgbUnitInputFromResizedRgba
} from './CustomModelService';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';

export class HarmonyCustomModelInputPreprocessor implements CustomModelInputPreprocessor {
  async createInputBuffer(imageUri: string): Promise<ArrayBuffer> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await createPixelMapWithExifOrientation(imageSource, customModelDecodeOptions());
      const rgbaBuffer = new ArrayBuffer(customModelInputSize * customModelInputSize * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return rgbUnitInputFromResizedRgba(new Uint8Array(rgbaBuffer));
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await fileIo.close(imageFile);
      }
    }
  }
}
