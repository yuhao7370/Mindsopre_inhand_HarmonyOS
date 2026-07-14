import { describe, it, expect } from '@ohos/hypium';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  TranslationChunk,
  configureTranslationTokenizer,
  configureTranslationTokenizerForTests,
  decodeTranslationTokens,
  encodeTranslationText,
  resetTranslationTokenizerForTests,
  translationTargetLanguageForText
} from '../main/ets/services/ai/TinyTranslationTokenizer';
import {
  TOKENIZER_DECODE_GOLDENS,
  TOKENIZER_GOLDEN_CASES,
  TOKENIZER_RUNTIME_FIXTURE,
  TranslationTokenizerGoldenCase,
  TranslationTokenizerGoldenChunk
} from './TranslationTokenizerFixture';
import {
  TranslationGraphManifest,
  TranslationModelManifest,
  TranslationTensorManifest,
  parseTranslationModelManifest
} from '../main/ets/services/ai/TranslationModelManifest';
import {
  createMindSporeLiteTranslationTensorSessionForTests,
  MindSporeLiteTranslationRunner,
  productionTranslationModelBundleFactory,
  TranslationMindSporeModel,
  TranslationMindSporeTensor,
  TranslationModelBundle,
  TranslationModelResourceManager,
  TranslationRawFileDescriptor,
  TranslationRequestQueue,
  TranslationTensor,
  TranslationTensorSession,
  resetTranslationModelCacheForTests
} from '../main/ets/services/ai/MindSporeLiteTranslationRunner';

function assertStringArrayEqual(actual: Array<string>, expected: Array<string>): void {
  expect(actual.length).assertEqual(expected.length);
  for (let index = 0; index < expected.length; index++) {
    expect(actual[index]).assertEqual(expected[index]);
  }
}

function assertNumberArrayEqual(actual: Array<number>, expected: Array<number>): void {
  expect(actual.length).assertEqual(expected.length);
  for (let index = 0; index < expected.length; index++) {
    expect(actual[index]).assertEqual(expected[index]);
  }
}

function findGolden(name: string): TranslationTokenizerGoldenCase {
  for (let index = 0; index < TOKENIZER_GOLDEN_CASES.length; index++) {
    if (TOKENIZER_GOLDEN_CASES[index].name === name) {
      return TOKENIZER_GOLDEN_CASES[index];
    }
  }
  throw new Error(`Missing tokenizer golden ${name}`);
}

function assertChunk(actual: TranslationChunk, expected: TranslationTokenizerGoldenChunk): void {
  expect(actual.sourceText).assertEqual(expected.sourceText);
  expect(actual.normalized).assertEqual(expected.normalized);
  assertStringArrayEqual(actual.pieces, expected.pieces);
  assertNumberArrayEqual(actual.pieceIds, expected.pieceIds);
  expect(actual.separatorBefore).assertEqual(expected.separatorBefore);
  expect(actual.separatorAfter).assertEqual(expected.separatorAfter);
  expect(actual.inputIds.length).assertEqual(128);
  expect(actual.attentionMask.length).assertEqual(128);
  expect(actual.inputIds[0]).assertEqual(expected.directionId);
  for (let index = 0; index < expected.pieceIds.length; index++) {
    expect(actual.inputIds[index + 1]).assertEqual(expected.pieceIds[index]);
  }
  const eosIndex = expected.pieceIds.length + 1;
  expect(actual.inputIds[eosIndex]).assertEqual(0);
  expect(actual.attentionMask[eosIndex]).assertEqual(1);
  for (let index = eosIndex + 1; index < 128; index++) {
    expect(actual.inputIds[index]).assertEqual(32000);
    expect(actual.attentionMask[index]).assertEqual(0);
  }
  expect(decodeTranslationTokens(actual.inputIds)).assertEqual(expected.decoded);
}

function assertThrows(action: () => void): void {
  let threw = false;
  try {
    action();
  } catch (_) {
    threw = true;
  }
  expect(threw).assertTrue();
}

function asciiCodepoints(text: string): string {
  const values: Array<string> = [];
  for (let index = 0; index < text.length; index++) {
    values.push(text.charCodeAt(index).toString(16).toUpperCase());
  }
  return values.join(',');
}

function buildFullRuntimeTable(): string {
  const lines: Array<string> = [
    'TTOK1\te5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640\t32000\t1\t-20\t1\t1\t1',
    'N\tFF21\t41',
    'P\t0\t0\t3\t3C,2F,73,3E',
    'P\t1\t0\t2\t3C,75,6E,6B,3E'
  ];
  for (let id = 2; id < 32000; id++) {
    lines.push(`P\t${id}\t-1\t1\t${asciiCodepoints(`p${id}`)}`);
  }
  return lines.join('\n');
}

function reconstructedSource(chunks: Array<TranslationChunk>): string {
  let source = '';
  for (let index = 0; index < chunks.length; index++) {
    source += chunks[index].separatorBefore + chunks[index].sourceText + chunks[index].separatorAfter;
  }
  return source;
}

const FULL_RUNTIME_TABLE = buildFullRuntimeTable();

function manifestTensor(name: string, dtype: 'INT32' | 'FLOAT32', shape: Array<number>): TranslationTensorManifest {
  return { name: name, dtype: dtype, shape: shape };
}

function manifestGraph(
  file: string,
  inputs: Array<TranslationTensorManifest>,
  outputs: Array<TranslationTensorManifest>
): TranslationGraphManifest {
  return {
    file: file,
    size: 100,
    sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    inputs: inputs,
    outputs: outputs
  };
}

