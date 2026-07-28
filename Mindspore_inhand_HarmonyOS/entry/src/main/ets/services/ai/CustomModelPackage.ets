import {
  decodePortableTokenizerText,
  encodePortableTokenizerText,
  PortableTokenizerEncoding
} from './TinyTranslationTokenizer';

export type CustomModelInputKind = 'image' | 'text';
export type CustomModelOutputKind = 'classification' | 'text' | 'raw';
export type CustomModelDataType = 'FLOAT32' | 'UINT8' | 'INT32';
export type CustomModelTensorFormat = 'NHWC' | 'NCHW' | '';

export interface CustomModelAssetRef {
  readonly file: string;
  readonly sha256: string;
}

export interface CustomModelTensorContract {
  readonly name: string;
  readonly dtype: CustomModelDataType;
  readonly shape: Array<number>;
  readonly format?: CustomModelTensorFormat;
}

export interface CustomModelImageInput {
  readonly width: number;
  readonly height: number;
  readonly layout: 'NHWC' | 'NCHW';
  readonly color: 'RGB' | 'BGR';
  readonly resize: 'fit' | 'fill';
  readonly mean: Array<number>;
  readonly std: Array<number>;
}

export interface CustomModelTextInput {
  readonly tokenizer: CustomModelAssetRef;
  readonly maxTokens: number;
  readonly padId: number;
  readonly unkId: number;
  readonly bosId: number;
  readonly eosId: number;
  readonly inputIdsTensor: string;
  readonly attentionMaskTensor?: string;
}

export interface CustomModelInputContract {
  readonly kind: CustomModelInputKind;
  readonly tensors: Array<CustomModelTensorContract>;
  readonly image?: CustomModelImageInput;
  readonly text?: CustomModelTextInput;
}

export interface CustomModelOutputContract {
  readonly kind: CustomModelOutputKind;
  readonly tensor: CustomModelTensorContract;
  readonly labels?: CustomModelAssetRef;
  readonly tokenizer?: CustomModelAssetRef;
  readonly topK?: number;
}

export interface CustomModelPackageManifest {
  readonly version: number;
  readonly name: string;
  readonly model: CustomModelAssetRef;
  readonly input: CustomModelInputContract;
  readonly output: CustomModelOutputContract;
}

interface CustomModelPackageManifestWire {
  readonly version: number;
  readonly name: string;
  readonly model: CustomModelAssetRef;
  readonly input: CustomModelInputContract;
  readonly output: CustomModelOutputContract;
}

export interface CustomModelTensorMetadata {
  readonly name: string;
  readonly dtype: CustomModelDataType;
  readonly shape: Array<number>;
  readonly format: CustomModelTensorFormat;
  readonly elementNum: number;
  readonly dataSize: number;
}

export interface CustomModelTensorValue {
  readonly name: string;
  readonly dtype: CustomModelDataType;
  readonly shape: Array<number>;
  readonly data: ArrayBuffer;
}

export const customModelPackageMaxZipBytes: number = 256 * 1024 * 1024;
export const customModelPackageMaxExtractedBytes: number = 512 * 1024 * 1024;
export const customModelPackageMaxTextLogitsBytes: number = 32 * 1024 * 1024;

const SHA256_PATTERN: RegExp = /^[0-9a-f]{64}$/;

export function parseCustomModelPackageManifest(content: string): CustomModelPackageManifest {
  let manifest: CustomModelPackageManifestWire;
  try {
    manifest = JSON.parse(content) as CustomModelPackageManifestWire;
  } catch (_) {
    throw new Error('Model package manifest is not valid JSON.');
  }
  requireExactKeys(manifest, ['version', 'name', 'model', 'input', 'output'], '$');
  requireInteger(manifest.version, 1, '$.version');
  requireNonEmptyString(manifest.name, '$.name');
  validateAsset(manifest.model, '$.model');
  validateInput(manifest.input);
  validateOutput(manifest.output, manifest.input);
  return manifest;
}

