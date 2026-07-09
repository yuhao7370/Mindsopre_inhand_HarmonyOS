import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { image } from '@kit.ImageKit';
import { FileUriContentReader } from './FileUriContentReader';
import {
  floatScoresFromOutputBuffer,
  mindSporeLiteCpuContext,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';

export const customModelInputSize: number = 224;
export const customModelInputChannels: number = 3;
export const customModelInputFloatCount: number =
  customModelInputSize * customModelInputSize * customModelInputChannels;

export interface CustomModelRunResult {
  readonly ok: boolean;
  readonly output: Array<number>;
  readonly executionMs: number;
}

export interface CustomModelInputPreprocessor {
  createInputBuffer(imageUri: string): Promise<ArrayBuffer>;
}

export interface CustomModelTensorRunner {
  predictOutput(modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>>;
}

export interface CustomModelSelectedFileRunnerOptions {
  readonly modelContentReader?: FileUriContentReader;
}

export interface CustomModelServiceOptions {
  readonly preprocessor: CustomModelInputPreprocessor;
  readonly tensorRunner: CustomModelTensorRunner;
}

export class CustomModelService {
  private readonly runner: CustomModelMindSporeRunner;

  constructor(options: CustomModelServiceOptions) {
    this.runner = new CustomModelMindSporeRunner(options);
  }

  async run(modelUri: string, imageUri: string): Promise<CustomModelRunResult> {
    return this.runner.run(modelUri, imageUri);
  }
}

export class CustomModelMindSporeRunner {
  private readonly preprocessor: CustomModelInputPreprocessor;
  private readonly tensorRunner: CustomModelTensorRunner;

  constructor(options: CustomModelServiceOptions) {
    this.preprocessor = options.preprocessor;
    this.tensorRunner = options.tensorRunner;
  }

  async run(modelUri: string, imageUri: string): Promise<CustomModelRunResult> {
    const startedAt = Date.now();
    const inputBuffer = await this.preprocessor.createInputBuffer(imageUri);
    const output = await this.tensorRunner.predictOutput(modelUri, inputBuffer);
    return {
      ok: output.length > 0,
      output: output,
      executionMs: Date.now() - startedAt
    };
  }
}

export class CustomModelSelectedFileRunner implements CustomModelTensorRunner {
  private readonly modelContentReader: FileUriContentReader;
  private readonly cachedModels: Map<string, mindSporeLite.Model> = new Map<string, mindSporeLite.Model>();

  constructor(options?: CustomModelSelectedFileRunnerOptions) {
    this.modelContentReader = options?.modelContentReader ?? new FileUriContentReader();
  }

  async predictOutput(modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    const model = await this.loadModel(modelUri);
    const inputs = model.getInputs();
    if (inputs.length === 0) {
      return [];
    }

    inputs[0].setData(inputBuffer);
    const outputs = await model.predict(inputs);
    if (outputs.length === 0) {
      return [];
    }

    return floatScoresFromOutputBuffer(outputs[0].getData());
  }

  private async loadModel(modelUri: string): Promise<mindSporeLite.Model> {
    const cachedModel = this.cachedModels.get(modelUri);
    if (cachedModel !== undefined) {
      return cachedModel;
    }

    const modelContent = await this.modelContentReader.readFileContent(modelUri);
    const modelBuffer = rawfileContentToArrayBuffer(modelContent);
    const model = await mindSporeLite.loadModelFromBuffer(modelBuffer, mindSporeLiteCpuContext());
    this.cachedModels.set(modelUri, model);
    return model;
  }
}

export function customModelDecodeOptions(): image.DecodingOptions {
  return {
    desiredSize: {
      width: customModelInputSize,
      height: customModelInputSize
    },
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

export function rgbUnitInputFromResizedRgba(rgba: Uint8Array): ArrayBuffer {
  const expectedLength = customModelInputSize * customModelInputSize * 4;
  if (rgba.length !== expectedLength) {
    throw new Error(`Expected ${expectedLength} RGBA bytes, got ${rgba.length}.`);
  }

  const input = new Float32Array(customModelInputFloatCount);
  let outputIndex = 0;
  for (let index = 0; index < rgba.length; index += 4) {
    input[outputIndex] = rgba[index] / 255;
    input[outputIndex + 1] = rgba[index + 1] / 255;
    input[outputIndex + 2] = rgba[index + 2] / 255;
    outputIndex += customModelInputChannels;
  }
  return input.buffer as ArrayBuffer;
}
