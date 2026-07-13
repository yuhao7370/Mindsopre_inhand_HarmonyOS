import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  TranslationGraphManifest,
  TranslationModelManifest,
  TranslationTensorDataType,
  TranslationTensorManifest,
  parseTranslationModelManifest,
  translationArchiveRawfilePath,
  translationManifestRawfilePath,
  translationTokenizerRuntimeRawfilePath
} from './TranslationModelManifest';
import {
  configureTranslationTokenizer,
  decodeTranslationTokens,
  encodeTranslationText,
  TranslationChunk
} from './TinyTranslationTokenizer';
import {
  TextTranslationResult,
  TextTranslationRunner
} from './TextRecognitionService';
import { mindSporeLiteCpuContext } from './MindSporeLiteModelRunner';

export type TranslationGraphName = 'encoder' | 'decoder_prefill' | 'decoder_step';

export interface TranslationTensor {
  readonly name: string;
  readonly dtype: TranslationTensorDataType;
  readonly shape: Array<number>;
  readonly data: Int32Array | Float32Array;
}

export interface TranslationTensorSession {
  run(graph: TranslationGraphName, inputs: Array<TranslationTensor>): Promise<Array<TranslationTensor>>;
  close(): Promise<void>;
}

export interface TranslationModelBundle {
  readonly manifest: TranslationModelManifest;
  readonly session: TranslationTensorSession;
}

export type TranslationModelBundleFactory = () => Promise<TranslationModelBundle>;

export interface MindSporeLiteTranslationRunnerOptions {
  readonly bundleFactory: TranslationModelBundleFactory;
}

export interface TranslationRawFileDescriptor {
  readonly fd: number;
  readonly offset: number;
  readonly length: number;
}

export interface TranslationModelResourceManager {
  getRawFileContent(path: string): Promise<Uint8Array>;
  getRawFd(path: string): Promise<TranslationRawFileDescriptor>;
  closeRawFd(path: string): Promise<void>;
}

export interface TranslationProductionBundleOptions {
  readonly resourceManager: TranslationModelResourceManager;
  readonly cacheRoot: string;
}

interface TranslationArchiveMember {
  readonly name: 'encoder.ms' | 'decoder_prefill.ms' | 'decoder_step.ms';
  readonly size: number;
  readonly sha256: string;
}

interface TranslationArchiveRequest {
  readonly archiveFd: number;
  readonly archiveOffset: number;
  readonly archiveLength: number;
  readonly cacheRoot: string;
  readonly archiveSha256: string;
  readonly members: Array<TranslationArchiveMember>;
}

interface TranslationArchiveResult {
  readonly directory: string;
  readonly reused: boolean;
}

let cachedBundlePromise: Promise<TranslationModelBundle> | undefined = undefined;
let cacheGeneration: number = 0;

export class MindSporeLiteTranslationRunner implements TextTranslationRunner {
  private readonly bundleFactory: TranslationModelBundleFactory;

  constructor(options: MindSporeLiteTranslationRunnerOptions) {
    this.bundleFactory = options.bundleFactory;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    if (targetLanguage !== 'en' && targetLanguage !== 'zh') {
      return failedTranslation(text, targetLanguage);
    }
    try {
      const chunks = encodeTranslationText(text, targetLanguage);
      if (chunks.length === 0) {
        return failedTranslation(text, targetLanguage);
      }
      const bundle = await cachedTranslationBundle(this.bundleFactory);
      let translatedText = '';
      for (let index = 0; index < chunks.length; index++) {
        const decoded = await decodeChunk(bundle, chunks[index]);
        if (decoded.length === 0) {
          return failedTranslation(text, targetLanguage);
        }
        translatedText += chunks[index].separatorBefore + decoded + chunks[index].separatorAfter;
      }
      if (translatedText.trim().length === 0) {
        return failedTranslation(text, targetLanguage);
      }
      return {
        ok: true,
        sourceText: text,
        translatedText: translatedText,
        targetLanguage: targetLanguage,
        runtimeSource: 'localModel'
      };
    } catch (_) {
      return failedTranslation(text, targetLanguage);
    }
  }
}

export function productionTranslationModelBundleFactory(
  options: TranslationProductionBundleOptions
): TranslationModelBundleFactory {
  return async (): Promise<TranslationModelBundle> => loadProductionTranslationModelBundle(options);
}

