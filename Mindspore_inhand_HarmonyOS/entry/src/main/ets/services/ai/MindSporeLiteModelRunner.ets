import { mindSporeLite } from '@kit.MindSporeLiteKit';

export interface RawfileContentReader {
  getRawFileContent(path: string): Promise<Uint8Array>;
}

export interface MindSporeLiteModelRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
}

export class MindSporeLiteModelRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly modelRawfilePath: string;
  private cachedModel?: mindSporeLite.Model;

  constructor(options: MindSporeLiteModelRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.modelRawfilePath = options.modelRawfilePath;
  }

  async predictScoresFromInput(inputBuffer: ArrayBuffer): Promise<Array<number>> {
    const model = await this.loadModel();
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

  private async loadModel(): Promise<mindSporeLite.Model> {
    if (this.cachedModel) {
      return this.cachedModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.modelRawfilePath);
    const modelBuffer = rawfileContentToArrayBuffer(content);
    const model = await mindSporeLite.loadModelFromBuffer(modelBuffer);
    this.cachedModel = model;
    return model;
  }
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
