import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { imageCategoryLabelCount } from './ImageClassificationService';

export interface RawfileContentReader {
  getRawFileContent(path: string): Promise<Uint8Array>;
}

export type MindSporeLiteModelLoader = (
  buffer: ArrayBuffer,
  context: mindSporeLite.Context
) => Promise<mindSporeLite.Model>;

export interface MindSporeLiteModelRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
  readonly modelLoader?: MindSporeLiteModelLoader;
  readonly outputTensorDecoder?: (output: mindSporeLite.MSTensor) => Array<number>;
  readonly inputTensorValidator?: (input: mindSporeLite.MSTensor) => boolean;
}

export interface MindSporeLiteInputTensorContract {
  readonly dtype: mindSporeLite.DataType;
  readonly shape: Array<number>;
  readonly elementNum: number;
  readonly dataSize: number;
}

export const mindSporeLiteCpuThreadNum: number = 2;
export const imageClassificationOutputScoreCount: number = imageCategoryLabelCount + 1;

export function mindSporeLiteCpuContext(threadNum: number = mindSporeLiteCpuThreadNum): mindSporeLite.Context {
  return {
    target: ['cpu'],
    cpu: {
      threadNum: threadNum
    }
  };
}

export class MindSporeLiteModelRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly modelRawfilePath: string;
  private readonly modelLoader: MindSporeLiteModelLoader;
  private readonly outputTensorDecoder?: (output: mindSporeLite.MSTensor) => Array<number>;
  private readonly inputTensorValidator?: (input: mindSporeLite.MSTensor) => boolean;
  private cachedModel?: mindSporeLite.Model;
  private stopped: boolean = false;
  private generation: number = 0;

  constructor(options: MindSporeLiteModelRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.modelRawfilePath = options.modelRawfilePath;
    this.modelLoader = options.modelLoader ?? ((buffer: ArrayBuffer, context: mindSporeLite.Context) => {
      return mindSporeLite.loadModelFromBuffer(buffer, context);
    });
    this.outputTensorDecoder = options.outputTensorDecoder;
    this.inputTensorValidator = options.inputTensorValidator;
  }

  async predictScoresFromInput(inputBuffer: ArrayBuffer): Promise<Array<number>> {
    const generation = this.currentGeneration();
    const model = await this.loadModel(generation);
    this.ensureCurrent(generation);
    const inputs = model.getInputs();
    if (inputs.length === 0) {
      return [];
    }
    if (this.inputTensorValidator !== undefined && !this.inputTensorValidator(inputs[0])) {
      return [];
    }

    inputs[0].setData(inputBuffer);
    const outputs = await model.predict(inputs);
    this.ensureCurrent(generation);
    if (outputs.length === 0) {
      return [];
    }

    if (this.outputTensorDecoder !== undefined) {
      return this.outputTensorDecoder(outputs[0]);
    }
    return floatScoresFromOutputBuffer(outputs[0].getData());
  }

  async stop(): Promise<void> {
    // MindSpore Lite exposes no stable explicit model-release API on this target.
    this.stopped = true;
    this.generation++;
    this.cachedModel = undefined;
  }

  private currentGeneration(): number {
    this.ensureCurrent(this.generation);
    return this.generation;
  }

  private ensureCurrent(generation: number): void {
    if (this.stopped || generation !== this.generation) {
      throw new Error('MindSpore Lite model runner has stopped.');
    }
  }

  private async loadModel(generation: number): Promise<mindSporeLite.Model> {
    this.ensureCurrent(generation);
    if (this.cachedModel) {
      return this.cachedModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.modelRawfilePath);
    this.ensureCurrent(generation);
    const modelBuffer = rawfileContentToArrayBuffer(content);
    const model = await this.modelLoader(modelBuffer, mindSporeLiteCpuContext());
    this.ensureCurrent(generation);
    this.cachedModel = model;
    return model;
  }
}

export function mindSporeLiteInputTensorMatchesContract(
  input: mindSporeLite.MSTensor,
  contract: MindSporeLiteInputTensorContract
): boolean {
  if (input.dtype !== contract.dtype || input.elementNum !== contract.elementNum ||
    input.dataSize !== contract.dataSize || input.shape.length !== contract.shape.length) {
    return false;
  }
  for (let index = 0; index < contract.shape.length; index++) {
    if (input.shape[index] !== contract.shape[index]) {
      return false;
    }
  }
  return true;
}

export function rawfileContentToArrayBuffer(content: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(content.length);
  const copy = new Uint8Array(buffer);
  copy.set(content);
  return buffer;
}

export function floatScoresFromOutputBuffer(buffer: ArrayBuffer): Array<number> {
  const output = new Float32Array(buffer);
  const scores: Array<number> = [];
  for (let index = 0; index < output.length; index++) {
    scores.push(output[index]);
  }
  return scores;
}

export function imageClassificationScoresFromOutputTensor(output: mindSporeLite.MSTensor): Array<number> {
  if (output.dtype !== mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 ||
    output.elementNum !== imageClassificationOutputScoreCount ||
    output.dataSize !== imageClassificationOutputScoreCount * Float32Array.BYTES_PER_ELEMENT ||
    output.shape.length !== 2 || output.shape[0] !== 1 || output.shape[1] !== imageClassificationOutputScoreCount) {
    return [];
  }

  const rawScores = new Float32Array(output.getData());
  if (rawScores.length !== imageClassificationOutputScoreCount) {
    return [];
  }

  const decodedScores: Array<number> = [];
  for (let index = 1; index < rawScores.length; index++) {
    decodedScores.push(rawScores[index]);
  }
  return decodedScores;
}