async function loadProductionTranslationModelBundle(
  options: TranslationProductionBundleOptions
): Promise<TranslationModelBundle> {
  if (options.cacheRoot.trim().length === 0) {
    throw new Error('Translation model cache root is empty.');
  }
  const manifestContent = await options.resourceManager.getRawFileContent(translationManifestRawfilePath);
  const manifest = parseTranslationModelManifest(asciiContentToText(manifestContent));
  const tokenizerContent = await options.resourceManager.getRawFileContent(translationTokenizerRuntimeRawfilePath);
  configureTranslationTokenizer(asciiContentToText(tokenizerContent));

  const descriptor = await options.resourceManager.getRawFd(translationArchiveRawfilePath);
  let extraction: TranslationArchiveResult;
  try {
    if (!Number.isInteger(descriptor.fd) || descriptor.fd < 0 ||
      !Number.isInteger(descriptor.offset) || descriptor.offset < 0 ||
      !Number.isInteger(descriptor.length) || descriptor.length !== manifest.archive.size) {
      throw new Error('Translation archive descriptor differs from manifest.');
    }
    extraction = await extractTranslationArchive({
      archiveFd: descriptor.fd,
      archiveOffset: descriptor.offset,
      archiveLength: descriptor.length,
      cacheRoot: options.cacheRoot,
      archiveSha256: manifest.archive.sha256,
      members: archiveMembers(manifest)
    });
  } finally {
    await options.resourceManager.closeRawFd(translationArchiveRawfilePath);
  }
  if (extraction.directory.trim().length === 0) {
    throw new Error('Translation archive extractor returned an empty directory.');
  }
  const encoder = await mindSporeLite.loadModelFromFile(
    modelFilePath(extraction.directory, manifest.graphs[0].file), mindSporeLiteCpuContext()
  );
  const prefill = await mindSporeLite.loadModelFromFile(
    modelFilePath(extraction.directory, manifest.graphs[1].file), mindSporeLiteCpuContext()
  );
  const step = await mindSporeLite.loadModelFromFile(
    modelFilePath(extraction.directory, manifest.graphs[2].file), mindSporeLiteCpuContext()
  );
  return {
    manifest: manifest,
    session: new MindSporeLiteTranslationTensorSession(manifest, encoder, prefill, step)
  };
}

export function resetTranslationModelCacheForTests(): void {
  cacheGeneration++;
  const promise = cachedBundlePromise;
  cachedBundlePromise = undefined;
  if (promise !== undefined) {
    promise.then(async (bundle: TranslationModelBundle): Promise<void> => {
      await closeSession(bundle.session);
    }).catch((): void => {});
  }
}

async function cachedTranslationBundle(factory: TranslationModelBundleFactory): Promise<TranslationModelBundle> {
  if (cachedBundlePromise !== undefined) {
    return cachedBundlePromise;
  }
  const generation = cacheGeneration;
  let promise: Promise<TranslationModelBundle>;
  promise = factory().then(async (bundle: TranslationModelBundle): Promise<TranslationModelBundle> => {
    if (generation !== cacheGeneration || cachedBundlePromise !== promise) {
      await closeSession(bundle.session);
      throw new Error('Translation model load was reset.');
    }
    return bundle;
  });
  cachedBundlePromise = promise;
  promise.catch((): void => {
    if (generation === cacheGeneration && cachedBundlePromise === promise) {
      cachedBundlePromise = undefined;
    }
  });
  return promise;
}

