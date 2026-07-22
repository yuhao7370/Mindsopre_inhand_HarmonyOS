import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { fileIo } from '@kit.CoreFileKit';
import {
  TranslationGraphManifest,
  TranslationDirectionManifest,
  TranslationModelManifest,
  TranslationTokenizerManifest,
  TranslationTensorDataType,
  TranslationTensorManifest,
  parseTranslationModelManifest,
  translationArchiveRawfilePath,
  translationDirectionForTarget,
  translationManifestRawfilePath
} from './TranslationModelManifest';
import {
  configureTranslationTokenizers,
  decodeTranslationTokensForDirection,
  encodeTranslationTextForDirection,
  TranslationTokenizerContract,
  TranslationChunk
} from './TinyTranslationTokenizer';
import {
  TextTranslationResult,
  TextTranslationRunner
} from './TextRecognitionService';
import { mindSporeLiteCpuContext } from './MindSporeLiteModelRunner';
import {
  isTranslatableTranslationText,
  prepareTranslationInput,
  TranslationInputSegment
} from './TranslationInputPolicy';

export type TranslationGraphName = 'encoder' | 'decoder_full';

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

export class TranslationRequestQueue {
  private tail: Promise<void> = Promise.resolve();

  runExclusive<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.tail.then(operation, operation);
    this.tail = result.then((): void => {}, (): void => {});
    return result;
  }
}

export interface TranslationModelBundle {
  readonly direction: TranslationDirectionManifest;
  readonly session: TranslationTensorSession;
  readonly requestQueue: TranslationRequestQueue;
}

export type TranslationModelBundleFactory = (targetLanguage?: string) => Promise<TranslationModelBundle>;

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

export interface PreparedTranslationModelFiles {
  readonly manifest: TranslationModelManifest;
  readonly directory: string;
}

interface TranslationArchiveMember {
  readonly name: string;
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
let cachedBundleTarget: string | undefined = undefined;
let cacheGeneration: number = 0;

export class MindSporeLiteTranslationRunner implements TextTranslationRunner {
  private readonly bundleFactory: TranslationModelBundleFactory;

