import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  normalizedObjectDetectionRgbInputFromRgba,
  objectDetectionDecodeOptions,
  objectDetectionInputSize,
  ObjectDetectionInput,
  ObjectDetectionInputPreprocessor
} from './ObjectDetectionService';

export class HarmonyObjectDetectionInputPreprocessor implements ObjectDetectionInputPreprocessor {
  async createInput(imageUri: string): Promise<ObjectDetectionInput> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await openObjectDetectionImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      pixelMap = await imageSource.createPixelMap(objectDetectionDecodeOptions());
      const rgbaBuffer = new ArrayBuffer(objectDetectionInputSize * objectDetectionInputSize * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return {
        inputBuffer: normalizedObjectDetectionRgbInputFromRgba(new Uint8Array(rgbaBuffer)),
        imageWidth: imageInfo.size.width,
        imageHeight: imageInfo.size.height
      };
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeObjectDetectionImageFile(imageFile);
      }
    }
  }
}

async function openObjectDetectionImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for object detection.');
  }
}

async function closeObjectDetectionImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
