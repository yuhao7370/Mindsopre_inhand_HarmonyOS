import { fileIo } from '@kit.CoreFileKit';
import { resourceManager } from '@kit.LocalizationKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  createHarmonyTextRecognitionService,
  HarmonyRawfileContentReader
} from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';

interface OcrFixture {
  readonly rawfilePath: string;
  readonly expected: string;
  readonly name: string;
}

async function cacheFixture(
  manager: resourceManager.ResourceManager,
  cacheDir: string,
  fixture: OcrFixture
): Promise<string> {
  const bytes = await manager.getRawFileContent(fixture.rawfilePath);
  const path = `${cacheDir}/${fixture.name}`;
  const file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    const written = await fileIo.write(file.fd, bytes.buffer as ArrayBuffer, {
      offset: bytes.byteOffset,
      length: bytes.byteLength
    });
    expect(written).assertEqual(bytes.byteLength);
  } finally {
    await fileIo.close(file);
  }
  return path;
}

function characterErrorRate(expected: string, actual: string): number {
  const previous: Array<number> = [];
  const current: Array<number> = [];
  for (let index = 0; index <= expected.length; index++) { previous.push(index); current.push(0); }
  for (let actualIndex = 1; actualIndex <= actual.length; actualIndex++) {
    current[0] = actualIndex;
    for (let expectedIndex = 1; expectedIndex <= expected.length; expectedIndex++) {
      const cost = expected[expectedIndex - 1] === actual[actualIndex - 1] ? 0 : 1;
      current[expectedIndex] = Math.min(current[expectedIndex - 1] + 1, previous[expectedIndex] + 1,
        previous[expectedIndex - 1] + cost);
    }
    for (let index = 0; index <= expected.length; index++) { previous[index] = current[index]; }
  }
  return expected.length === 0 ? 1 : previous[expected.length] / expected.length;
}

export default function ocrNativeTest() {
  describe('OcrNativeTest', () => {
    const fixtures: Array<OcrFixture> = [
      { rawfilePath: 'fixtures/ocr/english.png', expected: 'HELLO OCR 2026', name: 'ocr-english.png' },
      { rawfilePath: 'fixtures/ocr/chinese.png', expected: '\u6587\u5b57\u63d0\u53d6', name: 'ocr-chinese.png' },
      { rawfilePath: 'fixtures/ocr/multiline.png', expected: 'HELLO OCR\nMULTI LINE 2026', name: 'ocr-multiline.png' }
    ];
    fixtures.forEach((fixture: OcrFixture) => {
      it(`recognizes ${fixture.name} with CER at most ten percent`, 0, async () => {
        const applicationContext = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext();
        const mainManager = applicationContext.createModuleContext('entry').resourceManager;
        const testManager = applicationContext.createModuleContext('entry_test').resourceManager;
        const resources = new HarmonyRawfileContentReader(mainManager);
        const service = createHarmonyTextRecognitionService({ resourceManager: resources });
        const input = await cacheFixture(testManager, applicationContext.cacheDir, fixture);
        const result = await service.recognizeText(input);
        const cer = characterErrorRate(fixture.expected, result.text);
        console.info(`ocr-fixture=${fixture.name} text=${result.text} cer=${cer} elapsedMs=${result.executionMs}`);
        expect(result.ok).assertTrue();
        expect(cer <= 0.10).assertTrue();
      });
    });
  });
}
