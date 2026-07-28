import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { image } from '@kit.ImageKit';
import { FileUriContentReader } from './FileUriContentReader';
import {
  floatScoresFromOutputBuffer,
  MindSporeLiteModelRunner,
  mindSporeLiteCpuContext,
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';
import { CustomModelPackageRunner } from './CustomModelPackageRunner';

export const customModelInputSize: number = 224;
export const customModelInputChannels: number = 3;
export const customModelInputFloatCount: number =
  customModelInputSize * customModelInputSize * customModelInputChannels;
export const customModelInputByteCount: number =
  customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT;
export const customModelMaxOutputElementCount: number = 262144;
export const customModelMaxOutputByteCount: number =
  customModelMaxOutputElementCount * Float32Array.BYTES_PER_ELEMENT;
export const customModelDefaultModelUri: string = 'rawfile://model/mobilenetv2.ms';

export interface CustomModelRunResult {
  readonly ok: boolean;
  readonly output: Array<number>;
  readonly displayText?: string;
  readonly outputCount?: number;
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
  readonly runtime?: CustomModelBufferRuntime;
}

export interface CustomModelBufferRuntime {
  run(modelContent: Uint8Array, inputBuffer: ArrayBuffer): Promise<Array<number>>;
}

export interface CustomModelRawfileRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
}

export interface CustomModelDefaultOrSelectedRunnerOptions {
  readonly defaultModelRunner: CustomModelTensorRunner;
  readonly selectedModelRunner?: CustomModelTensorRunner;
  readonly defaultModelUri?: string;
}

export interface CustomModelServiceOptions {
  readonly preprocessor: CustomModelInputPreprocessor;
  readonly tensorRunner: CustomModelTensorRunner;
  readonly packageRunner?: CustomModelPackageRunner;
}

export class CustomModelService {
  private readonly runner: CustomModelMindSporeRunner;
  private readonly packageRunner?: CustomModelPackageRunner;

  constructor(options: CustomModelServiceOptions) {
    this.runner = new CustomModelMindSporeRunner(options);
    this.packageRunner = options.packageRunner;
  }

  async run(modelUri: string, imageUri: string): Promise<CustomModelRunResult> {
    return this.runner.run(modelUri, imageUri);
  }

  async runPackage(modelUri: string, imageUri: string, text: string): Promise<CustomModelRunResult> {
    if (this.packageRunner === undefined) {
      throw new Error('Custom model package runtime is unavailable.');
    }
    return this.packageRunner.run(modelUri, imageUri, text);
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
    if (inputBuffer.byteLength !== customModelInputByteCount) {
      return {
        ok: false,
        output: [],
        executionMs: Date.now() - startedAt
      };
    }
    const output = await this.tensorRunner.predictOutput(modelUri, inputBuffer);
    const validOutput = customModelOutputValuesAreValid(output) ? output : [];
    return {
      ok: validOutput.length > 0,
      output: validOutput,
      executionMs: Date.now() - startedAt
    };
  }
}

class MindSporeLiteCustomModelBufferRuntime implements CustomModelBufferRuntime {
  async run(modelContent: Uint8Array, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    if (inputBuffer.byteLength !== customModelInputByteCount) {
      return [];
    }
    const model = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(modelContent),
      mindSporeLiteCpuContext()
    );
    const inputs = model.getInputs();
    if (!customModelInputTensorsCompatible(inputs)) {
      return [];
    }
    inputs[0].setData(inputBuffer);
    const outputs = await model.predict(inputs);
    if (outputs.length === 0) {
      return [];
    }
    return customModelOutputValues(outputs[0]);
  }
}

class CustomModelRuntimeState {
  operationTail: Promise<void> = Promise.resolve();
}

const nativeCustomModelBufferRuntime: CustomModelBufferRuntime = new MindSporeLiteCustomModelBufferRuntime();
const customModelRuntimeStates: Map<CustomModelBufferRuntime, CustomModelRuntimeState> = new Map();

function customModelRuntimeState(runtime: CustomModelBufferRuntime): CustomModelRuntimeState {
  const existing = customModelRuntimeStates.get(runtime);
  if (existing !== undefined) {
    return existing;
  }
  const state = new CustomModelRuntimeState();
  customModelRuntimeStates.set(runtime, state);
  return state;
}

export class CustomModelSelectedFileRunner implements CustomModelTensorRunner {
  private readonly modelContentReader: FileUriContentReader;
  private readonly runtime: CustomModelBufferRuntime;
  private readonly runtimeState: CustomModelRuntimeState;

  constructor(options?: CustomModelSelectedFileRunnerOptions) {
    this.modelContentReader = options?.modelContentReader ?? new FileUriContentReader();
    this.runtime = options?.runtime ?? nativeCustomModelBufferRuntime;
    this.runtimeState = customModelRuntimeState(this.runtime);
  }

  predictOutput(modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    const result = this.runtimeState.operationTail.then(async (): Promise<Array<number>> => {
      const modelContent = await this.modelContentReader.readFileContent(modelUri);
      return await this.runtime.run(modelContent, inputBuffer);
    });
    this.runtimeState.operationTail = result.then((): void => {}, (): void => {});
    return result;
  }
}

export async function validateCustomModelContent(content: Uint8Array): Promise<boolean> {
  const state = customModelRuntimeState(nativeCustomModelBufferRuntime);
  const result = state.operationTail.then(async (): Promise<Array<number>> =>
    await nativeCustomModelBufferRuntime.run(content, customModelProbeInputBuffer()));
  state.operationTail = result.then((): void => {}, (): void => {});
  try {
    const output = await result;
    return customModelOutputValuesAreValid(output);
  } catch (_) {
    return false;
  }
}

