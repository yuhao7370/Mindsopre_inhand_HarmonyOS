import { describe, it, expect } from '@ohos/hypium';
import {
  TranslationChunk,
  configureTranslationTokenizer,
  configureTranslationTokenizerForTests,
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

export default function translationModelUnitTest(): void {
  describe('TranslationModelUnit', () => {
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
      expect(chunks[1].separatorBefore).assertEqual('\n\n');
      expect(chunks[2].separatorBefore).assertEqual('\r\n');
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
  });
}