export function customModelDeclaredFiles(manifest: CustomModelPackageManifest): Array<string> {
  const files: Array<string> = ['manifest.json', manifest.model.file];
  if (manifest.input.text !== undefined) {
    pushUnique(files, manifest.input.text.tokenizer.file);
  }
  if (manifest.output.labels !== undefined) {
    pushUnique(files, manifest.output.labels.file);
  }
  if (manifest.output.tokenizer !== undefined) {
    pushUnique(files, manifest.output.tokenizer.file);
  }
  return files;
}

export function validateCustomModelTensorContract(
  manifest: CustomModelPackageManifest,
  inputs: Array<CustomModelTensorMetadata>,
  outputs: Array<CustomModelTensorMetadata>
): void {
  if (inputs.length !== manifest.input.tensors.length) {
    throw new Error('Model input tensor count does not match manifest.');
  }
  for (let index = 0; index < manifest.input.tensors.length; index++) {
    validateTensorMetadata(manifest.input.tensors[index], inputs[index], `input[${index}]`);
  }
  const output = outputs.find((value: CustomModelTensorMetadata) => value.name === manifest.output.tensor.name);
  if (output === undefined) {
    throw new Error('Model output tensor is missing.');
  }
  validateTensorMetadata(manifest.output.tensor, output, 'output');
}

export function imageTensorFromRgba(
  rgba: Uint8Array,
  sourceWidth: number,
  sourceHeight: number,
  manifest: CustomModelPackageManifest
): ArrayBuffer {
  const image = manifest.input.image;
  const tensor = manifest.input.tensors[0];
  if (manifest.input.kind !== 'image' || image === undefined ||
    rgba.length !== sourceWidth * sourceHeight * 4 || sourceWidth <= 0 || sourceHeight <= 0) {
    throw new Error('Image input is invalid.');
  }
  const targetWidth = image.width;
  const targetHeight = image.height;
  const scale = image.resize === 'fit' ?
    Math.min(targetWidth / sourceWidth, targetHeight / sourceHeight) :
    Math.max(targetWidth / sourceWidth, targetHeight / sourceHeight);
  const offsetX = (targetWidth - sourceWidth * scale) / 2;
  const offsetY = (targetHeight - sourceHeight * scale) / 2;
  const values = tensor.dtype === 'UINT8' ?
    new Uint8Array(targetWidth * targetHeight * 3) :
    new Float32Array(targetWidth * targetHeight * 3);
  for (let y = 0; y < targetHeight; y++) {
    for (let x = 0; x < targetWidth; x++) {
      const sourceX = Math.floor((x - offsetX) / scale);
      const sourceY = Math.floor((y - offsetY) / scale);
      const inside = sourceX >= 0 && sourceX < sourceWidth && sourceY >= 0 && sourceY < sourceHeight;
      const sourceIndex = inside ? (sourceY * sourceWidth + sourceX) * 4 : -1;
      for (let channel = 0; channel < 3; channel++) {
        const rgbaChannel = image.color === 'RGB' ? channel : 2 - channel;
        const byteValue = sourceIndex < 0 ? 0 : rgba[sourceIndex + rgbaChannel];
        const targetIndex = image.layout === 'NHWC' ?
          (y * targetWidth + x) * 3 + channel :
          channel * targetWidth * targetHeight + y * targetWidth + x;
        values[targetIndex] = tensor.dtype === 'UINT8' ? byteValue :
          (byteValue / 255 - image.mean[channel]) / image.std[channel];
      }
    }
  }
  return values.buffer as ArrayBuffer;
}

