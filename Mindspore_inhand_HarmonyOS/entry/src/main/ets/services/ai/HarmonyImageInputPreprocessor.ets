import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { ImageClassificationInputPreprocessor } from './ImageClassificationPipeline';
import {
  imageClassificationResizedSize,
  normalizedRgbInputFromResizedRgba
} from './ImageClassificationPreprocess';

export class HarmonyImageClassificationInputPreprocessor implements ImageClassificationInputPreprocessor {
  async createInputBuffer(imageUri: string): Promise<ArrayBuffer> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await openImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await imageSource.createPixelMap(imageClassificationDecodeOptions());
      const rgbaBuffer = new ArrayBuffer(imageClassificationResizedSize * imageClassificationResizedSize * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return normalizedRgbInputFromResizedRgba(new Uint8Array(rgbaBuffer));
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeImageFile(imageFile);
      }
    }
  }
}

export function imageClassificationDecodeOptions(): image.DecodingOptions {
  return {
    desiredSize: {
      width: imageClassificationResizedSize,
      height: imageClassificationResizedSize
    },
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

async function openImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for classification.');
  }
}

async function closeImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