async function decodeChunk(bundle: TranslationModelBundle, chunk: TranslationChunk): Promise<string> {
  const manifest = bundle.manifest;
  const encoderInputs: Array<TranslationTensor> = [
    intTensor('input_ids', [1, 128], chunk.inputIds),
    intTensor('attention_mask', [1, 128], chunk.attentionMask)
  ];
  const encoderOutputs = requireOutputs(
    await bundle.session.run('encoder', encoderInputs), manifest.graphs[0], 'encoder'
  );
  const encoderHidden = encoderOutputs[0];
  const prefillInputs: Array<TranslationTensor> = [
    intTensor('decoder_input_ids', [1, 1], [manifest.vocabulary.decoderStart]),
    namedTensor('encoder_hidden_states', encoderHidden),
    intTensor('encoder_attention_mask', [1, 128], chunk.attentionMask)
  ];
  const prefillOutputs = requireOutputs(
    await bundle.session.run('decoder_prefill', prefillInputs), manifest.graphs[1], 'decoder_prefill'
  );
  const generated: Array<number> = [];
  let token = stableFiniteArgmax(floatData(prefillOutputs[0]));
  if (token === manifest.vocabulary.eos) {
    return '';
  }
  generated.push(token);

  const pastKeys: Array<Float32Array> = [new Float32Array(8 * 127 * 32), new Float32Array(8 * 127 * 32)];
  const pastValues: Array<Float32Array> = [new Float32Array(8 * 127 * 32), new Float32Array(8 * 127 * 32)];
  scatterCacheSlot(pastKeys[0], floatData(prefillOutputs[1]), 0);
  scatterCacheSlot(pastValues[0], floatData(prefillOutputs[2]), 0);
  scatterCacheSlot(pastKeys[1], floatData(prefillOutputs[5]), 0);
  scatterCacheSlot(pastValues[1], floatData(prefillOutputs[6]), 0);
  const crossCaches: Array<TranslationTensor> = [
    prefillOutputs[3], prefillOutputs[4], prefillOutputs[7], prefillOutputs[8]
  ];

  while (generated.length < 128) {
    const position = generated.length;
    const stepInputs = stepInputTensors(token, position, chunk.attentionMask, pastKeys, pastValues, crossCaches);
    const stepOutputs = requireOutputs(
      await bundle.session.run('decoder_step', stepInputs), manifest.graphs[2], 'decoder_step'
    );
    if (position < 127) {
      scatterCacheSlot(pastKeys[0], floatData(stepOutputs[1]), position);
      scatterCacheSlot(pastValues[0], floatData(stepOutputs[2]), position);
      scatterCacheSlot(pastKeys[1], floatData(stepOutputs[3]), position);
      scatterCacheSlot(pastValues[1], floatData(stepOutputs[4]), position);
    }
    token = stableFiniteArgmax(floatData(stepOutputs[0]));
    if (token === manifest.vocabulary.eos) {
      break;
    }
    generated.push(token);
  }
  return decodeTranslationTokens(generated);
}

function stepInputTensors(
  token: number,
  position: number,
  encoderAttentionMask: Array<number>,
  pastKeys: Array<Float32Array>,
  pastValues: Array<Float32Array>,
  crossCaches: Array<TranslationTensor>
): Array<TranslationTensor> {
  const selfMask = new Int32Array(128);
  for (let index = 0; index <= position; index++) {
    selfMask[index] = 1;
  }
  return [
    intTensor('decoder_input_ids', [1, 1], [token]),
    intTensor('position_id', [1], [position]),
    { name: 'self_attention_mask', dtype: 'INT32', shape: [1, 128], data: selfMask },
    intTensor('cross_attention_mask', [1, 128], encoderAttentionMask),
    floatTensor('past_key_0', [1, 8, 127, 32], pastKeys[0]),
    floatTensor('past_value_0', [1, 8, 127, 32], pastValues[0]),
    namedTensor('cross_key_0', crossCaches[0]),
    namedTensor('cross_value_0', crossCaches[1]),
    floatTensor('past_key_1', [1, 8, 127, 32], pastKeys[1]),
    floatTensor('past_value_1', [1, 8, 127, 32], pastValues[1]),
    namedTensor('cross_key_1', crossCaches[2]),
    namedTensor('cross_value_1', crossCaches[3])
  ];
}

function requireOutputs(
  outputs: Array<TranslationTensor>,
  graph: TranslationGraphManifest,
  graphName: string
): Array<TranslationTensor> {
  if (outputs.length !== graph.outputs.length) {
    throw new Error(`${graphName} output count mismatch.`);
  }
  const ordered: Array<TranslationTensor> = [];
  for (let index = 0; index < graph.outputs.length; index++) {
    const expected = graph.outputs[index];
    let found: TranslationTensor | undefined = undefined;
    for (let outputIndex = 0; outputIndex < outputs.length; outputIndex++) {
      if (outputs[outputIndex].name === expected.name) {
        if (found !== undefined) {
          throw new Error(`${graphName} has duplicate output ${expected.name}.`);
        }
        found = outputs[outputIndex];
      }
    }
    if (found === undefined) {
      throw new Error(`${graphName} is missing output ${expected.name}.`);
    }
    validateTensor(found, expected, `${graphName}.${expected.name}`);
    ordered.push(found);
  }
  return ordered;
}

