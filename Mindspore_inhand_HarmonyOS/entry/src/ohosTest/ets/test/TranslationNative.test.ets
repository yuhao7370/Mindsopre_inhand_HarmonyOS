import { resourceManager } from '@kit.LocalizationKit';
import { fileIo } from '@kit.CoreFileKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  createHarmonyTextRecognitionService,
  createHarmonyTextTranslationService,
  HarmonyImageClassificationRuntimeOptions,
  HarmonyRawfileContentReader
} from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';
import { RawfileContentReader } from '../../../main/ets/services/ai/MindSporeLiteModelRunner';
import {
  productionTranslationModelBundleFactory,
  resetTranslationModelCacheForTests,
  TranslationModelBundleFactory,
  TranslationModelResourceManager,
  TranslationProductionBundleOptions
} from '../../../main/ets/services/ai/MindSporeLiteTranslationRunner';

class TranslationNativeBundleOptions implements TranslationProductionBundleOptions {
  readonly resourceManager: TranslationModelResourceManager;
  readonly cacheRoot: string;

  constructor(resourceManager: TranslationModelResourceManager, cacheRoot: string) {
    this.resourceManager = resourceManager;
    this.cacheRoot = cacheRoot;
  }
}

class TranslationNativeServiceOptions implements HarmonyImageClassificationRuntimeOptions {
  readonly resourceManager: RawfileContentReader;
  readonly translationModelResourceManager: TranslationModelResourceManager;
  readonly translationModelCacheRoot: string;
  readonly translationModelBundleFactory: TranslationModelBundleFactory;

  constructor(
    resourceManager: RawfileContentReader,
    translationModelResourceManager: TranslationModelResourceManager,
    translationModelCacheRoot: string,
    translationModelBundleFactory: TranslationModelBundleFactory
  ) {
    this.resourceManager = resourceManager;
    this.translationModelResourceManager = translationModelResourceManager;
    this.translationModelCacheRoot = translationModelCacheRoot;
    this.translationModelBundleFactory = translationModelBundleFactory;
  }
}

async function cacheOcrFixture(
  manager: resourceManager.ResourceManager,
  cacheDir: string,
  rawfilePath: string,
  outputName: string
): Promise<string> {
  const bytes = await manager.getRawFileContent(rawfilePath);
  const path = `${cacheDir}/${outputName}`;
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

function containsCjk(text: string): boolean {
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if (code >= 0x4e00 && code <= 0x9fff) {
      return true;
    }
  }
  return false;
}

function hasAdjacentRepeatedSpan(text: string): boolean {
  for (let width = 2; width * 2 <= text.length; width++) {
    for (let start = 0; start + width * 2 <= text.length; start++) {
      if (text.slice(start, start + width) === text.slice(start + width, start + width * 2)) {
        return true;
      }
    }
  }
  return false;
}

function containsLatinLetter(text: string): boolean {
  return /[A-Za-z]/.test(text);
}

function characterErrorRate(expected: string, actual: string): number {
  const previous: Array<number> = [];
  const current: Array<number> = [];
  for (let index = 0; index <= expected.length; index++) {
    previous.push(index);
    current.push(0);
  }
  for (let actualIndex = 1; actualIndex <= actual.length; actualIndex++) {
    current[0] = actualIndex;
    for (let expectedIndex = 1; expectedIndex <= expected.length; expectedIndex++) {
      const cost = expected[expectedIndex - 1] === actual[actualIndex - 1] ? 0 : 1;
      current[expectedIndex] = Math.min(
        current[expectedIndex - 1] + 1,
        previous[expectedIndex] + 1,
        previous[expectedIndex - 1] + cost
      );
    }
    for (let index = 0; index <= expected.length; index++) {
      previous[index] = current[index];
    }
  }
  return expected.length === 0 ? 1 : previous[expected.length] / expected.length;
}

