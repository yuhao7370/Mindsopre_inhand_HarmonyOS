import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  mindSporeLiteCpuContext,
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';
import { FileUriContentReader } from './FileUriContentReader';

export const stylePredictModelRawfilePath: string = 'model/style_predict_quant.ms';
export const styleTransferModelRawfilePath: string = 'model/style_transfer_quant.ms';
export const stylePredictModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms';
export const styleTransferModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms';
export const styleTransferStyleImageSize: number = 256;
export const styleTransferContentImageSize: number = 384;
export const styleTransferMaxOutputImageSize: number = 1024;
export const styleTransferChannels: number = 3;
export const styleTransferMindSporeCpuThreadNum: number = 4;
export const styleTransferOutputFloatCount: number =
  styleTransferContentImageSize * styleTransferContentImageSize * styleTransferChannels;
export const builtInStyleTransferStyleCount: number = 21;
export const builtInStyleTransferRawfileUriPrefix: string = 'rawfile://';

export interface BuiltInStyleTransferStyle {
  readonly id: number;
  readonly rawfilePath: string;
}

export const builtInStyleTransferStyles: Array<BuiltInStyleTransferStyle> = [
  { id: 0, rawfilePath: 'styletransfer/style0.jpg' },
  { id: 1, rawfilePath: 'styletransfer/style1.jpg' },
  { id: 2, rawfilePath: 'styletransfer/style2.jpg' },
  { id: 3, rawfilePath: 'styletransfer/style3.jpg' },
  { id: 4, rawfilePath: 'styletransfer/style4.jpg' },
  { id: 5, rawfilePath: 'styletransfer/style5.jpg' },
  { id: 6, rawfilePath: 'styletransfer/style6.jpg' },
  { id: 7, rawfilePath: 'styletransfer/style7.jpg' },
  { id: 8, rawfilePath: 'styletransfer/style8.jpg' },
  { id: 9, rawfilePath: 'styletransfer/style9.jpg' },
  { id: 10, rawfilePath: 'styletransfer/style10.jpg' },
  { id: 11, rawfilePath: 'styletransfer/style11.jpg' },
  { id: 12, rawfilePath: 'styletransfer/style12.jpg' },
  { id: 13, rawfilePath: 'styletransfer/style13.jpg' },
  { id: 14, rawfilePath: 'styletransfer/style14.jpg' },
  { id: 15, rawfilePath: 'styletransfer/style15.jpg' },
  { id: 16, rawfilePath: 'styletransfer/style16.jpg' },
  { id: 17, rawfilePath: 'styletransfer/style17.jpg' },
  { id: 18, rawfilePath: 'styletransfer/style18.jpg' },
  { id: 19, rawfilePath: 'styletransfer/style19.jpg' },
  { id: 20, rawfilePath: 'styletransfer/style20.jpg' }
];

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
  readonly contentImageWidth?: number;
  readonly contentImageHeight?: number;
}

export interface StyleTransferImageSize {
  readonly width: number;
  readonly height: number;
}

export interface StyleTransferModelUris {
  readonly predictModelUri?: string;
  readonly transferModelUri?: string;
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
  runStyleTransfer(input: StyleTransferInput, modelUris?: StyleTransferModelUris): Promise<StyleTransferTensorOutput>;
}

export interface StyleTransferOutputImageResizer {
  resize(
    rgba: ArrayBuffer,
    sourceWidth: number,
    sourceHeight: number,
    targetWidth: number,
    targetHeight: number
  ): Promise<ArrayBuffer>;
}

export interface StyleTransferRunner {
  run(
    contentImageUri: string,
    styleImageUri: string,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferResult>;
}

export function builtInStyleTransferUri(style: BuiltInStyleTransferStyle): string {
  return `${builtInStyleTransferRawfileUriPrefix}${style.rawfilePath}`;
}

export function builtInStyleTransferMediaName(style: BuiltInStyleTransferStyle): string {
  return `style${style.id}`;
}

export function rawfilePathFromBuiltInStyleTransferUri(uri: string): string {
  if (!uri.startsWith(builtInStyleTransferRawfileUriPrefix)) {
    return '';
  }
  return uri.substring(builtInStyleTransferRawfileUriPrefix.length);
}

export interface StyleTransferMindSporeRunnerOptions {
  readonly preprocessor: StyleTransferInputPreprocessor;
  readonly tensorRunner: StyleTransferTensorRunner;
  readonly outputImageResizer?: StyleTransferOutputImageResizer;
}

export class StyleTransferMindSporeRunner implements StyleTransferRunner {
  private readonly preprocessor: StyleTransferInputPreprocessor;
  private readonly tensorRunner: StyleTransferTensorRunner;
  private readonly outputImageResizer: StyleTransferOutputImageResizer;

