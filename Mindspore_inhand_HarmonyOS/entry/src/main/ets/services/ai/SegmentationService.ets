import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { subjectSegmentation } from '@kit.CoreVisionKit';
import {
  decodingOptionsWithImageRotation,
  imageRotationDegreesFromImageSource,
  rotatedImageSize
} from './ImageDecodeOrientation';

export interface SegmentationRectangle {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface SegmentationResult {
  readonly ok: boolean;
  readonly subjectCount: number;
  readonly detailCount: number;
  readonly foregroundAvailable: boolean;
  readonly foregroundImageRgba?: ArrayBuffer;
  readonly foregroundImageWidth?: number;
  readonly foregroundImageHeight?: number;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly rectangles: Array<SegmentationRectangle>;
  readonly executionMs: number;
}

interface SegmentationForegroundImage {
  readonly rgba: ArrayBuffer;
  readonly width: number;
  readonly height: number;
}

export interface SegmentationRectanglePercent {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface SegmentationRunner {
  segmentPerson(imageUri: string): Promise<SegmentationResult>;
}

export interface SegmentationServiceOptions {
  readonly runner: SegmentationRunner;
}

export class SegmentationService {
  private readonly runner: SegmentationRunner;

  constructor(options: SegmentationServiceOptions) {
    this.runner = options.runner;
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    const startMs = Date.now();
    try {
      return await this.runner.segmentPerson(imageUri);
    } catch (_) {
      return {
        ok: false,
        subjectCount: 0,
        detailCount: 0,
        foregroundAvailable: false,
        rectangles: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export class HarmonySubjectSegmentationRunner implements SegmentationRunner {
  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    const startMs = Date.now();
    try {
      imageFile = await openSegmentationImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
      const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);
      pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({}, rotationDegrees));
      const result = await subjectSegmentation.doSegmentation({
        pixelMap: pixelMap
      }, {
        maxCount: 6,
        enableSubjectDetails: true,
        enableSubjectForegroundImage: true
      });
      const segmentationResult = await segmentationResultFromCoreVision(
        result,
        Date.now() - startMs,
        displaySize.width,
        displaySize.height
      );
      await releaseSegmentationResultImages(result);
      return segmentationResult;
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeSegmentationImageFile(imageFile);
      }
    }
  }
}

export async function segmentationResultFromCoreVision(
  result: subjectSegmentation.SegmentationResult,
  executionMs: number,
  imageWidth: number = 0,
  imageHeight: number = 0
): Promise<SegmentationResult> {
  const rectangles: Array<SegmentationRectangle> = [];
  rectangles.push(rectangleFromCoreVision(result.fullSubject.subjectRectangle));
  if (result.subjectDetails !== undefined) {
    result.subjectDetails.forEach((subject: subjectSegmentation.SubjectResult) => {
      rectangles.push(rectangleFromCoreVision(subject.subjectRectangle));
    });
  }
  const foreground = await foregroundImageFromSubject(result.fullSubject);
  return {
    ok: result.subjectCount > 0,
    subjectCount: result.subjectCount,
    detailCount: result.subjectDetails?.length ?? 0,
    foregroundAvailable: foreground !== undefined,
    foregroundImageRgba: foreground?.rgba,
    foregroundImageWidth: foreground?.width,
    foregroundImageHeight: foreground?.height,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    rectangles: rectangles,
    executionMs: executionMs
  };
}

export function segmentationRectanglePercent(
  rectangle: SegmentationRectangle,
  imageWidth: number,
  imageHeight: number
): SegmentationRectanglePercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      left: 0,
      top: 0,
      width: 0,
      height: 0
    };
  }

  const left = segmentationPercent(rectangle.left, imageWidth);
  const top = segmentationPercent(rectangle.top, imageHeight);
  const right = segmentationPercent(rectangle.left + rectangle.width, imageWidth);
  const bottom = segmentationPercent(rectangle.top + rectangle.height, imageHeight);
  return {
    left: left,
    top: top,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top)
  };
}

function segmentationPercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}

function rectangleFromCoreVision(rectangle: subjectSegmentation.Rectangle): SegmentationRectangle {
  return {
    left: rectangle.left,
    top: rectangle.top,
    width: rectangle.width,
    height: rectangle.height
  };
}

async function foregroundImageFromSubject(
  subject: subjectSegmentation.SubjectResult
): Promise<SegmentationForegroundImage | undefined> {
  try {
    const imageInfo: image.ImageInfo = await subject.foregroundImage.getImageInfo();
    const width = imageInfo.size.width;
    const height = imageInfo.size.height;
    if (width <= 0 || height <= 0) {
      return undefined;
    }
    const rgba = new ArrayBuffer(width * height * 4);
    await subject.foregroundImage.readPixelsToBuffer(rgba);
    return {
      rgba: rgba,
      width: width,
      height: height
    };
  } catch (_) {
    return undefined;
  }
}

async function releaseSegmentationResultImages(result: subjectSegmentation.SegmentationResult): Promise<void> {
  await releaseSubjectImage(result.fullSubject);
  if (result.subjectDetails !== undefined) {
    for (const subject of result.subjectDetails) {
      await releaseSubjectImage(subject);
    }
  }
}

async function releaseSubjectImage(subject: subjectSegmentation.SubjectResult): Promise<void> {
  try {
    await subject.foregroundImage.release();
  } catch (_) {
  }
}

async function openSegmentationImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for segmentation.');
  }
}

async function closeSegmentationImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
