import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  danceNoActScore,
  danceNoPointScore,
  danceScoreFromFrames,
  danceTemplateFrames
} from '../ai/DanceScoreService';
import { DanceSamplingResult } from './DanceSamplingService';

export const dancePagePath: string = 'pages/DancePage';
export const danceResultComponentId: string = 'danceResultPanel';
export const danceReferenceVideoUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/apk/danceFactory/dance_factory_demo2.mp4';
export const danceReferenceVideoLengthBytes: number = 41282333;
export const danceCountdownStepMs: number = 1000;

export function danceCountdownSequence(): Array<number> {
  return [3, 2, 1];
}

export interface DanceSamplingPageState {
  readonly scoreText: string;
  readonly resultMessageKey: AppStringKey;
  readonly hasResult: boolean;
  readonly summaryText: string;
}

export interface DanceReferenceVideoReadiness {
  readonly cached: boolean;
  readonly playerPrepared: boolean;
  readonly preparing: boolean;
  readonly failed: boolean;
}

export function danceReferenceVideoCanStartLive(readiness: DanceReferenceVideoReadiness): boolean {
  return readiness.cached && readiness.playerPrepared && !readiness.preparing && !readiness.failed;
}

export function danceReferenceVideoPlayerPreparedAfterCacheResult(
  cacheReady: boolean,
  nextUri: string,
  previousUri: string,
  previousPlayerPrepared: boolean
): boolean {
  return cacheReady && previousPlayerPrepared && nextUri.length > 0 && nextUri === previousUri;
}

export function danceTemplateDemoScore(): number {
  return danceScoreFromFrames(danceTemplateFrames());
}

export function danceScoreText(score: number, prefix: string = ''): string {
  return `${prefix}${Math.round(score)}`;
}

export function danceResultMessageKey(score: number): AppStringKey {
  if (score === danceNoActScore) {
    return 'dance_score_level_no_action';
  }
  if (score === danceNoPointScore) {
    return 'dance_score_level_no_point';
  }
  if (score === 100) {
    return 'dance_score_level_full';
  }
  if (score >= 95 && score < 100) {
    return 'dance_score_level_perfect';
  }
  if (score >= 90 && score < 95) {
    return 'dance_score_level_excellent';
  }
  if (score >= 80 && score < 90) {
    return 'dance_score_level_great';
  }
  if (score >= 70 && score < 80) {
    return 'dance_score_level_good';
  }
  if (score >= 60 && score < 70) {
    return 'dance_score_level_warmup';
  }
  if (score >= 50 && score < 60) {
    return 'dance_score_level_try_again';
  }
  return 'empty';
}

export function danceSamplingPageState(result: DanceSamplingResult, scorePrefix: string = ''): DanceSamplingPageState {
  const state: DanceSamplingPageState = {
    scoreText: danceScoreText(result.score, scorePrefix),
    resultMessageKey: danceResultMessageKey(result.score),
    hasResult: true,
    summaryText: `${result.validFrameCount}/${result.frameCount}`
  };
  return state;
}

export function danceSamplingCompletionStatusKey(result: DanceSamplingResult): AppStringKey {
  if (result.cancelled) {
    return 'empty';
  }
  if (result.frameCount > 0 && result.failedFrameCount >= result.frameCount) {
    return 'feature_runtime_live_frame_failed';
  }
  return 'dance_sampling_done';
}

export function danceSamplingResultStopsLiveCameraPreview(result: DanceSamplingResult): boolean {
  return danceSamplingCompletionStatusKey(result) === 'dance_sampling_done';
}