function validateTensor(actual: TranslationTensor, expected: TranslationTensorManifest, path: string): void {
  if (actual.dtype !== expected.dtype || !sameShape(actual.shape, expected.shape)) {
    throw new Error(`${path} contract mismatch.`);
  }
  const count = elementCount(expected.shape);
  if (actual.data.length !== count) {
    throw new Error(`${path} data length mismatch.`);
  }
  if (expected.dtype === 'FLOAT32') {
    const data = floatData(actual);
    for (let index = 0; index < data.length; index++) {
      if (!Number.isFinite(data[index])) {
        throw new Error(`${path} contains a non-finite value.`);
      }
    }
  } else if (!(actual.data instanceof Int32Array)) {
    throw new Error(`${path} data type mismatch.`);
  }
}

function stableFiniteArgmax(logits: Float32Array): number {
  if (logits.length === 0) {
    throw new Error('Translation logits are empty.');
  }
  let bestId = 0;
  let bestValue = logits[0];
  if (!Number.isFinite(bestValue)) {
    throw new Error('Translation logits contain a non-finite value.');
  }
  for (let index = 1; index < logits.length; index++) {
    const value = logits[index];
    if (!Number.isFinite(value)) {
      throw new Error('Translation logits contain a non-finite value.');
    }
    if (value > bestValue) {
      bestValue = value;
      bestId = index;
    }
  }
  return bestId;
}

function scatterCacheSlot(history: Float32Array, slot: Float32Array, position: number): void {
  if (slot.length !== 8 * 32 || position < 0 || position >= 127) {
    throw new Error('Translation self cache slot mismatch.');
  }
  for (let head = 0; head < 8; head++) {
    const sourceOffset = head * 32;
    const destinationOffset = (head * 127 + position) * 32;
    for (let dimension = 0; dimension < 32; dimension++) {
      history[destinationOffset + dimension] = slot[sourceOffset + dimension];
    }
  }
}

function intTensor(name: string, shape: Array<number>, values: Array<number>): TranslationTensor {
  return { name: name, dtype: 'INT32', shape: shape, data: new Int32Array(values) };
}

function floatTensor(name: string, shape: Array<number>, data: Float32Array): TranslationTensor {
  return { name: name, dtype: 'FLOAT32', shape: shape, data: data };
}

function namedTensor(name: string, tensor: TranslationTensor): TranslationTensor {
  return { name: name, dtype: tensor.dtype, shape: tensor.shape, data: tensor.data };
}

function floatData(tensor: TranslationTensor): Float32Array {
  if (!(tensor.data instanceof Float32Array)) {
    throw new Error(`${tensor.name} is not FLOAT32 data.`);
  }
  return tensor.data;
}

function sameShape(actual: Array<number>, expected: Array<number>): boolean {
  if (actual.length !== expected.length) {
    return false;
  }
  for (let index = 0; index < expected.length; index++) {
    if (actual[index] !== expected[index]) {
      return false;
    }
  }
  return true;
}

function elementCount(shape: Array<number>): number {
  let count = 1;
  for (let index = 0; index < shape.length; index++) {
    count *= shape[index];
  }
  return count;
}

class MindSporeLiteTranslationTensorSession implements TranslationTensorSession {
  private readonly manifest: TranslationModelManifest;
  private readonly encoder: mindSporeLite.Model;
  private readonly prefill: mindSporeLite.Model;
  private readonly step: mindSporeLite.Model;
  private closed: boolean = false;

  constructor(
    manifest: TranslationModelManifest,
    encoder: mindSporeLite.Model,
    prefill: mindSporeLite.Model,
    step: mindSporeLite.Model
  ) {
    this.manifest = manifest;
    this.encoder = encoder;
    this.prefill = prefill;
    this.step = step;
    validateModelInputContract(encoder, manifest.graphs[0], 'encoder');
    validateModelInputContract(prefill, manifest.graphs[1], 'decoder_prefill');
    validateModelInputContract(step, manifest.graphs[2], 'decoder_step');
  }