export default function translationNativeTest() {
  describe('TranslationNativeTest', () => {
    it('translatesTypedAndOcrTextWithOneReusableLocalModelBundle', 0, async () => {
      resetTranslationModelCacheForTests();
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainResourceManager: resourceManager.ResourceManager =
        applicationContext.createModuleContext('entry').resourceManager;
      const testResourceManager: resourceManager.ResourceManager =
        applicationContext.createModuleContext('entry_test').resourceManager;
      const reader = new HarmonyRawfileContentReader(mainResourceManager);
      const translationResourceManager = reader as TranslationModelResourceManager;
      const cacheRoot = `${applicationContext.filesDir}/translation-ohos-test`;
      const productionBundleFactory = productionTranslationModelBundleFactory(
        new TranslationNativeBundleOptions(translationResourceManager, cacheRoot)
      );
      let bundleFactoryCalls = 0;
      const bundleFactory: TranslationModelBundleFactory = async () => {
        bundleFactoryCalls++;
        return await productionBundleFactory();
      };
      try {
        const service = await createHarmonyTextTranslationService(
          new TranslationNativeServiceOptions(reader, translationResourceManager, cacheRoot, bundleFactory)
        );
        const typedChinese = '\u8bf7\u628a\u95e8\u5173\u4e0a\u7136\u540e\u6253\u5f00\u7a97\u6237';
        const typedEnglish = 'Keep this report confidential until Monday.';
        const warmResult = await service.translateText(typedChinese);
        expect(warmResult.ok).assertTrue();
        expect(warmResult.targetLanguage).assertEqual('en');
        expect(warmResult.runtimeSource).assertEqual('localModel');

        let translationsFinished = false;
        let timerObservedPendingTranslation = false;
        const typedChineseAgain = service.translateText(typedChinese);
        const typedEnglishResult = service.translateText(typedEnglish);
        const timer = new Promise<void>((resolve: () => void): void => {
          setTimeout((): void => {
            timerObservedPendingTranslation = !translationsFinished;
            resolve();
          }, 0);
        });
        const results = await Promise.all([typedChineseAgain, typedEnglishResult]);
        translationsFinished = true;
        await timer;
        const typedChineseResult = results[0];
        const typedEnglishTranslated = results[1];
        const helloWorld = await service.translateText('hello world');

        expect(typedChineseResult.ok).assertTrue();
        expect(typedChineseResult.targetLanguage).assertEqual('en');
        expect(typedChineseResult.runtimeSource).assertEqual('localModel');
        expect(typedChineseResult.translatedText).assertEqual(warmResult.translatedText);
        expect(typedChineseResult.translatedText.trim().length > 0).assertTrue();
        expect(containsLatinLetter(typedChineseResult.translatedText)).assertTrue();
        expect(typedChineseResult.translatedText.toLowerCase().indexOf('close') >= 0).assertTrue();
        expect(typedChineseResult.translatedText.toLowerCase().indexOf('window') >= 0).assertTrue();
        expect(typedEnglishTranslated.ok).assertTrue();
        expect(typedEnglishTranslated.targetLanguage).assertEqual('zh');
        expect(typedEnglishTranslated.runtimeSource).assertEqual('localModel');
        expect(typedEnglishTranslated.translatedText.trim().length > 0).assertTrue();
        expect(containsCjk(typedEnglishTranslated.translatedText)).assertTrue();
        expect(typedEnglishTranslated.translatedText.indexOf('\u62a5\u544a') >= 0).assertTrue();
        expect(typedEnglishTranslated.translatedText.indexOf('\u4fdd\u5bc6') >= 0).assertTrue();
        expect(typedEnglishTranslated.translatedText.indexOf('\u661f\u671f\u4e00') >= 0).assertTrue();
        console.info(`translation-hello-world=${helloWorld.translatedText}`);
        expect(helloWorld.ok).assertTrue();
        expect(helloWorld.translatedText.trim().length > 0).assertTrue();
        expect(helloWorld.translatedText.length <= 128).assertTrue();
        expect(hasAdjacentRepeatedSpan(helloWorld.translatedText)).assertFalse();
        expect(typedChineseResult.translatedText !== typedEnglishTranslated.translatedText).assertTrue();
        expect(timerObservedPendingTranslation).assertTrue();

        const recognitionService = createHarmonyTextRecognitionService({ resourceManager: reader });
        const ocrInput = await cacheOcrFixture(
          testResourceManager,
          applicationContext.cacheDir,
          'fixtures/ocr/chinese_sentence.png',
          'translation-ocr-chinese-sentence.png'
        );
        const recognition = await recognitionService.recognizeText(ocrInput);
        const ocrCer = characterErrorRate(typedChinese, recognition.text);
        console.info(
          `translation-native-pre-ocr typedZhClose=${typedChineseResult.translatedText.toLowerCase().indexOf('close') >= 0}` +
          ` typedZhWindow=${typedChineseResult.translatedText.toLowerCase().indexOf('window') >= 0}` +
          ` typedEnReport=${typedEnglishTranslated.translatedText.indexOf('\u62a5\u544a') >= 0}` +
          ` typedEnConfidential=${typedEnglishTranslated.translatedText.indexOf('\u4fdd\u5bc6') >= 0}` +
          ` typedEnMonday=${typedEnglishTranslated.translatedText.indexOf('\u661f\u671f\u4e00') >= 0}` +
          ` timer=${timerObservedPendingTranslation} bundleFactoryCalls=${bundleFactoryCalls}` +
          ` ocrOk=${recognition.ok} ocrCer=${ocrCer} ocrSource=${recognition.text}`
        );
        expect(recognition.ok).assertTrue();
        expect(ocrCer <= 0.10).assertTrue();
        const ocrTranslation = await service.translateText(recognition.text);
        expect(ocrTranslation.ok).assertTrue();
        expect(ocrTranslation.runtimeSource).assertEqual('localModel');
        expect(ocrTranslation.sourceText).assertEqual(recognition.text);
        expect(ocrTranslation.translatedText.trim().length > 0).assertTrue();
        console.info(`translation-typed-zh=${typedChineseResult.translatedText}`);
        console.info(`translation-typed-en=${typedEnglishTranslated.translatedText}`);
        console.info(`translation-ocr-source=${recognition.text}`);
        console.info(`translation-ocr-output=${ocrTranslation.translatedText}`);
        console.info(
          `translation-native-post-ocr latin=${containsLatinLetter(ocrTranslation.translatedText)}` +
          ` close=${ocrTranslation.translatedText.toLowerCase().indexOf('close') >= 0}` +
          ` window=${ocrTranslation.translatedText.toLowerCase().indexOf('window') >= 0}` +
          ` bundleFactoryCalls=${bundleFactoryCalls}`
        );
        expect(containsLatinLetter(ocrTranslation.translatedText)).assertTrue();
        expect(ocrTranslation.translatedText.toLowerCase().indexOf('close') >= 0).assertTrue();
        expect(ocrTranslation.translatedText.toLowerCase().indexOf('window') >= 0).assertTrue();

        const empty = await service.translateText('');
        expect(empty.ok).assertFalse();
        expect(empty.errorCode).assertEqual('EMPTY_INPUT');
        expect(empty.translatedText).assertEqual('');
        expect(bundleFactoryCalls).assertEqual(1);
      } finally {
        resetTranslationModelCacheForTests();
      }
    });
  });
}
