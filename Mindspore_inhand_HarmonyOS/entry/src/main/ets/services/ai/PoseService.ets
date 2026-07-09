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
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly points: Array<PosePoint>;
  readonly executionMs: number;
}

export interface PosePointPercent {
  readonly x: number;
  readonly y: number;
}

export interface PoseLine {
  readonly start: PosePoint;
  readonly end: PosePoint;
}

export interface PoseLinePercent {
  readonly startX: number;
  readonly startY: number;
  readonly endX: number;
  readonly endY: number;
  readonly length: number;
  readonly angle: number;
}

interface PoseLineTypePair {
  readonly startType: number;
  readonly endType: number;
}

export interface PoseRunner {
  detectPose(imageUri: string): Promise<PoseResult>;
}

export interface PoseServiceOptions {
  readonly runner: PoseRunner;
}

export const poseMinPointScore = 0.2;

const poseSkeletonLineTypePairs: Array<PoseLineTypePair> = [
  {
    startType: skeletonDetection.SkeletonPointType.NOSE,
    endType: skeletonDetection.SkeletonPointType.LEFT_SHOULDER
  },
  {
    startType: skeletonDetection.SkeletonPointType.NOSE,
    endType: skeletonDetection.SkeletonPointType.RIGHT_SHOULDER
  },
  {
    startType: skeletonDetection.SkeletonPointType.LEFT_SHOULDER,
    endType: skeletonDetection.SkeletonPointType.LEFT_ELBOW
  },
  {
    startType: skeletonDetection.SkeletonPointType.LEFT_ELBOW,
    endType: skeletonDetection.SkeletonPointType.LEFT_WRIST
  },
  {
    startType: skeletonDetection.SkeletonPointType.LEFT_SHOULDER,
    endType: skeletonDetection.SkeletonPointType.LEFT_HIP
  },
  {
    startType: skeletonDetection.SkeletonPointType.LEFT_HIP,
    endType: skeletonDetection.SkeletonPointType.LEFT_KNEE
  },
  {
    startType: skeletonDetection.SkeletonPointType.LEFT_KNEE,
    endType: skeletonDetection.SkeletonPointType.LEFT_ANKLE
  },
  {
    startType: skeletonDetection.SkeletonPointType.RIGHT_SHOULDER,
    endType: skeletonDetection.SkeletonPointType.RIGHT_ELBOW
  },
  {
    startType: skeletonDetection.SkeletonPointType.RIGHT_ELBOW,
    endType: skeletonDetection.SkeletonPointType.RIGHT_WRIST
  },
  {
    startType: skeletonDetection.SkeletonPointType.RIGHT_SHOULDER,
    endType: skeletonDetection.SkeletonPointType.RIGHT_HIP
  },
  {
    startType: skeletonDetection.SkeletonPointType.RIGHT_HIP,
    endType: skeletonDetection.SkeletonPointType.RIGHT_KNEE
  },
  {
    startType: skeletonDetection.SkeletonPointType.RIGHT_KNEE,
    endType: skeletonDetection.SkeletonPointType.RIGHT_ANKLE
  }
];

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
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      pixelMap = await imageSource.createPixelMap();
      detector = await skeletonDetection.SkeletonDetector.create();
      const request = new visionBase.Request();
      const inputData: visionBase.ImageData = {
        pixelMap: pixelMap
      };
      request.inputData = inputData;
      const response = await detector.process(request);
      return poseResultFromCoreVision(
        response.skeletons,
        Date.now() - startMs,
        imageInfo.size.width,
        imageInfo.size.height
      );
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
  executionMs: number,
  imageWidth: number = 0,
  imageHeight: number = 0
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
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    points: points,
    executionMs: executionMs
  };
}

export function posePointPercent(point: PosePoint, imageWidth: number, imageHeight: number): PosePointPercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      x: 0,
      y: 0
    };
  }
  return {
    x: posePercent(point.x, imageWidth),
    y: posePercent(point.y, imageHeight)
  };
}

export function isPosePointVisible(point: PosePoint): boolean {
  return point.score >= poseMinPointScore && (point.x !== 0 || point.y !== 0);
}

export function poseSkeletonLines(points: Array<PosePoint>): Array<PoseLine> {
  const pointByType: Map<number, PosePoint> = new Map<number, PosePoint>();
  points.forEach((point: PosePoint) => {
    if (isPosePointVisible(point)) {
      pointByType.set(point.type, point);
    }
  });

  const lines: Array<PoseLine> = [];
  poseSkeletonLineTypePairs.forEach((pair: PoseLineTypePair) => {
    const start = pointByType.get(pair.startType);
    const end = pointByType.get(pair.endType);
    if (start !== undefined && end !== undefined) {
      lines.push({
        start: start,
        end: end
      });
    }
  });
  return lines;
}

export function poseLinePercent(line: PoseLine, imageWidth: number, imageHeight: number): PoseLinePercent {
  const start = posePointPercent(line.start, imageWidth, imageHeight);
  const end = posePointPercent(line.end, imageWidth, imageHeight);
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      startX: start.x,
      startY: start.y,
      endX: end.x,
      endY: end.y,
      length: 0,
      angle: 0
    };
  }

  const deltaX = line.end.x - line.start.x;
  const deltaY = line.end.y - line.start.y;
  return {
    startX: start.x,
    startY: start.y,
    endX: end.x,
    endY: end.y,
    length: Math.sqrt(deltaX * deltaX + deltaY * deltaY) * 100 / imageWidth,
    angle: Math.atan2(deltaY, deltaX) * 180 / Math.PI
  };
}

function posePercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
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
