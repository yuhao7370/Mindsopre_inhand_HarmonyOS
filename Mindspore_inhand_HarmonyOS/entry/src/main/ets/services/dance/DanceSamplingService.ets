import {
  DanceFrameData,
  DancePoint,
  DanceSkeletonPoints,
  danceFrameFromPoints,
  danceScoreFromFrames
} from '../ai/DanceScoreService';
import { PosePoint, PoseResult, PoseService, isPosePointVisible } from '../ai/PoseService';
import { PosePointType } from '../ai/PosePointType';
import { LiveFrameImageResult, LiveFrameImageService } from '../camera/LiveCameraService';

export const danceDefaultSampleFrameCount = 70;
export const danceSampleIntervalMs = 500;

export interface DancePosePointTypes {
  readonly LEFT_SHOULDER: number;
  readonly RIGHT_SHOULDER: number;
  readonly RIGHT_ELBOW: number;
  readonly RIGHT_WRIST: number;
  readonly LEFT_ELBOW: number;
  readonly LEFT_WRIST: number;
  readonly LEFT_KNEE: number;
  readonly LEFT_ANKLE: number;
}

export const dancePosePointType: DancePosePointTypes = {
  LEFT_SHOULDER: PosePointType.LEFT_SHOULDER,
  RIGHT_SHOULDER: PosePointType.RIGHT_SHOULDER,
  RIGHT_ELBOW: PosePointType.RIGHT_ELBOW,
  RIGHT_WRIST: PosePointType.RIGHT_WRIST,
  LEFT_ELBOW: PosePointType.LEFT_ELBOW,
  LEFT_WRIST: PosePointType.LEFT_WRIST,
  LEFT_KNEE: PosePointType.LEFT_KNEE,
  LEFT_ANKLE: PosePointType.LEFT_ANKLE
};

export interface DancePoseFrameSource {
  poseFrame(frameId: number): Promise<PoseResult>;
}

export interface DanceFrameImageCapturer {
  captureToCacheImage(surfaceId: string, cacheDir: string): Promise<LiveFrameImageResult>;
}

export interface DancePoseDetector {
  detectPose(imageUri: string): Promise<PoseResult>;
}

export interface DanceSamplingDelay {
  wait(intervalMs: number): Promise<void>;
}

export interface DanceSamplingClock {
  now(): number;
}

export interface DanceSamplingCancellation {
  isCancelled(): boolean;
}

export interface DanceSamplingResult {
  readonly frameCount: number;
  readonly validFrameCount: number;
  readonly failedFrameCount: number;
  readonly cancelled: boolean;
  readonly frames: Array<DanceFrameData | undefined>;
  readonly score: number;
}

export function danceSkeletonPointsFromPose(points: Array<PosePoint>): DanceSkeletonPoints | undefined {
  const leftShoulder = visiblePosePoint(points, dancePosePointType.LEFT_SHOULDER);
  const rightShoulder = visiblePosePoint(points, dancePosePointType.RIGHT_SHOULDER);
  const rightElbow = visiblePosePoint(points, dancePosePointType.RIGHT_ELBOW);
  const rightWrist = visiblePosePoint(points, dancePosePointType.RIGHT_WRIST);
  const leftElbow = visiblePosePoint(points, dancePosePointType.LEFT_ELBOW);
  const leftWrist = visiblePosePoint(points, dancePosePointType.LEFT_WRIST);
  const leftKnee = visiblePosePoint(points, dancePosePointType.LEFT_KNEE);
  const leftAnkle = visiblePosePoint(points, dancePosePointType.LEFT_ANKLE);

  if (leftShoulder === undefined ||
    rightShoulder === undefined ||
    rightElbow === undefined ||
    rightWrist === undefined ||
    leftElbow === undefined ||
    leftWrist === undefined ||
    leftKnee === undefined ||
    leftAnkle === undefined) {
    return undefined;
  }

  const skeletonPoints: DanceSkeletonPoints = {
    neck: danceNeckPoint(leftShoulder, rightShoulder),
    rightElbow: dancePointFromPose(rightElbow),
    rightWrist: dancePointFromPose(rightWrist),
    leftElbow: dancePointFromPose(leftElbow),
    leftWrist: dancePointFromPose(leftWrist),
    leftKnee: dancePointFromPose(leftKnee),
    leftAnkle: dancePointFromPose(leftAnkle)
  };
  return skeletonPoints;
}

export function danceFrameFromPoseResult(frameId: number, result: PoseResult): DanceFrameData | undefined {
  if (!result.ok) {
    return undefined;
  }
  const points = danceSkeletonPointsFromPose(result.points);
  if (points === undefined) {
    return undefined;
  }
  return danceFrameFromPoints(frameId, points);
}

export class DanceSamplingService {
  async sample(
    source: DancePoseFrameSource,
    frameCount: number = danceDefaultSampleFrameCount
  ): Promise<DanceSamplingResult> {
    const frames: Array<DanceFrameData | undefined> = [];
    const total = Math.max(0, frameCount);
    let failedFrameCount = 0;
    for (let frameId = 1; frameId <= total; frameId++) {
      try {
        frames.push(danceFrameFromPoseResult(frameId, await source.poseFrame(frameId)));
      } catch (_) {
        frames.push(undefined);
        failedFrameCount++;
      }
    }
    return danceSamplingResultFromFrames(frames, total, failedFrameCount, false);
  }
}

