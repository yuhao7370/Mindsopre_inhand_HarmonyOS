import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { imageRotationDegreesFromImageSource } from '../../services/ai/ImageDecodeOrientation';

export function featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(
  rotationDegrees: number
): ImageRotateOrientation {
  switch (rotationDegrees) {
    case 90:
      return ImageRotateOrientation.RIGHT;
    case 180:
      return ImageRotateOrientation.DOWN;
    case 270:
      return ImageRotateOrientation.LEFT;
    default:
      return ImageRotateOrientation.UP;
  }
}

export async function featureRuntimeOverlayPreviewImageOrientationForUri(
  imageUri: string
): Promise<ImageRotateOrientation> {
  let imageFile: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  try {
    imageFile = await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(imageFile.fd);
    const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
    return featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(rotationDegrees);
  } catch (_) {
    return ImageRotateOrientation.UP;
  } finally {
    if (imageSource !== undefined) {
      await releaseOverlayPreviewImageSource(imageSource);
    }
    if (imageFile !== undefined) {
      await closeOverlayPreviewImageFile(imageFile);
    }
  }
}

async function releaseOverlayPreviewImageSource(imageSource: image.ImageSource): Promise<void> {
  try {
    await imageSource.release();
  } catch (_) {
  }
}

async function closeOverlayPreviewImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
