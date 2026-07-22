import { describe, expect, it } from '@ohos/hypium';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  TranslationDirectionManifest,
  TranslationGraphManifest,
  TranslationTensorManifest
} from '../main/ets/services/ai/TranslationModelManifest';
import {
  configureTranslationTokenizersForTests,
  resetTranslationTokenizerForTests
} from '../main/ets/services/ai/TinyTranslationTokenizer';
import {
  createMindSporeLiteTranslationTensorSessionForTests,
  MindSporeLiteTranslationRunner,
  productionTranslationModelBundleFactory,
  resetTranslationModelCacheForTests,
  TranslationMindSporeModel,
  TranslationMindSporeTensor,
  TranslationModelBundle,
  TranslationModelResourceManager,
  TranslationRawFileDescriptor,
  TranslationRequestQueue,
  TranslationTensor,
  TranslationTensorSession
} from '../main/ets/services/ai/MindSporeLiteTranslationRunner';

const SHA_A: string = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const SHA_B: string = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

function codepoints(text: string): string {
  const values: Array<string> = [];
  for (let index = 0; index < text.length; index++) {
    values.push(text.charCodeAt(index).toString(16).toUpperCase());
  }
  return values.join(',');
}

function sourceTable(): string {
  return [
    `TTOK2\t${SHA_A}\t${SHA_B}\t6\t5\t0\t1\t-20\t1\t1\t1`,
    'N\tFF21\t41',
    `P\t0\t0\t3\t${codepoints('</s>')}`,
    `P\t1\t0\t2\t${codepoints('<unk>')}`,
    `P\t2\t-1\t1\t${codepoints('\u2581hello')}`,
    `P\t3\t-1\t1\t${codepoints('\u2581world')}`,
    `P\t1\t-2\t1\t${codepoints('\u2581unused')}`
  ].join('\n');
}

function targetTable(): string {
  return [
    `TTOK2\t${SHA_A}\t${SHA_B}\t6\t0\t6\t1\t-20\t1\t1\t1`,
    `V\t0\t${codepoints('</s>')}`,
    `V\t1\t${codepoints('<unk>')}`,
    `V\t2\t${codepoints('\u2581OK')}`,
    `V\t3\t${codepoints('\u2581NEXT')}`,
    `V\t4\t${codepoints('>>cmn_Hans<<')}`,
    `V\t5\t${codepoints('<pad>')}`
  ].join('\n');
}

function configureTokenizer(): void {
  resetTranslationTokenizerForTests();
  configureTranslationTokenizersForTests(sourceTable(), targetTable());
}

function tensor(name: string, dtype: 'INT32' | 'FLOAT32', shape: Array<number>): TranslationTensorManifest {
  return { name: name, dtype: dtype, shape: shape };
}

function graph(
  file: string,
  inputs: Array<TranslationTensorManifest>,
  outputs: Array<TranslationTensorManifest>
): TranslationGraphManifest {
  return { file: file, size: 1, sha256: SHA_A, inputs: inputs, outputs: outputs };
}

function direction(): TranslationDirectionManifest {
  return {
    sourceLanguage: 'en',
    targetLanguage: 'en',
    repository: 'test/safety',
    revision: 'test',
    generation: {
      strategy: 'greedy', numBeams: 1, sourcePrefix: '', sourcePrefixTokenId: -1,
      sourceMaxTokens: 128, targetMaxTokens: 32
    },
    vocabulary: { size: 6, eos: 0, unk: 1, pad: 5, decoderStart: 5 },
    tokenizers: {
      source: {
        file: 'source.ttok', size: 1, sha256: SHA_A, modelSha256: SHA_A,
        vocabularySha256: SHA_B, pieceCount: 5, decodeVocabularySize: 0,
        specialTokens: { eos: '</s>', unk: '<unk>', pad: '<pad>' }
      },
      target: {
        file: 'target.ttok', size: 1, sha256: SHA_A, modelSha256: SHA_A,
        vocabularySha256: SHA_B, pieceCount: 0, decodeVocabularySize: 6,
        specialTokens: { eos: '</s>', unk: '<unk>', pad: '<pad>' }
      }
    },
    graphs: {
      encoder: graph('encoder.ms', [
        tensor('input_ids', 'INT32', [1, 128]),
        tensor('attention_mask', 'INT32', [1, 128])
      ], [tensor('last_hidden_state', 'FLOAT32', [1, 128, 2])]),
      decoderFull: graph('decoder_full.ms', [
        tensor('decoder_input_ids', 'INT32', [1, 32]),
        tensor('decoder_attention_mask', 'INT32', [1, 32]),
        tensor('encoder_hidden_states', 'FLOAT32', [1, 128, 2]),
        tensor('encoder_attention_mask', 'INT32', [1, 128])
      ], [tensor('logits', 'FLOAT32', [1, 32, 6])])
    },
    graphBytes: 2,
    maxGraphBytes: 2
  };
}

