import { AppStringKey } from '../../common/i18n/AppStrings';
import { ImageClassificationScoreRunner, imageCategoryLabelCount } from './ImageClassificationService';

export interface GestureRectangle {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface GestureRectanglePercent {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface GestureDetection {
  readonly category: number;
  readonly label: string;
  readonly score: number;
  readonly rect?: GestureRectangle;
}

export interface GestureResult {
  readonly ok: boolean;
  readonly gestures: Array<GestureDetection>;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs: number;
}

export interface GestureRunner {
  detectGesture(imageUri: string): Promise<GestureResult>;
}

export interface GestureServiceOptions {
  readonly runner: GestureRunner;
}

export interface ImageClassificationGestureRunnerOptions {
  readonly labels: Array<string>;
  readonly scoreRunner: ImageClassificationScoreRunner;
  readonly maxGestures?: number;
  readonly minScore?: number;
}

interface LocalGestureCategoryMap {
  readonly category: number;
  readonly keywords: Array<string>;
}

export const localOtherGestureCategory: number = 14;
export const localGestureDetectionMaxGestureCount: number = 1;
export const localGestureDetectionScoreThreshold: number = 0.45;
export const localGestureDetectionImageWidth: number = 100;
export const localGestureDetectionImageHeight: number = 100;

const localGestureDetectionBox: GestureRectangle = {
  left: 25,
  top: 10,
  width: 50,
  height: 70
};

const localGestureCategoryMaps: Array<LocalGestureCategoryMap> = [
  { category: 0, keywords: ['one', 'number_one', 'digit_one'] },
  { category: 1, keywords: ['two', 'second', 'number_two', 'digit_two'] },
  { category: 2, keywords: ['three', 'number_three', 'digit_three'] },
  { category: 3, keywords: ['four', 'number_four', 'digit_four'] },
  { category: 4, keywords: ['five', 'number_five', 'digit_five', 'open_palm'] },
  { category: 5, keywords: ['six', 'number_six', 'digit_six'] },
  { category: 6, keywords: ['seven', 'number_seven', 'digit_seven'] },
  { category: 7, keywords: ['eight', 'number_eight', 'digit_eight'] },
  { category: 8, keywords: ['nine', 'number_nine', 'digit_nine'] },
  { category: 9, keywords: ['dislike', 'thumb_down', 'thumbs_down'] },
  { category: 10, keywords: ['fist', 'boxing_glove'] },
  { category: 11, keywords: ['good', 'thumb_up', 'thumbs_up'] },
  { category: 12, keywords: ['heart', 'finger_heart', 'hand_heart'] },
  { category: 13, keywords: ['ok', 'okay', 'ok_gesture'] },
  { category: localOtherGestureCategory, keywords: ['mitten'] }
];

export class GestureService {
  private readonly runner: GestureRunner;

