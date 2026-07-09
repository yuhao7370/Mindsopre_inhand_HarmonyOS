import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';

export const stylePredictModelRawfilePath: string = 'model/style_predict_quant.ms';
export const styleTransferModelRawfilePath: string = 'model/style_transfer_quant.ms';
export const stylePredictModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms';
export const styleTransferModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms';
export const styleTransferStyleImageSize: number = 256;
export const styleTransferContentImageSize: number = 384;
export const styleTransferChannels: number = 3;
export const styleTransferOutputFloatCount: number =
  styleTransferContentImageSize * styleTransferContentImageSize * styleTransferChannels;

export interface StyleTransferResult {
  readonly ok: boolean;
  readonly outputFloatCount: number;
  readonly outputImageRgba?: ArrayBuffer;
  readonly outputImageWidth?: number;
  readonly outputImageHeight?: number;
  readonly predictMs: number;
  readonly transferMs: number;
  readonly executionMs: number;
}

export interface StyleTransferInput {
  readonly contentInputBuffer: ArrayBuffer;
  readonly styleInputBuffer: ArrayBuffer;
}

export interface StyleTransferInputPreprocessor {
  createInput(contentImageUri: string, styleImageUri: string): Promise<StyleTransferInput>;
}

export interface StyleTransferTensorOutput {
  readonly output: Float32Array;
  readonly predictMs: number;
  readonly transferMs: number;
}

export interface StyleTransferTensorRunner {
  runStyleTransfer(input: StyleTransferInput): Promise<StyleTransferTensorOutput>;
}

export interface StyleTransferRunner {
  run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult>;
}

export interface StyleTransferMindSporeRunnerOptions {
  readonly preprocessor: StyleTransferInputPreprocessor;
  readonly tensorRunner: StyleTransferTensorRunner;
}

export class StyleTransferMindSporeRunner implements StyleTransferRunner {
  private readonly preprocessor: StyleTransferInputPreprocessor;
  private readonly tensorRunner: StyleTransferTensorRunner;

  constructor(options: StyleTransferMindSporeRunnerOptions) {
    this.preprocessor = options.preprocessor;
    this.tensorRunner = options.tensorRunner;
  }

  async run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult> {
    const startedAt = Date.now();
    const input = await this.preprocessor.createInput(contentImageUri, styleImageUri);
    const output = await this.tensorRunner.runStyleTransfer(input);
    const outputImageRgba = output.output.length >= styleTransferOutputFloatCount ?
      styleTransferRgbaOutputFromFloatOutput(
        output.output,
        styleTransferContentImageSize,
        styleTransferContentImageSize
      ) : new ArrayBuffer(0);
    return {
      ok: outputImageRgba.byteLength > 0,
      outputFloatCount: output.output.length,
      outputImageRgba: outputImageRgba,
      outputImageWidth: styleTransferContentImageSize,
      outputImageHeight: styleTransferContentImageSize,
      predictMs: output.predictMs,
      transferMs: output.transferMs,
      executionMs: Date.now() - startedAt
    };
  }
}

export interface MindSporeLiteStyleTransferTensorRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly predictModelRawfilePath: string;
  readonly transferModelRawfilePath: string;
}

export class MindSporeLiteStyleTransferTensorRunner implements StyleTransferTensorRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly predictModelRawfilePath: string;
  private readonly transferModelRawfilePath: string;
  private cachedPredictModel?: mindSporeLite.Model;
  private cachedTransferModel?: mindSporeLite.Model;

  constructor(options: MindSporeLiteStyleTransferTensorRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.predictModelRawfilePath = options.predictModelRawfilePath;
    this.transferModelRawfilePath = options.transferModelRawfilePath;
  }

  async runStyleTransfer(input: StyleTransferInput): Promise<StyleTransferTensorOutput> {
    const predictStartedAt = Date.now();
    const styleVector = await this.predictStyleVector(input.styleInputBuffer);
    const predictMs = Date.now() - predictStartedAt;

    const transferStartedAt = Date.now();
    const output = await this.transferStyle(styleVector.buffer as ArrayBuffer, input.contentInputBuffer);
    const transferMs = Date.now() - transferStartedAt;

    return {
      output: output,
      predictMs: predictMs,
      transferMs: transferMs
    };
  }

  private async predictStyleVector(styleInputBuffer: ArrayBuffer): Promise<Float32Array> {
    const model = await this.loadPredictModel();
    const inputs = model.getInputs();
    if (inputs.length === 0) {
      return new Float32Array(0);
    }

    inputs[0].setData(styleInputBuffer);
    const outputs = await model.predict(inputs);
    if (outputs.length === 0) {
      return new Float32Array(0);
    }
    return new Float32Array(outputs[0].getData());
  }

  private async transferStyle(styleVectorBuffer: ArrayBuffer, contentInputBuffer: ArrayBuffer): Promise<Float32Array> {
    const model = await this.loadTransferModel();
    const inputs = model.getInputs();
    if (inputs.length < 2 || styleVectorBuffer.byteLength === 0) {
      return new Float32Array(0);
    }

    inputs[0].setData(styleVectorBuffer);
    inputs[1].setData(contentInputBuffer);
    const outputs = await model.predict(inputs);
    if (outputs.length === 0) {
      return new Float32Array(0);
    }
    return new Float32Array(outputs[0].getData());
  }

  private async loadPredictModel(): Promise<mindSporeLite.Model> {
    if (this.cachedPredictModel !== undefined) {
      return this.cachedPredictModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.predictModelRawfilePath);
    const model = await mindSporeLite.loadModelFromBuffer(rawfileContentToArrayBuffer(content));
    this.cachedPredictModel = model;
    return model;
  }

  private async loadTransferModel(): Promise<mindSporeLite.Model> {
    if (this.cachedTransferModel !== undefined) {
      return this.cachedTransferModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.transferModelRawfilePath);
    const model = await mindSporeLite.loadModelFromBuffer(rawfileContentToArrayBuffer(content));
    this.cachedTransferModel = model;
    return model;
  }
}

