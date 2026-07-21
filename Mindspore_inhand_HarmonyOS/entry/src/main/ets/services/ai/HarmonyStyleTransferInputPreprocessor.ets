import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';
import {
  rawfilePathFromBuiltInStyleTransferUri,
  StyleTransferInput,
  StyleTransferInputPreprocessor,
  styleTransferContentImageSize,
  styleTransferDecodeOptions,
  styleTransferRgbUnitInputFromRgba,
  styleTransferStyleImageSize
} from './StyleTransferService';
import {
  decodingOptionsWithImageRotation,
  imageRotationDegreesFromImageSource,
  rotatedImageSize
} from './ImageDecodeOrientation';

export interface HarmonyStyleTransferInputPreprocessorOptions {
  readonly resourceManager?: RawfileContentReader;
}

interface PreparedStyleTransferImageInput {
  readonly inputBuffer: ArrayBuffer;
  readonly imageWidth: number;
  readonly imageHeight: number;
}

export class HarmonyStyleTransferInputPreprocessor implements StyleTransferInputPreprocessor {
  private readonly resourceManager?: RawfileContentReader;

  constructor(options?: HarmonyStyleTransferInputPreprocessorOptions) {
    this.resourceManager = options?.resourceManager;
  }

  async createInput(contentImageUri: string, styleImageUri: string): Promise<StyleTransferInput> {
    const contentInput = await createStyleTransferImageInput(
      contentImageUri,
      styleTransferContentImageSize,
      this.resourceManager
    );
    const styleInput = await createStyleTransferImageInput(
      styleImageUri,
      styleTransferStyleImageSize,
      this.resourceManager
    );
    return {
      contentInputBuffer: contentInput.inputBuffer,
      styleInputBuffer: styleInput.inputBuffer,
      contentImageWidth: contentInput.imageWidth,
      contentImageHeight: contentInput.imageHeight
    };
  }
}

async function createStyleTransferImageInput(
  imageUri: string,
  size: number,
  resourceManager?: RawfileContentReader
): Promise<PreparedStyleTransferImageInput> {
  let imageFile: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    const rawfilePath = rawfilePathFromBuiltInStyleTransferUri(imageUri);
    if (rawfilePath.length > 0) {
      if (resourceManager === undefined) {
        throw new Error('Unable to read built-in style transfer image without rawfile reader.');
      }
      const rawfileContent = await resourceManager.getRawFileContent(rawfilePath);
      imageSource = image.createImageSource(rawfileContentToArrayBuffer(rawfileContent));
    } else {
      imageFile = await openStyleTransferImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
    }
    const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
    const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
    const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);
    pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation(
      styleTransferDecodeOptions(size, imageInfo.size.width, imageInfo.size.height),
      rotationDegrees
    ));
    const rgbaBuffer = new ArrayBuffer(size * size * 4);
    await pixelMap.readPixelsToBuffer(rgbaBuffer);
    return {
      inputBuffer: styleTransferRgbUnitInputFromRgba(new Uint8Array(rgbaBuffer), size),
      imageWidth: displaySize.width,
      imageHeight: displaySize.height
    };
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
