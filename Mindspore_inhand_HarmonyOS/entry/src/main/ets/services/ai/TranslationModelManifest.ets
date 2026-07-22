export type TranslationTensorDataType = 'INT32' | 'FLOAT32';

export interface TranslationTensorManifest {
  readonly name: string;
  readonly dtype: TranslationTensorDataType;
  readonly shape: Array<number>;
}

export interface TranslationGraphManifest {
  readonly file: string;
  readonly size: number;
  readonly sha256: string;
  readonly inputs: Array<TranslationTensorManifest>;
  readonly outputs: Array<TranslationTensorManifest>;
}

export interface TranslationVocabularyManifest {
  readonly size: number;
  readonly eos: number;
  readonly unk: number;
  readonly pad: number;
  readonly decoderStart: number;
}

export interface TranslationTokenizerManifest {
  readonly file: string;
  readonly size: number;
  readonly sha256: string;
  readonly modelSha256: string;
  readonly vocabularySha256: string;
  readonly pieceCount: number;
  readonly decodeVocabularySize: number;
  readonly specialTokens: TranslationSpecialTokensManifest;
}

export interface TranslationSpecialTokensManifest {
  readonly eos: string;
  readonly unk: string;
  readonly pad: string;
}

export interface TranslationGenerationManifest {
  readonly strategy: string;
  readonly numBeams: number;
  readonly sourcePrefix: string;
  readonly sourcePrefixTokenId: number;
  readonly sourceMaxTokens: number;
  readonly targetMaxTokens: number;
}

export interface TranslationDirectionManifest {
  readonly sourceLanguage: string;
  readonly targetLanguage: string;
  readonly repository: string;
  readonly revision: string;
  readonly generation: TranslationGenerationManifest;
  readonly vocabulary: TranslationVocabularyManifest;
  readonly tokenizers: TranslationTokenizerRolesManifest;
  readonly graphs: TranslationDirectionGraphsManifest;
  readonly graphBytes: number;
  readonly maxGraphBytes: number;
}

export interface TranslationTokenizerRolesManifest {
  readonly source: TranslationTokenizerManifest;
  readonly target: TranslationTokenizerManifest;
}

export interface TranslationDirectionGraphsManifest {
  readonly encoder: TranslationGraphManifest;
  readonly decoderFull: TranslationGraphManifest;
}

export interface TranslationDirectionsManifest {
  readonly en: TranslationDirectionManifest;
  readonly zh: TranslationDirectionManifest;
}

export interface TranslationArchiveManifest {
  readonly file: string;
  readonly size: number;
  readonly sha256: string;
  readonly cacheKey: string;
  readonly tarSize: number;
  readonly tarSha256: string;
  readonly maxArchiveBytes: number;
  readonly maxTarBytes: number;
}

export interface TranslationModelManifest {
  readonly schemaVersion: number;
  readonly archive: TranslationArchiveManifest;
  readonly directions: TranslationDirectionsManifest;
}

interface TranslationModelManifestWire {
  readonly schemaVersion: number;
  readonly archive: TranslationArchiveManifest;
  readonly directions: TranslationDirectionsManifest;
}

export const translationManifestRawfilePath: string = 'models/translation/manifest.json';
export const translationArchiveRawfilePath: string = 'models/translation/translation-models.tar.xz';

const SHA256_PATTERN: RegExp = /^[0-9a-f]{64}$/;
const MAX_TAR_BYTES: number = 208 * 1024 * 1024;
// Updated to the deterministic archive's measured value after package generation.
const MAX_ARCHIVE_BYTES: number = 152 * 1024 * 1024;
const ZH_EN_GRAPH_LIMIT: number = 36 * 1024 * 1024;
const EN_ZH_GRAPH_LIMIT: number = 147 * 1024 * 1024;

export function parseTranslationModelManifest(content: string): TranslationModelManifest {
  let manifest: TranslationModelManifestWire;
  try {
    manifest = JSON.parse(content) as TranslationModelManifestWire;
  } catch (_) {
    throw new Error('Translation model manifest is not valid JSON.');
  }
  requireExactKeys(manifest, ['schemaVersion', 'archive', 'directions'], '$');
  requireInteger(manifest.schemaVersion, 2, '$.schemaVersion');
  validateArchive(manifest.archive);
  requireExactKeys(manifest.directions, ['en', 'zh'], '$.directions');
  validateDirection(manifest.directions.en, 'en');
  validateDirection(manifest.directions.zh, 'zh');
  return manifest;
}

