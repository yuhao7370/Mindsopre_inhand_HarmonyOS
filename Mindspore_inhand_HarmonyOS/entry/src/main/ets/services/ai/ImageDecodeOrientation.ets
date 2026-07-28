import { image } from '@kit.ImageKit';

export interface RotatedImageSize {
  readonly width: number;
  readonly height: number;
}

export interface ImageExifOrientationTransform {
  readonly rotationDegrees: number;
  readonly flipHorizontal: boolean;
  readonly flipVertical: boolean;
}

export function imageRotationDegreesFromOrientationProperty(orientation: string): number {
  return imageExifOrientationTransformFromOrientationProperty(orientation).rotationDegrees;
}

export function imageExifOrientationTransformFromOrientationProperty(orientation: string): ImageExifOrientationTransform {
  const normalized = orientation.trim().toLowerCase();
  switch (normalized) {
    case '2':
    case 'top-right':
      return { rotationDegrees: 0, flipHorizontal: true, flipVertical: false };
    case '6':
    case 'right-top':
      return { rotationDegrees: 90, flipHorizontal: false, flipVertical: false };
    case '3':
    case 'bottom-right':
      return { rotationDegrees: 180, flipHorizontal: false, flipVertical: false };
    case '4':
    case 'bottom-left':
      return { rotationDegrees: 0, flipHorizontal: false, flipVertical: true };
    case '5':
    case 'left-top':
      return { rotationDegrees: 270, flipHorizontal: true, flipVertical: false };
    case '7':
    case 'right-bottom':
      return { rotationDegrees: 90, flipHorizontal: true, flipVertical: false };
    case '8':
    case 'left-bottom':
      return { rotationDegrees: 270, flipHorizontal: false, flipVertical: false };
    default:
      return { rotationDegrees: 0, flipHorizontal: false, flipVertical: false };
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
  let transform: ImageExifOrientationTransform = { rotationDegrees: 0, flipHorizontal: false, flipVertical: false };
  try {
    transform = imageExifOrientationTransformFromOrientationProperty(
      await imageSource.getImageProperty(image.PropertyKey.ORIENTATION)
    );
  } catch (_) {
  }
  const pixelMap = options === undefined ? await imageSource.createPixelMap() : await imageSource.createPixelMap(options);
  await applyImageExifOrientation(pixelMap, transform);
  return pixelMap;
}

export async function applyImageExifOrientation(
  pixelMap: image.PixelMap,
  transform: ImageExifOrientationTransform
): Promise<void> {
  if (transform.flipHorizontal || transform.flipVertical) {
    await pixelMap.flip(transform.flipHorizontal, transform.flipVertical);
  }
  if (transform.rotationDegrees !== 0) {
    await pixelMap.rotate(transform.rotationDegrees);
  }
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

export function orientedImageSize(width: number, height: number, orientation: string): RotatedImageSize {
  return rotatedImageSize(width, height, imageExifOrientationTransformFromOrientationProperty(orientation).rotationDegrees);
}

function normalizedImageRotationDegrees(rotationDegrees: number): number {
  const normalized = ((rotationDegrees % 360) + 360) % 360;
  if (normalized === 90 || normalized === 180 || normalized === 270) {
    return normalized;
  }
  return 0;
}
