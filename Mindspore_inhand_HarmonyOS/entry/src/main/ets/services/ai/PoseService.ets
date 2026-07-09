import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { skeletonDetection, visionBase } from '@kit.CoreVisionKit';

export interface PosePoint {
  readonly type: number;
  readonly score: number;
  readonly x: number;
  readonly y: number;
}

export interface PoseResult {
  readonly ok: boolean;
  readonly skeletonCount: number;
  readonly pointCount: number;
  readonly points: Array<PosePoint>;
  readonly executionMs: number;
}

export interface PoseRunner {
  detectPose(imageUri: string): Promise<PoseResult>;
}

export interface PoseServiceOptions {
  readonly runner: PoseRunner;
}

export class PoseService {
  private readonly runner: PoseRunner;

  constructor(options: PoseServiceOptions) {
    this.runner = options.runner;
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    const startMs = Date.now();
    try {
      return await this.runner.detectPose(imageUri);
    } catch (_) {
      return {
        ok: false,
        skeletonCount: 0,
        pointCount: 0,
        points: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export class HarmonySkeletonDetectionRunner implements PoseRunner {
  async detectPose(imageUri: string): Promise<PoseResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let detector: skeletonDetection.SkeletonDetector | undefined = undefined;
    const startMs = Date.now();
    try {
      imageFile = await openPoseImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await imageSource.createPixelMap();
      detector = await skeletonDetection.SkeletonDetector.create();
      const request = new visionBase.Request();
      const inputData: visionBase.ImageData = {
        pixelMap: pixelMap
      };
      request.inputData = inputData;
      const response = await detector.process(request);
      return poseResultFromCoreVision(response.skeletons, Date.now() - startMs);
    } finally {
      if (detector !== undefined) {
        await destroySkeletonDetector(detector);
      }
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closePoseImageFile(imageFile);
      }
    }
  }
}

export function poseResultFromCoreVision(
  skeletons: Array<skeletonDetection.Skeleton>,
  executionMs: number
): PoseResult {
  const points: Array<PosePoint> = [];
  skeletons.forEach((skeleton: skeletonDetection.Skeleton) => {
    skeleton.points.forEach((point: skeletonDetection.SkeletonPoint) => {
      points.push({
        type: point.type,
        score: point.score,
        x: point.point.x,
        y: point.point.y
      });
    });
  });
  return {
    ok: skeletons.length > 0,
    skeletonCount: skeletons.length,
    pointCount: points.length,
    points: points,
    executionMs: executionMs
  };
}

async function destroySkeletonDetector(detector: skeletonDetection.SkeletonDetector): Promise<void> {
  try {
    await detector.destroy();
  } catch (_) {
  }
}

async function openPoseImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for pose detection.');
  }
}

async function closePoseImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