export function encodeCustomModelText(
  text: string,
  tokenizerTable: string,
  manifest: CustomModelPackageManifest
): Map<string, ArrayBuffer> {
  const settings = manifest.input.text;
  if (manifest.input.kind !== 'text' || settings === undefined) {
    throw new Error('Text input is not configured.');
  }
  const encoded: PortableTokenizerEncoding = encodePortableTokenizerText(
    tokenizerTable,
    text,
    settings.maxTokens,
    settings.padId,
    settings.bosId,
    settings.eosId
  );
  const tensors = new Map<string, ArrayBuffer>();
  tensors.set(settings.inputIdsTensor, new Int32Array(encoded.inputIds).buffer as ArrayBuffer);
  if (settings.attentionMaskTensor !== undefined) {
    tensors.set(settings.attentionMaskTensor,
      new Int32Array(encoded.attentionMask).buffer as ArrayBuffer);
  }
  return tensors;
}

export function decodeCustomModelOutput(
  manifest: CustomModelPackageManifest,
  outputs: Array<CustomModelTensorValue>,
  labels: Array<string>,
  tokenizerTable: string
): string {
  const contract = manifest.output.tensor;
  const output = outputs.find((value: CustomModelTensorValue): boolean => value.name === contract.name);
  if (output === undefined || output.dtype !== contract.dtype || !sameShape(output.shape, contract.shape)) {
    throw new Error('Model output does not match the package manifest.');
  }
  const count = shapeElementCount(output.shape);
  const expectedBytes = output.dtype === 'UINT8' ? count : count * 4;
  if (output.data.byteLength !== expectedBytes) {
    throw new Error('Model output byte size is invalid.');
  }
  if (manifest.output.kind === 'classification') {
    if (output.dtype !== 'FLOAT32' || labels.length !== count || manifest.output.topK === undefined) {
      throw new Error('Classification output or labels are invalid.');
    }
    const scores = new Float32Array(output.data);
    requireFiniteFloatValues(scores);
    const indices: Array<number> = [];
    for (let index = 0; index < scores.length; index++) indices.push(index);
    indices.sort((left: number, right: number): number => scores[right] - scores[left]);
    const lines: Array<string> = [];
    const resultCount = Math.min(manifest.output.topK, indices.length);
    for (let rank = 0; rank < resultCount; rank++) {
      const index = indices[rank];
      lines.push(`${rank + 1}. ${labels[index]} ${(scores[index] * 100).toFixed(2)}%`);
    }
    return lines.join('\n');
  }
  if (manifest.output.kind === 'text') {
    if (tokenizerTable.length === 0) {
      throw new Error('Text output tokenizer is missing.');
    }
    const ids: Array<number> = output.dtype === 'INT32' ?
      Array.from(new Int32Array(output.data)) :
      logitsToTokenIds(output);
    const settings = manifest.input.text;
    const padId = settings?.padId ?? -1;
    const bosId = settings?.bosId ?? -1;
    const eosId = settings?.eosId ?? 0;
    return decodePortableTokenizerText(tokenizerTable, ids, padId, bosId, eosId);
  }
  const preview: Array<string> = output.dtype === 'FLOAT32' ?
    finiteFloatPreview(new Float32Array(output.data)) :
    output.dtype === 'INT32' ?
      Array.from(new Int32Array(output.data)).slice(0, 16).map((value: number): string => `${value}`) :
      Array.from(new Uint8Array(output.data)).slice(0, 16).map((value: number): string => `${value}`);
  return `${output.name} · ${output.dtype} · [${output.shape.join(', ')}] · ${count} values\n${preview.join(', ')}`;
}

function logitsToTokenIds(output: CustomModelTensorValue): Array<number> {
  if (output.data.byteLength > customModelPackageMaxTextLogitsBytes || output.shape.length < 2) {
    throw new Error('Text logits are too large or have an invalid shape.');
  }
  const values = new Float32Array(output.data);
  requireFiniteFloatValues(values);
  const vocabularySize = output.shape[output.shape.length - 1];
  const stepCount = values.length / vocabularySize;
  const ids: Array<number> = [];
  for (let step = 0; step < stepCount; step++) {
    let bestIndex = 0;
    for (let index = 1; index < vocabularySize; index++) {
      if (values[step * vocabularySize + index] > values[step * vocabularySize + bestIndex]) {
        bestIndex = index;
      }
    }
    ids.push(bestIndex);
  }
  return ids;
}