export function customModelOutputCanDecode(
  dtype: mindSporeLite.DataType,
  data: ArrayBuffer,
  elementNum: number = data.byteLength / Float32Array.BYTES_PER_ELEMENT,
  dataSize: number = data.byteLength
): boolean {
  if (!customModelOutputBufferContractValid(dtype, data, elementNum, dataSize)) {
    return false;
  }
  return customModelOutputValuesAreValid(floatScoresFromOutputBuffer(data));
}

function customModelOutputBufferContractValid(
  dtype: mindSporeLite.DataType,
  data: ArrayBuffer,
  elementNum: number,
  dataSize: number
): boolean {
  if (dtype !== mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 ||
    data.byteLength <= 0 || data.byteLength > customModelMaxOutputByteCount ||
    data.byteLength % Float32Array.BYTES_PER_ELEMENT !== 0 ||
    dataSize !== data.byteLength ||
    elementNum <= 0 || elementNum > customModelMaxOutputElementCount ||
    elementNum * Float32Array.BYTES_PER_ELEMENT !== dataSize) {
    return false;
  }
  return true;
}

export function customModelOutputValuesAreValid(output: Array<number>): boolean {
  if (output.length <= 0 || output.length > customModelMaxOutputElementCount) {
    return false;
  }
  for (let index = 0; index < output.length; index++) {
    if (!Number.isFinite(output[index])) {
      return false;
    }
  }
  return true;
}

function customModelInputTensorsCompatible(inputs: Array<mindSporeLite.MSTensor>): boolean {
  if (inputs.length !== 1) {
    return false;
  }
  const input = inputs[0];
  return input.shape.length === 4 &&
    input.shape[0] === 1 &&
    input.shape[1] === customModelInputSize &&
    input.shape[2] === customModelInputSize &&
    input.shape[3] === customModelInputChannels &&
    input.dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 &&
    input.format === mindSporeLite.Format.NHWC &&
    input.elementNum === customModelInputFloatCount &&
    input.dataSize === customModelInputByteCount;
}

function customModelOutputValues(output: mindSporeLite.MSTensor): Array<number> {
  return customModelOutputValuesFromMetadata(
    output.dtype,
    output.elementNum,
    output.dataSize,
    output.shape,
    (): ArrayBuffer => output.getData()
  );
}

export function customModelOutputValuesFromMetadata(
  dtype: mindSporeLite.DataType,
  elementNum: number,
  dataSize: number,
  shape: Array<number>,
  readData: () => ArrayBuffer
): Array<number> {
  if (!customModelOutputMetadataCanDecode(dtype, elementNum, dataSize, shape)) {
    return [];
  }
  const data = readData();
  if (!customModelOutputBufferContractValid(dtype, data, elementNum, dataSize)) {
    return [];
  }
  const values = floatScoresFromOutputBuffer(data);
  return customModelOutputValuesAreValid(values) ? values : [];
}

export function customModelOutputMetadataCanDecode(
  dtype: mindSporeLite.DataType,
  elementNum: number,
  dataSize: number,
  shape: Array<number>
): boolean {
  return dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 &&
    elementNum > 0 && elementNum <= customModelMaxOutputElementCount &&
    dataSize > 0 && dataSize <= customModelMaxOutputByteCount &&
    dataSize % Float32Array.BYTES_PER_ELEMENT === 0 &&
    dataSize === elementNum * Float32Array.BYTES_PER_ELEMENT &&
    customModelOutputShapeIsCoherent(shape, elementNum);
}

function customModelOutputShapeIsCoherent(shape: Array<number>, elementNum: number): boolean {
  if (shape.length === 0) {
    return false;
  }
  let product = 1;
  for (let index = 0; index < shape.length; index++) {
    const dimension = shape[index];
    if (dimension <= 0 || product > customModelMaxOutputElementCount / dimension) {
      return false;
    }
    product *= dimension;
  }
  return product === elementNum;
}

function customModelProbeInputBuffer(): ArrayBuffer {
  const probe = new Float32Array(customModelInputFloatCount);
  for (let index = 0; index < probe.length; index++) {
    probe[index] = ((index * 37) % 256) / 255;
  }
  return probe.buffer as ArrayBuffer;
}

export class CustomModelRawfileRunner implements CustomModelTensorRunner {
  private readonly runner: MindSporeLiteModelRunner;

  constructor(options: CustomModelRawfileRunnerOptions) {
    this.runner = new MindSporeLiteModelRunner({
      resourceManager: options.resourceManager,
      modelRawfilePath: options.modelRawfilePath
    });
  }

  async predictOutput(_modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    return this.runner.predictScoresFromInput(inputBuffer);
  }
}

export class CustomModelDefaultOrSelectedRunner implements CustomModelTensorRunner {
  private readonly defaultModelRunner: CustomModelTensorRunner;
  private readonly selectedModelRunner: CustomModelTensorRunner;
  private readonly defaultModelUri: string;

  constructor(options: CustomModelDefaultOrSelectedRunnerOptions) {
    this.defaultModelRunner = options.defaultModelRunner;
    this.selectedModelRunner = options.selectedModelRunner ?? new CustomModelSelectedFileRunner();
    this.defaultModelUri = options.defaultModelUri ?? customModelDefaultModelUri;
  }

  async predictOutput(modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    if (modelUri === this.defaultModelUri) {
      return this.defaultModelRunner.predictOutput(this.defaultModelUri, inputBuffer);
    }
    return this.selectedModelRunner.predictOutput(modelUri, inputBuffer);
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