function validTranslationManifest(): TranslationModelManifest {
  const manifest: TranslationModelManifest = {
    schemaVersion: 1,
    vocabulary: {
      size: 32003,
      eos: 0,
      unk: 1,
      pad: 32000,
      decoderStart: 32000,
      toEnglish: 32001,
      toChinese: 32002
    },
    archive: {
      file: 'translation-models.tar.xz',
      size: 123,
      sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      cacheKey: 'ARCHIVE_SHA256'
    },
    graphs: [
      manifestGraph('encoder.ms', [
        manifestTensor('input_ids', 'INT32', [1, 128]),
        manifestTensor('attention_mask', 'INT32', [1, 128])
      ], [manifestTensor('last_hidden_state', 'FLOAT32', [1, 128, 256])]),
      manifestGraph('decoder_prefill.ms', [
        manifestTensor('decoder_input_ids', 'INT32', [1, 1]),
        manifestTensor('encoder_hidden_states', 'FLOAT32', [1, 128, 256]),
        manifestTensor('encoder_attention_mask', 'INT32', [1, 128])
      ], [
        manifestTensor('logits', 'FLOAT32', [1, 32003]),
        manifestTensor('self_key_0', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('self_value_0', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('cross_key_0', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('cross_value_0', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('self_key_1', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('self_value_1', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('cross_key_1', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('cross_value_1', 'FLOAT32', [1, 8, 128, 32])
      ]),
      manifestGraph('decoder_step.ms', [
        manifestTensor('decoder_input_ids', 'INT32', [1, 1]),
        manifestTensor('position_id', 'INT32', [1]),
        manifestTensor('self_attention_mask', 'INT32', [1, 128]),
        manifestTensor('cross_attention_mask', 'INT32', [1, 128]),
        manifestTensor('past_key_0', 'FLOAT32', [1, 8, 127, 32]),
        manifestTensor('past_value_0', 'FLOAT32', [1, 8, 127, 32]),
        manifestTensor('cross_key_0', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('cross_value_0', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('past_key_1', 'FLOAT32', [1, 8, 127, 32]),
        manifestTensor('past_value_1', 'FLOAT32', [1, 8, 127, 32]),
        manifestTensor('cross_key_1', 'FLOAT32', [1, 8, 128, 32]),
        manifestTensor('cross_value_1', 'FLOAT32', [1, 8, 128, 32])
      ], [
        manifestTensor('logits', 'FLOAT32', [1, 32003]),
        manifestTensor('new_key_0', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('new_value_0', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('new_key_1', 'FLOAT32', [1, 8, 1, 32]),
        manifestTensor('new_value_1', 'FLOAT32', [1, 8, 1, 32])
      ])
    ]
  };
  return manifest;
}

function validTranslationManifestText(): string {
  return JSON.stringify(validTranslationManifest());
}

function intData(tensor: TranslationTensor): Int32Array {
  if (!(tensor.data instanceof Int32Array)) {
    throw new Error(`${tensor.name} is not INT32.`);
  }
  return tensor.data;
}

function floatData(tensor: TranslationTensor): Float32Array {
  if (!(tensor.data instanceof Float32Array)) {
    throw new Error(`${tensor.name} is not FLOAT32.`);
  }
  return tensor.data;
}

function outputTensor(
  name: string,
  dtype: 'INT32' | 'FLOAT32',
  shape: Array<number>,
  data: Int32Array | Float32Array
): TranslationTensor {
  return { name: name, dtype: dtype, shape: shape, data: data };
}

function cacheSlot(value: number): Float32Array {
  const data = new Float32Array(8 * 32);
  for (let head = 0; head < 8; head++) {
    data[head * 32] = value + head * 100;
  }
  return data;
}

function logitsForToken(token: number): Float32Array {
  const data = new Float32Array(32003);
  data.fill(-1000);
  data[token] = 1;
  return data;
}

class FakeTranslationSession implements TranslationTensorSession {
  readonly tokens: Array<number>;
  readonly positions: Array<number> = [];
  readonly selfMaskCounts: Array<number> = [];
  readonly seenDecoderTokens: Array<number> = [];
  encoderCalls: number = 0;
  prefillCalls: number = 0;
  stepCalls: number = 0;
  closeCalls: number = 0;
  retainedCrossCaches: boolean = true;
  firstPastHeadOneValue: number = -1;
  malformedMode: string = '';
  tieToken: number = -1;
  private stepInChunk: number = 0;
  private crossData: Array<Float32Array> = [];

  constructor(tokens: Array<number>) {
    this.tokens = tokens;
  }

  async run(graph: 'encoder' | 'decoder_prefill' | 'decoder_step', inputs: Array<TranslationTensor>):
    Promise<Array<TranslationTensor>> {
    if (graph === 'encoder') {
      this.encoderCalls++;
      this.stepInChunk = 0;
      expect(inputs.length).assertEqual(2);
      return [outputTensor(
        'last_hidden_state', 'FLOAT32', [1, 128, 256], new Float32Array(128 * 256)
      )];
    }
    if (graph === 'decoder_prefill') {
      this.prefillCalls++;
      expect(intData(inputs[0])[0]).assertEqual(32000);
      expect(inputs[1].name).assertEqual('encoder_hidden_states');
      const logits = logitsForToken(this.tokens[0]);
      if (this.tieToken >= 0) {
        logits[this.tieToken] = 1;
      }
      if (this.malformedMode === 'nan') {
        logits[0] = Number.NaN;
      }
      const cross0 = new Float32Array(8 * 128 * 32);
      const cross1 = new Float32Array(8 * 128 * 32);
      const cross2 = new Float32Array(8 * 128 * 32);
      const cross3 = new Float32Array(8 * 128 * 32);
      this.crossData = [cross0, cross1, cross2, cross3];
      const outputs: Array<TranslationTensor> = [
        outputTensor('logits', 'FLOAT32', [1, 32003], logits),
        outputTensor('self_key_0', 'FLOAT32', [1, 8, 1, 32], cacheSlot(10)),
        outputTensor('self_value_0', 'FLOAT32', [1, 8, 1, 32], cacheSlot(20)),
        outputTensor('cross_key_0', 'FLOAT32', [1, 8, 128, 32], cross0),
        outputTensor('cross_value_0', 'FLOAT32', [1, 8, 128, 32], cross1),
        outputTensor('self_key_1', 'FLOAT32', [1, 8, 1, 32], cacheSlot(30)),
        outputTensor('self_value_1', 'FLOAT32', [1, 8, 1, 32], cacheSlot(40)),
        outputTensor('cross_key_1', 'FLOAT32', [1, 8, 128, 32], cross2),
        outputTensor('cross_value_1', 'FLOAT32', [1, 8, 128, 32], cross3)
      ];
      if (this.malformedMode === 'missing') {
        outputs.pop();
      } else if (this.malformedMode === 'extra') {
        outputs.push(outputTensor('extra', 'FLOAT32', [1], new Float32Array(1)));
      } else if (this.malformedMode === 'shape') {
        outputs[0] = outputTensor('logits', 'FLOAT32', [32003], logits);
      } else if (this.malformedMode === 'dtype') {
        outputs[0] = outputTensor('logits', 'INT32', [1, 32003], new Int32Array(32003));
      } else if (this.malformedMode === 'duplicate') {
        outputs[8] = outputTensor('logits', 'FLOAT32', [1, 32003], logits);
      }
      return outputs;
    }
    this.stepCalls++;
    const position = intData(inputs[1])[0];
    this.positions.push(position);
    this.seenDecoderTokens.push(intData(inputs[0])[0]);
    let maskCount = 0;
    const mask = intData(inputs[2]);
    for (let index = 0; index < mask.length; index++) {
      maskCount += mask[index];
    }
    this.selfMaskCounts.push(maskCount);
    if (this.stepCalls === 1) {
      this.firstPastHeadOneValue = floatData(inputs[4])[(1 * 127) * 32];
    }
    const crossInputs: Array<TranslationTensor> = [inputs[6], inputs[7], inputs[10], inputs[11]];
    for (let index = 0; index < crossInputs.length; index++) {
      if (floatData(crossInputs[index]) !== this.crossData[index]) {
        this.retainedCrossCaches = false;
      }
    }
    this.stepInChunk++;
    const tokenIndex = Math.min(this.stepInChunk, this.tokens.length - 1);
    return [
      outputTensor('logits', 'FLOAT32', [1, 32003], logitsForToken(this.tokens[tokenIndex])),
      outputTensor('new_key_0', 'FLOAT32', [1, 8, 1, 32], cacheSlot(10 + position)),
      outputTensor('new_value_0', 'FLOAT32', [1, 8, 1, 32], cacheSlot(20 + position)),
      outputTensor('new_key_1', 'FLOAT32', [1, 8, 1, 32], cacheSlot(30 + position)),
      outputTensor('new_value_1', 'FLOAT32', [1, 8, 1, 32], cacheSlot(40 + position))
    ];
  }

  async close(): Promise<void> {
    this.closeCalls++;
  }
}

class MissingTranslationResources implements TranslationModelResourceManager {
  async getRawFileContent(_path: string): Promise<Uint8Array> {
    throw new Error('missing rawfile');
  }

  async getRawFd(_path: string): Promise<TranslationRawFileDescriptor> {
    throw new Error('missing rawfile');
  }

  async closeRawFd(_path: string): Promise<void> {
  }
}

class FakeMindSporeTensor implements TranslationMindSporeTensor {
  name: string;
  shape: Array<number>;
  elementNum: number;
  dataSize: number;
  dtype: mindSporeLite.DataType;
  getDataCalls: number = 0;
  setDataCalls: number = 0;
  private data: ArrayBuffer;

  constructor(
    name: string,
    shape: Array<number>,
    elementNum: number,
    dataSize: number,
    dtype: mindSporeLite.DataType,
    data: ArrayBuffer
  ) {
    this.name = name;
    this.shape = shape;
    this.elementNum = elementNum;
    this.dataSize = dataSize;
    this.dtype = dtype;
    this.data = data;
  }

  getData(): ArrayBuffer {
    this.getDataCalls++;
    return this.data;
  }

  setData(data: ArrayBuffer): void {
    this.setDataCalls++;
    const copy = new ArrayBuffer(data.byteLength);
    new Uint8Array(copy).set(new Uint8Array(data));
    this.data = copy;
  }
}

class FakeMindSporeModel implements TranslationMindSporeModel {
  readonly inputs: Array<FakeMindSporeTensor>;
  readonly outputsByCall: Array<Array<FakeMindSporeTensor>>;
  predictCalls: number = 0;
  failFirstPredict: boolean = false;
  private firstPredictGate: Promise<void> | undefined = undefined;
  private firstPredictResolver: (() => void) | undefined = undefined;

  constructor(
    inputs: Array<FakeMindSporeTensor>,
    outputsByCall: Array<Array<FakeMindSporeTensor>>
  ) {
    this.inputs = inputs;
    this.outputsByCall = outputsByCall;
  }

  getInputs(): Array<TranslationMindSporeTensor> {
    return this.inputs;
  }

  blockFirstPredict(): void {
    this.firstPredictGate = new Promise<void>((resolve: () => void) => {
      this.firstPredictResolver = resolve;
    });
  }

  releaseFirstPredict(): void {
    if (this.firstPredictResolver !== undefined) {
      this.firstPredictResolver();
      this.firstPredictResolver = undefined;
    }
  }

  async predict(_inputs: Array<TranslationMindSporeTensor>): Promise<Array<TranslationMindSporeTensor>> {
    this.predictCalls++;
    if (this.predictCalls === 1 && this.firstPredictGate !== undefined) {
      await this.firstPredictGate;
    }
    if (this.predictCalls === 1 && this.failFirstPredict) {
      throw new Error('scripted prediction failure');
    }
    const outputIndex = Math.min(this.predictCalls - 1, this.outputsByCall.length - 1);
    return this.outputsByCall[outputIndex];
  }
}

function manifestElementCount(tensor: TranslationTensorManifest): number {
  let count = 1;
  for (let index = 0; index < tensor.shape.length; index++) {
    count *= tensor.shape[index];
  }
  return count;
}

function fakeMindSporeTensor(
  tensor: TranslationTensorManifest,
  token: number = -1
): FakeMindSporeTensor {
  const count = manifestElementCount(tensor);
  const buffer = new ArrayBuffer(count * 4);
  if (token >= 0 && tensor.name === 'logits') {
    const logits = new Float32Array(buffer);
    logits.fill(-1000);
    logits[token] = 1;
  }
  return new FakeMindSporeTensor(
    tensor.name,
    tensor.shape.slice(),
    count,
    count * 4,
    tensor.dtype === 'INT32' ?
      mindSporeLite.DataType.NUMBER_TYPE_INT32 : mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
    buffer
  );
}

function fakeMindSporeTensors(
  tensors: Array<TranslationTensorManifest>,
  token: number = -1
): Array<FakeMindSporeTensor> {
  const result: Array<FakeMindSporeTensor> = [];
  for (let index = 0; index < tensors.length; index++) {
    result.push(fakeMindSporeTensor(tensors[index], token));
  }
  return result;
}

function encoderTranslationInputs(): Array<TranslationTensor> {
  return [
    outputTensor('input_ids', 'INT32', [1, 128], new Int32Array(128)),
    outputTensor('attention_mask', 'INT32', [1, 128], new Int32Array(128))
  ];
}

function fakeAdapterSession(
  manifest: TranslationModelManifest,
  encoder: FakeMindSporeModel,
  prefill?: FakeMindSporeModel,
  step?: FakeMindSporeModel
): TranslationTensorSession {
  const prefillModel = prefill ?? new FakeMindSporeModel(
    fakeMindSporeTensors(manifest.graphs[1].inputs),
    [fakeMindSporeTensors(manifest.graphs[1].outputs, 0)]
  );
  const stepModel = step ?? new FakeMindSporeModel(
    fakeMindSporeTensors(manifest.graphs[2].inputs),
    [fakeMindSporeTensors(manifest.graphs[2].outputs, 0)]
  );
  return createMindSporeLiteTranslationTensorSessionForTests(manifest, encoder, prefillModel, stepModel);
}

async function expectEncoderRunRejected(session: TranslationTensorSession): Promise<void> {
  let rejected = false;
  try {
    await session.run('encoder', encoderTranslationInputs());
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
}

async function flushTranslationMicrotasks(): Promise<void> {
  for (let index = 0; index < 12; index++) {
    await Promise.resolve();
  }
}

function bundleFor(session: TranslationTensorSession): TranslationModelBundle {
  return {
    manifest: validTranslationManifest(),
    session: session,
    requestQueue: new TranslationRequestQueue()
  };
}

function runnerFor(session: TranslationTensorSession): MindSporeLiteTranslationRunner {
  return new MindSporeLiteTranslationRunner({
    bundleFactory: async (): Promise<TranslationModelBundle> => bundleFor(session)
  });
}

export default function translationModelUnitTest(): void {
  describe('TranslationModelUnit', () => {
    it('acceptsOnlyTheFinalPackageRuntimeManifestContract', 0, () => {
      const parsed = parseTranslationModelManifest(validTranslationManifestText());
      expect(parsed.graphs.length).assertEqual(3);
      expect(parsed.graphs[2].inputs[4].name).assertEqual('past_key_0');
      expect(parsed.graphs[2].inputs[4].shape.join(',')).assertEqual('1,8,127,32');
      const valid = validTranslationManifestText();
      assertThrows((): void => { parseTranslationModelManifest(valid.replace('32003', '32004')); });
      assertThrows((): void => { parseTranslationModelManifest(valid.replace('encoder.ms', 'encoder2.ms')); });
      assertThrows((): void => { parseTranslationModelManifest(valid.replace('INT32', 'INT64')); });
      assertThrows((): void => { parseTranslationModelManifest(valid.replace('[1,128]', '[1,127]')); });
      assertThrows((): void => { parseTranslationModelManifest(valid.replace('aaaaaaaa', 'notahash')); });
      assertThrows((): void => {
        parseTranslationModelManifest(valid.replace('"schemaVersion":1', '"schemaVersion":1,"extra":1'));
      });
    });

    it('rejectsAllInvalidProductionOutputMetadataBeforeReadingAnyBuffer', 0, async () => {
      const modes: Array<string> = [
        'unknownDtype', 'shape', 'elementNum', 'shortDataSize', 'oversizedDataSize',
        'missing', 'extra', 'duplicate'
      ];
      for (let modeIndex = 0; modeIndex < modes.length; modeIndex++) {
        const manifest = validTranslationManifest();
        const expected = manifest.graphs[0].outputs[0];
        const valid = fakeMindSporeTensor(expected);
        const outputs: Array<FakeMindSporeTensor> = [valid];
        if (modes[modeIndex] === 'unknownDtype') {
          valid.dtype = mindSporeLite.DataType.TYPE_UNKNOWN;
        } else if (modes[modeIndex] === 'shape') {
          valid.shape = [1, 32768];
        } else if (modes[modeIndex] === 'elementNum') {
          valid.elementNum--;
        } else if (modes[modeIndex] === 'shortDataSize') {
          valid.dataSize -= 4;
        } else if (modes[modeIndex] === 'oversizedDataSize') {
          valid.dataSize += 4;
        } else if (modes[modeIndex] === 'missing') {
          outputs.pop();
        } else if (modes[modeIndex] === 'extra') {
          outputs.push(new FakeMindSporeTensor(
            'extra', [1], 1, 4, mindSporeLite.DataType.NUMBER_TYPE_FLOAT32, new ArrayBuffer(4)
          ));
        } else if (modes[modeIndex] === 'duplicate') {
          manifest.graphs[0].outputs.push(manifestTensor('second_output', 'FLOAT32', [1]));
          outputs.push(fakeMindSporeTensor(expected));
        }
        const encoder = new FakeMindSporeModel(
          fakeMindSporeTensors(manifest.graphs[0].inputs),
          [outputs]
        );
        await expectEncoderRunRejected(fakeAdapterSession(manifest, encoder));
        for (let outputIndex = 0; outputIndex < outputs.length; outputIndex++) {
          expect(outputs[outputIndex].getDataCalls).assertEqual(0);
        }
      }
    });

    it('rejectsShortAndOversizedProductionOutputBuffersAfterOneBoundedRead', 0, async () => {
      const byteDeltas: Array<number> = [-4, 4];
      for (let deltaIndex = 0; deltaIndex < byteDeltas.length; deltaIndex++) {
        const manifest = validTranslationManifest();
        const expected = manifest.graphs[0].outputs[0];
        const count = manifestElementCount(expected);
        const output = new FakeMindSporeTensor(
          expected.name,
          expected.shape.slice(),
          count,
          count * 4,
          mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          new ArrayBuffer(count * 4 + byteDeltas[deltaIndex])
        );
        const encoder = new FakeMindSporeModel(
          fakeMindSporeTensors(manifest.graphs[0].inputs),
          [[output]]
        );
        await expectEncoderRunRejected(fakeAdapterSession(manifest, encoder));
        expect(output.getDataCalls).assertEqual(1);
      }
    });

    it('serializesProductionModelMutationAcrossTheWholeTranslationRequest', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const manifest = validTranslationManifest();
      const firstEncoderOutput = fakeMindSporeTensors(manifest.graphs[0].outputs);
      const secondEncoderOutput = fakeMindSporeTensors(manifest.graphs[0].outputs);
      const encoder = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[0].inputs),
        [firstEncoderOutput, secondEncoderOutput]
      );
      const prefill = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[1].inputs),
        [
          fakeMindSporeTensors(manifest.graphs[1].outputs, 12249),
          fakeMindSporeTensors(manifest.graphs[1].outputs, 192)
        ]
      );
      prefill.blockFirstPredict();
      const step = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[2].inputs),
        [
          fakeMindSporeTensors(manifest.graphs[2].outputs, 0),
          fakeMindSporeTensors(manifest.graphs[2].outputs, 0)
        ]
      );
      const session = fakeAdapterSession(manifest, encoder, prefill, step);
      const bundle: TranslationModelBundle = {
        manifest: manifest,
        session: session,
        requestQueue: new TranslationRequestQueue()
      };
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => bundle
      });

      const firstResultPromise = runner.translate('first', 'zh');
      const secondResultPromise = runner.translate('second', 'zh');
      await flushTranslationMicrotasks();
      expect(encoder.predictCalls).assertEqual(1);
      expect(encoder.inputs[0].setDataCalls).assertEqual(1);
      expect(encoder.inputs[1].setDataCalls).assertEqual(1);
      expect(firstEncoderOutput[0].getDataCalls).assertEqual(1);
      expect(prefill.predictCalls).assertEqual(1);
      expect(prefill.inputs[0].setDataCalls).assertEqual(1);
      resetTranslationModelCacheForTests();
      prefill.releaseFirstPredict();

      const results = await Promise.all([firstResultPromise, secondResultPromise]);
      expect(results[0].ok).assertTrue();
      expect(results[1].ok).assertTrue();
      expect(results[0].translatedText).assertEqual(decodeTranslationTokens([12249]));
      expect(results[1].translatedText).assertEqual(decodeTranslationTokens([192]));
      expect(encoder.predictCalls).assertEqual(2);
      expect(prefill.predictCalls).assertEqual(2);
      expect(step.predictCalls).assertEqual(2);
      expect(encoder.inputs[0].setDataCalls).assertEqual(2);
      await flushTranslationMicrotasks();
      await expectEncoderRunRejected(session);
    });

    it('releasesProductionRequestQueueAfterPredictionFailure', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const manifest = validTranslationManifest();
      const encoder = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[0].inputs),
        [
          fakeMindSporeTensors(manifest.graphs[0].outputs),
          fakeMindSporeTensors(manifest.graphs[0].outputs)
        ]
      );
      const prefill = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[1].inputs),
        [
          fakeMindSporeTensors(manifest.graphs[1].outputs, 12249),
          fakeMindSporeTensors(manifest.graphs[1].outputs, 192)
        ]
      );
      prefill.failFirstPredict = true;
      const step = new FakeMindSporeModel(
        fakeMindSporeTensors(manifest.graphs[2].inputs),
        [fakeMindSporeTensors(manifest.graphs[2].outputs, 0)]
      );
      const session = fakeAdapterSession(manifest, encoder, prefill, step);
      const bundle: TranslationModelBundle = {
        manifest: manifest,
        session: session,
        requestQueue: new TranslationRequestQueue()
      };
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => bundle
      });

      const results = await Promise.all([
        runner.translate('first', 'zh'), runner.translate('second', 'zh')
      ]);
      expect(results[0].ok).assertFalse();
      expect(results[1].ok).assertTrue();
      expect(results[1].translatedText).assertEqual(decodeTranslationTokens([192]));
      expect(encoder.predictCalls).assertEqual(2);
      expect(prefill.predictCalls).assertEqual(2);
      expect(step.predictCalls).assertEqual(1);
    });

    it('runsEncoderPrefillAndStepWithExactCacheEvolution', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const session = new FakeTranslationSession([12249, 192, 0]);
      const result = await runnerFor(session).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(result.runtimeSource).assertEqual('localModel');
      expect(result.translatedText).assertEqual(decodeTranslationTokens([12249, 192]));
      expect(session.encoderCalls).assertEqual(1);
      expect(session.prefillCalls).assertEqual(1);
      expect(session.stepCalls).assertEqual(2);
      assertNumberArrayEqual(session.positions, [1, 2]);
      assertNumberArrayEqual(session.selfMaskCounts, [2, 3]);
      assertNumberArrayEqual(session.seenDecoderTokens, [12249, 192]);
      expect(session.firstPastHeadOneValue).assertEqual(110);
      expect(session.retainedCrossCaches).assertTrue();
    });

    it('usesStableSmallestIdArgmaxAndStopsAtEos', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const session = new FakeTranslationSession([12249, 0]);
      session.tieToken = 192;
      const result = await runnerFor(session).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual(decodeTranslationTokens([192]));
      expect(session.stepCalls).assertEqual(1);
    });

    it('runsEachChunkOnceAndPreservesEverySeparator', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const source = findGolden('multiple_newlines').text;
      const chunks = encodeTranslationText(source, 'zh');
      const session = new FakeTranslationSession([12249, 0]);
      const result = await runnerFor(session).translate(source, 'zh');
      let expectedText = '';
      for (let index = 0; index < chunks.length; index++) {
        expectedText += chunks[index].separatorBefore + 'Hello' + chunks[index].separatorAfter;
      }
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual(expectedText);
      expect(session.encoderCalls).assertEqual(chunks.length);
      expect(session.prefillCalls).assertEqual(chunks.length);
      expect(session.stepCalls).assertEqual(chunks.length);
    });

    it('stopsAtExactly128GeneratedTokensWithoutWritingPastSlot127', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const session = new FakeTranslationSession([12249]);
      const result = await runnerFor(session).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(session.stepCalls).assertEqual(127);
      expect(session.positions[0]).assertEqual(1);
      expect(session.positions[126]).assertEqual(127);
      expect(decodeTranslationTokens(new Array<number>(128).fill(12249))).assertEqual(result.translatedText);
    });

    it('failsClosedForMalformedAndNonFiniteModelOutputs', 0, async () => {
      const modes: Array<string> = ['missing', 'extra', 'shape', 'dtype', 'duplicate', 'nan'];
      for (let index = 0; index < modes.length; index++) {
        resetTranslationModelCacheForTests();
        configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
        const session = new FakeTranslationSession([12249, 0]);
        session.malformedMode = modes[index];
        const result = await runnerFor(session).translate('hello', 'zh');
        expect(result.ok).assertFalse();
        expect(result.translatedText).assertEqual('');
        expect(result.runtimeSource === undefined).assertTrue();
      }
    });

    it('rejectsEmptyOutputAndUnsupportedTargetWithoutFallbackOrLoad', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      let loadCalls = 0;
      const session = new FakeTranslationSession([0]);
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          loadCalls++;
          return bundleFor(session);
        }
      });
      const unsupported = await runner.translate('hello', 'fr');
      expect(unsupported.ok).assertFalse();
      expect(loadCalls).assertEqual(0);
      const empty = await runner.translate('hello', 'zh');
      expect(empty.ok).assertFalse();
      expect(loadCalls).assertEqual(1);
    });

    it('sharesConcurrentLoadResetsAndRetriesFailedLoad', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      let loadCalls = 0;
      const shared = new FakeTranslationSession([12249, 0]);
      const factory = async (): Promise<TranslationModelBundle> => {
        loadCalls++;
        return bundleFor(shared);
      };
      const firstRunner = new MindSporeLiteTranslationRunner({ bundleFactory: factory });
      const secondRunner = new MindSporeLiteTranslationRunner({ bundleFactory: factory });
      const results = await Promise.all([
        firstRunner.translate('hello', 'zh'), secondRunner.translate('world', 'zh')
      ]);
      expect(results[0].ok).assertTrue();
      expect(results[1].ok).assertTrue();
      expect(loadCalls).assertEqual(1);
      resetTranslationModelCacheForTests();
      await flushTranslationMicrotasks();
      expect(shared.closeCalls).assertEqual(1);

      let retryCalls = 0;
      const recovered = new FakeTranslationSession([12249, 0]);
      const retryRunner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          retryCalls++;
          if (retryCalls === 1) {
            throw new Error('load failed');
          }
          return bundleFor(recovered);
        }
      });
      expect((await retryRunner.translate('hello', 'zh')).ok).assertFalse();
      expect((await retryRunner.translate('hello', 'zh')).ok).assertTrue();
      expect(retryCalls).assertEqual(2);
    });

    it('keepsResetGenerationSafeWhenAnOldLoadFinishesLate', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const stale = new FakeTranslationSession([12249, 0]);
      const staleRunner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          await Promise.resolve();
          return bundleFor(stale);
        }
      });
      const staleResultPromise = staleRunner.translate('hello', 'zh');
      resetTranslationModelCacheForTests();
      const fresh = new FakeTranslationSession([12249, 0]);
      const freshResult = await runnerFor(fresh).translate('hello', 'zh');
      const staleResult = await staleResultPromise;
      expect(freshResult.ok).assertTrue();
      expect(staleResult.ok).assertFalse();
      expect(stale.closeCalls).assertEqual(1);
      expect(fresh.closeCalls).assertEqual(0);
    });

    it('loadsTheProductionBundleBeforeEncodingConfiguresTheTokenizer', 0, async () => {
      resetTranslationModelCacheForTests();
      resetTranslationTokenizerForTests();
      let loadCalls = 0;
      const session = new FakeTranslationSession([12249, 0]);
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          loadCalls++;
          configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
          return bundleFor(session);
        }
      });

      const result = await runner.translate('hello', 'zh');

      expect(loadCalls).assertEqual(1);
      expect(result.ok).assertTrue();
      expect(result.runtimeSource).assertEqual('localModel');
    });

    it('productionLoaderFailsHonestlyWhenFinalAssetsAreMissing', 0, async () => {
      resetTranslationModelCacheForTests();
      resetTranslationTokenizerForTests();
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: productionTranslationModelBundleFactory({
          resourceManager: new MissingTranslationResources(),
          cacheRoot: '/data/storage/el2/base/cache/translation'
        })
      });
      const result = await runner.translate('hello', 'zh');
      expect(result.ok).assertFalse();
      expect(result.translatedText).assertEqual('');
      expect(result.runtimeSource === undefined).assertTrue();
    });
    it('matchesPinnedPythonSentencePieceGoldens', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      for (let caseIndex = 0; caseIndex < TOKENIZER_GOLDEN_CASES.length; caseIndex++) {
        const golden = TOKENIZER_GOLDEN_CASES[caseIndex];
        const chunks = encodeTranslationText(golden.text, golden.target);
        expect(chunks.length).assertEqual(golden.chunks.length);
        for (let chunkIndex = 0; chunkIndex < golden.chunks.length; chunkIndex++) {
          assertChunk(chunks[chunkIndex], golden.chunks[chunkIndex]);
        }
      }
    });

    it('keeps127And128TokensInOneChunkAndSplits129', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const boundary127 = encodeTranslationText(findGolden('boundary_127').text, 'zh');
      const boundary128 = encodeTranslationText(findGolden('boundary_128').text, 'zh');
      const boundary129 = encodeTranslationText(findGolden('boundary_129').text, 'zh');

      expect(boundary127.length).assertEqual(1);
      expect(boundary127[0].pieceIds.length + 2).assertEqual(127);
      expect(boundary128.length).assertEqual(1);
      expect(boundary128[0].pieceIds.length + 2).assertEqual(128);
      expect(boundary129.length).assertEqual(2);
      expect(boundary129[0].pieceIds.length + 2).assertEqual(128);
      expect(boundary129[1].pieceIds.length + 2).assertEqual(3);
      expect(reconstructedSource(boundary127)).assertEqual(findGolden('boundary_127').text);
      expect(reconstructedSource(boundary128)).assertEqual(findGolden('boundary_128').text);
      expect(reconstructedSource(boundary129)).assertEqual(findGolden('boundary_129').text);
    });

    it('preservesOriginalNewlineCountOrderAndKinds', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const golden = findGolden('multiple_newlines');
      const chunks = encodeTranslationText(golden.text, golden.target);

      expect(chunks.length).assertEqual(3);
      expect(chunks[0].separatorBefore).assertEqual('');
      expect(chunks[0].separatorAfter).assertEqual('\n\n');
      expect(chunks[1].separatorBefore).assertEqual('');
      expect(chunks[1].separatorAfter).assertEqual('\r\n');
      expect(chunks[2].separatorBefore).assertEqual('');
      expect(chunks[2].separatorAfter).assertEqual('\n');
    });

    it('usesAndroidBroadUnicodeDirectionRuleAndExactDirectionTokens', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      expect(translationTargetLanguageForText('plain English')).assertEqual('zh');
      expect(translationTargetLanguageForText('\u4F60')).assertEqual('en');
      expect(translationTargetLanguageForText('\uFF21')).assertEqual('en');
      expect(translationTargetLanguageForText('\u2E80')).assertEqual('en');
      expect(translationTargetLanguageForText('\u3002')).assertEqual('en');
      expect(translationTargetLanguageForText('\u31C0')).assertEqual('en');
      expect(encodeTranslationText('Hello', 'zh')[0].inputIds[0]).assertEqual(32002);
      expect(encodeTranslationText('\u4F60\u597D', 'en')[0].inputIds[0]).assertEqual(32001);
      assertThrows((): void => { encodeTranslationText('Hello', 'fr'); });
    });

    it('decodeSkipsControlsAndUsesSentencePieceUnknownReplacement', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      for (let index = 0; index < TOKENIZER_DECODE_GOLDENS.length; index++) {
        const golden = TOKENIZER_DECODE_GOLDENS[index];
        expect(decodeTranslationTokens(golden.pieceIds)).assertEqual(golden.decoded);
        expect(decodeTranslationTokens([32002].concat(golden.pieceIds))).assertEqual(golden.decoded);
      }
      expect(decodeTranslationTokens([32002, 12249, 3, 1, 192, 0, 32000]))
        .assertEqual('Hello  \u2047  world');
      expect(decodeTranslationTokens([32001, 14627, 0, 32000, 12249])).assertEqual('\u4F60\u597D');
    });

    it('rejectsMalformedRuntimeTableAndWhitespaceOnlyInput', 0, () => {
      assertThrows((): void => { configureTranslationTokenizer('TTOK1\tbad'); });
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      expect(encodeTranslationText(' \t \n\r\n ', 'zh').length).assertEqual(0);
    });

    it('productionLoaderRequiresExactContiguous32000PieceTable', 0, () => {
      configureTranslationTokenizer(FULL_RUNTIME_TABLE);
      expect(encodeTranslationText('p2', 'zh').length).assertEqual(1);
      assertThrows((): void => { configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE); });

      const missingLast = FULL_RUNTIME_TABLE.substring(0, FULL_RUNTIME_TABLE.lastIndexOf('\n'));
      assertThrows((): void => { configureTranslationTokenizer(missingLast); });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('\t32000\t1\t-20', '\t31999\t1\t-20'));
      });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('P\t2\t-1\t1\t70,32', 'P\t1\t-1\t1\t70,32'));
      });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('P\t2\t-1\t1\t70,32', 'P\t32000\t-1\t1\t70,32'));
      });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('P\t2\t-1\t1\t70,32', 'P\t2\tNaN\t1\t70,32'));
      });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('P\t2\t-1\t1\t70,32', 'P\t2\t-1\t4\t70,32'));
      });
      assertThrows((): void => {
        configureTranslationTokenizer(FULL_RUNTIME_TABLE.replace('N\tFF21\t41', 'N\tFF21\t41\nN\tFF21\t42'));
      });
    });

    it('mergesUnknownRunsAndMatchesPinnedSentencePieceDecodeSpacing', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const runGolden = findGolden('unknown_run');
      const run = encodeTranslationText(runGolden.text, runGolden.target)[0];
      assertNumberArrayEqual(run.pieceIds, [71, 1, 256]);
      expect(run.pieces[1]).assertEqual('\uD83E\uDDEA\uD83E\uDDEC');
      expect(decodeTranslationTokens(run.inputIds)).assertEqual('A \u2047 B');

      const bmpGolden = findGolden('unknown_bmp_run');
      const bmp = encodeTranslationText(bmpGolden.text, bmpGolden.target)[0];
      assertNumberArrayEqual(bmp.pieceIds, [71, 1, 256]);
      expect(bmp.pieces[1]).assertEqual('\uE000\uE001');
      expect(decodeTranslationTokens(bmp.inputIds)).assertEqual('A \u2047 B');

      const adjacencyGolden = findGolden('unknown_adjacency');
      const adjacency = encodeTranslationText(adjacencyGolden.text, adjacencyGolden.target)[0];
      assertChunk(adjacency, adjacencyGolden.chunks[0]);

      const boundaryGolden = findGolden('unknown_boundary_128');
      const boundary = encodeTranslationText(boundaryGolden.text, boundaryGolden.target);
      expect(boundary.length).assertEqual(1);
      expect(boundary[0].pieceIds.length).assertEqual(126);
      let unknownCount = 0;
      for (let index = 0; index < boundary[0].pieceIds.length; index++) {
        if (boundary[0].pieceIds[index] === 1) {
          unknownCount++;
        }
      }
      expect(unknownCount).assertEqual(1);
    });

    it('splitsByChineseThenEnglishThenSpaceBeforeHardBoundaryWithoutLoss', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const names: Array<string> = ['priority_mixed', 'priority_english', 'priority_space', 'priority_hard'];
      for (let nameIndex = 0; nameIndex < names.length; nameIndex++) {
        const golden = findGolden(names[nameIndex]);
        const chunks = encodeTranslationText(golden.text, golden.target);
        expect(reconstructedSource(chunks)).assertEqual(golden.text);
        for (let chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
          expect(chunks[chunkIndex].pieceIds.length <= 126).assertTrue();
        }
      }
      expect(encodeTranslationText(findGolden('priority_mixed').text, 'zh')[0].sourceText.endsWith('\u3002'))
        .assertTrue();
      expect(encodeTranslationText(findGolden('priority_english').text, 'zh')[0].sourceText.endsWith('.'))
        .assertTrue();
      expect(encodeTranslationText(findGolden('priority_space').text, 'zh')[0].sourceText.endsWith(' '))
        .assertTrue();
      const hard = encodeTranslationText(findGolden('priority_hard').text, 'en')[0].sourceText;
      expect(hard.endsWith('\u3002') || hard.endsWith('.') || hard.endsWith(' ')).assertFalse();
    });

    it('ownsNewlinesOnPreviousChunkAndPreservesWhitespaceOnlyLines', 0, () => {
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const names: Array<string> = [
        'separator_whitespace_line', 'separator_edges', 'separator_punctuation'
      ];
      for (let index = 0; index < names.length; index++) {
        const golden = findGolden(names[index]);
        const chunks = encodeTranslationText(golden.text, golden.target);
        expect(reconstructedSource(chunks)).assertEqual(golden.text);
        for (let chunkIndex = 1; chunkIndex < chunks.length; chunkIndex++) {
          expect(chunks[chunkIndex].separatorBefore).assertEqual('');
        }
      }

      const whitespace = encodeTranslationText(findGolden('separator_whitespace_line').text, 'zh');
      expect(whitespace[0].separatorAfter).assertEqual('\n  \n');
      const edges = encodeTranslationText(findGolden('separator_edges').text, 'zh');
      expect(edges[0].separatorBefore).assertEqual('\n');
      expect(edges[0].separatorAfter).assertEqual('\r\n\r\n \t\r\n');
      expect(edges[edges.length - 1].separatorAfter).assertEqual('\n');
      const punctuation = encodeTranslationText(findGolden('separator_punctuation').text, 'zh');
      expect(punctuation[0].sourceText.endsWith('\u3002')).assertTrue();
      expect(punctuation[punctuation.length - 2].separatorAfter).assertEqual('\r\n');
    });
  });
}
