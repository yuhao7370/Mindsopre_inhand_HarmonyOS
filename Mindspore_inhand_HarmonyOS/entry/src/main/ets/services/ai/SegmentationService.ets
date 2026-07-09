import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { subjectSegmentation } from '@kit.CoreVisionKit';

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
  readonly rectangles: Array<SegmentationRectangle>;
  readonly executionMs: number;
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
      pixelMap = await imageSource.createPixelMap();
      const result = await subjectSegmentation.doSegmentation({
        pixelMap: pixelMap
      }, {
        maxCount: 6,
        enableSubjectDetails: true,
        enableSubjectForegroundImage: true
      });
      const segmentationResult = segmentationResultFromCoreVision(result, Date.now() - startMs);
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

export function segmentationResultFromCoreVision(
  result: subjectSegmentation.SegmentationResult,
  executionMs: number
): SegmentationResult {
  const rectangles: Array<SegmentationRectangle> = [];
  rectangles.push(rectangleFromCoreVision(result.fullSubject.subjectRectangle));
  if (result.subjectDetails !== undefined) {
    result.subjectDetails.forEach((subject: subjectSegmentation.SubjectResult) => {
      rectangles.push(rectangleFromCoreVision(subject.subjectRectangle));
    });
  }
  return {
    ok: result.subjectCount > 0,
    subjectCount: result.subjectCount,
    detailCount: result.subjectDetails?.length ?? 0,
    foregroundAvailable: true,
    rectangles: rectangles,
    executionMs: executionMs
  };
}

function rectangleFromCoreVision(rectangle: subjectSegmentation.Rectangle): SegmentationRectangle {
  return {
    left: rectangle.left,
    top: rectangle.top,
    width: rectangle.width,
    height: rectangle.height
  };
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
