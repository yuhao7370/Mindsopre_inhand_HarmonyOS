import { skeletonDetection } from '@kit.CoreVisionKit';
import {
  DanceFrameData,
  DancePoint,
  DanceSkeletonPoints,
  danceFrameFromPoints,
  danceScoreFromFrames
} from '../ai/DanceScoreService';
import { PosePoint, PoseResult, isPosePointVisible } from '../ai/PoseService';

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
  LEFT_SHOULDER: skeletonDetection.SkeletonPointType.LEFT_SHOULDER,
  RIGHT_SHOULDER: skeletonDetection.SkeletonPointType.RIGHT_SHOULDER,
  RIGHT_ELBOW: skeletonDetection.SkeletonPointType.RIGHT_ELBOW,
  RIGHT_WRIST: skeletonDetection.SkeletonPointType.RIGHT_WRIST,
  LEFT_ELBOW: skeletonDetection.SkeletonPointType.LEFT_ELBOW,
  LEFT_WRIST: skeletonDetection.SkeletonPointType.LEFT_WRIST,
  LEFT_KNEE: skeletonDetection.SkeletonPointType.LEFT_KNEE,
  LEFT_ANKLE: skeletonDetection.SkeletonPointType.LEFT_ANKLE
};

export interface DancePoseFrameSource {
  poseFrame(frameId: number): Promise<PoseResult>;
}

export interface DanceSamplingResult {
  readonly frameCount: number;
  readonly validFrameCount: number;
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
    for (let frameId = 1; frameId <= total; frameId++) {
      try {
        frames.push(danceFrameFromPoseResult(frameId, await source.poseFrame(frameId)));
      } catch (_) {
        frames.push(undefined);
      }
    }
    return {
      frameCount: total,
      validFrameCount: frames.filter((frame: DanceFrameData | undefined) => frame !== undefined).length,
      frames: frames,
      score: danceScoreFromFrames(frames)
    };
  }
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