  constructor(options: GestureServiceOptions) {
    this.runner = options.runner;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    const startMs = Date.now();
    try {
      return await this.runner.detectGesture(imageUri);
    } catch (_) {
      return {
        ok: false,
        gestures: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export class ImageClassificationGestureRunner implements GestureRunner {
  private readonly labels: Array<string>;
  private readonly scoreRunner: ImageClassificationScoreRunner;
  private readonly maxGestures: number;
  private readonly minScore: number;

  constructor(options: ImageClassificationGestureRunnerOptions) {
    this.labels = options.labels;
    this.scoreRunner = options.scoreRunner;
    this.maxGestures = options.maxGestures ?? localGestureDetectionMaxGestureCount;
    this.minScore = options.minScore ?? localGestureDetectionScoreThreshold;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    const startMs = Date.now();
    try {
      const scores = await this.scoreRunner.predictScores(imageUri);
      const gestures = topLocalGestureDetections(scores, this.labels, this.maxGestures, this.minScore);
      return {
        ok: gestures.length > 0,
        gestures: gestures,
        imageWidth: localGestureDetectionImageWidth,
        imageHeight: localGestureDetectionImageHeight,
        executionMs: Date.now() - startMs
      };
    } catch (_) {
      return {
        ok: false,
        gestures: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export function gestureDetectionLabel(gesture: GestureDetection): string {
  const runnerLabel = gesture.label.trim();
  if (runnerLabel.length > 0) {
    return runnerLabel;
  }
  return androidGestureLabel(gesture.category);
}

export function gestureDetectionLabelKey(gesture: GestureDetection): AppStringKey | undefined {
  const runnerLabel = gesture.label.trim();
  if (runnerLabel.length > 0 && runnerLabel !== androidGestureLabel(gesture.category)) {
    return undefined;
  }
  return androidGestureLabelKey(gesture.category);
}

export function androidGestureLabelKey(category: number): AppStringKey {
  switch (category) {
    case 0:
      return 'gesture_label_one';
    case 1:
      return 'gesture_label_two';
    case 2:
      return 'gesture_label_three';
    case 3:
      return 'gesture_label_four';
    case 4:
      return 'gesture_label_five';
    case 5:
      return 'gesture_label_six';
    case 6:
      return 'gesture_label_seven';
    case 7:
      return 'gesture_label_eight';
    case 8:
      return 'gesture_label_nine';
    case 9:
      return 'gesture_label_dislike';
    case 10:
      return 'gesture_label_fist';
    case 11:
      return 'gesture_label_thumb_up';
    case 12:
      return 'gesture_label_heart';
    case 13:
      return 'gesture_label_ok';
    default:
      return 'gesture_label_other';
  }
}

export function androidGestureLabel(category: number): string {
  switch (category) {
    case 0:
      return 'One';
    case 1:
      return 'Two';
    case 2:
      return 'Three';
    case 3:
      return 'Four';
    case 4:
      return 'Five';
    case 5:
      return 'Six';
    case 6:
      return 'Seven';
    case 7:
      return 'Eight';
    case 8:
      return 'Nine';
    case 9:
      return 'Dislike';
    case 10:
      return 'Fist';
    case 11:
      return 'Thumb up';
    case 12:
      return 'Heart';
    case 13:
      return 'OK';
    default:
      return 'Other gesture';
  }
}

export function topLocalGestureDetections(
  scores: Array<number>,
  labels: Array<string>,
  maxGestures: number = localGestureDetectionMaxGestureCount,
  minScore: number = localGestureDetectionScoreThreshold
): Array<GestureDetection> {
  const candidates: Array<GestureDetection> = [];
  const scanLimit = Math.min(scores.length, labels.length, imageCategoryLabelCount);
  for (let index = 0; index < scanLimit; index++) {
    const score = scores[index];
    if (!(score >= minScore)) {
      continue;
    }
    const category = gestureCategoryForImageClassificationLabel(labels[index]);
    if (category < 0) {
      continue;
    }
    candidates.push({
      category: category,
      label: androidGestureLabel(category),
      score: score,
      rect: localGestureDetectionBox
    });
  }
  candidates.sort((left: GestureDetection, right: GestureDetection) => right.score - left.score);

  const limit = maxGestures > 0 ? maxGestures : localGestureDetectionMaxGestureCount;
  const gestures: Array<GestureDetection> = [];
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (!hasGestureCategory(gestures, candidate.category)) {
      gestures.push(candidate);
    }
    if (gestures.length >= limit) {
      break;
    }
  }
  return gestures;
}

export function gestureCategoryForImageClassificationLabel(label: string): number {
  const normalized = normalizeGestureLabel(label);
  for (let index = 0; index < localGestureCategoryMaps.length; index++) {
    const entry = localGestureCategoryMaps[index];
    for (let keywordIndex = 0; keywordIndex < entry.keywords.length; keywordIndex++) {
      if (gestureLabelEqualsKeyword(normalized, entry.keywords[keywordIndex])) {
        return entry.category;
      }
    }
  }
  return -1;
}

export function gestureRectanglePercent(
  rectangle: GestureRectangle,
  imageWidth: number,
  imageHeight: number
): GestureRectanglePercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      left: 0,
      top: 0,
      width: 0,
      height: 0
    };
  }

  const left = gesturePercent(rectangle.left, imageWidth);
  const top = gesturePercent(rectangle.top, imageHeight);
  const right = gesturePercent(rectangle.left + rectangle.width, imageWidth);
  const bottom = gesturePercent(rectangle.top + rectangle.height, imageHeight);
  return {
    left: left,
    top: top,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top)
  };
}

function gesturePercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}

function normalizeGestureLabel(label: string): string {
  return label.trim().toLowerCase().split(' ').join('_').split('-').join('_').split('/').join('_');
}

function gestureLabelEqualsKeyword(label: string, keyword: string): boolean {
  return label === keyword;
}

function hasGestureCategory(gestures: Array<GestureDetection>, category: number): boolean {
  for (let index = 0; index < gestures.length; index++) {
    if (gestures[index].category === category) {
      return true;
    }
  }
  return false;
}