export class DanceLivePoseFrameSource implements DancePoseFrameSource {
  private readonly surfaceId: string;
  private readonly cacheDir: string;
  private readonly frameImageCapturer: DanceFrameImageCapturer;
  private readonly poseDetector: DancePoseDetector;

  constructor(
    surfaceId: string,
    cacheDir: string,
    frameImageCapturer: DanceFrameImageCapturer,
    poseDetector: DancePoseDetector
  ) {
    this.surfaceId = surfaceId;
    this.cacheDir = cacheDir;
    this.frameImageCapturer = frameImageCapturer;
    this.poseDetector = poseDetector;
  }

  async poseFrame(_frameId: number): Promise<PoseResult> {
    const frame = await this.frameImageCapturer.captureToCacheImage(this.surfaceId, this.cacheDir);
    if (!frame.ok || frame.uri.length === 0) {
      throw new Error(frame.messageKey);
    }
    return this.poseDetector.detectPose(frame.uri);
  }
}

export class DanceLiveFrameImageCapturer implements DanceFrameImageCapturer {
  private readonly service: LiveFrameImageService;

  constructor(service: LiveFrameImageService) {
    this.service = service;
  }

  async captureToCacheImage(surfaceId: string, cacheDir: string): Promise<LiveFrameImageResult> {
    return this.service.captureToCacheImage(surfaceId, cacheDir);
  }
}

export class DancePoseServiceDetector implements DancePoseDetector {
  private readonly service: PoseService;

  constructor(service: PoseService) {
    this.service = service;
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    return this.service.detectPose(imageUri);
  }
}

export class HarmonyDanceSamplingDelay implements DanceSamplingDelay {
  async wait(intervalMs: number): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, intervalMs);
    });
  }
}

export class HarmonyDanceSamplingClock implements DanceSamplingClock {
  now(): number {
    return Date.now();
  }
}

export class DanceSamplingCancellationToken implements DanceSamplingCancellation {
  private cancelled: boolean = false;

  isCancelled(): boolean {
    return this.cancelled;
  }

  cancel(): void {
    this.cancelled = true;
  }
}

export class DanceTimedSamplingService {
  private readonly delay: DanceSamplingDelay;
  private readonly clock: DanceSamplingClock;
  private readonly cancellation: DanceSamplingCancellation | undefined;

  constructor(
    delay: DanceSamplingDelay = new HarmonyDanceSamplingDelay(),
    clock: DanceSamplingClock = new HarmonyDanceSamplingClock(),
    cancellation?: DanceSamplingCancellation
  ) {
    this.delay = delay;
    this.clock = clock;
    this.cancellation = cancellation;
  }

  async sample(
    source: DancePoseFrameSource,
    frameCount: number = danceDefaultSampleFrameCount
  ): Promise<DanceSamplingResult> {
    const frames: Array<DanceFrameData | undefined> = [];
    const total = Math.max(0, frameCount);
    const startMs = this.clock.now();
    let failedFrameCount = 0;
    for (let frameId = 1; frameId <= total; frameId++) {
      if (this.isCancelled()) {
        return danceSamplingResultFromFrames(frames, total, failedFrameCount, true);
      }
      const targetMs = startMs + ((frameId - 1) * danceSampleIntervalMs);
      const waitMs = targetMs - this.clock.now();
      if (waitMs > 0) {
        await this.delay.wait(waitMs);
      }
      if (this.isCancelled()) {
        return danceSamplingResultFromFrames(frames, total, failedFrameCount, true);
      }
      try {
        frames.push(danceFrameFromPoseResult(frameId, await source.poseFrame(frameId)));
      } catch (_) {
        frames.push(undefined);
        failedFrameCount++;
      }
    }
    return danceSamplingResultFromFrames(frames, total, failedFrameCount, false);
  }

  private isCancelled(): boolean {
    return this.cancellation !== undefined && this.cancellation.isCancelled();
  }
}

function danceSamplingResultFromFrames(
  frames: Array<DanceFrameData | undefined>,
  total: number,
  failedFrameCount: number,
  cancelled: boolean
): DanceSamplingResult {
  const result: DanceSamplingResult = {
    frameCount: total,
    validFrameCount: frames.filter((frame: DanceFrameData | undefined) => frame !== undefined).length,
    failedFrameCount: failedFrameCount,
    cancelled: cancelled,
    frames: frames,
    score: danceScoreFromFrames(frames)
  };
  return result;
}

function visiblePosePoint(points: Array<PosePoint>, type: number): PosePoint | undefined {
  return points.find((point: PosePoint) => point.type === type && isPosePointVisible(point));
}

function dancePointFromPose(point: PosePoint): DancePoint {
  const dancePoint: DancePoint = {
    x: point.x,
    y: point.y
  };
  return dancePoint;
}

function danceNeckPoint(leftShoulder: PosePoint, rightShoulder: PosePoint): DancePoint {
  const neck: DancePoint = {
    x: (leftShoulder.x + rightShoulder.x) / 2,
    y: (leftShoulder.y + rightShoulder.y) / 2
  };
  return neck;
}
