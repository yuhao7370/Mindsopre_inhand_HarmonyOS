import { ImageClassificationScoreRunner } from './ImageClassificationService';

export interface ImageClassificationInputPreprocessor {
  createInputBuffer(imageUri: string): Promise<ArrayBuffer>;
}

export interface ImageClassificationTensorRunner {
  predictScoresFromInput(inputBuffer: ArrayBuffer): Promise<Array<number>>;
}

export interface ImageClassificationMindSporeScoreRunnerOptions {
  readonly preprocessor: ImageClassificationInputPreprocessor;
  readonly tensorRunner: ImageClassificationTensorRunner;
}

export class ImageClassificationMindSporeScoreRunner implements ImageClassificationScoreRunner {
  private readonly preprocessor: ImageClassificationInputPreprocessor;
  private readonly tensorRunner: ImageClassificationTensorRunner;

  constructor(options: ImageClassificationMindSporeScoreRunnerOptions) {
    this.preprocessor = options.preprocessor;
    this.tensorRunner = options.tensorRunner;
  }

  async predictScores(imageUri: string): Promise<Array<number>> {
    const inputBuffer = await this.preprocessor.createInputBuffer(imageUri);
    return this.tensorRunner.predictScoresFromInput(inputBuffer);
  }
}
