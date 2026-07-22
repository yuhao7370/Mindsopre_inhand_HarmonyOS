import { describe, expect, it } from '@ohos/hypium';
import {
  TranslationDirectionManifest,
  TranslationGraphManifest,
  TranslationModelManifest,
  TranslationTensorManifest,
  translationDirectionForTarget
} from '../main/ets/services/ai/TranslationModelManifest';
import {
  configureTranslationTokenizersForTests,
  decodeTranslationTokensForDirection,
  encodeTranslationTextForDirection,
  resetTranslationTokenizerForTests
} from '../main/ets/services/ai/TinyTranslationTokenizer';
import {
  MindSporeLiteTranslationRunner,
  TranslationModelBundle,
  TranslationRequestQueue,
  TranslationTensor,
  TranslationTensorSession,
  resetTranslationModelCacheForTests
} from '../main/ets/services/ai/MindSporeLiteTranslationRunner';

const MODEL_SHA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const VOCAB_SHA = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

function codepoints(text: string): string {
  const values: Array<string> = [];
  for (let index = 0; index < text.length; index++) values.push(text.charCodeAt(index).toString(16).toUpperCase());
  return values.join(',');
}

function sourceTable(): string {
  return [
    `TTOK2\t${MODEL_SHA}\t${VOCAB_SHA}\t6\t5\t0\t1\t-20\t1\t1\t1`,
    'N\tFF21\t41',
    `P\t0\t0\t3\t${codepoints('</s>')}`,
    `P\t1\t0\t2\t${codepoints('<unk>')}`,
    `P\t2\t-1\t1\t${codepoints('\u2581x')}`,
    `P\t3\t-1\t1\t${codepoints('\u2581hello')}`,
    `P\t1\t-2\t1\t${codepoints('\u2581unused')}`
  ].join('\n');
}

function targetTable(): string {
  return [
    `TTOK2\t${MODEL_SHA}\t${VOCAB_SHA}\t6\t0\t6\t1\t-20\t1\t1\t1`,
    `V\t0\t${codepoints('</s>')}`,
    `V\t1\t${codepoints('<unk>')}`,
    `V\t2\t${codepoints('\u2581\u4F60')}`,
    `V\t3\t${codepoints('\u597D')}`,
    `V\t4\t${codepoints('>>cmn_Hans<<')}`,
    `V\t5\t${codepoints('<pad>')}`
  ].join('\n');
}

function assertThrows(action: () => void): void {
  let threw = false;
  try { action(); } catch (_) { threw = true; }
  expect(threw).assertTrue();
}

function tensor(name: string, dtype: 'INT32' | 'FLOAT32', shape: Array<number>): TranslationTensorManifest {
  return { name: name, dtype: dtype, shape: shape };
}

function graph(file: string, inputs: Array<TranslationTensorManifest>, outputs: Array<TranslationTensorManifest>): TranslationGraphManifest {
  return { file: file, size: 1, sha256: MODEL_SHA, inputs: inputs, outputs: outputs };
}

function direction(strategy: string = 'greedy', targetLanguage: string = 'en'): TranslationDirectionManifest {
  return {
    sourceLanguage: targetLanguage === 'en' ? 'zh' : 'en', targetLanguage: targetLanguage,
    repository: 'test', revision: MODEL_SHA,
    generation: { strategy: strategy, numBeams: strategy === 'beam' ? 4 : 1,
      sourcePrefix: targetLanguage === 'zh' ? '>>cmn_Hans<< ' : '',
      sourcePrefixTokenId: targetLanguage === 'zh' ? 5 : -1,
      sourceMaxTokens: 128, targetMaxTokens: 32 },
    vocabulary: { size: 6, eos: 0, unk: 1, pad: 5, decoderStart: 5 },
    tokenizers: {
      source: { file: 'source.ttok', size: 1, sha256: MODEL_SHA, modelSha256: MODEL_SHA,
        vocabularySha256: VOCAB_SHA, pieceCount: 5, decodeVocabularySize: 0,
        specialTokens: { eos: '</s>', unk: '<unk>', pad: '<pad>' } },
      target: { file: 'target.ttok', size: 1, sha256: MODEL_SHA, modelSha256: MODEL_SHA,
        vocabularySha256: VOCAB_SHA, pieceCount: 0, decodeVocabularySize: 6,
        specialTokens: { eos: '</s>', unk: '<unk>', pad: '<pad>' } }
    },
    graphs: {
      encoder: graph('encoder.ms', [tensor('input_ids', 'INT32', [1, 128]),
        tensor('attention_mask', 'INT32', [1, 128])],
      [tensor('last_hidden_state', 'FLOAT32', [1, 128, 2])]),
      decoderFull: graph('decoder_full.ms', [tensor('decoder_input_ids', 'INT32', [1, 32]),
        tensor('decoder_attention_mask', 'INT32', [1, 32]),
        tensor('encoder_hidden_states', 'FLOAT32', [1, 128, 2]),
        tensor('encoder_attention_mask', 'INT32', [1, 128])],
      [tensor('logits', 'FLOAT32', [1, 32, 6])])
    }, graphBytes: 2, maxGraphBytes: 2
  };
}