  constructor(options: MindSporeLiteTranslationRunnerOptions) {
    this.bundleFactory = options.bundleFactory;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    if (targetLanguage !== 'en' && targetLanguage !== 'zh') {
      return failedTranslation(text, targetLanguage, 'UNSUPPORTED_TARGET');
    }
    const segments = prepareTranslationInput(text);
    if (segments.length === 0 || text.trim().length === 0) {
      return failedTranslation(text, targetLanguage, 'EMPTY_INPUT');
    }
    if (!hasTranslationModelSegment(segments)) {
      return successfulTranslation(text, text, targetLanguage);
    }
    try {
      const bundle = await cachedTranslationBundle(this.bundleFactory, targetLanguage);
      return await bundle.requestQueue.runExclusive(async (): Promise<TextTranslationResult> => {
        return await runTranslationModelRequest(bundle, text, targetLanguage);
      });
    } catch (_) {
      return failedTranslation(text, targetLanguage, 'MODEL_EXECUTION_FAILED');
    }
  }
}

async function translateInputSegments(
  bundle: TranslationModelBundle,
  segments: Array<TranslationInputSegment>,
  text: string,
  targetLanguage: string
): Promise<TextTranslationResult> {
  let translatedText = '';
  for (let index = 0; index < segments.length; index++) {
    const segment = segments[index];
    if (segment.kind === 'protected' || !isTranslatableTranslationText(segment.text)) {
      translatedText += segment.text;
      continue;
    }
    const direction = bundle.direction;
    const chunks = encodeTranslationTextForDirection(segment.text, direction.generation.sourcePrefix,
      direction.generation.sourcePrefixTokenId,
      direction.vocabulary.pad, direction.vocabulary.eos);
    if (chunks.length === 0) {
      return failedTranslation(text, targetLanguage, 'DECODE_FAILED');
    }
    const translatedSegment = await translateChunksToText(bundle, chunks);
    if (translatedSegment.length === 0) {
      return failedTranslation(text, targetLanguage, 'DECODE_FAILED');
    }
    translatedText += translatedSegment;
  }
  if (translatedText.trim().length === 0) {
    return failedTranslation(text, targetLanguage, 'DECODE_FAILED');
  }
  return successfulTranslation(text, translatedText, targetLanguage);
}

async function translateChunksToText(
  bundle: TranslationModelBundle,
  chunks: Array<TranslationChunk>
): Promise<string> {
  let translatedText = '';
  for (let index = 0; index < chunks.length; index++) {
    const decoded = await decodeChunk(bundle, chunks[index]);
    if (decoded.length === 0) {
      return '';
    }
    translatedText += chunks[index].separatorBefore + decoded + chunks[index].separatorAfter;
  }
  return translatedText;
}

function successfulTranslation(
  sourceText: string,
  translatedText: string,
  targetLanguage: string
): TextTranslationResult {
  return {
    ok: true,
    sourceText: sourceText,
    translatedText: translatedText,
    targetLanguage: targetLanguage,
    runtimeSource: 'localModel'
  };
}

function hasTranslationModelSegment(segments: Array<TranslationInputSegment>): boolean {
  for (let index = 0; index < segments.length; index++) {
    if (segments[index].kind === 'model' && isTranslatableTranslationText(segments[index].text)) {
      return true;
    }
  }
  return false;
}

export function productionTranslationModelBundleFactory(
  options: TranslationProductionBundleOptions
): TranslationModelBundleFactory {
  return async (targetLanguage?: string): Promise<TranslationModelBundle> =>
    loadProductionTranslationModelBundle(options, targetLanguage ?? 'en');
}

async function loadProductionTranslationModelBundle(
  options: TranslationProductionBundleOptions,
  targetLanguage: string
): Promise<TranslationModelBundle> {
  const prepared = await prepareProductionTranslationModelFiles(options);
  const direction = translationDirectionForTarget(prepared.manifest, targetLanguage);
  const sourceTable = await readVerifiedTranslationText(modelFilePath(prepared.directory, direction.tokenizers.source.file),
    direction.tokenizers.source.size, direction.tokenizers.source.file);
  const targetTable = direction.tokenizers.target.file === direction.tokenizers.source.file ? sourceTable :
    await readVerifiedTranslationText(modelFilePath(prepared.directory, direction.tokenizers.target.file),
      direction.tokenizers.target.size, direction.tokenizers.target.file);
  configureTranslationTokenizers(sourceTable, targetTable,
    tokenizerContract(direction, true), tokenizerContract(direction, false));
  const encoderBuffer = await readVerifiedTranslationModel(
    modelFilePath(prepared.directory, direction.graphs.encoder.file), direction.graphs.encoder);
  const encoder = await mindSporeLite.loadModelFromBuffer(encoderBuffer, mindSporeLiteCpuContext());
  const decoderBuffer = await readVerifiedTranslationModel(
    modelFilePath(prepared.directory, direction.graphs.decoderFull.file), direction.graphs.decoderFull);
  const decoder = await mindSporeLite.loadModelFromBuffer(decoderBuffer, mindSporeLiteCpuContext());
  return {
    direction: direction,
    session: new MindSporeLiteTranslationTensorSession(
      direction,
      new TranslationMindSporeModelAdapter(encoder),
      new TranslationMindSporeModelAdapter(decoder)
    ),
    requestQueue: new TranslationRequestQueue()
  };
}

export async function runTranslationModelRequest(
  bundle: TranslationModelBundle,
  text: string,
  targetLanguage: string
): Promise<TextTranslationResult> {
  if (targetLanguage !== 'en' && targetLanguage !== 'zh') {
    return failedTranslation(text, targetLanguage, 'UNSUPPORTED_TARGET');
  }
  const segments = prepareTranslationInput(text);
  if (segments.length === 0 || text.trim().length === 0) {
    return failedTranslation(text, targetLanguage, 'EMPTY_INPUT');
  }
  if (!hasTranslationModelSegment(segments)) {
    return successfulTranslation(text, text, targetLanguage);
  }
  return await translateInputSegments(bundle, segments, text, targetLanguage);
}

export function translationResultWithoutModel(
  text: string,
  targetLanguage: string
): TextTranslationResult | undefined {
  if (targetLanguage !== 'en' && targetLanguage !== 'zh') {
    return failedTranslation(text, targetLanguage, 'UNSUPPORTED_TARGET');
  }
  const segments = prepareTranslationInput(text);
  if (segments.length === 0 || text.trim().length === 0) {
    return failedTranslation(text, targetLanguage, 'EMPTY_INPUT');
  }
  if (!hasTranslationModelSegment(segments)) return successfulTranslation(text, text, targetLanguage);
  return undefined;
}

export async function prepareProductionTranslationModelFiles(
  options: TranslationProductionBundleOptions
): Promise<PreparedTranslationModelFiles> {
  if (options.cacheRoot.trim().length === 0) {
    throw new Error('Translation model cache root is empty.');
  }
  const manifestContent = await options.resourceManager.getRawFileContent(translationManifestRawfilePath);
  const manifest = parseTranslationModelManifest(asciiContentToText(manifestContent));
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
  return {
    manifest: manifest,
    directory: extraction.directory
  };
}

export function resetTranslationModelCacheForTests(): void {
  cacheGeneration++;
  const promise = cachedBundlePromise;
  cachedBundlePromise = undefined;
  cachedBundleTarget = undefined;
  if (promise !== undefined) {
    promise.then(async (bundle: TranslationModelBundle): Promise<void> => {
      await closeBundle(bundle);
    }).catch((): void => {});
  }
}

async function cachedTranslationBundle(
  factory: TranslationModelBundleFactory,
  targetLanguage: string
): Promise<TranslationModelBundle> {
  if (cachedBundlePromise !== undefined && cachedBundleTarget === targetLanguage) {
    return cachedBundlePromise;
  }
  if (cachedBundlePromise !== undefined) {
    const old = cachedBundlePromise;
    cachedBundlePromise = undefined;
    cachedBundleTarget = undefined;
    old.then(async (bundle: TranslationModelBundle): Promise<void> => { await closeBundle(bundle); }).catch((): void => {});
  }
  const generation = cacheGeneration;
  let promise: Promise<TranslationModelBundle>;
  promise = factory(targetLanguage).then(async (bundle: TranslationModelBundle): Promise<TranslationModelBundle> => {
    if (generation !== cacheGeneration || cachedBundlePromise !== promise) {
      await closeBundle(bundle);
      throw new Error('Translation model load was reset.');
    }
    return bundle;
  });
  cachedBundlePromise = promise;
  cachedBundleTarget = targetLanguage;
  promise.catch((): void => {
    if (generation === cacheGeneration && cachedBundlePromise === promise) {
      cachedBundlePromise = undefined;
      cachedBundleTarget = undefined;
    }
  });
  return promise;
}

async function decodeChunk(bundle: TranslationModelBundle, chunk: TranslationChunk): Promise<string> {
  const direction = bundle.direction;
  const encoderInputs: Array<TranslationTensor> = [
    intTensor('input_ids', [1, 128], chunk.inputIds),
    intTensor('attention_mask', [1, 128], chunk.attentionMask)
  ];
  const encoderOutputs = requireOutputs(
    await bundle.session.run('encoder', encoderInputs), direction.graphs.encoder, 'encoder'
  );
  const encoderHidden = encoderOutputs[0];
  const generated = direction.generation.strategy === 'beam' ?
    await beamDecode(bundle, encoderHidden, chunk.attentionMask) :
    await greedyDecode(bundle, encoderHidden, chunk.attentionMask);
  return decodeTranslationTokensForDirection(generated, direction.vocabulary.eos, direction.vocabulary.pad);
}

function decoderInputs(
  direction: TranslationDirectionManifest,
  prefix: Array<number>,
  encoderHidden: TranslationTensor,
  encoderAttentionMask: Array<number>,
): Array<TranslationTensor> {
  const ids = new Array<number>(32).fill(direction.vocabulary.pad);
  const mask = new Array<number>(32).fill(0);
  for (let index = 0; index < prefix.length; index++) { ids[index] = prefix[index]; mask[index] = 1; }
  return [
    intTensor('decoder_input_ids', [1, 32], ids),
    intTensor('decoder_attention_mask', [1, 32], mask),
    namedTensor('encoder_hidden_states', encoderHidden),
    intTensor('encoder_attention_mask', [1, 128], encoderAttentionMask)
  ];
}

async function runFullDecoder(
  bundle: TranslationModelBundle,
  prefix: Array<number>,
  encoderHidden: TranslationTensor,
  encoderAttentionMask: Array<number>
): Promise<Float32Array> {
  const outputs = requireOutputs(await bundle.session.run('decoder_full',
    decoderInputs(bundle.direction, prefix, encoderHidden, encoderAttentionMask)),
  bundle.direction.graphs.decoderFull, 'decoder_full');
  const logits = floatData(outputs[0]);
  const vocabularySize = bundle.direction.vocabulary.size;
  const offset = (prefix.length - 1) * vocabularySize;
  return logits.subarray(offset, offset + vocabularySize);
}

async function greedyDecode(
  bundle: TranslationModelBundle,
  encoderHidden: TranslationTensor,
  encoderAttentionMask: Array<number>
): Promise<Array<number>> {
  const direction = bundle.direction;
  const prefix: Array<number> = [direction.vocabulary.decoderStart];
  const generated: Array<number> = [];
  while (prefix.length < direction.generation.targetMaxTokens) {
    let token: number;
    if (prefix.length === direction.generation.targetMaxTokens - 1) token = direction.vocabulary.eos;
    else token = stableFiniteArgmax(await runFullDecoder(bundle, prefix, encoderHidden, encoderAttentionMask),
      direction.vocabulary.pad);
    if (token === direction.vocabulary.eos) break;
    generated.push(token); prefix.push(token);
  }
  return generated;
}

interface TranslationBeam {
  readonly tokens: Array<number>;
  readonly score: number;
  readonly order: number;
  readonly normalizationLength: number;
}

async function beamDecode(
  bundle: TranslationModelBundle,
  encoderHidden: TranslationTensor,
  encoderAttentionMask: Array<number>
): Promise<Array<number>> {
  const direction = bundle.direction;
  const beamCount = direction.generation.numBeams;
  let beams: Array<TranslationBeam> = [{
    tokens: [direction.vocabulary.decoderStart], score: 0, order: 0, normalizationLength: 0
  }];
  const completed: Array<TranslationBeam> = [];
  let candidateOrder = 1;
  while (beams.length > 0 && beams[0].tokens.length < direction.generation.targetMaxTokens) {
    const candidates: Array<TranslationBeam> = [];
    const forceEos = beams[0].tokens.length === direction.generation.targetMaxTokens - 1;
    for (let beamIndex = 0; beamIndex < beams.length; beamIndex++) {
      if (forceEos) {
        const tokens = beams[beamIndex].tokens.concat([direction.vocabulary.eos]);
        candidates.push({ tokens: tokens, score: beams[beamIndex].score, order: candidateOrder++,
          normalizationLength: tokens.length - 1 });
        continue;
      }
      const logits = await runFullDecoder(bundle, beams[beamIndex].tokens, encoderHidden, encoderAttentionMask);
      const next = topLogProbabilities(logits, beamCount * 2, direction.vocabulary.pad);
      for (let rank = 0; rank < next.length; rank++) {
        const tokens = beams[beamIndex].tokens.concat([next[rank].token]);
        candidates.push({ tokens: tokens, score: beams[beamIndex].score + next[rank].score,
          order: candidateOrder++, normalizationLength: tokens.length - 1 });
      }
    }
    candidates.sort((left: TranslationBeam, right: TranslationBeam): number =>
      right.score === left.score ? left.order - right.order : right.score - left.score);
    const nextBeams: Array<TranslationBeam> = [];
    const limit = Math.min(candidates.length, beamCount * 2);
    for (let rank = 0; rank < limit; rank++) {
      const candidate = candidates[rank];
      const token = candidate.tokens[candidate.tokens.length - 1];
      if (token === direction.vocabulary.eos) {
        if (rank < beamCount) {
          completed.push({ tokens: candidate.tokens.slice(0, candidate.tokens.length - 1),
            score: candidate.score, order: candidate.order,
            normalizationLength: candidate.normalizationLength });
          completed.sort(compareCompletedBeams);
          while (completed.length > beamCount) completed.pop();
        }
      } else if (nextBeams.length < beamCount) {
        nextBeams.push(candidate);
      }
    }
    if (nextBeams.length === 0) break;
    beams = nextBeams;
    if (beamSearchDone(completed, candidates[0].score, candidates[0].tokens.length, beamCount)) break;
  }
  if (completed.length === 0) completed.push(...beams);
  completed.sort(compareCompletedBeams);
  const best = completed[0].tokens.slice(1);
  return best;
}

interface TokenScore { readonly token: number; readonly score: number; }

function topLogProbabilities(logits: Float32Array, count: number, excludedToken: number): Array<TokenScore> {
  let max = Number.NEGATIVE_INFINITY;
  for (let index = 0; index < logits.length; index++) {
    if (!Number.isFinite(logits[index])) throw new Error('Decoder logits contain a non-finite value.');
    if (logits[index] > max) max = logits[index];
  }
  let sum = 0;
  for (let index = 0; index < logits.length; index++) sum += Math.exp(logits[index] - max);
  const logDenominator = max + Math.log(sum);
  const best: Array<TokenScore> = [];
  for (let token = 0; token < logits.length; token++) {
    if (token === excludedToken) continue;
    const item: TokenScore = { token: token, score: logits[token] - logDenominator };
    let position = 0;
    while (position < best.length && (best[position].score > item.score ||
      (best[position].score === item.score && best[position].token < token))) position++;
    if (position < count) { best.splice(position, 0, item); if (best.length > count) best.pop(); }
  }
  return best;
}

function compareCompletedBeams(left: TranslationBeam, right: TranslationBeam): number {
  const score = normalizedBeamScore(right) - normalizedBeamScore(left);
  return score === 0 ? left.order - right.order : score;
}

function normalizedBeamScore(beam: TranslationBeam): number {
  return beam.score / Math.max(1, beam.normalizationLength);
}

function beamSearchDone(
  completed: Array<TranslationBeam>,
  bestRunningScore: number,
  length: number,
  beamCount: number
): boolean {
  if (completed.length < beamCount) return false;
  let worst = Number.POSITIVE_INFINITY;
  for (let index = 0; index < completed.length; index++) worst = Math.min(worst, normalizedBeamScore(completed[index]));
  return worst >= bestRunningScore / Math.max(1, length - 1);
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

function stableFiniteArgmax(logits: Float32Array, excludedToken: number = -1): number {
  if (logits.length === 0) {
    throw new Error('Translation logits are empty.');
  }
  let bestId = -1;
  let bestValue = Number.NEGATIVE_INFINITY;
  for (let index = 0; index < logits.length; index++) {
    const value = logits[index];
    if (!Number.isFinite(value)) {
      throw new Error('Translation logits contain a non-finite value.');
    }
    if (index !== excludedToken && value > bestValue) {
      bestValue = value;
      bestId = index;
    }
  }
  if (bestId < 0) throw new Error('Translation logits contain no selectable token.');
  return bestId;
}

function intTensor(name: string, shape: Array<number>, values: Array<number>): TranslationTensor {
  return { name: name, dtype: 'INT32', shape: shape, data: new Int32Array(values) };
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
  return checkedElementCount(shape, 'translation tensor shape');
}

function checkedElementCount(shape: Array<number>, path: string): number {
  let count = 1;
  for (let index = 0; index < shape.length; index++) {
    if (!Number.isInteger(shape[index]) || shape[index] <= 0 || count > 9007199254740991 / shape[index]) {
      throw new Error(`${path} element count overflows.`);
    }
    count *= shape[index];
  }
  return count;
}

function checkedDataSize(elementCount: number, bytesPerElement: number, path: string): number {
  if (!Number.isInteger(elementCount) || elementCount < 0 ||
    !Number.isInteger(bytesPerElement) || bytesPerElement <= 0 ||
    elementCount > 9007199254740991 / bytesPerElement) {
    throw new Error(`${path} byte size overflows.`);
  }
  return elementCount * bytesPerElement;
}

export interface TranslationMindSporeTensor {
  readonly name: string;
  readonly shape: Array<number>;
  readonly elementNum: number;
  readonly dataSize: number;
  readonly dtype: mindSporeLite.DataType;
  getData(): ArrayBuffer;
  setData(data: ArrayBuffer): void;
}

export interface TranslationMindSporeModel {
  getInputs(): Array<TranslationMindSporeTensor>;
  predict(inputs: Array<TranslationMindSporeTensor>): Promise<Array<TranslationMindSporeTensor>>;
}

export function createMindSporeLiteTranslationTensorSessionForTests(
  direction: TranslationDirectionManifest,
  encoder: TranslationMindSporeModel,
  decoder: TranslationMindSporeModel
): TranslationTensorSession {
  return new MindSporeLiteTranslationTensorSession(direction, encoder, decoder);
}

class TranslationMindSporeModelAdapter implements TranslationMindSporeModel {
  private readonly model: mindSporeLite.Model;

  constructor(model: mindSporeLite.Model) {
    this.model = model;
  }

  getInputs(): Array<TranslationMindSporeTensor> {
    return this.model.getInputs();
  }

  async predict(inputs: Array<TranslationMindSporeTensor>): Promise<Array<TranslationMindSporeTensor>> {
    return await this.model.predict(inputs as Array<mindSporeLite.MSTensor>);
  }
}

class MindSporeLiteTranslationTensorSession implements TranslationTensorSession {
  private readonly direction: TranslationDirectionManifest;
  private readonly encoder: TranslationMindSporeModel;
  private readonly decoder: TranslationMindSporeModel;
  private closed: boolean = false;

  constructor(
    direction: TranslationDirectionManifest,
    encoder: TranslationMindSporeModel,
    decoder: TranslationMindSporeModel
  ) {
    this.direction = direction;
    this.encoder = encoder;
    this.decoder = decoder;
    validateModelInputContract(encoder, direction.graphs.encoder, 'encoder');
    validateModelInputContract(decoder, direction.graphs.decoderFull, 'decoder_full');
  }

  async run(graph: TranslationGraphName, inputs: Array<TranslationTensor>): Promise<Array<TranslationTensor>> {
    if (this.closed) {
      throw new Error('Translation tensor session is closed.');
    }
    const model = this.modelForGraph(graph);
    const graphManifest = this.manifestForGraph(graph);
    const runtimeInputs = bindModelInputs(model, graphManifest, inputs, graph);
    const outputs = await model.predict(runtimeInputs);
    return bindModelOutputs(outputs, graphManifest, graph);
  }

  async close(): Promise<void> {
    this.closed = true;
  }

  private modelForGraph(graph: TranslationGraphName): TranslationMindSporeModel {
    return graph === 'encoder' ? this.encoder : this.decoder;
  }

  private manifestForGraph(graph: TranslationGraphName): TranslationGraphManifest {
    return graph === 'encoder' ? this.direction.graphs.encoder : this.direction.graphs.decoderFull;
  }
}

function validateModelInputContract(
  model: TranslationMindSporeModel,
  graph: TranslationGraphManifest,
  graphName: string
): void {
  const runtimeInputs = model.getInputs();
  if (runtimeInputs === undefined) {
    throw new Error(`${graphName} model returned no inputs after load.`);
  }
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
  model: TranslationMindSporeModel,
  graph: TranslationGraphManifest,
  inputs: Array<TranslationTensor>,
  graphName: string
): Array<TranslationMindSporeTensor> {
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
  actual: TranslationMindSporeTensor,
  expected: TranslationTensorManifest,
  path: string
): void {
  const count = checkedElementCount(expected.shape, `${path}.shape`);
  const dataSize = checkedDataSize(count, 4, path);
  if (actual.dtype !== mindSporeDataType(expected.dtype) || !sameShape(actual.shape, expected.shape) ||
    actual.elementNum !== count || actual.dataSize !== dataSize) {
    throw new Error(`${path} runtime tensor contract mismatch.`);
  }
}

function bindModelOutputs(
  outputs: Array<TranslationMindSporeTensor>,
  graph: TranslationGraphManifest,
  graphName: string
): Array<TranslationTensor> {
  if (outputs.length !== graph.outputs.length) {
    throw new Error(`${graphName} output count mismatch.`);
  }
  for (let index = 0; index < outputs.length; index++) {
    const expected = findTensorManifest(graph.outputs, outputs[index].name);
    if (expected === undefined || countNamedMindSporeTensors(outputs, outputs[index].name) !== 1) {
      throw new Error(`${graphName} returned an unexpected or duplicate output.`);
    }
    validateMindSporeTensorMetadata(outputs[index], expected, `${graphName}.${outputs[index].name}`);
  }

  const bound: Array<TranslationTensor> = [];
  for (let index = 0; index < graph.outputs.length; index++) {
    const output = findMindSporeTensor(outputs, graph.outputs[index].name);
    if (output === undefined) {
      throw new Error(`${graphName} output ${graph.outputs[index].name} is missing.`);
    }
    bound.push(translationTensorFromMindSpore(
      output,
      graph.outputs[index],
      `${graphName}.${graph.outputs[index].name}`
    ));
  }
  return bound;
}

function translationTensorFromMindSpore(
  tensor: TranslationMindSporeTensor,
  expected: TranslationTensorManifest,
  path: string
): TranslationTensor {
  const dtype = translationDataType(tensor.dtype);
  const buffer = tensor.getData();
  const expectedBytes = checkedDataSize(checkedElementCount(expected.shape, `${path}.shape`), 4, path);
  if (buffer.byteLength !== expectedBytes) {
    throw new Error(`${path} output buffer size mismatch.`);
  }
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

function findMindSporeTensor(
  tensors: Array<TranslationMindSporeTensor>,
  name: string
): TranslationMindSporeTensor | undefined {
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

function countNamedMindSporeTensors(tensors: Array<TranslationMindSporeTensor>, name: string): number {
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
  const en = manifest.directions.en;
  const zh = manifest.directions.zh;
  return [
    graphArchiveMember(en.graphs.encoder), graphArchiveMember(en.graphs.decoderFull),
    tokenizerArchiveMember(en.tokenizers.source),
    graphArchiveMember(zh.graphs.encoder), graphArchiveMember(zh.graphs.decoderFull),
    tokenizerArchiveMember(zh.tokenizers.source), tokenizerArchiveMember(zh.tokenizers.target)
  ];
}

function graphArchiveMember(graph: TranslationGraphManifest): TranslationArchiveMember {
  return { name: graph.file, size: graph.size, sha256: graph.sha256 };
}

function tokenizerArchiveMember(tokenizer: TranslationTokenizerManifest): TranslationArchiveMember {
  return { name: tokenizer.file, size: tokenizer.size, sha256: tokenizer.sha256 };
}

function tokenizerContract(direction: TranslationDirectionManifest, source: boolean): TranslationTokenizerContract {
  const tokenizer = source ? direction.tokenizers.source : direction.tokenizers.target;
  return { modelSha256: tokenizer.modelSha256, vocabularySha256: tokenizer.vocabularySha256,
    vocabularySize: direction.vocabulary.size, pieceCount: tokenizer.pieceCount,
    decodeVocabularySize: tokenizer.decodeVocabularySize, unknownId: direction.vocabulary.unk };
}

async function extractTranslationArchive(request: TranslationArchiveRequest): Promise<TranslationArchiveResult> {
  const namespace: ESObject = await import('libtranslation_archive.so');
  return await namespace.default.extractArchive(request) as TranslationArchiveResult;
}

function modelFilePath(directory: string, file: string): string {
  const separator = directory.endsWith('/') ? '' : '/';
  return `${directory}${separator}${file}`;
}

async function readVerifiedTranslationModel(
  path: string,
  graph: TranslationGraphManifest
): Promise<ArrayBuffer> {
  let file: fileIo.File | undefined = undefined;
  try {
    file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    const stat = await fileIo.stat(file.fd);
    if (!Number.isInteger(stat.size) || stat.size !== graph.size) {
      throw new Error(`${graph.file} size differs from the verified translation manifest.`);
    }
    return await readTranslationModelFully(file.fd, stat.size, graph.file);
  } finally {
    if (file !== undefined) {
      await fileIo.close(file);
    }
  }
}

async function readVerifiedTranslationText(path: string, size: number, fileName: string): Promise<string> {
  let file: fileIo.File | undefined = undefined;
  try {
    file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    const stat = await fileIo.stat(file.fd);
    if (!Number.isInteger(stat.size) || stat.size !== size) throw new Error(`${fileName} size differs from manifest.`);
    return asciiContentToText(new Uint8Array(await readTranslationModelFully(file.fd, stat.size, fileName)));
  } finally {
    if (file !== undefined) await fileIo.close(file);
  }
}

async function readTranslationModelFully(fd: number, size: number, fileName: string): Promise<ArrayBuffer> {
  const buffer = new ArrayBuffer(size);
  let copied = 0;
  while (copied < size) {
    const chunk = new ArrayBuffer(Math.min(1024 * 1024, size - copied));
    const bytesRead = await fileIo.read(fd, chunk, { offset: copied, length: chunk.byteLength });
    if (!Number.isInteger(bytesRead) || bytesRead <= 0 || bytesRead > chunk.byteLength) {
      throw new Error(`${fileName} could not be read completely.`);
    }
    new Uint8Array(buffer, copied, bytesRead).set(new Uint8Array(chunk, 0, bytesRead));
    copied += bytesRead;
  }
  return buffer;
}

export function asciiContentToText(content: Uint8Array): string {
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

async function closeBundle(bundle: TranslationModelBundle): Promise<void> {
  await bundle.requestQueue.runExclusive(async (): Promise<void> => {
    await closeSession(bundle.session);
  });
}

function failedTranslation(
  sourceText: string,
  targetLanguage: string,
  errorCode: 'EMPTY_INPUT' | 'UNSUPPORTED_TARGET' | 'DECODE_FAILED' | 'MODEL_EXECUTION_FAILED'
): TextTranslationResult {
  return {
    ok: false,
    sourceText: sourceText,
    translatedText: '',
    targetLanguage: targetLanguage,
    errorCode: errorCode
  };
}