function elementCount(shape: Array<number>): number {
  let count = 1;
  for (let index = 0; index < shape.length; index++) count *= shape[index];
  return count;
}

class FakeMindSporeTensor implements TranslationMindSporeTensor {
  readonly name: string;
  shape: Array<number>;
  elementNum: number;
  dataSize: number;
  dtype: mindSporeLite.DataType;
  buffer: ArrayBuffer;
  getDataCalls: number = 0;
  setDataCalls: number = 0;

  constructor(
    name: string,
    shape: Array<number>,
    dtype: mindSporeLite.DataType,
    bufferBytes: number = -1
  ) {
    this.name = name;
    this.shape = shape;
    this.elementNum = elementCount(shape);
    this.dataSize = this.elementNum * 4;
    this.dtype = dtype;
    this.buffer = new ArrayBuffer(bufferBytes < 0 ? this.dataSize : bufferBytes);
  }

  getData(): ArrayBuffer {
    this.getDataCalls++;
    return this.buffer;
  }

  setData(data: ArrayBuffer): void {
    this.setDataCalls++;
    this.buffer = data;
  }
}

class FakeMindSporeModel implements TranslationMindSporeModel {
  readonly inputs: Array<TranslationMindSporeTensor>;
  outputs: Array<TranslationMindSporeTensor>;
  predictCalls: number = 0;

  constructor(inputs: Array<TranslationMindSporeTensor>, outputs: Array<TranslationMindSporeTensor>) {
    this.inputs = inputs;
    this.outputs = outputs;
  }

  getInputs(): Array<TranslationMindSporeTensor> {
    return this.inputs;
  }

  async predict(_inputs: Array<TranslationMindSporeTensor>): Promise<Array<TranslationMindSporeTensor>> {
    this.predictCalls++;
    return this.outputs;
  }
}

function runtimeTensor(spec: TranslationTensorManifest): FakeMindSporeTensor {
  return new FakeMindSporeTensor(
    spec.name,
    spec.shape.slice(),
    spec.dtype === 'INT32' ? mindSporeLite.DataType.NUMBER_TYPE_INT32 :
      mindSporeLite.DataType.NUMBER_TYPE_FLOAT32
  );
}

function runtimeTensors(specs: Array<TranslationTensorManifest>): Array<TranslationMindSporeTensor> {
  const values: Array<TranslationMindSporeTensor> = [];
  for (let index = 0; index < specs.length; index++) values.push(runtimeTensor(specs[index]));
  return values;
}

function encoderInputs(): Array<TranslationTensor> {
  return [
    { name: 'input_ids', dtype: 'INT32', shape: [1, 128], data: new Int32Array(128) },
    { name: 'attention_mask', dtype: 'INT32', shape: [1, 128], data: new Int32Array(128) }
  ];
}

