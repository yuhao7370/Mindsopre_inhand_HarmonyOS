import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  CustomModelPackageManifest,
  imageTensorFromRgba
} from './CustomModelPackage';
import {
  customModelDecodeOptions,
  customModelInputSize,
  CustomModelInputPreprocessor,
  rgbUnitInputFromResizedRgba
} from './CustomModelService';
import { CustomModelPackageImagePreprocessor } from './CustomModelPackageRunner';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';

export class HarmonyCustomModelInputPreprocessor
implements CustomModelInputPreprocessor, CustomModelPackageImagePreprocessor {
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

  async createPackageInputBuffer(
    imageUri: string,
    manifest: CustomModelPackageManifest
  ): Promise<ArrayBuffer> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await createPixelMapWithExifOrientation(imageSource, {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const imageInfo = await pixelMap.getImageInfo();
      const rgbaBuffer = new ArrayBuffer(imageInfo.size.width * imageInfo.size.height * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return imageTensorFromRgba(
        new Uint8Array(rgbaBuffer),
        imageInfo.size.width,
        imageInfo.size.height,
        manifest
      );
    } finally {
      if (pixelMap !== undefined) await pixelMap.release();
      if (imageSource !== undefined) await imageSource.release();
      if (imageFile !== undefined) await fileIo.close(imageFile);
    }
  }
}