function requireFiniteFloatValues(values: Float32Array): void {
  for (let index = 0; index < values.length; index++) {
    if (!Number.isFinite(values[index])) throw new Error('Model output contains a non-finite value.');
  }
}

function finiteFloatPreview(values: Float32Array): Array<string> {
  requireFiniteFloatValues(values);
  return Array.from(values).slice(0, 16).map((value: number): string => `${value}`);
}

function validateInput(input: CustomModelInputContract): void {
  if (input.kind === 'image') {
    requireExactKeys(input, ['kind', 'tensors', 'image'], '$.input');
    validateTensors(input.tensors, '$.input.tensors');
    if (input.tensors.length !== 1 || input.image === undefined) {
      throw new Error('Image packages require one image tensor.');
    }
    validateImage(input.image, input.tensors[0]);
    return;
  }
  if (input.kind === 'text') {
    requireExactKeys(input, ['kind', 'tensors', 'text'], '$.input');
    validateTensors(input.tensors, '$.input.tensors');
    if (input.text === undefined) {
      throw new Error('Text packages require tokenizer settings.');
    }
    validateText(input.text, input.tensors);
    return;
  }
  throw new Error('Unsupported model input kind.');
}

function validateImage(image: CustomModelImageInput, tensor: CustomModelTensorContract): void {
  requireExactKeys(image, ['width', 'height', 'layout', 'color', 'resize', 'mean', 'std'], '$.input.image');
  requirePositiveInteger(image.width, '$.input.image.width');
  requirePositiveInteger(image.height, '$.input.image.height');
  requireOneOf(image.layout, ['NHWC', 'NCHW'], '$.input.image.layout');
  requireOneOf(image.color, ['RGB', 'BGR'], '$.input.image.color');
  requireOneOf(image.resize, ['fit', 'fill'], '$.input.image.resize');
  requireThreeFiniteNumbers(image.mean, false, '$.input.image.mean');
  requireThreeFiniteNumbers(image.std, true, '$.input.image.std');
  if (tensor.dtype !== 'FLOAT32' && tensor.dtype !== 'UINT8') {
    throw new Error('Image tensor dtype must be FLOAT32 or UINT8.');
  }
  if (tensor.format !== image.layout || tensor.shape.length !== 4 || tensor.shape[0] !== 1) {
    throw new Error('Image tensor layout does not match image settings.');
  }
  const expected = image.layout === 'NHWC' ?
    [1, image.height, image.width, 3] :
    [1, 3, image.height, image.width];
  if (!sameShape(tensor.shape, expected)) {
    throw new Error('Image tensor shape does not match image settings.');
  }
}