async function expectRejected(operation: Promise<Array<TranslationTensor>>): Promise<void> {
  let rejected = false;
  try {
    await operation;
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
}

function adapterSessionWithEncoderOutput(output: TranslationMindSporeTensor): TranslationTensorSession {
  const selected = direction();
  const encoder = new FakeMindSporeModel(runtimeTensors(selected.graphs.encoder.inputs), [output]);
  const decoder = new FakeMindSporeModel(
    runtimeTensors(selected.graphs.decoderFull.inputs),
    runtimeTensors(selected.graphs.decoderFull.outputs)
  );
  return createMindSporeLiteTranslationTensorSessionForTests(selected, encoder, decoder);
}

class Deferred {
  readonly promise: Promise<void>;
  private resolver: (() => void) | undefined = undefined;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void): void => {
      this.resolver = resolve;
    });
  }

  resolve(): void {
    if (this.resolver !== undefined) this.resolver();
  }
}

class StaticSafetySession implements TranslationTensorSession {
  encoderCalls: number = 0;
  decoderCalls: number = 0;
  closeCalls: number = 0;
  failNextEncoder: boolean = false;
  malformedMode: string = '';
  readonly events: Array<string> = [];
  firstDecoderStarted: Deferred | undefined = undefined;
  firstDecoderRelease: Deferred | undefined = undefined;
  private blockedOnce: boolean = false;

  async run(graphName: 'encoder' | 'decoder_full', inputs: Array<TranslationTensor>):
    Promise<Array<TranslationTensor>> {
    this.events.push(graphName);
    if (graphName === 'encoder') {
      this.encoderCalls++;
      if (this.failNextEncoder) {
        this.failNextEncoder = false;
        throw new Error('expected encoder failure');
      }
      if (this.malformedMode === 'encoderShape') {
        return [{
          name: 'last_hidden_state', dtype: 'FLOAT32', shape: [1, 127, 2], data: new Float32Array(254)
        }];
      }
      return [{
        name: 'last_hidden_state', dtype: 'FLOAT32', shape: [1, 128, 2], data: new Float32Array(256)
      }];
    }
    this.decoderCalls++;
    if (!this.blockedOnce && this.firstDecoderStarted !== undefined && this.firstDecoderRelease !== undefined) {
      this.blockedOnce = true;
      this.firstDecoderStarted.resolve();
      await this.firstDecoderRelease.promise;
    }
    const mask = inputs[1].data as Int32Array;
    let prefixLength = 0;
    for (let index = 0; index < mask.length; index++) prefixLength += mask[index];
    const logits = new Float32Array(32 * 6);
    logits.fill(-20);
    const tokenId = this.malformedMode === 'empty' ? 0 : (prefixLength === 1 ? 2 : 0);
    logits[(prefixLength - 1) * 6 + tokenId] = 10;
    if (this.malformedMode === 'nonFinite') logits[0] = Number.NaN;
    if (this.malformedMode === 'decoderShape') {
      return [{ name: 'logits', dtype: 'FLOAT32', shape: [1, 31, 6], data: logits }];
    }
    return [{ name: 'logits', dtype: 'FLOAT32', shape: [1, 32, 6], data: logits }];
  }

  async close(): Promise<void> {
    this.closeCalls++;
  }
}

function bundle(session: TranslationTensorSession): TranslationModelBundle {
  return { direction: direction(), session: session, requestQueue: new TranslationRequestQueue() };
}

function runnerWith(session: TranslationTensorSession): MindSporeLiteTranslationRunner {
  return new MindSporeLiteTranslationRunner({
    bundleFactory: async (): Promise<TranslationModelBundle> => bundle(session)
  });
}

class MissingResourceManager implements TranslationModelResourceManager {
  contentCalls: number = 0;
  descriptorCalls: number = 0;
  closeCalls: number = 0;

  async getRawFileContent(_path: string): Promise<Uint8Array> {
    this.contentCalls++;
    throw new Error('missing manifest');
  }

  async getRawFd(_path: string): Promise<TranslationRawFileDescriptor> {
    this.descriptorCalls++;
    return { fd: 1, offset: 0, length: 1 };
  }

  async closeRawFd(_path: string): Promise<void> {
    this.closeCalls++;
  }
}