  constructor(options: StyleTransferMindSporeRunnerOptions) {
    this.preprocessor = options.preprocessor;
    this.tensorRunner = options.tensorRunner;
    this.outputImageResizer = options.outputImageResizer ?? new ImageKitStyleTransferOutputImageResizer();
  }

  async run(
    contentImageUri: string,
    styleImageUri: string,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferResult> {
    const startedAt = Date.now();
    const input = await this.preprocessor.createInput(contentImageUri, styleImageUri);
    const output = await this.tensorRunner.runStyleTransfer(input, modelUris);
    const modelOutputImageRgba = output.output.length >= styleTransferOutputFloatCount ?
      styleTransferRgbaOutputFromFloatOutput(
        output.output,
        styleTransferContentImageSize,
        styleTransferContentImageSize
      ) : new ArrayBuffer(0);
    const outputImageSize = styleTransferOutputImageSizeForContent(
      input.contentImageWidth,
      input.contentImageHeight
    );
    const outputImageRgba = modelOutputImageRgba.byteLength > 0 ?
      await this.outputImageResizer.resize(
        modelOutputImageRgba,
        styleTransferContentImageSize,
        styleTransferContentImageSize,
        outputImageSize.width,
        outputImageSize.height
      ) : modelOutputImageRgba;
    return {
      ok: outputImageRgba.byteLength > 0,
      outputFloatCount: output.output.length,
      outputImageRgba: outputImageRgba,
      outputImageWidth: outputImageSize.width,
      outputImageHeight: outputImageSize.height,
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
  readonly modelFileReader?: FileUriContentReader;
}

export class MindSporeLiteStyleTransferTensorRunner implements StyleTransferTensorRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly predictModelRawfilePath: string;
  private readonly transferModelRawfilePath: string;
  private readonly modelFileReader: FileUriContentReader;
  private cachedPredictModel?: mindSporeLite.Model;
  private cachedTransferModel?: mindSporeLite.Model;
  private cachedPredictModelUri: string = '';
  private cachedSelectedPredictModel?: mindSporeLite.Model;
  private cachedTransferModelUri: string = '';
  private cachedSelectedTransferModel?: mindSporeLite.Model;

  constructor(options: MindSporeLiteStyleTransferTensorRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.predictModelRawfilePath = options.predictModelRawfilePath;
    this.transferModelRawfilePath = options.transferModelRawfilePath;
    this.modelFileReader = options.modelFileReader ?? new FileUriContentReader();
  }

  async runStyleTransfer(
    input: StyleTransferInput,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferTensorOutput> {
    const predictStartedAt = Date.now();
    const styleVector = await this.predictStyleVector(input.styleInputBuffer, modelUris?.predictModelUri ?? '');
    const predictMs = Date.now() - predictStartedAt;

    const transferStartedAt = Date.now();
    const output = await this.transferStyle(
      styleVector.buffer as ArrayBuffer,
      input.contentInputBuffer,
      modelUris?.transferModelUri ?? ''
    );
    const transferMs = Date.now() - transferStartedAt;

    return {
      output: output,
      predictMs: predictMs,
      transferMs: transferMs
    };
  }

  private async predictStyleVector(styleInputBuffer: ArrayBuffer, modelUri: string): Promise<Float32Array> {
    const model = await this.loadPredictModel(modelUri);
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

  private async transferStyle(
    styleVectorBuffer: ArrayBuffer,
    contentInputBuffer: ArrayBuffer,
    modelUri: string
  ): Promise<Float32Array> {
    const model = await this.loadTransferModel(modelUri);
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

  private async loadPredictModel(modelUri: string): Promise<mindSporeLite.Model> {
    if (modelUri.length > 0) {
      if (this.cachedSelectedPredictModel !== undefined && this.cachedPredictModelUri === modelUri) {
        return this.cachedSelectedPredictModel;
      }
      const content = await this.modelFileReader.readFileContent(modelUri);
      const model = await mindSporeLite.loadModelFromBuffer(
        rawfileContentToArrayBuffer(content),
        mindSporeLiteCpuContext(styleTransferMindSporeCpuThreadNum)
      );
      this.cachedPredictModelUri = modelUri;
      this.cachedSelectedPredictModel = model;
      return model;
    }
    if (this.cachedPredictModel !== undefined) {
      return this.cachedPredictModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.predictModelRawfilePath);
    const model = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(content),
      mindSporeLiteCpuContext(styleTransferMindSporeCpuThreadNum)
    );
    this.cachedPredictModel = model;
    return model;
  }

  private async loadTransferModel(modelUri: string): Promise<mindSporeLite.Model> {
    if (modelUri.length > 0) {
      if (this.cachedSelectedTransferModel !== undefined && this.cachedTransferModelUri === modelUri) {
        return this.cachedSelectedTransferModel;
      }
      const content = await this.modelFileReader.readFileContent(modelUri);
      const model = await mindSporeLite.loadModelFromBuffer(
        rawfileContentToArrayBuffer(content),
        mindSporeLiteCpuContext(styleTransferMindSporeCpuThreadNum)
      );
      this.cachedTransferModelUri = modelUri;
      this.cachedSelectedTransferModel = model;
      return model;
    }
    if (this.cachedTransferModel !== undefined) {
      return this.cachedTransferModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.transferModelRawfilePath);
    const model = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(content),
      mindSporeLiteCpuContext(styleTransferMindSporeCpuThreadNum)
    );
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

  async run(
    contentImageUri: string,
    styleImageUri: string,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferResult> {
    if (this.runner === undefined) {
      return emptyStyleTransferResult();
    }
    try {
      return await this.runner.run(contentImageUri, styleImageUri, modelUris);
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

export class ImageKitStyleTransferOutputImageResizer implements StyleTransferOutputImageResizer {
  async resize(
    rgba: ArrayBuffer,
    sourceWidth: number,
    sourceHeight: number,
    targetWidth: number,
    targetHeight: number
  ): Promise<ArrayBuffer> {
    if (!validStyleTransferImageSize(sourceWidth) || !validStyleTransferImageSize(sourceHeight) ||
      !validStyleTransferImageSize(targetWidth) || !validStyleTransferImageSize(targetHeight)) {
      return new ArrayBuffer(0);
    }
    if (sourceWidth === targetWidth && sourceHeight === targetHeight) {
      return rgba;
    }

    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await styleTransferPixelMapFromRgbaOutput(rgba, sourceWidth, sourceHeight);
      await pixelMap.scale(
        targetWidth / sourceWidth,
        targetHeight / sourceHeight,
        image.AntiAliasingLevel.LOW
      );
      const scaledRgba = new ArrayBuffer(targetWidth * targetHeight * 4);
      await pixelMap.readPixelsToBuffer(scaledRgba);
      return scaledRgba;
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
    }
  }
}

export function styleTransferOutputImageSizeForContent(
  contentWidth?: number,
  contentHeight?: number
): StyleTransferImageSize {
  if (!validStyleTransferImageSize(contentWidth) || !validStyleTransferImageSize(contentHeight)) {
    return {
      width: styleTransferContentImageSize,
      height: styleTransferContentImageSize
    };
  }

  const width: number = contentWidth!;
  const height: number = contentHeight!;
  const largerSide = Math.max(width, height);
  if (largerSide <= styleTransferMaxOutputImageSize) {
    return {
      width: width,
      height: height
    };
  }

  const scale = styleTransferMaxOutputImageSize / largerSide;
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale))
  };
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

function validStyleTransferImageSize(size: number | undefined): boolean {
  return size !== undefined && size > 0 && Math.trunc(size) === size;
}

function styleTransferOutputByte(value: number): number {
  const scaled = Math.trunc(value * 255);
  return Math.min(255, Math.max(0, scaled));
}