export function translationDirectionForTarget(
  manifest: TranslationModelManifest,
  targetLanguage: string
): TranslationDirectionManifest {
  if (targetLanguage === 'en') return manifest.directions.en;
  if (targetLanguage === 'zh') return manifest.directions.zh;
  throw new Error('Unsupported translation target.');
}

function validateArchive(value: TranslationArchiveManifest): void {
  requireExactKeys(value, [
    'file', 'size', 'sha256', 'cacheKey', 'tarSize', 'tarSha256',
    'maxArchiveBytes', 'maxTarBytes'
  ], '$.archive');
  requireString(value.file, 'translation-models.tar.xz', '$.archive.file');
  requireString(value.cacheKey, 'ARCHIVE_SHA256', '$.archive.cacheKey');
  requirePositiveInteger(value.size, '$.archive.size');
  requirePositiveInteger(value.tarSize, '$.archive.tarSize');
  requireSha256(value.sha256, '$.archive.sha256');
  requireSha256(value.tarSha256, '$.archive.tarSha256');
  requireInteger(value.maxArchiveBytes, MAX_ARCHIVE_BYTES, '$.archive.maxArchiveBytes');
  requireInteger(value.maxTarBytes, MAX_TAR_BYTES, '$.archive.maxTarBytes');
  if (value.size > MAX_ARCHIVE_BYTES || value.tarSize > MAX_TAR_BYTES) {
    throw new Error('Translation archive exceeds its measured package limit.');
  }
}

function validateDirection(value: TranslationDirectionManifest, targetKey: string): void {
  const path = `$.directions.${targetKey}`;
  requireExactKeys(value, [
    'sourceLanguage', 'targetLanguage', 'repository', 'revision', 'generation',
    'vocabulary', 'tokenizers', 'graphs', 'graphBytes', 'maxGraphBytes'
  ], path);
  const zhEn = targetKey === 'en';
  const name = zhEn ? 'zh-en' : 'en-zh';
  const hiddenSize = zhEn ? 256 : 512;
  const vocabularySize = zhEn ? 32001 : 65001;
  const graphLimit = zhEn ? ZH_EN_GRAPH_LIMIT : EN_ZH_GRAPH_LIMIT;
  requireString(value.sourceLanguage, zhEn ? 'zh' : 'en', `${path}.sourceLanguage`);
  requireString(value.targetLanguage, zhEn ? 'en' : 'zh', `${path}.targetLanguage`);
  requireString(
    value.repository,
    zhEn ? 'Helsinki-NLP/opus-mt_tiny_zho-eng' : 'Helsinki-NLP/opus-mt-en-zh',
    `${path}.repository`
  );
  requireString(
    value.revision,
    zhEn ? '4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd' :
      '408d9bc410a388e1d9aef112a2daba955b945255',
    `${path}.revision`
  );
  validateGeneration(value.generation, zhEn, `${path}.generation`);
  validateVocabulary(value.vocabulary, vocabularySize, `${path}.vocabulary`);
  validateTokenizers(value.tokenizers, name, zhEn, `${path}.tokenizers`);
  requireExactKeys(value.graphs, ['encoder', 'decoderFull'], `${path}.graphs`);
  validateGraph(
    value.graphs.encoder, `${name}/encoder.ms`,
    zhEn ? 16115736 : 55211640,
    zhEn ? '86a9272199af2b3699a3d873b69e5741de3e26da545de06180902df071ff91bb' :
      '4a1eae7e4b3600801b88df822bd42f786e9e34f715d12d0bac6454683599c5ee',
    encoderInputs(), [
    tensor('last_hidden_state', 'FLOAT32', [1, 128, hiddenSize])
  ], `${path}.graphs.encoder`);
  validateGraph(
    value.graphs.decoderFull, `${name}/decoder_full.ms`,
    zhEn ? 21247904 : 97121896,
    zhEn ? '8dc03af96ac9f7bf9efb37ffcc42a0034f5305810a0059cd7c3cb66e48a3550d' :
      '5046af7b4311c14676d099e6cd01839f9c3b910d437184017797e972e559e66e', [
    tensor('decoder_input_ids', 'INT32', [1, 32]),
    tensor('decoder_attention_mask', 'INT32', [1, 32]),
    tensor('encoder_hidden_states', 'FLOAT32', [1, 128, hiddenSize]),
    tensor('encoder_attention_mask', 'INT32', [1, 128])
  ], [tensor('logits', 'FLOAT32', [1, 32, vocabularySize])], `${path}.graphs.decoderFull`);
  requirePositiveInteger(value.graphBytes, `${path}.graphBytes`);
  requireInteger(value.maxGraphBytes, graphLimit, `${path}.maxGraphBytes`);
  if (value.graphBytes !== value.graphs.encoder.size + value.graphs.decoderFull.size ||
    value.graphBytes > graphLimit) {
    throw new Error(`${path}.graphBytes differs or exceeds its measured limit.`);
  }
}

