import {
  HandwrittenDigitPrediction,
  handwrittenDigitInputFloatCount,
  topHandwrittenDigitResults
} from './HandwrittenDigitPreprocess';

export interface HandwrittenDigitImagePreprocessor {
  createInput(imageUri: string): Promise<ArrayBuffer>;
}

export interface HandwrittenDigitScoreRunner {
  predictLogits(input: ArrayBuffer): Promise<Array<number>>;
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
      throw new Error('Handwritten digit image URI is required.');
    }
    const input = await this.preprocessor.createInput(imageUri);
    if (input.byteLength !== handwrittenDigitInputFloatCount * Float32Array.BYTES_PER_ELEMENT) {
      throw new Error('Handwritten digit input tensor must be 1x1x28x28 float32.');
    }
    return topHandwrittenDigitResults(await this.scoreRunner.predictLogits(input));
  }
}