function validateText(text: CustomModelTextInput, tensors: Array<CustomModelTensorContract>): void {
  const expectedKeys = text.attentionMaskTensor === undefined ?
    ['tokenizer', 'maxTokens', 'padId', 'unkId', 'bosId', 'eosId', 'inputIdsTensor'] :
    ['tokenizer', 'maxTokens', 'padId', 'unkId', 'bosId', 'eosId', 'inputIdsTensor', 'attentionMaskTensor'];
  requireExactKeys(text, expectedKeys, '$.input.text');
  validateAsset(text.tokenizer, '$.input.text.tokenizer');
  requirePositiveInteger(text.maxTokens, '$.input.text.maxTokens');
  requireNonNegativeInteger(text.padId, '$.input.text.padId');
  requireNonNegativeInteger(text.unkId, '$.input.text.unkId');
  requireNonNegativeInteger(text.bosId, '$.input.text.bosId');
  requireNonNegativeInteger(text.eosId, '$.input.text.eosId');
  requireNonEmptyString(text.inputIdsTensor, '$.input.text.inputIdsTensor');
  const expectedNames: Array<string> = [text.inputIdsTensor];
  if (text.attentionMaskTensor !== undefined) {
    requireNonEmptyString(text.attentionMaskTensor, '$.input.text.attentionMaskTensor');
    expectedNames.push(text.attentionMaskTensor);
  }
  if (tensors.length !== expectedNames.length) {
    throw new Error('Text tensor count does not match tokenizer settings.');
  }
  for (let index = 0; index < expectedNames.length; index++) {
    const tensor = tensors.find((value: CustomModelTensorContract) => value.name === expectedNames[index]);
    if (tensor === undefined || tensor.dtype !== 'INT32' ||
      !sameShape(tensor.shape, [1, text.maxTokens])) {
      throw new Error('Text tensor contract is not supported.');
    }
  }
}

function validateOutput(output: CustomModelOutputContract, input: CustomModelInputContract): void {
  if (output.kind === 'classification') {
    requireExactKeys(output, ['kind', 'tensor', 'labels', 'topK'], '$.output');
    validateTensor(output.tensor, '$.output.tensor');
    if (output.tensor.dtype !== 'FLOAT32' || output.labels === undefined || output.topK === undefined) {
      throw new Error('Classification output requires FLOAT32 scores and labels.');
    }
    validateAsset(output.labels, '$.output.labels');
    requirePositiveInteger(output.topK, '$.output.topK');
    return;
  }
  if (output.kind === 'text') {
    const keys = output.tokenizer === undefined ?
      ['kind', 'tensor'] :
      ['kind', 'tensor', 'tokenizer'];
    requireExactKeys(output, keys, '$.output');
    validateTensor(output.tensor, '$.output.tensor');
    if (output.tensor.dtype !== 'INT32' && output.tensor.dtype !== 'FLOAT32') {
      throw new Error('Text output must contain token IDs or logits.');
    }
    if (output.tokenizer !== undefined) {
      validateAsset(output.tokenizer, '$.output.tokenizer');
    } else if (input.text === undefined) {
      throw new Error('Text output requires a tokenizer.');
    }
    return;
  }
  if (output.kind === 'raw') {
    requireExactKeys(output, ['kind', 'tensor'], '$.output');
    validateTensor(output.tensor, '$.output.tensor');
    return;
  }
  throw new Error('Unsupported model output kind.');
}

function validateAsset(asset: CustomModelAssetRef, path: string): void {
  requireExactKeys(asset, ['file', 'sha256'], path);
  requireRootFileName(asset.file, `${path}.file`);
  if (typeof asset.sha256 !== 'string' || !SHA256_PATTERN.test(asset.sha256)) {
    throw new Error(`${path}.sha256 must be lower-case SHA-256.`);
  }
}

function validateTensors(tensors: Array<CustomModelTensorContract>, path: string): void {
  if (!Array.isArray(tensors) || tensors.length === 0) {
    throw new Error(`${path} must not be empty.`);
  }
  const names: Array<string> = [];
  for (let index = 0; index < tensors.length; index++) {
    validateTensor(tensors[index], `${path}[${index}]`);
    if (names.includes(tensors[index].name)) {
      throw new Error(`${path} tensor names must be unique.`);
    }
    names.push(tensors[index].name);
  }
}

function validateTensor(tensor: CustomModelTensorContract, path: string): void {
  const keys = tensor.format === undefined ? ['name', 'dtype', 'shape'] : ['name', 'dtype', 'shape', 'format'];
  requireExactKeys(tensor, keys, path);
  requireNonEmptyString(tensor.name, `${path}.name`);
  requireOneOf(tensor.dtype, ['FLOAT32', 'UINT8', 'INT32'], `${path}.dtype`);
  if (!Array.isArray(tensor.shape) || tensor.shape.length === 0) {
    throw new Error(`${path}.shape must not be empty.`);
  }
  for (let index = 0; index < tensor.shape.length; index++) {
    requirePositiveInteger(tensor.shape[index], `${path}.shape[${index}]`);
  }
  if (tensor.format !== undefined) {
    requireOneOf(tensor.format, ['NHWC', 'NCHW'], `${path}.format`);
  }
}

