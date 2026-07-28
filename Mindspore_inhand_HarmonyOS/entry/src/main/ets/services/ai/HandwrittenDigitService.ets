import {
  HandwrittenDigitPrediction,
  handwrittenDigitInputFloatCount,
  topHandwrittenDigitResults
} from './HandwrittenDigitPreprocess';

export type HandwrittenDigitFailureCode =
  'IMAGE_URI_INVALID' | 'IMAGE_DECODE_FAILED' | 'INPUT_INVALID' | 'MODEL_UNAVAILABLE' | 'MODEL_OUTPUT_INVALID';

export class HandwrittenDigitFailure extends Error {
  readonly code: HandwrittenDigitFailureCode;

  constructor(code: HandwrittenDigitFailureCode) {
    super(code);
    this.code = code;
  }
}

export interface HandwrittenDigitImagePreprocessor {
  createInput(imageUri: string): Promise<ArrayBuffer>;
}

export interface HandwrittenDigitScoreRunner {
  predictLogits(input: ArrayBuffer): Promise<Array<number>>;
}

export interface HandwrittenDigitTensorRunner {
  predictScoresFromInput(input: ArrayBuffer): Promise<Array<number>>;
}

export class HandwrittenDigitMindSporeScoreRunner implements HandwrittenDigitScoreRunner {
  private readonly tensorRunner: HandwrittenDigitTensorRunner;

  constructor(tensorRunner: HandwrittenDigitTensorRunner) {
    this.tensorRunner = tensorRunner;
  }

  async predictLogits(input: ArrayBuffer): Promise<Array<number>> {
    return this.tensorRunner.predictScoresFromInput(input);
  }
}

export interface HandwrittenDigitServiceOptions {
  readonly preprocessor: HandwrittenDigitImagePreprocessor;
  readonly scoreRunner: HandwrittenDigitScoreRunner;
}

export class HandwrittenDigitService {
  private readonly preprocessor: HandwrittenDigitImagePreprocessor;
  private readonly scoreRunner: HandwrittenDigitScoreRunner;

  constructor(options: HandwrittenDigitServiceOptions) {
    this.preprocessor = options.preprocessor;
    this.scoreRunner = options.scoreRunner;
  }

  async recognizeDigit(imageUri: string): Promise<Array<HandwrittenDigitPrediction>> {
    if (imageUri.trim().length === 0) {
      throw new HandwrittenDigitFailure('IMAGE_URI_INVALID');
    }
    let input: ArrayBuffer;
    try {
      input = await this.preprocessor.createInput(imageUri);
    } catch (_) {
      throw new HandwrittenDigitFailure('IMAGE_DECODE_FAILED');
    }
    if (input.byteLength !== handwrittenDigitInputFloatCount * Float32Array.BYTES_PER_ELEMENT) {
      throw new HandwrittenDigitFailure('INPUT_INVALID');
    }
    let logits: Array<number>;
    try {
      logits = await this.scoreRunner.predictLogits(input);
    } catch (_) {
      throw new HandwrittenDigitFailure('MODEL_UNAVAILABLE');
    }
    try {
      return topHandwrittenDigitResults(logits);
    } catch (_) {
      throw new HandwrittenDigitFailure('MODEL_OUTPUT_INVALID');
    }
  }
}
