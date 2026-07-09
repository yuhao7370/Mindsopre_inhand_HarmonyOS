import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  StyleTransferInput,
  StyleTransferInputPreprocessor,
  styleTransferContentImageSize,
  styleTransferDecodeOptions,
  styleTransferRgbUnitInputFromRgba,
  styleTransferStyleImageSize
} from './StyleTransferService';

export class HarmonyStyleTransferInputPreprocessor implements StyleTransferInputPreprocessor {
  async createInput(contentImageUri: string, styleImageUri: string): Promise<StyleTransferInput> {
    const contentInputBuffer = await createStyleTransferImageInput(
      contentImageUri,
      styleTransferContentImageSize
    );
    const styleInputBuffer = await createStyleTransferImageInput(
      styleImageUri,
      styleTransferStyleImageSize
    );
    return {
      contentInputBuffer: contentInputBuffer,
      styleInputBuffer: styleInputBuffer
    };
  }
}

async function createStyleTransferImageInput(imageUri: string, size: number): Promise<ArrayBuffer> {
  let imageFile: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    imageFile = await openStyleTransferImageFile(imageUri);
    imageSource = image.createImageSource(imageFile.fd);
    pixelMap = await imageSource.createPixelMap(styleTransferDecodeOptions(size));
    const rgbaBuffer = new ArrayBuffer(size * size * 4);
    await pixelMap.readPixelsToBuffer(rgbaBuffer);
    return styleTransferRgbUnitInputFromRgba(new Uint8Array(rgbaBuffer), size);
  } finally {
    if (pixelMap !== undefined) {
      await pixelMap.release();
    }
    if (imageSource !== undefined) {
      await imageSource.release();
    }
    if (imageFile !== undefined) {
      await closeStyleTransferImageFile(imageFile);
    }
  }
}

async function openStyleTransferImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for style transfer.');
  }
}

async function closeStyleTransferImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
