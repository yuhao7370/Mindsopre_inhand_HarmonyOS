import { image } from '@kit.ImageKit';

export interface RotatedImageSize {
  readonly width: number;
  readonly height: number;
}

export function imageRotationDegreesFromOrientationProperty(orientation: string): number {
  const normalized = orientation.trim().toLowerCase();
  switch (normalized) {
    case '6':
    case 'right-top':
      return 90;
    case '3':
    case 'bottom-right':
      return 180;
    case '8':
    case 'left-bottom':
      return 270;
    default:
      return 0;
  }
}

export async function imageRotationDegreesFromImageSource(imageSource: image.ImageSource): Promise<number> {
  try {
    const orientation = await imageSource.getImageProperty(image.PropertyKey.ORIENTATION);
    return imageRotationDegreesFromOrientationProperty(orientation);
  } catch (_) {
    return 0;
  }
}

export function decodingOptionsWithImageRotation(
  options: image.DecodingOptions,
  rotationDegrees: number
): image.DecodingOptions {
  const normalizedRotation = normalizedImageRotationDegrees(rotationDegrees);
  if (normalizedRotation !== 0) {
    options.rotate = normalizedRotation;
  }
  return options;
}

export async function createPixelMapWithExifOrientation(
  imageSource: image.ImageSource,
  options?: image.DecodingOptions
): Promise<image.PixelMap> {
  const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
  if (options === undefined && rotationDegrees === 0) {
    return imageSource.createPixelMap();
  }
  return imageSource.createPixelMap(decodingOptionsWithImageRotation(options ?? {}, rotationDegrees));
}

export function rotatedImageSize(width: number, height: number, rotationDegrees: number): RotatedImageSize {
  const normalizedRotation = normalizedImageRotationDegrees(rotationDegrees);
  if (normalizedRotation === 90 || normalizedRotation === 270) {
    return {
      width: height,
      height: width
    };
  }
  return {
    width: width,
    height: height
  };
}

function normalizedImageRotationDegrees(rotationDegrees: number): number {
  const normalized = ((rotationDegrees % 360) + 360) % 360;
  if (normalized === 90 || normalized === 180 || normalized === 270) {
    return normalized;
  }
  return 0;
}
