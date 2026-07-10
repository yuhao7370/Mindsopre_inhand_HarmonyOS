import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { skeletonDetection, visionBase } from '@kit.CoreVisionKit';
import {
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';

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
  readonly similarity?: number;
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

interface PoseBounds {
  readonly minX: number;
  readonly minY: number;
  readonly width: number;
  readonly height: number;
}

interface NormalizedPosePoint {
  readonly x: number;
  readonly y: number;
}

export interface PoseRunner {
  detectPose(imageUri: string): Promise<PoseResult>;
}

export interface PoseServiceOptions {
  readonly runner: PoseRunner;
}

export interface HarmonySkeletonDetectionRunnerOptions {
  readonly resourceManager?: RawfileContentReader;
}

export interface PoseImageSourceInput {
  readonly imageSource: image.ImageSource;
  readonly imageFile?: fileIo.File;
}

export interface PoseImageSourceFactory {
  createSourceFromRawfileContent(content: Uint8Array): image.ImageSource;
  createSourceFromFile(imageFile: fileIo.File): image.ImageSource;
}

export interface PoseImageFileOpener {
  open(imageUri: string): Promise<fileIo.File>;
  close(imageFile: fileIo.File): Promise<void>;
}

export interface PoseImageSourceForUriOptions {
  readonly resourceManager?: RawfileContentReader;
  readonly sourceFactory?: PoseImageSourceFactory;
  readonly fileOpener?: PoseImageFileOpener;
}

export const poseMinPointScore = 0.2;
export const poseRawfileUriPrefix = 'rawfile://';

export const androidLiveSkeletonTemplatePoints: Array<PosePoint> = [
  { x: 416.6629, y: 312.46442, type: 101, score: 0.8042025 },
  { x: 382.3348, y: 519.43396, type: 102, score: 0.86383355 },
  { x: 381.0387, y: 692.09515, type: 103, score: 0.7551306 },
  { x: 659.49194, y: 312.24445, type: 104, score: 0.8305682 },
  { x: 693.5356, y: 519.4844, type: 105, score: 0.8932837 },
  { x: 694.0054, y: 692.4169, type: 106, score: 0.8742422 },
  { x: 485.08786, y: 726.8787, type: 107, score: 0.6004682 },
  { x: 485.02808, y: 935.4897, type: 108, score: 0.7334503 },
  { x: 485.09384, y: 1177.127, type: 109, score: 0.67240065 },
  { x: 623.7807, y: 726.7474, type: 110, score: 0.5483011 },
  { x: 624.5828, y: 936.3222, type: 111, score: 0.730425 },
  { x: 625.81915, y: 1212.2491, type: 112, score: 0.72417295 },
  { x: 521.47363, y: 103.95903, type: 113, score: 0.7780853 },
  { x: 521.6231, y: 277.2533, type: 114, score: 0.7745689 }
];

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
      return poseResultWithAndroidTemplateSimilarity(await this.runner.detectPose(imageUri));
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
  private readonly resourceManager?: RawfileContentReader;

  constructor(options?: HarmonySkeletonDetectionRunnerOptions) {
    this.resourceManager = options?.resourceManager;
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let detector: skeletonDetection.SkeletonDetector | undefined = undefined;
    const startMs = Date.now();
    try {
      const input = await createPoseImageSourceForUri(imageUri, {
        resourceManager: this.resourceManager
      });
      imageSource = input.imageSource;
      imageFile = input.imageFile;
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

export class HarmonyPoseImageSourceFactory implements PoseImageSourceFactory {
  createSourceFromRawfileContent(content: Uint8Array): image.ImageSource {
    return image.createImageSource(rawfileContentToArrayBuffer(content));
  }

  createSourceFromFile(imageFile: fileIo.File): image.ImageSource {
    return image.createImageSource(imageFile.fd);
  }
}

export class HarmonyPoseImageFileOpener implements PoseImageFileOpener {
  async open(imageUri: string): Promise<fileIo.File> {
    return openPoseImageFile(imageUri);
  }

  async close(imageFile: fileIo.File): Promise<void> {
    await closePoseImageFile(imageFile);
  }
}

export async function createPoseImageSourceForUri(
  imageUri: string,
  options?: PoseImageSourceForUriOptions
): Promise<PoseImageSourceInput> {
  const sourceFactory = options?.sourceFactory ?? new HarmonyPoseImageSourceFactory();
  const rawfilePath = rawfilePathFromPoseImageUri(imageUri);
  if (rawfilePath.length > 0) {
    if (options?.resourceManager === undefined) {
      throw new Error('Unable to read built-in pose image without rawfile reader.');
    }
    const rawfileContent = await options.resourceManager.getRawFileContent(rawfilePath);
    return {
      imageSource: sourceFactory.createSourceFromRawfileContent(rawfileContent)
    };
  }

  const fileOpener = options?.fileOpener ?? new HarmonyPoseImageFileOpener();
  const imageFile = await fileOpener.open(imageUri);
  try {
    return {
      imageSource: sourceFactory.createSourceFromFile(imageFile),
      imageFile: imageFile
    };
  } catch (_) {
    await fileOpener.close(imageFile);
    throw new Error('Unable to create image source for pose detection.');
  }
}

export function rawfilePathFromPoseImageUri(uri: string): string {
  if (!uri.startsWith(poseRawfileUriPrefix)) {
    return '';
  }
  return uri.substring(poseRawfileUriPrefix.length);
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

export function poseSimilarityToAndroidTemplate(points: Array<PosePoint>): number | undefined {
  return poseSimilarityToTemplate(points, androidLiveSkeletonTemplatePoints);
}

export function poseSimilarityPercent(similarity: number): string {
  return `${Math.floor(clampPoseSimilarity(similarity) * 100)}%`;
}

function poseResultWithAndroidTemplateSimilarity(result: PoseResult): PoseResult {
  if (!result.ok || result.similarity !== undefined) {
    return result;
  }
  const similarity = poseSimilarityToAndroidTemplate(result.points);
  if (similarity === undefined) {
    return result;
  }
  return {
    ok: result.ok,
    skeletonCount: result.skeletonCount,
    pointCount: result.pointCount,
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    points: result.points,
    similarity: similarity,
    executionMs: result.executionMs
  };
}

function poseSimilarityToTemplate(
  points: Array<PosePoint>,
  templatePoints: Array<PosePoint>
): number | undefined {
  const pointByType: Map<number, PosePoint> = visiblePosePointMap(points);
  const visibleTemplatePoints: Array<PosePoint> = templatePoints.filter((point: PosePoint) => isPosePointVisible(point));
  const matchedPoints: Array<PosePoint> = [];
  const matchedTemplatePoints: Array<PosePoint> = [];

  visibleTemplatePoints.forEach((templatePoint: PosePoint) => {
    const point = pointByType.get(templatePoint.type);
    if (point !== undefined) {
      matchedPoints.push(point);
      matchedTemplatePoints.push(templatePoint);
    }
  });

  if (matchedPoints.length < 2) {
    return undefined;
  }

  const pointBounds = poseBounds(matchedPoints);
  const templateBounds = poseBounds(matchedTemplatePoints);
  let distanceSum = 0;
  for (let index = 0; index < matchedPoints.length; index++) {
    const point = normalizePosePoint(matchedPoints[index], pointBounds);
    const templatePoint = normalizePosePoint(matchedTemplatePoints[index], templateBounds);
    const deltaX = point.x - templatePoint.x;
    const deltaY = point.y - templatePoint.y;
    distanceSum += Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  const averageDistance = distanceSum / matchedPoints.length;
  return clampPoseSimilarity(1 - averageDistance / Math.SQRT2);
}

function visiblePosePointMap(points: Array<PosePoint>): Map<number, PosePoint> {
  const pointByType: Map<number, PosePoint> = new Map<number, PosePoint>();
  points.forEach((point: PosePoint) => {
    if (isPosePointVisible(point)) {
      pointByType.set(point.type, point);
    }
  });
  return pointByType;
}

function poseBounds(points: Array<PosePoint>): PoseBounds {
  let minX = points[0].x;
  let maxX = points[0].x;
  let minY = points[0].y;
  let maxY = points[0].y;
  points.forEach((point: PosePoint) => {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
  });
  return {
    minX: minX,
    minY: minY,
    width: maxX - minX,
    height: maxY - minY
  };
}

function normalizePosePoint(point: PosePoint, bounds: PoseBounds): NormalizedPosePoint {
  return {
    x: bounds.width <= 0 ? 0.5 : (point.x - bounds.minX) / bounds.width,
    y: bounds.height <= 0 ? 0.5 : (point.y - bounds.minY) / bounds.height
  };
}

function clampPoseSimilarity(value: number): number {
  return Math.min(1, Math.max(0, value));
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