function modelManifest(): TranslationModelManifest {
  return { schemaVersion: 2,
    archive: { file: 'translation-models.tar.xz', size: 1, sha256: MODEL_SHA, cacheKey: 'ARCHIVE_SHA256',
      tarSize: 1, tarSha256: VOCAB_SHA, maxArchiveBytes: 1, maxTarBytes: 1 },
    directions: { en: direction(), zh: direction('beam', 'zh') } };
}

function output(name: string, shape: Array<number>, data: Float32Array): TranslationTensor {
  return { name: name, dtype: 'FLOAT32', shape: shape, data: data };
}

class StaticDecoderSession implements TranslationTensorSession {
  readonly scripted: Array<number>;
  decoderCalls: number = 0;
  encoderCalls: number = 0;
  exactBindings: boolean = true;
  padWasHighest: boolean = false;
  closeCalls: number = 0;

  constructor(scripted: Array<number>) { this.scripted = scripted; }

  async run(graphName: 'encoder' | 'decoder_full', inputs: Array<TranslationTensor>): Promise<Array<TranslationTensor>> {
    if (graphName === 'encoder') {
      this.encoderCalls++;
      return [output('last_hidden_state', [1, 128, 2], new Float32Array(256))];
    }
    this.decoderCalls++;
    const ids = inputs[0].data as Int32Array;
    const mask = inputs[1].data as Int32Array;
    this.exactBindings = this.exactBindings && inputs[0].shape.join(',') === '1,32' &&
      inputs[1].shape.join(',') === '1,32' && ids.length === 32 && mask.length === 32;
    let prefixLength = 0;
    for (let index = 0; index < mask.length; index++) prefixLength += mask[index];
    const logits = new Float32Array(32 * 6);
    logits.fill(-20);
    const token = this.scripted[Math.min(this.decoderCalls - 1, this.scripted.length - 1)];
    const offset = (prefixLength - 1) * 6;
    logits[offset + token] = 10;
    logits[offset + 5] = 20;
    this.padWasHighest = true;
    return [output('logits', [1, 32, 6], logits)];
  }

  async close(): Promise<void> { this.closeCalls++; }
}

function beamLogits(values: Array<number>): Array<number> {
  const logits = new Array<number>(6).fill(-20);
  for (let index = 0; index < values.length; index += 2) logits[values[index]] = values[index + 1];
  return logits;
}

class PrefixBeamSession implements TranslationTensorSession {
  private readonly logitsByPrefix: Map<string, Array<number>>;
  readonly fallback: Array<number>;
  decoderCalls: number = 0;
  readonly seenPrefixes: Array<string> = [];

  constructor(logitsByPrefix: Map<string, Array<number>>, fallback: Array<number>) {
    this.logitsByPrefix = logitsByPrefix;
    this.fallback = fallback;
  }

  async run(graphName: 'encoder' | 'decoder_full', inputs: Array<TranslationTensor>): Promise<Array<TranslationTensor>> {
    if (graphName === 'encoder') {
      return [output('last_hidden_state', [1, 128, 2], new Float32Array(256))];
    }
    this.decoderCalls++;
    const ids = inputs[0].data as Int32Array;
    const mask = inputs[1].data as Int32Array;
    let length = 0;
    for (let index = 0; index < mask.length; index++) length += mask[index];
    const prefix: Array<number> = [];
    for (let index = 0; index < length; index++) prefix.push(ids[index]);
    const key = prefix.join(',');
    this.seenPrefixes.push(key);
    const row = this.logitsByPrefix.get(key) ?? this.fallback;
    const logits = new Float32Array(32 * 6);
    logits.fill(-20);
    const offset = (length - 1) * 6;
    for (let token = 0; token < row.length; token++) logits[offset + token] = row[token];
    return [output('logits', [1, 32, 6], logits)];
  }

