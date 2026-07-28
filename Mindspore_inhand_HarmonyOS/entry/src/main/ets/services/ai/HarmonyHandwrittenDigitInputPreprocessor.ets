import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { HandwrittenDigitFailure, HandwrittenDigitImagePreprocessor } from './HandwrittenDigitService';
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
      const sourceInfo = await imageSource.getImageInfo();
      pixelMap = await createPixelMapWithExifOrientation(
        imageSource,
        handwrittenDigitDecodeOptions(sourceInfo.size.width, sourceInfo.size.height)
      );
      const imageInfo = await pixelMap.getImageInfo();
      if (imageInfo.size.width <= 0 || imageInfo.size.height <= 0) {
        throw new Error('Invalid digit image dimensions.');
      }
      const rgbaBuffer = new ArrayBuffer(imageInfo.size.width * imageInfo.size.height * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      try {
        return handwrittenDigitInputFromRgba(new Uint8Array(rgbaBuffer), imageInfo.size.width, imageInfo.size.height);
      } catch (_) {
        throw new HandwrittenDigitFailure('INPUT_INVALID');
      }
    } finally {
      await releaseHandwrittenDigitPixelMap(pixelMap);
      await releaseHandwrittenDigitImageSource(imageSource);
      await closeHandwrittenDigitImageFile(imageFile);
    }
  }
}

export function handwrittenDigitDecodeOptions(width: number, height: number): image.DecodingOptions {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) {
    throw new Error('Invalid handwritten digit source dimensions.');
  }
  const options: image.DecodingOptions = {
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
  const maximumEdge = Math.max(width, height);
  if (maximumEdge > 1024) {
    const scale = 1024 / maximumEdge;
    options.desiredSize = {
      width: Math.max(1, Math.round(width * scale)),
      height: Math.max(1, Math.round(height * scale))
    };
  }
  return options;
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
