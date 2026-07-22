import { describe, it, expect } from '@ohos/hypium';
import { TranslationChunk, configureTranslationTokenizer, configureTranslationTokenizerForTests, decodeTranslationTokens, encodeTranslationText, translationTargetLanguageForText } from '../main/ets/services/ai/TinyTranslationTokenizer';
import { TOKENIZER_DECODE_GOLDENS, TOKENIZER_GOLDEN_CASES, TOKENIZER_RUNTIME_FIXTURE, TranslationTokenizerGoldenCase, TranslationTokenizerGoldenChunk } from './TranslationTokenizerFixture';
import { TranslationGraphManifest, TranslationDirectionManifest, TranslationModelManifest, TranslationTensorManifest, TranslationTokenizerManifest, parseTranslationModelManifest } from '../main/ets/services/ai/TranslationModelManifest';
import { isTranslatableTranslationText, normalizeOcrLetterSpacing, prepareTranslationInput, TranslationInputSegment } from '../main/ets/services/ai/TranslationInputPolicy';

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
function assertDecoderSelfMask(mask: Array<number>, position: number): void {
    expect(mask.length).assertEqual(128);
    for (let index = 0; index < mask.length; index++) {
        expect(mask[index]).assertEqual(index < position || index === 127 ? 1 : 0);
    }
}
function serializedTranslationSegments(segments: Array<TranslationInputSegment>): string {
    const values: Array<string> = [];
    for (let index = 0; index < segments.length; index++) {
        values.push(`${segments[index].kind}:${segments[index].text}`);
    }
    return values.join('|');
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
    }
    catch (_) {
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
function manifestGraph(file: string, inputs: Array<TranslationTensorManifest>, outputs: Array<TranslationTensorManifest>): TranslationGraphManifest {
    let size = 100;
    let sha256 = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    if (file === 'zh-en/encoder.ms') {
        size = 16115736;
        sha256 = '86a9272199af2b3699a3d873b69e5741de3e26da545de06180902df071ff91bb';
    }
    else if (file === 'zh-en/decoder_full.ms') {
        size = 21247904;
        sha256 = '8dc03af96ac9f7bf9efb37ffcc42a0034f5305810a0059cd7c3cb66e48a3550d';
    }
    else if (file === 'en-zh/encoder.ms') {
        size = 55211640;
        sha256 = '4a1eae7e4b3600801b88df822bd42f786e9e34f715d12d0bac6454683599c5ee';
    }
    else if (file === 'en-zh/decoder_full.ms') {
        size = 97121896;
        sha256 = '5046af7b4311c14676d099e6cd01839f9c3b910d437184017797e972e559e66e';
    }
    return {
        file: file,
        size: size,
        sha256: sha256,
        inputs: inputs,
        outputs: outputs
    };
}
function manifestTokenizer(file: string): TranslationTokenizerManifest {
    const shared = file === 'zh-en/tokenizer.ttok';
    const source = file === 'en-zh/source.ttok';
    return {
        file: file,
        size: 100,
        sha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        modelSha256: shared ?
            'e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640' :
            (source ? '5775ddc9e3ff2fae91554da56468ad35ff56edaba870fea74447bc7234bfdaa8' :
                '81dc94efa84e4025ef38d25d5d07429fe41e3eb29d44003f1db6fe98487b0052'),
        vocabularySha256: shared ?
            '13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe' :
            'f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03',
        pieceCount: shared || source ? 32000 : 0,
        decodeVocabularySize: shared ? 32001 : (source ? 0 : 65001),
        specialTokens: { eos: '</s>', unk: '<unk>', pad: '<pad>' }
    };
}
function directionManifest(name: string): TranslationDirectionManifest {
    const zhEn = name === 'zh-en';
    const hidden = zhEn ? 256 : 512;
    const vocab = zhEn ? 32001 : 65001;
    const direction = zhEn ? 'zh-en' : 'en-zh';
    const sourceTokenizer = zhEn ? `${direction}/tokenizer.ttok` : `${direction}/source.ttok`;
    const targetTokenizer = zhEn ? sourceTokenizer : `${direction}/target.ttok`;
    const encoder = manifestGraph(`${direction}/encoder.ms`, [
        manifestTensor('input_ids', 'INT32', [1, 128]),
        manifestTensor('attention_mask', 'INT32', [1, 128])
    ], [manifestTensor('last_hidden_state', 'FLOAT32', [1, 128, hidden])]);
    const decoderFull = manifestGraph(`${direction}/decoder_full.ms`, [
        manifestTensor('decoder_input_ids', 'INT32', [1, 32]),
        manifestTensor('decoder_attention_mask', 'INT32', [1, 32]),
        manifestTensor('encoder_hidden_states', 'FLOAT32', [1, 128, hidden]),
        manifestTensor('encoder_attention_mask', 'INT32', [1, 128])
    ], [manifestTensor('logits', 'FLOAT32', [1, 32, vocab])]);
    return {
        sourceLanguage: zhEn ? 'zh' : 'en',
        targetLanguage: zhEn ? 'en' : 'zh',
        repository: zhEn ? 'Helsinki-NLP/opus-mt_tiny_zho-eng' : 'Helsinki-NLP/opus-mt-en-zh',
        revision: zhEn ? '4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd' :
            '408d9bc410a388e1d9aef112a2daba955b945255',
        generation: {
            strategy: zhEn ? 'greedy' : 'beam',
            numBeams: zhEn ? 1 : 4,
            sourcePrefix: zhEn ? '' : '>>cmn_Hans<< ',
            sourcePrefixTokenId: zhEn ? -1 : 5,
            sourceMaxTokens: 128,
            targetMaxTokens: 32
        },
        vocabulary: { size: vocab, eos: 0, unk: 1, pad: vocab - 1, decoderStart: vocab - 1 },
        tokenizers: {
            source: manifestTokenizer(sourceTokenizer),
            target: manifestTokenizer(targetTokenizer)
        },
        graphs: { encoder: encoder, decoderFull: decoderFull },
        graphBytes: encoder.size + decoderFull.size,
        maxGraphBytes: zhEn ? 36 * 1024 * 1024 : 147 * 1024 * 1024
    };
}
function validTranslationManifest(): TranslationModelManifest {
    return {
        schemaVersion: 2,
        directions: { en: directionManifest('zh-en'), zh: directionManifest('en-zh') },
        archive: { file: 'translation-models.tar.xz', size: 123,
            sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            cacheKey: 'ARCHIVE_SHA256', tarSize: 456,
            tarSha256: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            maxArchiveBytes: 152 * 1024 * 1024, maxTarBytes: 208 * 1024 * 1024 }
    };
}
function validTranslationManifestText(): string {
    const manifest = validTranslationManifest();
    return JSON.stringify({
        schemaVersion: manifest.schemaVersion,
        archive: manifest.archive,
        directions: manifest.directions
    });
}
export default function translationModelUnitTest(): void {
    describe('TranslationModelUnit', () => {
        it('normalizesOnlyLongOcrSpacedAsciiLetterRuns', 0, () => {
            expect(normalizeOcrLetterSpacing('P L E A S E   K E E P   C L E A R'))
                .assertEqual('PLEASE KEEP CLEAR');
            expect(normalizeOcrLetterSpacing('A B test')).assertEqual('A B test');
            expect(normalizeOcrLetterSpacing('中文 A B C')).assertEqual('中文 ABC');
            expect(normalizeOcrLetterSpacing('I N V O I C E\r\nN O.  B-3017'))
                .assertEqual('INVOICE\r\nN O.  B-3017');
        });
        it('protectsOnlyExactRuntimeDataSpans', 0, () => {
            const segments = prepareTranslationInput('Open https://example.com/help, mail a.b+1@example.org, then use report_v5 or B-3017.');
            expect(serializedTranslationSegments(segments)).assertEqual('model:Open |protected:https://example.com/help|model:, mail |' +
                'protected:a.b+1@example.org|model:, then use |protected:report_v5|' +
                'model: or |protected:B-3017|model:.');
        });
        it('keepsDatesNamesAndOrdinaryHyphenatedWordsInModelContext', 0, () => {
            const text = 'OpenAI met Alice on 2025-12-09 for state-of-the-art work.';
            expect(serializedTranslationSegments(prepareTranslationInput(text)))
                .assertEqual(`model:${text}`);
            expect(serializedTranslationSegments(prepareTranslationInput('Open http:// now')))
                .assertEqual('model:Open http:// now');
        });
        it('normalizesBeforeSegmentationAndPreservesNewlineOrder', 0, () => {
            expect(serializedTranslationSegments(prepareTranslationInput('O P E N   report_v5')))
                .assertEqual('model:OPEN |protected:report_v5');
            expect(serializedTranslationSegments(prepareTranslationInput('Open report_v5\r\nhttps://example.com/help'))).assertEqual('model:Open |protected:report_v5|model:\r\n|protected:https://example.com/help');
        });
        it('doesNotSendPunctuationOnlySeparatorsToTheModel', 0, () => {
            expect(isTranslatableTranslationText('.')).assertFalse();
            expect(isTranslatableTranslationText('\r\n')).assertFalse();
            expect(isTranslatableTranslationText('The guide is at ')).assertTrue();
            expect(isTranslatableTranslationText('指南位于')).assertTrue();
        });
        it('acceptsOnlyTheFinalPackageRuntimeManifestContract', 0, () => {
            const parsed = parseTranslationModelManifest(validTranslationManifestText());
            expect(parsed.schemaVersion).assertEqual(2);
            expect(parsed.directions.en.graphs.decoderFull.outputs[0].shape.join(','))
                .assertEqual('1,32,32001');
            expect(parsed.directions.zh.generation.numBeams).assertEqual(4);
            expect(parsed.directions.zh.generation.sourcePrefix).assertEqual('>>cmn_Hans<< ');
            expect(parsed.directions.zh.generation.sourcePrefixTokenId).assertEqual(5);
            expect(parsed.directions.en.generation.sourcePrefixTokenId).assertEqual(-1);
            expect(parsed.directions.en.tokenizers.source.file)
                .assertEqual(parsed.directions.en.tokenizers.target.file);
            const valid = validTranslationManifestText();
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"size":32001', '"size":32002')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('encoder.ms', 'encoder2.ms')); });
            assertThrows((): void => {
                parseTranslationModelManifest(valid.replace('"sourcePrefixTokenId":5', '"sourcePrefixTokenId":6'));
            });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('INT32', 'INT64')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('[1,128]', '[1,127]')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('aaaaaaaa', 'notahash')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"numBeams":4', '"numBeams":1')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('en-zh/source.ttok', 'zh-en/tokenizer.ttok')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('Helsinki-NLP/opus-mt-en-zh', 'other/model')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('408d9bc410a388e1d9aef112a2daba955b945255', '0000000000000000000000000000000000000000')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('4a1eae7e4b3600801b88df822bd42f786e9e34f715d12d0bac6454683599c5ee', 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('5775ddc9e3ff2fae91554da56468ad35ff56edaba870fea74447bc7234bfdaa8', 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"decodeVocabularySize":65001', '"decodeVocabularySize":32001')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"specialTokens":{"eos":"</s>"', '"specialTokens":{"eos":"<eos>"')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"graphBytes":37363640', '"graphBytes":37363641')); });
            assertThrows((): void => { parseTranslationModelManifest(valid.replace('"maxTarBytes":218103808', '"maxTarBytes":62914560')); });
            assertThrows((): void => {
                parseTranslationModelManifest(valid.replace('"schemaVersion":2', '"schemaVersion":2,"extra":1'));
            });
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
