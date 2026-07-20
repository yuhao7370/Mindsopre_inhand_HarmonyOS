export const imageCategoryLabelRawfilePath: string = 'labels/image_category_old.txt';
export const imageCategoryLabelCount: number = 1000;
export const imageClassificationModelRawfilePath: string = 'model/mobilenetv2.ms';
export const imageClassificationModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/quick_start/mobilenetv2.ms';

export interface ImageClassificationResult {
  readonly ok: boolean;
  readonly index: number;
  readonly label: string;
  readonly score: number;
}

export type ImageClassificationRunCode =
  'MISSING_INPUT' |
  'MODEL_PENDING' |
  'CLASSIFICATION_DONE' |
  'CLASSIFICATION_INVALID_OUTPUT';

export interface ImageClassificationRunResult {
  readonly ok: boolean;
  readonly code: ImageClassificationRunCode;
  readonly classification: ImageClassificationResult;
}

export interface ImageClassificationScoreRunner {
  predictScores(imageUri: string): Promise<Array<number>>;
}

export interface ImageClassificationServiceOptions {
  readonly labels: Array<string>;
  readonly scoreRunner?: ImageClassificationScoreRunner;
}

export class ImageClassificationService {
  private readonly labels: Array<string>;
  private readonly scoreRunner?: ImageClassificationScoreRunner;

  constructor(options: ImageClassificationServiceOptions) {
    this.labels = options.labels;
    this.scoreRunner = options.scoreRunner;
  }

  async classifyImage(imageUri: string): Promise<ImageClassificationRunResult> {
    if (imageUri.length === 0) {
      return this.runResult(false, 'MISSING_INPUT', emptyClassificationResult());
    }
    if (!this.scoreRunner) {
      return this.runResult(false, 'MODEL_PENDING', emptyClassificationResult());
    }

    let scores: Array<number>;
    try {
      scores = await this.scoreRunner.predictScores(imageUri);
    } catch (_) {
      return this.runResult(false, 'CLASSIFICATION_INVALID_OUTPUT', emptyClassificationResult());
    }

    const classification = topClassificationResult(scores, this.labels);
    if (!classification.ok) {
      return this.runResult(false, 'CLASSIFICATION_INVALID_OUTPUT', classification);
    }
    return this.runResult(true, 'CLASSIFICATION_DONE', classification);
  }

  private runResult(
    ok: boolean,
    code: ImageClassificationRunCode,
    classification: ImageClassificationResult
  ): ImageClassificationRunResult {
    return {
      ok: ok,
      code: code,
      classification: classification
    };
  }
}

export function parseImageCategoryLabels(rawText: string): Array<string> {
  const labels: Array<string> = [];
  rawText.split('\n').forEach((line: string) => {
    const label = line.split('\r').join('').trim();
    if (label.length > 0) {
      labels.push(label);
    }
  });
  return labels;
}

export function topClassificationResult(scores: Array<number>, labels: Array<string>): ImageClassificationResult {
  if (scores.length === 0 || labels.length === 0) {
    return emptyClassificationResult();
  }

  let maxIndex = 0;
  let maxScore = 0;
  const scanLimit = Math.min(scores.length, imageCategoryLabelCount);
  for (let index = 0; index < scanLimit; index++) {
    const score = scores[index];
    if (score > maxScore) {
      maxScore = score;
      maxIndex = index;
    }
  }

  if (maxIndex >= labels.length) {
    return {
      ok: false,
      index: maxIndex,
      label: '',
      score: maxScore
    };
  }

  return {
    ok: true,
    index: maxIndex,
    label: labels[maxIndex],
    score: maxScore
  };
}

function emptyClassificationResult(): ImageClassificationResult {
  return {
    ok: false,
    index: -1,
    label: '',
    score: 0
  };
}
