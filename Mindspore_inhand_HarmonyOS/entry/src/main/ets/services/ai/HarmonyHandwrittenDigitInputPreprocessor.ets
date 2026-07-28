import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { HandwrittenDigitImagePreprocessor } from './HandwrittenDigitService';
import { handwrittenDigitInputFromRgba } from './HandwrittenDigitPreprocess';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';

export class HarmonyHandwrittenDigitInputPreprocessor implements HandwrittenDigitImagePreprocessor {
  async createInput(imageUri: string): Promise<ArrayBuffer> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await openHandwrittenDigitImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await createPixelMapWithExifOrientation(imageSource, handwrittenDigitDecodeOptions());
      const imageInfo = await pixelMap.getImageInfo();
      if (imageInfo.size.width <= 0 || imageInfo.size.height <= 0) {
        throw new Error('Invalid digit image dimensions.');
      }
      const rgbaBuffer = new ArrayBuffer(imageInfo.size.width * imageInfo.size.height * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return handwrittenDigitInputFromRgba(new Uint8Array(rgbaBuffer), imageInfo.size.width, imageInfo.size.height);
    } finally {
      await releaseHandwrittenDigitPixelMap(pixelMap);
      await releaseHandwrittenDigitImageSource(imageSource);
      await closeHandwrittenDigitImageFile(imageFile);
    }
  }
}

export function handwrittenDigitDecodeOptions(): image.DecodingOptions {
  return {
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

async function openHandwrittenDigitImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open handwritten digit image.');
  }
}

async function releaseHandwrittenDigitPixelMap(pixelMap?: image.PixelMap): Promise<void> {
  if (pixelMap === undefined) {
    return;
  }
  try {
    await pixelMap.release();
  } catch (_) {
  }
}

async function releaseHandwrittenDigitImageSource(imageSource?: image.ImageSource): Promise<void> {
  if (imageSource === undefined) {
    return;
  }
  try {
    await imageSource.release();
  } catch (_) {
  }
}

async function closeHandwrittenDigitImageFile(imageFile?: fileIo.File): Promise<void> {
  if (imageFile === undefined) {
    return;
  }
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