export interface StyleTransferServiceOptions {
  readonly runner?: StyleTransferRunner;
}

export class StyleTransferService {
  private readonly runner?: StyleTransferRunner;

  constructor(options: StyleTransferServiceOptions) {
    this.runner = options.runner;
  }

  async run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult> {
    if (this.runner === undefined) {
      return emptyStyleTransferResult();
    }
    try {
      return await this.runner.run(contentImageUri, styleImageUri);
    } catch (_) {
      return emptyStyleTransferResult();
    }
  }
}

function emptyStyleTransferResult(): StyleTransferResult {
  return {
    ok: false,
    outputFloatCount: 0,
    predictMs: 0,
    transferMs: 0,
    executionMs: 0
  };
}

export function styleTransferDecodeOptions(size: number): image.DecodingOptions {
  return {
    desiredSize: {
      width: size,
      height: size
    },
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

export function styleTransferPixelMapOptions(width: number, height: number): image.InitializationOptions {
  return {
    size: {
      width: width,
      height: height
    },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

export async function styleTransferPixelMapFromRgbaOutput(
  rgba: ArrayBuffer,
  width: number,
  height: number
): Promise<image.PixelMap> {
  return image.createPixelMap(rgba, styleTransferPixelMapOptions(width, height));
}

export function styleTransferRgbUnitInputFromRgba(rgba: Uint8Array, size: number): ArrayBuffer {
  const expectedLength = size * size * 4;
  if (rgba.length !== expectedLength) {
    throw new Error(`Expected ${expectedLength} RGBA bytes, got ${rgba.length}.`);
  }

  const input = new Float32Array(size * size * styleTransferChannels);
  let outputIndex = 0;
  for (let index = 0; index < rgba.length; index += 4) {
    input[outputIndex] = rgba[index] / 255;
    input[outputIndex + 1] = rgba[index + 1] / 255;
    input[outputIndex + 2] = rgba[index + 2] / 255;
    outputIndex += styleTransferChannels;
  }
  return input.buffer as ArrayBuffer;
}

export function styleTransferRgbaOutputFromFloatOutput(
  output: Float32Array,
  width: number,
  height: number
): ArrayBuffer {
  const pixelCount = width * height;
  const expectedLength = pixelCount * styleTransferChannels;
  if (output.length < expectedLength) {
    throw new Error(`Expected at least ${expectedLength} style output floats, got ${output.length}.`);
  }

  const rgba = new Uint8Array(pixelCount * 4);
  for (let pixelIndex = 0; pixelIndex < pixelCount; pixelIndex++) {
    const sourceIndex = pixelIndex * styleTransferChannels;
    const targetIndex = pixelIndex * 4;
    rgba[targetIndex] = styleTransferOutputByte(output[sourceIndex]);
    rgba[targetIndex + 1] = styleTransferOutputByte(output[sourceIndex + 1]);
    rgba[targetIndex + 2] = styleTransferOutputByte(output[sourceIndex + 2]);
    rgba[targetIndex + 3] = 255;
  }
  return rgba.buffer as ArrayBuffer;
}

function styleTransferOutputByte(value: number): number {
  const scaled = Math.trunc(value * 255);
  return Math.min(255, Math.max(0, scaled));
}