function validateTensorMetadata(
  expected: CustomModelTensorContract,
  actual: CustomModelTensorMetadata,
  path: string
): void {
  validateTensor(expected, path);
  if (expected.name !== actual.name || expected.dtype !== actual.dtype ||
    !sameShape(expected.shape, actual.shape) ||
    (expected.format !== undefined && expected.format !== actual.format)) {
    throw new Error(`${path} does not match the real model tensor.`);
  }
  const elementNum = shapeElementCount(expected.shape);
  const byteSize = expected.dtype === 'UINT8' ? elementNum : elementNum * 4;
  if (actual.elementNum !== elementNum || actual.dataSize !== byteSize) {
    throw new Error(`${path} tensor byte size mismatch.`);
  }
}

function shapeElementCount(shape: Array<number>): number {
  let count = 1;
  for (let index = 0; index < shape.length; index++) {
    if (count > Number.MAX_SAFE_INTEGER / shape[index]) {
      throw new Error('Tensor shape is too large.');
    }
    count *= shape[index];
  }
  return count;
}

function requireExactKeys(value: Object, expected: Array<string>, path: string): void {
  if (value === undefined || value === null || Array.isArray(value)) {
    throw new Error(`${path} must be an object.`);
  }
  const actual = Object.keys(value).sort();
  const wanted = expected.slice().sort();
  if (actual.length !== wanted.length) {
    throw new Error(`${path} properties mismatch.`);
  }
  for (let index = 0; index < wanted.length; index++) {
    if (actual[index] !== wanted[index]) {
      throw new Error(`${path} properties mismatch.`);
    }
  }
}

function requireInteger(value: number, expected: number, path: string): void {
  if (!Number.isInteger(value) || value !== expected) {
    throw new Error(`${path} mismatch.`);
  }
}

function requirePositiveInteger(value: number, path: string): void {
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${path} must be a positive integer.`);
  }
}

function requireNonNegativeInteger(value: number, path: string): void {
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${path} must be a non-negative integer.`);
  }
}

function requireNonEmptyString(value: string, path: string): void {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${path} must not be empty.`);
  }
}

function requireRootFileName(value: string, path: string): void {
  requireNonEmptyString(value, path);
  if (value.includes('/') || value.includes('\\') || value.includes('..') ||
    /^[A-Za-z]:/.test(value) || value.startsWith('.')) {
    throw new Error(`${path} must be a root file name.`);
  }
}

function requireOneOf(value: string, allowed: Array<string>, path: string): void {
  if (typeof value !== 'string' || !allowed.includes(value)) {
    throw new Error(`${path} is not supported.`);
  }
}

function requireThreeFiniteNumbers(values: Array<number>, nonZero: boolean, path: string): void {
  if (!Array.isArray(values) || values.length !== 3) {
    throw new Error(`${path} must contain three values.`);
  }
  for (let index = 0; index < values.length; index++) {
    if (!Number.isFinite(values[index]) || (nonZero && values[index] === 0)) {
      throw new Error(`${path} contains an invalid value.`);
    }
  }
}

function sameShape(actual: Array<number>, expected: Array<number>): boolean {
  if (actual.length !== expected.length) {
    return false;
  }
  for (let index = 0; index < actual.length; index++) {
    if (actual[index] !== expected[index]) {
      return false;
    }
  }
  return true;
}

function pushUnique(values: Array<string>, value: string): void {
  if (!values.includes(value)) {
    values.push(value);
  }
}
