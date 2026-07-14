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
  readonly toEnglish: number;
  readonly toChinese: number;
}

export interface TranslationArchiveManifest {
  readonly file: string;
  readonly size: number;
  readonly sha256: string;
  readonly cacheKey: string;
}

export interface TranslationModelManifest {
  readonly schemaVersion: number;
  readonly vocabulary: TranslationVocabularyManifest;
  readonly archive: TranslationArchiveManifest;
  readonly graphs: Array<TranslationGraphManifest>;
}

export const translationManifestRawfilePath: string = 'models/translation/manifest.json';
export const translationTokenizerRuntimeRawfilePath: string = 'models/translation/tokenizer_runtime.json';
export const translationArchiveRawfilePath: string = 'models/translation/translation-models.tar.xz';

const SHA256_PATTERN: RegExp = /^[0-9A-Fa-f]{64}$/;

const ENCODER_INPUTS: Array<TranslationTensorManifest> = [
  tensor('input_ids', 'INT32', [1, 128]),
  tensor('attention_mask', 'INT32', [1, 128])
];
const ENCODER_OUTPUTS: Array<TranslationTensorManifest> = [
  tensor('last_hidden_state', 'FLOAT32', [1, 128, 256])
];
const PREFILL_INPUTS: Array<TranslationTensorManifest> = [
  tensor('decoder_input_ids', 'INT32', [1, 1]),
  tensor('encoder_hidden_states', 'FLOAT32', [1, 128, 256]),
  tensor('encoder_attention_mask', 'INT32', [1, 128])
];
const PREFILL_OUTPUTS: Array<TranslationTensorManifest> = [
  tensor('logits', 'FLOAT32', [1, 32003]),
  tensor('self_key_0', 'FLOAT32', [1, 8, 1, 32]),
  tensor('self_value_0', 'FLOAT32', [1, 8, 1, 32]),
  tensor('cross_key_0', 'FLOAT32', [1, 8, 128, 32]),
  tensor('cross_value_0', 'FLOAT32', [1, 8, 128, 32]),
  tensor('self_key_1', 'FLOAT32', [1, 8, 1, 32]),
  tensor('self_value_1', 'FLOAT32', [1, 8, 1, 32]),
  tensor('cross_key_1', 'FLOAT32', [1, 8, 128, 32]),
  tensor('cross_value_1', 'FLOAT32', [1, 8, 128, 32])
];
const STEP_INPUTS: Array<TranslationTensorManifest> = [
  tensor('decoder_input_ids', 'INT32', [1, 1]),
  tensor('position_id', 'INT32', [1]),
  tensor('self_attention_mask', 'INT32', [1, 128]),
  tensor('cross_attention_mask', 'INT32', [1, 128]),
  tensor('past_key_0', 'FLOAT32', [1, 8, 127, 32]),
  tensor('past_value_0', 'FLOAT32', [1, 8, 127, 32]),
  tensor('cross_key_0', 'FLOAT32', [1, 8, 128, 32]),
  tensor('cross_value_0', 'FLOAT32', [1, 8, 128, 32]),
  tensor('past_key_1', 'FLOAT32', [1, 8, 127, 32]),
  tensor('past_value_1', 'FLOAT32', [1, 8, 127, 32]),
  tensor('cross_key_1', 'FLOAT32', [1, 8, 128, 32]),
  tensor('cross_value_1', 'FLOAT32', [1, 8, 128, 32])
];
const STEP_OUTPUTS: Array<TranslationTensorManifest> = [
  tensor('logits', 'FLOAT32', [1, 32003]),
  tensor('new_key_0', 'FLOAT32', [1, 8, 1, 32]),
  tensor('new_value_0', 'FLOAT32', [1, 8, 1, 32]),
  tensor('new_key_1', 'FLOAT32', [1, 8, 1, 32]),
  tensor('new_value_1', 'FLOAT32', [1, 8, 1, 32])
];

export function parseTranslationModelManifest(content: string): TranslationModelManifest {
  let manifest: TranslationModelManifest;
  try {
    manifest = JSON.parse(content) as TranslationModelManifest;
  } catch (_) {
    throw new Error('Translation model manifest is not valid JSON.');
  }
  requireExactKeys(manifest, ['schemaVersion', 'vocabulary', 'archive', 'graphs'], '$');
  requireInteger(manifest.schemaVersion, 1, '$.schemaVersion');
  validateVocabulary(manifest.vocabulary);
  validateArchive(manifest.archive);
  if (!Array.isArray(manifest.graphs) || manifest.graphs.length !== 3) {
    throw new Error('$.graphs must contain exactly three graphs.');
  }
  validateGraph(manifest.graphs[0], 'encoder.ms', ENCODER_INPUTS, ENCODER_OUTPUTS, '$.graphs[0]');
  validateGraph(manifest.graphs[1], 'decoder_prefill.ms', PREFILL_INPUTS, PREFILL_OUTPUTS, '$.graphs[1]');
  validateGraph(manifest.graphs[2], 'decoder_step.ms', STEP_INPUTS, STEP_OUTPUTS, '$.graphs[2]');
  if (manifest.graphs[0].size + manifest.graphs[1].size + manifest.graphs[2].size > 60 * 1024 * 1024) {
    throw new Error('Uncompressed translation graphs exceed 60 MiB.');
  }
  return manifest;
}

function tensor(name: string, dtype: TranslationTensorDataType, shape: Array<number>): TranslationTensorManifest {
  return { name: name, dtype: dtype, shape: shape };
}

function validateVocabulary(value: TranslationVocabularyManifest): void {
  requireExactKeys(value, ['size', 'eos', 'unk', 'pad', 'decoderStart', 'toEnglish', 'toChinese'], '$.vocabulary');
  requireInteger(value.size, 32003, '$.vocabulary.size');
  requireInteger(value.eos, 0, '$.vocabulary.eos');
  requireInteger(value.unk, 1, '$.vocabulary.unk');
  requireInteger(value.pad, 32000, '$.vocabulary.pad');
  requireInteger(value.decoderStart, 32000, '$.vocabulary.decoderStart');
  requireInteger(value.toEnglish, 32001, '$.vocabulary.toEnglish');
  requireInteger(value.toChinese, 32002, '$.vocabulary.toChinese');
}

function validateArchive(value: TranslationArchiveManifest): void {
  requireExactKeys(value, ['file', 'size', 'sha256', 'cacheKey'], '$.archive');
  requireString(value.file, 'translation-models.tar.xz', '$.archive.file');
  requirePositiveInteger(value.size, '$.archive.size');
  requireSha256(value.sha256, '$.archive.sha256');
  requireString(value.cacheKey, 'ARCHIVE_SHA256', '$.archive.cacheKey');
  if (value.size > 32 * 1024 * 1024) {
    throw new Error('$.archive.size exceeds 32 MiB.');
  }
}

function validateGraph(
  value: TranslationGraphManifest,
  file: string,
  inputs: Array<TranslationTensorManifest>,
  outputs: Array<TranslationTensorManifest>,
  path: string
): void {
  requireExactKeys(value, ['file', 'size', 'sha256', 'inputs', 'outputs'], path);
  requireString(value.file, file, `${path}.file`);
  requirePositiveInteger(value.size, `${path}.size`);
  requireSha256(value.sha256, `${path}.sha256`);
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
