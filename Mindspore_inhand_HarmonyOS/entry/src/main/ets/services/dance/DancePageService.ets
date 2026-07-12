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
export const dancePrepareBackgroundMediaName: string = 'app.media.dance_prepare_bk';
export const danceRunBackgroundMediaName: string = 'app.media.dance_run_bk';
export const danceResultBackgroundMediaName: string = 'app.media.dance_result_bk';
export const danceResultSaveMediaName: string = 'app.media.dance_result_save';
export const danceResultPlayAgainMediaName: string = 'app.media.dance_result_play_again';
export const danceResultBackMediaName: string = 'app.media.dance_result_back';
export const danceResultBackgroundWidthPx: number = 1920;
export const danceResultBackgroundHeightPx: number = 1080;
export const danceResultActionButtonWidthPx: number = 492;
export const danceResultActionButtonHeightPx: number = 145;
export const danceResultBackButtonWidthPx: number = 140;
export const danceResultBackButtonHeightPx: number = 140;
export const danceResultPlayAgainLabelKey: AppStringKey = 'dance_reset';

export function danceSaveStatusKey(ok: boolean): AppStringKey {
  return ok ? 'image_save_success' : 'image_save_failed';
}

export function danceResultBackgroundAspectRatio(): number {
  return danceResultBackgroundWidthPx / danceResultBackgroundHeightPx;
}

export function danceCountdownSequence(): Array<number> {
  return [3, 2, 1];
}

export interface DanceSamplingPageState {
  readonly scoreLabelKey: AppStringKey;
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

export function danceReferenceVideoProgressText(percent: number): string {
  if (percent !== percent) {
    return '0%';
  }
  const roundedPercent = Math.round(percent);
  if (roundedPercent <= 0) {
    return '0%';
  }
  if (roundedPercent >= 100) {
    return '100%';
  }
  return `${roundedPercent}%`;
}

export function danceTemplateDemoScore(): number {
  return danceScoreFromFrames(danceTemplateFrames());
}

export function danceTemplateDemoActionVisible(): boolean {
  return false;
}

export function danceResultScoreLabelKey(score: number): AppStringKey {
  if (score === danceNoActScore) {
    return 'dance_score_level_no_action';
  }
  if (score === danceNoPointScore) {
    return 'dance_score_level_no_point';
  }
  return 'dance_score_prefix';
}

export function danceScoreText(score: number): string {
  if (score === danceNoActScore || score === danceNoPointScore) {
    return '';
  }
  return `${Math.round(score)}`;
}

export function danceResultMessageKey(score: number): AppStringKey {
  if (score === danceNoActScore) {
    return 'empty';
  }
  if (score === danceNoPointScore) {
    return 'empty';
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

export function danceSamplingPageState(result: DanceSamplingResult): DanceSamplingPageState {
  const state: DanceSamplingPageState = {
    scoreLabelKey: danceResultScoreLabelKey(result.score),
    scoreText: danceScoreText(result.score),
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