function validateGeneration(value: TranslationGenerationManifest, zhEn: boolean, path: string): void {
  requireExactKeys(value, [
    'strategy', 'numBeams', 'sourcePrefix', 'sourcePrefixTokenId', 'sourceMaxTokens', 'targetMaxTokens'
  ], path);
  requireString(value.strategy, zhEn ? 'greedy' : 'beam', `${path}.strategy`);
  requireInteger(value.numBeams, zhEn ? 1 : 4, `${path}.numBeams`);
  requireString(value.sourcePrefix, zhEn ? '' : '>>cmn_Hans<< ', `${path}.sourcePrefix`);
  requireInteger(value.sourcePrefixTokenId, zhEn ? -1 : 5, `${path}.sourcePrefixTokenId`);
  requireInteger(value.sourceMaxTokens, 128, `${path}.sourceMaxTokens`);
  requireInteger(value.targetMaxTokens, 32, `${path}.targetMaxTokens`);
}

function validateVocabulary(value: TranslationVocabularyManifest, size: number, path: string): void {
  requireExactKeys(value, ['size', 'eos', 'unk', 'pad', 'decoderStart'], path);
  requireInteger(value.size, size, `${path}.size`);
  requireInteger(value.eos, 0, `${path}.eos`);
  requireInteger(value.unk, 1, `${path}.unk`);
  requireInteger(value.pad, size - 1, `${path}.pad`);
  requireInteger(value.decoderStart, size - 1, `${path}.decoderStart`);
}

function validateTokenizers(
  value: TranslationTokenizerRolesManifest,
  direction: string,
  shared: boolean,
  path: string
): void {
  requireExactKeys(value, ['source', 'target'], path);
  validateTokenizer(
    value.source, shared ? `${direction}/tokenizer.ttok` : `${direction}/source.ttok`,
    shared ? 'e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640' :
      '5775ddc9e3ff2fae91554da56468ad35ff56edaba870fea74447bc7234bfdaa8',
    shared ? '13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe' :
      'f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03',
    32000, shared ? 32001 : 0,
    `${path}.source`
  );
  validateTokenizer(
    value.target, shared ? `${direction}/tokenizer.ttok` : `${direction}/target.ttok`,
    shared ? 'e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640' :
      '81dc94efa84e4025ef38d25d5d07429fe41e3eb29d44003f1db6fe98487b0052',
    shared ? '13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe' :
      'f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03',
    shared ? 32000 : 0, shared ? 32001 : 65001,
    `${path}.target`
  );
  if (shared && !sameTokenizer(value.source, value.target)) {
    throw new Error(`${path} must reuse the identical tokenizer artifact.`);
  }
}

function sameTokenizer(left: TranslationTokenizerManifest, right: TranslationTokenizerManifest): boolean {
  return left.file === right.file && left.size === right.size && left.sha256 === right.sha256 &&
    left.modelSha256 === right.modelSha256 &&
    left.vocabularySha256 === right.vocabularySha256 && left.pieceCount === right.pieceCount &&
    left.decodeVocabularySize === right.decodeVocabularySize &&
    left.specialTokens.eos === right.specialTokens.eos &&
    left.specialTokens.unk === right.specialTokens.unk &&
    left.specialTokens.pad === right.specialTokens.pad;
}

