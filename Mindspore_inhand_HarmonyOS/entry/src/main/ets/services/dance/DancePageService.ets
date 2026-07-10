import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  danceNoActScore,
  danceNoPointScore,
  danceScoreFromFrames,
  danceTemplateFrames
} from '../ai/DanceScoreService';

export const dancePagePath: string = 'pages/DancePage';

export function danceTemplateDemoScore(): number {
  return danceScoreFromFrames(danceTemplateFrames());
}

export function danceScoreText(score: number): string {
  if (score < 0) {
    return '--';
  }
  return `${Math.round(score)}`;
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