  async close(): Promise<void> {}
}

function runnerFor(session: TranslationTensorSession, selectedDirection: TranslationDirectionManifest): MindSporeLiteTranslationRunner {
  return new MindSporeLiteTranslationRunner({ bundleFactory: async (): Promise<TranslationModelBundle> => ({
    direction: selectedDirection, session: session, requestQueue: new TranslationRequestQueue()
  }) });
}

export default function translationModelUnitTest(): void {
  describe('TranslationModelUnit', () => {
    it('routesSchemaV2TargetsWithoutACompatibilityView', 0, () => {
      const manifest = modelManifest();
      expect(translationDirectionForTarget(manifest, 'en').targetLanguage).assertEqual('en');
      expect(translationDirectionForTarget(manifest, 'zh').generation.numBeams).assertEqual(4);
      assertThrows((): void => { translationDirectionForTarget(manifest, 'fr'); });
      expect(Object.keys(manifest).indexOf('graphs')).assertEqual(-1);
      expect(Object.keys(manifest).indexOf('vocabulary')).assertEqual(-1);
    });

    it('usesSparseRepeatedUnkPForEncodingAndCompleteVForDecoding', 0, () => {
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const chunks = encodeTranslationTextForDirection('hello', '>>missing-prefix<< ', 5, 5, 0);
      expect(chunks.length).assertEqual(1);
      expect(chunks[0].inputIds.slice(0, 4).join(',')).assertEqual('5,3,0,5');
      expect(chunks[0].attentionMask.slice(0, 4).join(',')).assertEqual('1,1,1,0');
      const withoutPrefix = encodeTranslationTextForDirection('hello', '', -1, 5, 0);
      expect(withoutPrefix.length).assertEqual(1);
      expect(withoutPrefix[0].inputIds.slice(0, 3).join(',')).assertEqual('3,0,5');
      expect(withoutPrefix[0].attentionMask.slice(0, 3).join(',')).assertEqual('1,1,0');
      expect(decodeTranslationTokensForDirection([4, 2, 3, 0, 5], 0, 5)).assertEqual('\u4F60\u597D');
      assertThrows((): void => {
        configureTranslationTokenizersForTests(sourceTable(), targetTable().replace(`V\t3\t${codepoints('\u597D')}`, ''));
      });
    });

    it('reservesOneSourceSlotForTheManifestPrefixTokenId', 0, () => {
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const text = new Array<string>(127).fill('hello').join(' ');
      const withoutPrefix = encodeTranslationTextForDirection(text, '', -1, 5, 0);
      const withPrefix = encodeTranslationTextForDirection(text, 'not-in-p ', 5, 5, 0);
      expect(withoutPrefix.length).assertEqual(1);
      expect(withPrefix.length).assertEqual(2);
      expect(withPrefix[0].inputIds[0]).assertEqual(5);
    });

    it('rerunsStaticDecoderWithFixed32BindingsAndMasksPadInGreedy', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const session = new StaticDecoderSession([2, 0]);
      const result = await runnerFor(session, direction()).translate('hello', 'en');
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual('\u4F60');
      expect(session.encoderCalls).assertEqual(1);
      expect(session.decoderCalls).assertEqual(2);
      expect(session.exactBindings).assertTrue();
      expect(session.padWasHighest).assertTrue();
    });

    it('forcesGreedyEosAtTheFinalDecoderSlot', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const session = new StaticDecoderSession([2]);
      const result = await runnerFor(session, direction()).translate('hello', 'en');
      expect(result.ok).assertTrue();
      expect(session.decoderCalls).assertEqual(30);
    });

    it('beam4UsesFixedDecoderBindingsWithoutSelectingPad', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const session = new StaticDecoderSession([2, 0]);
      const result = await runnerFor(session, direction('beam', 'zh')).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(session.decoderCalls > 0).assertTrue();
      expect(session.exactBindings).assertTrue();
      expect(result.translatedText.indexOf('<pad>')).assertEqual(-1);
    });

    it('beamLengthPenaltyCountsTheCompletedEosGenerationStep', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const rows = new Map<string, Array<number>>();
      rows.set('5', beamLogits([2, 0.3, 3, 0]));
      rows.set('5,2', beamLogits([0, 0]));
      rows.set('5,3', beamLogits([3, 0]));
      rows.set('5,3,3', beamLogits([0, 0]));
      const session = new PrefixBeamSession(rows, beamLogits([0, 0]));
      const result = await runnerFor(session, direction('beam', 'zh')).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual('\u4F60');
    });

    it('beamEarlyDoneUsesTheGlobalTwoBeamCandidateBoundIncludingEos', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const rows = new Map<string, Array<number>>();
      rows.set('5', beamLogits([1, Math.log(0.4), 2, Math.log(0.3), 3, Math.log(0.2), 4, Math.log(0.1)]));
      for (let token = 1; token <= 4; token++) {
        rows.set(`5,${token}`, beamLogits([0, 0, token, Math.log(0.01 / 0.99)]));
      }
      const session = new PrefixBeamSession(rows, beamLogits([0, 0]));
      const result = await runnerFor(session, direction('beam', 'zh')).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(session.decoderCalls).assertEqual(9);
    });

    it('beamGlobalTwoBMergeCanSelectFourChildrenFromOneParent', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const rows = new Map<string, Array<number>>();
      rows.set('5', beamLogits([1, 0, 2, -5, 3, -6, 4, -7]));
      rows.set('5,1', beamLogits([1, 0, 2, -0.1, 3, -0.2, 4, -0.3]));
      rows.set('5,2', beamLogits([0, 0]));
      rows.set('5,3', beamLogits([0, 0]));
      rows.set('5,4', beamLogits([0, 0]));
      const session = new PrefixBeamSession(rows, beamLogits([0, 0]));
      const result = await runnerFor(session, direction('beam', 'zh')).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(session.seenPrefixes.slice(5, 9).join('|')).assertEqual('5,1,1|5,1,2|5,1,3|5,1,4');
    });

    it('beamEosRanksAndEqualScoresUseDeterministicFlattenedOrder', 0, async () => {
      resetTranslationTokenizerForTests();
      resetTranslationModelCacheForTests();
      configureTranslationTokenizersForTests(sourceTable(), targetTable());
      const rows = new Map<string, Array<number>>();
      rows.set('5', beamLogits([1, 0, 2, 0, 3, 0, 4, 0]));
      const tied = beamLogits([0, 0, 1, 0, 2, 0, 3, 0, 4, 0]);
      const session = new PrefixBeamSession(rows, tied);
      const result = await runnerFor(session, direction('beam', 'zh')).translate('hello', 'zh');
      expect(result.ok).assertTrue();
      expect(session.seenPrefixes.slice(5, 9).join('|')).assertEqual('5,1,1|5,1,2|5,1,3|5,1,4');
      expect(session.decoderCalls).assertEqual(17);
    });

    it('doesNotLoadOrInferForProtectedOnlyParagraphs', 0, async () => {
      let loads = 0;
      const runner = new MindSporeLiteTranslationRunner({ bundleFactory: async (): Promise<TranslationModelBundle> => {
        loads++;
        return { direction: direction(), session: new StaticDecoderSession([0]), requestQueue: new TranslationRequestQueue() };
      } });
      const result = await runner.translate('https://example.com/report_v5', 'en');
      expect(result.ok).assertTrue();
      expect(result.translatedText).assertEqual('https://example.com/report_v5');
      expect(loads).assertEqual(0);
    });

    it('translationRequestQueueKeepsFifoAfterARejectedOperation', 0, async () => {
      const queue = new TranslationRequestQueue();
      const order: Array<number> = [];
      const first = queue.runExclusive(async (): Promise<void> => { order.push(1); throw new Error('expected'); });
      const second = queue.runExclusive(async (): Promise<void> => { order.push(2); });
      try { await first; } catch (_) {}
      await second;
      expect(order.join(',')).assertEqual('1,2');
    });
  });
}