  async run(graph: TranslationGraphName, inputs: Array<TranslationTensor>): Promise<Array<TranslationTensor>> {
    if (this.closed) {
      throw new Error('Translation tensor session is closed.');
    }
    const model = this.modelForGraph(graph);
    const graphManifest = this.manifestForGraph(graph);
    const runtimeInputs = bindModelInputs(model, graphManifest, inputs, graph);
    const outputs = await model.predict(runtimeInputs);
    const converted: Array<TranslationTensor> = [];
    for (let index = 0; index < outputs.length; index++) {
      converted.push(translationTensorFromMindSpore(outputs[index]));
    }
    return converted;
  }

  async close(): Promise<void> {
    this.closed = true;
  }

  private modelForGraph(graph: TranslationGraphName): mindSporeLite.Model {
    if (graph === 'encoder') {
      return this.encoder;
    }
    if (graph === 'decoder_prefill') {
      return this.prefill;
    }
    return this.step;
  }

  private manifestForGraph(graph: TranslationGraphName): TranslationGraphManifest {
    if (graph === 'encoder') {
      return this.manifest.graphs[0];
    }
    if (graph === 'decoder_prefill') {
      return this.manifest.graphs[1];
    }
    return this.manifest.graphs[2];
  }
}

function validateModelInputContract(
  model: mindSporeLite.Model,
  graph: TranslationGraphManifest,
  graphName: string
): void {
  const runtimeInputs = model.getInputs();
  if (runtimeInputs.length !== graph.inputs.length) {
    throw new Error(`${graphName} model input count mismatch.`);
  }
  for (let index = 0; index < runtimeInputs.length; index++) {
    const expected = findTensorManifest(graph.inputs, runtimeInputs[index].name);
    if (expected === undefined || countNamedMindSporeTensors(runtimeInputs, runtimeInputs[index].name) !== 1) {
      throw new Error(`${graphName} model has an unexpected or duplicate input.`);
    }
    validateMindSporeTensorMetadata(runtimeInputs[index], expected, `${graphName}.${runtimeInputs[index].name}`);
  }
}

function bindModelInputs(
  model: mindSporeLite.Model,
  graph: TranslationGraphManifest,
  inputs: Array<TranslationTensor>,
  graphName: string
): Array<mindSporeLite.MSTensor> {
  const runtimeInputs = model.getInputs();
  if (inputs.length !== graph.inputs.length || runtimeInputs.length !== graph.inputs.length) {
    throw new Error(`${graphName} input count mismatch.`);
  }
  for (let index = 0; index < inputs.length; index++) {
    const expected = findTensorManifest(graph.inputs, inputs[index].name);
    if (expected === undefined || countNamedTranslationTensors(inputs, inputs[index].name) !== 1) {
      throw new Error(`${graphName} has an unexpected or duplicate input.`);
    }
    validateTensor(inputs[index], expected, `${graphName}.${inputs[index].name}`);
  }
  for (let index = 0; index < runtimeInputs.length; index++) {
    const expected = findTensorManifest(graph.inputs, runtimeInputs[index].name);
    const provided = findTranslationTensor(inputs, runtimeInputs[index].name);
    if (expected === undefined || provided === undefined) {
      throw new Error(`${graphName} cannot bind ${runtimeInputs[index].name}.`);
    }
    validateMindSporeTensorMetadata(runtimeInputs[index], expected, `${graphName}.${runtimeInputs[index].name}`);
    runtimeInputs[index].setData(copyTensorData(provided.data));
  }
  return runtimeInputs;
}

function validateMindSporeTensorMetadata(
  actual: mindSporeLite.MSTensor,
  expected: TranslationTensorManifest,
  path: string
): void {
  const count = elementCount(expected.shape);
  if (actual.dtype !== mindSporeDataType(expected.dtype) || !sameShape(actual.shape, expected.shape) ||
    actual.elementNum !== count || actual.dataSize !== count * 4) {
    throw new Error(`${path} runtime tensor contract mismatch.`);
  }
}

