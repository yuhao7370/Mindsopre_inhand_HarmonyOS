import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AppStringKey } from '../../common/i18n/AppStrings';
import { ImageClassificationScoreRunner, imageCategoryLabelCount } from './ImageClassificationService';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';

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

export interface GestureRegionEstimate {
  readonly rect: GestureRectangle;
  readonly imageWidth: number;
  readonly imageHeight: number;
}

export interface GestureRegionEstimator {
  estimateRegion(imageUri: string): Promise<GestureRegionEstimate | undefined>;
}

export interface GestureServiceOptions {
  readonly runner: GestureRunner;
}

export interface ImageClassificationGestureRunnerOptions {
  readonly labels: Array<string>;
  readonly scoreRunner: ImageClassificationScoreRunner;
  readonly regionEstimator?: GestureRegionEstimator;
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
export const localGestureDetectionMaxForegroundAreaRatio: number = 0.75;

const localGestureDetectionBox: GestureRectangle = {
  left: 25,
  top: 10,
  width: 50,
  height: 70
};

const localGestureCategoryMaps: Array<LocalGestureCategoryMap> = [
  { category: 0, keywords: ['one', 'number_one', 'digit_one', 'pointing_up', 'pointing_up_gesture'] },
  { category: 1, keywords: ['two', 'second', 'number_two', 'digit_two', 'victory', 'peace', 'v_sign'] },
  { category: 2, keywords: ['three', 'number_three', 'digit_three'] },
  { category: 3, keywords: ['four', 'number_four', 'digit_four'] },
  { category: 4, keywords: ['five', 'number_five', 'digit_five', 'open_palm', 'raised_hand'] },
  { category: 5, keywords: ['six', 'number_six', 'digit_six'] },
  { category: 6, keywords: ['seven', 'number_seven', 'digit_seven'] },
  { category: 7, keywords: ['eight', 'number_eight', 'digit_eight'] },
  { category: 8, keywords: ['nine', 'number_nine', 'digit_nine'] },
  { category: 9, keywords: ['diss', 'dislike', 'thumb_down', 'thumb_down_gesture', 'thumbs_down'] },
  { category: 10, keywords: ['fist', 'closed_fist', 'boxing_glove'] },
  { category: 11, keywords: ['good', 'like_gesture', 'thumb_up', 'thumbs_up'] },
  { category: 12, keywords: ['heart', 'heart_gesture', 'finger_heart', 'finger_heart_gesture', 'hand_heart'] },
  { category: 13, keywords: ['ok', 'okay', 'ok_sign', 'ok_gesture'] },
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
  private readonly regionEstimator?: GestureRegionEstimator;
  private readonly maxGestures: number;
  private readonly minScore: number;

  constructor(options: ImageClassificationGestureRunnerOptions) {
    this.labels = options.labels;
    this.scoreRunner = options.scoreRunner;
    this.regionEstimator = options.regionEstimator;
    this.maxGestures = options.maxGestures ?? localGestureDetectionMaxGestureCount;
    this.minScore = options.minScore ?? localGestureDetectionScoreThreshold;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    const startMs = Date.now();
    try {
      const scores = await this.scoreRunner.predictScores(imageUri);
      let region: GestureRegionEstimate | undefined = undefined;
      let gestures = topLocalGestureDetections(scores, this.labels, this.maxGestures, this.minScore);
      if (gestures.length > 0) {
        region = await this.estimateRegion(imageUri);
        if (region !== undefined) {
          gestures = topLocalGestureDetections(scores, this.labels, this.maxGestures, this.minScore, region.rect);
        }
      }
      return {
        ok: gestures.length > 0,
        gestures: gestures,
        imageWidth: region?.imageWidth ?? localGestureDetectionImageWidth,
        imageHeight: region?.imageHeight ?? localGestureDetectionImageHeight,
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

  private async estimateRegion(imageUri: string): Promise<GestureRegionEstimate | undefined> {
    if (this.regionEstimator === undefined) {
      return undefined;
    }
    try {
      return await this.regionEstimator.estimateRegion(imageUri);
    } catch (_) {
      return undefined;
    }
  }
}

export class HarmonyGestureRegionEstimator implements GestureRegionEstimator {
  async estimateRegion(imageUri: string): Promise<GestureRegionEstimate | undefined> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageFile = await openGestureRegionImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await createPixelMapWithExifOrientation(imageSource, gestureRegionDecodeOptions());
      const imageInfo = await pixelMap.getImageInfo();
      const width = imageInfo.size.width;
      const height = imageInfo.size.height;
      const rgba = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(rgba);
      const rect = gestureRectangleFromRgbaForeground(new Uint8Array(rgba), width, height);
      if (rect === undefined) {
        return undefined;
      }
      return {
        rect: rect,
        imageWidth: width,
        imageHeight: height
      };
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeGestureRegionImageFile(imageFile);
      }
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
  minScore: number = localGestureDetectionScoreThreshold,
  rect: GestureRectangle = localGestureDetectionBox
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
      rect: rect
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

export function gestureRectangleFromRgbaForeground(
  rgba: Uint8Array,
  width: number,
  height: number
): GestureRectangle | undefined {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return undefined;
  }

  const topLeft = 0;
  const topRight = (width - 1) * 4;
  const bottomLeft = ((height - 1) * width) * 4;
  const bottomRight = ((height - 1) * width + width - 1) * 4;
  const backgroundR = (rgba[topLeft] + rgba[topRight] + rgba[bottomLeft] + rgba[bottomRight]) / 4;
  const backgroundG = (rgba[topLeft + 1] + rgba[topRight + 1] + rgba[bottomLeft + 1] + rgba[bottomRight + 1]) / 4;
  const backgroundB = (rgba[topLeft + 2] + rgba[topRight + 2] + rgba[bottomLeft + 2] + rgba[bottomRight + 2]) / 4;

  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  const foregroundThreshold = 48;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const offset = (y * width + x) * 4;
      const diff = Math.abs(rgba[offset] - backgroundR) +
        Math.abs(rgba[offset + 1] - backgroundG) +
        Math.abs(rgba[offset + 2] - backgroundB);
      if (rgba[offset + 3] === 0 || diff <= foregroundThreshold) {
        continue;
      }
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }

  if (maxX < minX || maxY < minY) {
    return undefined;
  }
  const rectWidth = maxX - minX + 1;
  const rectHeight = maxY - minY + 1;
  if (rectWidth * rectHeight > width * height * localGestureDetectionMaxForegroundAreaRatio) {
    return undefined;
  }
  return {
    left: minX,
    top: minY,
    width: rectWidth,
    height: rectHeight
  };
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

function gestureRegionDecodeOptions(): image.DecodingOptions {
  return {
    desiredSize: {
      width: localGestureDetectionImageWidth,
      height: localGestureDetectionImageHeight
    },
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

async function openGestureRegionImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for gesture region estimation.');
  }
}

async function closeGestureRegionImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