function validateTokenizer(
  value: TranslationTokenizerManifest,
  file: string,
  modelSha256: string,
  vocabularySha256: string,
  pieceCount: number,
  decodeVocabularySize: number,
  path: string
): void {
  requireExactKeys(value, [
    'file', 'size', 'sha256', 'modelSha256', 'vocabularySha256', 'pieceCount',
    'decodeVocabularySize', 'specialTokens'
  ], path);
  requireString(value.file, file, `${path}.file`);
  requirePositiveInteger(value.size, `${path}.size`);
  requireSha256(value.sha256, `${path}.sha256`);
  requireString(value.modelSha256, modelSha256, `${path}.modelSha256`);
  requireString(value.vocabularySha256, vocabularySha256, `${path}.vocabularySha256`);
  requireInteger(value.pieceCount, pieceCount, `${path}.pieceCount`);
  requireInteger(value.decodeVocabularySize, decodeVocabularySize, `${path}.decodeVocabularySize`);
  requireExactKeys(value.specialTokens, ['eos', 'unk', 'pad'], `${path}.specialTokens`);
  requireString(value.specialTokens.eos, '</s>', `${path}.specialTokens.eos`);
  requireString(value.specialTokens.unk, '<unk>', `${path}.specialTokens.unk`);
  requireString(value.specialTokens.pad, '<pad>', `${path}.specialTokens.pad`);
}

function encoderInputs(): Array<TranslationTensorManifest> {
  return [
    tensor('input_ids', 'INT32', [1, 128]),
    tensor('attention_mask', 'INT32', [1, 128])
  ];
}

function tensor(
  name: string,
  dtype: TranslationTensorDataType,
  shape: Array<number>
): TranslationTensorManifest {
  return { name: name, dtype: dtype, shape: shape };
}

function validateGraph(
  value: TranslationGraphManifest,
  file: string,
  size: number,
  sha256: string,
  inputs: Array<TranslationTensorManifest>,
  outputs: Array<TranslationTensorManifest>,
  path: string
): void {
  requireExactKeys(value, ['file', 'size', 'sha256', 'inputs', 'outputs'], path);
  requireString(value.file, file, `${path}.file`);
  requireInteger(value.size, size, `${path}.size`);
  requireString(value.sha256, sha256, `${path}.sha256`);
  validateTensors(value.inputs, inputs, `${path}.inputs`);
  validateTensors(value.outputs, outputs, `${path}.outputs`);
}

function validateTensors(
  actual: Array<TranslationTensorManifest>,
  expected: Array<TranslationTensorManifest>,
  path: string
): void {
  if (!Array.isArray(actual) || actual.length !== expected.length) {
    throw new Error(`${path} tensor count mismatch.`);
  }
  for (let index = 0; index < expected.length; index++) {
    const tensorPath = `${path}[${index}]`;
    requireExactKeys(actual[index], ['name', 'dtype', 'shape'], tensorPath);
    requireString(actual[index].name, expected[index].name, `${tensorPath}.name`);
    requireString(actual[index].dtype, expected[index].dtype, `${tensorPath}.dtype`);
    if (!Array.isArray(actual[index].shape) || !sameShape(actual[index].shape, expected[index].shape)) {
      throw new Error(`${tensorPath}.shape mismatch.`);
    }
  }
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

function requireString(value: string, expected: string, path: string): void {
  if (typeof value !== 'string' || value !== expected) {
    throw new Error(`${path} mismatch.`);
  }
}

function requireSha256(value: string, path: string): void {
  if (typeof value !== 'string' || !SHA256_PATTERN.test(value)) {
    throw new Error(`${path} must be a SHA-256 string.`);
  }
}

function sameShape(actual: Array<number>, expected: Array<number>): boolean {
  if (actual.length !== expected.length) {
    return false;
  }
  for (let index = 0; index < expected.length; index++) {
    if (!Number.isInteger(actual[index]) || actual[index] !== expected[index]) {
      return false;
    }
  }
  return true;
}
