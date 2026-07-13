import { describe, it, expect } from '@ohos/hypium';
import {
  TranslationChunk,
  configureTranslationTokenizer,
  decodeTranslationTokens,
  encodeTranslationText,
  translationTargetLanguageForText
} from '../main/ets/services/ai/TinyTranslationTokenizer';
import {
  TOKENIZER_GOLDEN_CASES,
  TOKENIZER_RUNTIME_FIXTURE,
  TranslationTokenizerGoldenCase,
  TranslationTokenizerGoldenChunk
} from './TranslationTokenizerFixture';

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

export default function translationModelUnitTest(): void {
  describe('TranslationModelUnit', () => {
    it('matchesPinnedPythonSentencePieceGoldens', 0, () => {
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
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
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
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
    });

    it('preservesOriginalNewlineCountOrderAndKinds', 0, () => {
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
      const golden = findGolden('multiple_newlines');
      const chunks = encodeTranslationText(golden.text, golden.target);

      expect(chunks.length).assertEqual(3);
      expect(chunks[0].separatorBefore).assertEqual('');
      expect(chunks[1].separatorBefore).assertEqual('\n\n');
      expect(chunks[2].separatorBefore).assertEqual('\r\n');
      expect(chunks[2].separatorAfter).assertEqual('\n');
    });

    it('usesAndroidBroadUnicodeDirectionRuleAndExactDirectionTokens', 0, () => {
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
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
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
      expect(decodeTranslationTokens([32002, 12249, 3, 1, 192, 0, 32000]))
        .assertEqual('Hello \u2047 world');
      expect(decodeTranslationTokens([32001, 14627, 0, 32000, 12249])).assertEqual('\u4F60\u597D');
    });

    it('rejectsMalformedRuntimeTableAndWhitespaceOnlyInput', 0, () => {
      assertThrows((): void => { configureTranslationTokenizer('TTOK1\tbad'); });
      configureTranslationTokenizer(TOKENIZER_RUNTIME_FIXTURE);
      expect(encodeTranslationText(' \t \n\r\n ', 'zh').length).assertEqual(0);
    });
  });
}
