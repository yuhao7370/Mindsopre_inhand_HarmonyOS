import { AiRunResult } from '../../services/ai/AiService';
import { GestureDetection } from '../../services/ai/GestureService';
import { isLiveRuntimeGenerationCurrent } from '../../services/camera/LiveCameraService';

export interface LiveGestureResultState {
  readonly generation: number;
  readonly imageUri: string;
  readonly detections: Array<GestureDetection>;
  readonly imageWidth: number;
  readonly imageHeight: number;
}

export function projectLiveGestureResult(
  result: AiRunResult,
  expectedGeneration: number | undefined,
  currentGeneration: number
): LiveGestureResultState | undefined {
  if (!isLiveRuntimeGenerationCurrent(expectedGeneration, currentGeneration)) {
    return undefined;
  }
  const generation = expectedGeneration ?? currentGeneration;
  const data = result.data;
  if (data === undefined || data.kind !== 'gesture' || data.result.gestures.length === 0) {
    return { generation: generation, imageUri: '', detections: [], imageWidth: 0, imageHeight: 0 };
  }
  return {
    generation: generation,
    imageUri: data.imageUri,
    detections: data.result.gestures,
    imageWidth: data.result.imageWidth ?? 0,
    imageHeight: data.result.imageHeight ?? 0
  };
}
