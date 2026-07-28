import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  CustomModelDataType,
  CustomModelPackageManifest,
  CustomModelTensorValue,
  decodeCustomModelOutput,
  encodeCustomModelText,
  parseCustomModelPackageManifest
} from './CustomModelPackage';
import { FileUriContentReader } from './FileUriContentReader';
import { mindSporeLiteCpuContext, rawfileContentToArrayBuffer } from './MindSporeLiteModelRunner';

export interface CustomModelPackageImagePreprocessor {
  createPackageInputBuffer(
    imageUri: string,
    manifest: CustomModelPackageManifest
  ): Promise<ArrayBuffer>;
}

export interface CustomModelPackageRunResult {
  readonly ok: boolean;
  readonly output: Array<number>;
  readonly displayText: string;
  readonly outputCount: number;
  readonly executionMs: number;
}

export class CustomModelPackageRunner {
  private operationTail: Promise<void> = Promise.resolve();
  private readonly imagePreprocessor: CustomModelPackageImagePreprocessor;

  constructor(imagePreprocessor: CustomModelPackageImagePreprocessor) {
    this.imagePreprocessor = imagePreprocessor;
  }

  run(modelPath: string, imageUri: string, text: string): Promise<CustomModelPackageRunResult> {
    const result = this.operationTail.then(async (): Promise<CustomModelPackageRunResult> =>
      await this.runExclusive(modelPath, imageUri, text));
    this.operationTail = result.then((): void => {}, (): void => {});
    return result;
  }

  private async runExclusive(
    modelPath: string,
    imageUri: string,
    text: string
  ): Promise<CustomModelPackageRunResult> {
    const startedAt = Date.now();
    const rootDir = parentPath(modelPath);
    const manifest: CustomModelPackageManifest = parseCustomModelPackageManifest(
      await fileIo.readText(joinPath(rootDir, 'manifest.json'))
    );
    const modelContent = await new FileUriContentReader().readFileContent(modelPath);
    const model = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(modelContent),
      mindSporeLiteCpuContext()
    );
    const buffers = await this.inputBuffers(rootDir, manifest, imageUri, text);
    const inputs = model.getInputs();
    for (let index = 0; index < inputs.length; index++) {
      const data = buffers.get(inputs[index].name);
      if (data === undefined || data.byteLength !== inputs[index].dataSize) {
        throw new Error(`Model input ${inputs[index].name} is missing or has the wrong size.`);
      }
      inputs[index].setData(data);
    }
    const outputs = await model.predict(inputs);
    const values: Array<CustomModelTensorValue> =
      outputs.map((tensor: mindSporeLite.MSTensor): CustomModelTensorValue => {
        return {
          name: tensor.name,
          dtype: dataType(tensor.dtype),
          shape: tensor.shape.slice(),
          data: tensor.getData()
        };
      });
    const labels = manifest.output.labels === undefined ? [] :
      labelsFromText(await fileIo.readText(joinPath(rootDir, manifest.output.labels.file)));
    const tokenizer = manifest.output.tokenizer ?? manifest.input.text?.tokenizer;
    const tokenizerTable = tokenizer === undefined ? '' :
      await fileIo.readText(joinPath(rootDir, tokenizer.file));
    const declaredOutput = values.find((value: CustomModelTensorValue): boolean =>
      value.name === manifest.output.tensor.name);
    if (declaredOutput === undefined) throw new Error('Declared model output is missing.');
    const flatOutput = tensorNumbers(declaredOutput);
    return {
      ok: true,
      output: flatOutput,
      displayText: decodeCustomModelOutput(manifest, values, labels, tokenizerTable),
      outputCount: flatOutput.length,
      executionMs: Date.now() - startedAt
    };
  }

  private async inputBuffers(
    rootDir: string,
    manifest: CustomModelPackageManifest,
    imageUri: string,
    text: string
  ): Promise<Map<string, ArrayBuffer>> {
    if (manifest.input.kind === 'image') {
      if (imageUri.length === 0) throw new Error('An image is required by this model.');
      const buffers = new Map<string, ArrayBuffer>();
      buffers.set(manifest.input.tensors[0].name,
        await this.imagePreprocessor.createPackageInputBuffer(imageUri, manifest));
      return buffers;
    }
    if (text.trim().length === 0 || manifest.input.text === undefined) {
      throw new Error('Text is required by this model.');
    }
    const table = await fileIo.readText(joinPath(rootDir, manifest.input.text.tokenizer.file));
    return encodeCustomModelText(text, table, manifest);
  }
}

function tensorNumbers(tensor: CustomModelTensorValue): Array<number> {
  if (tensor.dtype === 'FLOAT32') return Array.from(new Float32Array(tensor.data));
  if (tensor.dtype === 'INT32') return Array.from(new Int32Array(tensor.data));
  return Array.from(new Uint8Array(tensor.data));
}

function dataType(dtype: mindSporeLite.DataType): CustomModelDataType {
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32) return 'FLOAT32';
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_UINT8) return 'UINT8';
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_INT32) return 'INT32';
  throw new Error('Model output dtype is not supported.');
}

function labelsFromText(content: string): Array<string> {
  return content.split(/\r?\n/)
    .map((value: string): string => value.trim())
    .filter((value: string): boolean => value.length > 0);
}

function parentPath(path: string): string {
  const slash = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
  if (slash <= 0) throw new Error('Model package path is invalid.');
  return path.substring(0, slash);
}

function joinPath(parent: string, child: string): string {
  return `${parent.endsWith('/') || parent.endsWith('\\') ?
    parent.substring(0, parent.length - 1) : parent}/${child}`;
}