function translationTensorFromMindSpore(tensor: mindSporeLite.MSTensor): TranslationTensor {
  const dtype = translationDataType(tensor.dtype);
  const buffer = tensor.getData();
  let data: Int32Array | Float32Array;
  if (dtype === 'INT32') {
    data = new Int32Array(copyArrayBuffer(buffer));
  } else {
    data = new Float32Array(copyArrayBuffer(buffer));
  }
  return {
    name: tensor.name,
    dtype: dtype,
    shape: tensor.shape.slice(),
    data: data
  };
}

function mindSporeDataType(dtype: TranslationTensorDataType): mindSporeLite.DataType {
  return dtype === 'INT32' ?
    mindSporeLite.DataType.NUMBER_TYPE_INT32 : mindSporeLite.DataType.NUMBER_TYPE_FLOAT32;
}

function translationDataType(dtype: mindSporeLite.DataType): TranslationTensorDataType {
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_INT32) {
    return 'INT32';
  }
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32) {
    return 'FLOAT32';
  }
  throw new Error('MindSpore returned an unsupported translation tensor dtype.');
}

function findTensorManifest(
  tensors: Array<TranslationTensorManifest>,
  name: string
): TranslationTensorManifest | undefined {
  for (let index = 0; index < tensors.length; index++) {
    if (tensors[index].name === name) {
      return tensors[index];
    }
  }
  return undefined;
}

function findTranslationTensor(
  tensors: Array<TranslationTensor>,
  name: string
): TranslationTensor | undefined {
  for (let index = 0; index < tensors.length; index++) {
    if (tensors[index].name === name) {
      return tensors[index];
    }
  }
  return undefined;
}

function countNamedTranslationTensors(tensors: Array<TranslationTensor>, name: string): number {
  let count = 0;
  for (let index = 0; index < tensors.length; index++) {
    if (tensors[index].name === name) {
      count++;
    }
  }
  return count;
}

function countNamedMindSporeTensors(tensors: Array<mindSporeLite.MSTensor>, name: string): number {
  let count = 0;
  for (let index = 0; index < tensors.length; index++) {
    if (tensors[index].name === name) {
      count++;
    }
  }
  return count;
}

function copyTensorData(data: Int32Array | Float32Array): ArrayBuffer {
  const buffer = new ArrayBuffer(data.byteLength);
  if (data instanceof Int32Array) {
    new Int32Array(buffer).set(data);
  } else {
    new Float32Array(buffer).set(data);
  }
  return buffer;
}

function copyArrayBuffer(source: ArrayBuffer): ArrayBuffer {
  const copy = new ArrayBuffer(source.byteLength);
  new Uint8Array(copy).set(new Uint8Array(source));
  return copy;
}

function archiveMembers(manifest: TranslationModelManifest): Array<TranslationArchiveMember> {
  return [
    { name: 'encoder.ms', size: manifest.graphs[0].size, sha256: manifest.graphs[0].sha256 },
    { name: 'decoder_prefill.ms', size: manifest.graphs[1].size, sha256: manifest.graphs[1].sha256 },
    { name: 'decoder_step.ms', size: manifest.graphs[2].size, sha256: manifest.graphs[2].sha256 }
  ];
}

async function extractTranslationArchive(request: TranslationArchiveRequest): Promise<TranslationArchiveResult> {
  const namespace: ESObject = await import('libtranslation_archive.so');
  return await namespace.default.extractArchive(request) as TranslationArchiveResult;
}

function modelFilePath(directory: string, file: string): string {
  const separator = directory.endsWith('/') ? '' : '/';
  return `${directory}${separator}${file}`;
}

function asciiContentToText(content: Uint8Array): string {
  const chunks: Array<string> = [];
  let chunk = '';
  for (let index = 0; index < content.length; index++) {
    if (content[index] > 0x7F) {
      throw new Error('Translation runtime metadata must be ASCII.');
    }
    chunk += String.fromCharCode(content[index]);
    if (chunk.length >= 4096) {
      chunks.push(chunk);
      chunk = '';
    }
  }
  chunks.push(chunk);
  return chunks.join('');
}

async function closeSession(session: TranslationTensorSession): Promise<void> {
  try {
    await session.close();
  } catch (_) {
  }
}

function failedTranslation(sourceText: string, targetLanguage: string): TextTranslationResult {
  return {
    ok: false,
    sourceText: sourceText,
    translatedText: '',
    targetLanguage: targetLanguage
  };
}
