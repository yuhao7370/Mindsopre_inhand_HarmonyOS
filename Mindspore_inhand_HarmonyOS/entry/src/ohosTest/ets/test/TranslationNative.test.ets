import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
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

export default function translationNativeTest() {
  describe('TranslationNativeTest', () => {
    it('translatesBothDirectionsDeterministicallyWithPackagedLocalModel', 0, async () => {
      const appContext = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const reader = new HarmonyRawfileContentReader(appContext.resourceManager);
      const translationResourceManager = reader as TranslationModelResourceManager;
      const cacheRoot = `${appContext.cacheDir}/translation-ohos-test`;
      const bundleOptions = new TranslationNativeBundleOptions(translationResourceManager, cacheRoot);
      const bundleFactory = productionTranslationModelBundleFactory(bundleOptions);
      const bundle = await bundleFactory();
      try {
        const sharedBundleFactory: TranslationModelBundleFactory = async () => bundle;
        const serviceOptions = new TranslationNativeServiceOptions(
          reader,
          translationResourceManager,
          cacheRoot,
          sharedBundleFactory
        );
        const service = await createHarmonyTextTranslationService(serviceOptions);
        const zhFirst = await service.translateText('请把门关上。');
        const zhSecond = await service.translateText('请把门关上。');
        const enFirst = await service.translateText('Do not delete this folder.');
        const enSecond = await service.translateText('Do not delete this folder.');

        expect(zhFirst.ok).assertTrue();
        expect(zhFirst.targetLanguage).assertEqual('en');
        expect(zhFirst.runtimeSource).assertEqual('localModel');
        expect(zhFirst.translatedText.trim().length > 0).assertTrue();
        expect(zhSecond.translatedText).assertEqual(zhFirst.translatedText);
        expect(enFirst.ok).assertTrue();
        expect(enFirst.targetLanguage).assertEqual('zh');
        expect(enFirst.runtimeSource).assertEqual('localModel');
        expect(enFirst.translatedText.trim().length > 0).assertTrue();
        expect(enSecond.translatedText).assertEqual(enFirst.translatedText);
      } finally {
        resetTranslationModelCacheForTests();
        await bundle.session.close();
      }
    });
  });
}