export default function translationRuntimeV2SafetyUnitTest(): void {
  describe('TranslationRuntimeV2SafetyUnit', () => {
    it('rejectsInvalidProductionOutputMetadataBeforeReadingBuffers', 0, async () => {
      const selected = direction();
      const expected = selected.graphs.encoder.outputs[0];
      const modes: Array<string> = [
        'dtype', 'shape', 'elementNum', 'dataSize', 'missing', 'extra', 'duplicate'
      ];
      for (let modeIndex = 0; modeIndex < modes.length; modeIndex++) {
        const output = runtimeTensor(expected);
        let outputs: Array<TranslationMindSporeTensor> = [output];
        if (modes[modeIndex] === 'dtype') output.dtype = mindSporeLite.DataType.TYPE_UNKNOWN;
        if (modes[modeIndex] === 'shape') output.shape = [1, 127, 2];
        if (modes[modeIndex] === 'elementNum') output.elementNum--;
        if (modes[modeIndex] === 'dataSize') output.dataSize -= 4;
        if (modes[modeIndex] === 'missing') outputs = [];
        if (modes[modeIndex] === 'extra') outputs = [output, runtimeTensor(expected)];
        if (modes[modeIndex] === 'duplicate') outputs = [output, runtimeTensor(expected)];
        const encoder = new FakeMindSporeModel(runtimeTensors(selected.graphs.encoder.inputs), outputs);
        const decoder = new FakeMindSporeModel(
          runtimeTensors(selected.graphs.decoderFull.inputs),
          runtimeTensors(selected.graphs.decoderFull.outputs)
        );
        const session = createMindSporeLiteTranslationTensorSessionForTests(selected, encoder, decoder);
        await expectRejected(session.run('encoder', encoderInputs()));
        expect(output.getDataCalls).assertEqual(0);
      }
    });

    it('readsProductionOutputBufferOnceBeforeRejectingWrongByteLength', 0, async () => {
      for (let delta = -4; delta <= 4; delta += 8) {
        const expected = direction().graphs.encoder.outputs[0];
        const output = new FakeMindSporeTensor(
          expected.name,
          expected.shape.slice(),
          mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          elementCount(expected.shape) * 4 + delta
        );
        const session = adapterSessionWithEncoderOutput(output);
        await expectRejected(session.run('encoder', encoderInputs()));
        expect(output.getDataCalls).assertEqual(1);
      }
    });

    it('serializesTheWholeTranslationRequestAcrossASharedSession', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const session = new StaticSafetySession();
      session.firstDecoderStarted = new Deferred();
      session.firstDecoderRelease = new Deferred();
      const shared = bundle(session);
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => shared
      });
      const first = runner.translate('hello', 'en');
      await session.firstDecoderStarted.promise;
      const second = runner.translate('world', 'en');
      await Promise.resolve();
      await Promise.resolve();
      expect(session.encoderCalls).assertEqual(1);
      session.firstDecoderRelease.resolve();
      const results = await Promise.all([first, second]);
      expect(results[0].ok).assertTrue();
      expect(results[1].ok).assertTrue();
      expect(session.encoderCalls).assertEqual(2);
      expect(session.events.join(',')).assertEqual(
        'encoder,decoder_full,decoder_full,encoder,decoder_full,decoder_full'
      );
    });

    it('releasesTheProductionRequestQueueAfterPredictionFailure', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const session = new StaticSafetySession();
      session.failNextEncoder = true;
      const shared = bundle(session);
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => shared
      });
      const first = runner.translate('hello', 'en');
      const second = runner.translate('world', 'en');
      const results = await Promise.all([first, second]);
      expect(results[0].ok).assertFalse();
      expect(results[1].ok).assertTrue();
      expect(session.encoderCalls).assertEqual(2);
    });

    it('runsEveryChunkOnceAndPreservesSeparatorsAndProtectedOrder', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const session = new StaticSafetySession();
      const result = await runnerWith(session).translate('hello\r\nB-3017\r\nworld', 'en');
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual('OK\r\nB-3017\r\nOK');
      expect(session.encoderCalls).assertEqual(2);
    });

    it('failsTheWholeRequestForEmptyModelOutput', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const session = new StaticSafetySession();
      session.malformedMode = 'empty';
      const source = 'hello\r\nB-3017';
      const result = await runnerWith(session).translate(source, 'en');
      expect(result.ok).assertFalse();
      expect(result.sourceText).assertEqual(source);
    });

    it('failsClosedForMalformedAndNonFiniteSessionOutputs', 0, async () => {
      for (const mode of ['encoderShape', 'decoderShape', 'nonFinite']) {
        resetTranslationModelCacheForTests();
        configureTokenizer();
        const session = new StaticSafetySession();
        session.malformedMode = mode;
        const result = await runnerWith(session).translate('hello', 'en');
        expect(result.ok).assertFalse();
        expect(result.sourceText).assertEqual('hello');
      }
    });

    it('rejectsUnsupportedAndEmptyInputWithoutLoading', 0, async () => {
      resetTranslationModelCacheForTests();
      let loads = 0;
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          loads++;
          return bundle(new StaticSafetySession());
        }
      });
      const unsupported = await runner.translate('hello', 'fr');
      const empty = await runner.translate(' \r\n ', 'en');
      expect(unsupported.ok).assertFalse();
      expect(empty.ok).assertFalse();
      expect(loads).assertEqual(0);
    });

    it('sharesConcurrentLoadsAndRetriesAfterARejectedLoad', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const gate = new Deferred();
      const sharedSession = new StaticSafetySession();
      const shared = bundle(sharedSession);
      let loads = 0;
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          loads++;
          if (loads === 1) await gate.promise;
          return shared;
        }
      });
      const first = runner.translate('hello', 'en');
      const second = runner.translate('world', 'en');
      expect(loads).assertEqual(1);
      gate.resolve();
      const concurrent = await Promise.all([first, second]);
      expect(concurrent[0].ok).assertTrue();
      expect(concurrent[1].ok).assertTrue();
      expect(loads).assertEqual(1);

      resetTranslationModelCacheForTests();
      let attempts = 0;
      const retryRunner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          attempts++;
          if (attempts === 1) throw new Error('expected load failure');
          return bundle(new StaticSafetySession());
        }
      });
      expect((await retryRunner.translate('hello', 'en')).ok).assertFalse();
      expect((await retryRunner.translate('hello', 'en')).ok).assertTrue();
      expect(attempts).assertEqual(2);
    });

    it('closesALateBundleAfterResetWithoutPoisoningTheNextLoad', 0, async () => {
      resetTranslationModelCacheForTests();
      configureTokenizer();
      const gate = new Deferred();
      const oldSession = new StaticSafetySession();
      const nextSession = new StaticSafetySession();
      let loads = 0;
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: async (): Promise<TranslationModelBundle> => {
          loads++;
          if (loads === 1) {
            await gate.promise;
            return bundle(oldSession);
          }
          return bundle(nextSession);
        }
      });
      const stale = runner.translate('hello', 'en');
      expect(loads).assertEqual(1);
      resetTranslationModelCacheForTests();
      gate.resolve();
      expect((await stale).ok).assertFalse();
      expect(oldSession.closeCalls).assertEqual(1);
      expect((await runner.translate('hello', 'en')).ok).assertTrue();
      expect(loads).assertEqual(2);
    });

    it('failsHonestlyWhenProductionAssetsAreMissing', 0, async () => {
      resetTranslationModelCacheForTests();
      const resources = new MissingResourceManager();
      const runner = new MindSporeLiteTranslationRunner({
        bundleFactory: productionTranslationModelBundleFactory({
          resourceManager: resources,
          cacheRoot: 'translation-cache'
        })
      });
      const result = await runner.translate('hello', 'en');
      expect(result.ok).assertFalse();
      expect(result.sourceText).assertEqual('hello');
      expect(result.translatedText).assertEqual('');
      expect(resources.contentCalls).assertEqual(1);
      expect(resources.descriptorCalls).assertEqual(0);
      expect(resources.closeCalls).assertEqual(0);
    });
  });
}
