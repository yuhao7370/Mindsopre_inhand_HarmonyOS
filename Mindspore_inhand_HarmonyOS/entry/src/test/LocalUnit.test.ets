import { describe, it, expect } from '@ohos/hypium';
import { AppRoute, findRouteByName } from '../main/ets/app/AppRoutes';
import { MainTab, mainTabs } from '../main/ets/app/AppState';
import { hasAppStringKey } from '../main/ets/common/i18n/AppStrings';
import { iconLabel } from '../main/ets/common/icons/IconSymbols';
import { DefaultAiService } from '../main/ets/services/ai/AiService';
import {
  ImageClassificationService,
  ImageClassificationScoreRunner,
  imageClassificationModelDownloadUrl,
  imageClassificationModelRawfilePath,
  imageCategoryLabelCount,
  parseImageCategoryLabels,
  topClassificationResult
} from '../main/ets/services/ai/ImageClassificationService';
import {
  ImageClassificationInputPreprocessor,
  ImageClassificationMindSporeScoreRunner,
  ImageClassificationTensorRunner
} from '../main/ets/services/ai/ImageClassificationPipeline';
import { imageClassificationDecodeOptions } from '../main/ets/services/ai/HarmonyImageInputPreprocessor';
import {
  CustomModelInputPreprocessor,
  CustomModelMindSporeRunner,
  CustomModelService,
  CustomModelTensorRunner,
  customModelDecodeOptions,
  customModelInputFloatCount,
  customModelInputSize,
  rgbUnitInputFromResizedRgba
} from '../main/ets/services/ai/CustomModelService';
import {
  createHarmonyDefaultAiService,
  createRuntimeAiServiceForWorkflow,
  rawfileAsciiContentToText
} from '../main/ets/services/ai/ImageClassificationRuntimeFactory';
import {
  floatScoresFromOutputBuffer,
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from '../main/ets/services/ai/MindSporeLiteModelRunner';
import {
  FileUriContentBackend,
  FileUriContentReader,
  FileUriDescriptor
} from '../main/ets/services/ai/FileUriContentReader';
import {
  objectDetectionModelDownloadUrl,
  objectDetectionModelRawfilePath,
  objectCategoryLabelCount,
  objectCategoryLabelRawfilePath,
  parseObjectCategoryLabels
} from '../main/ets/services/ai/ObjectDetectionService';
import { image } from '@kit.ImageKit';
import {
  imageClassificationCropOffset,
  imageClassificationCropSize,
  imageClassificationInputFloatCount,
  imageClassificationMean,
  imageClassificationResizedSize,
  imageClassificationStd,
  normalizedRgbInputFromResizedRgba
} from '../main/ets/services/ai/ImageClassificationPreprocess';
import { FeatureWorkflow, workflowForRoute } from '../main/ets/features/runtime/FeatureWorkflowCatalog';
import {
  declaredPermissionNames,
  runtimePermissionNamesForWorkflow
} from '../main/ets/services/permissions/PermissionService';
import {
  inputActionForKind,
  modelFileSuffixFilters,
  runtimeInputActionsForWorkflow
} from '../main/ets/services/picker/PickerService';
import {
  allExperienceFeatures,
  FeatureItem,
  FeatureSection,
  findFeatureByRoute,
  experienceSections,
  visibleExperienceSections
} from '../main/ets/common/data/FeatureCatalog';
import { collegeItems, isCollegeItemUrlNavigable } from '../main/ets/common/data/CollegeCatalog';
import { meItems, visibleMeItems } from '../main/ets/common/data/MeCatalog';

class FixedScoreRunner implements ImageClassificationScoreRunner {
  private readonly scores: Array<number>;

  constructor(scores: Array<number>) {
    this.scores = scores;
  }

  async predictScores(_imageUri: string): Promise<Array<number>> {
    return this.scores;
  }
}

class RejectingScoreRunner implements ImageClassificationScoreRunner {
  async predictScores(_imageUri: string): Promise<Array<number>> {
    throw new Error('native runner failed');
  }
}

class FixedInputPreprocessor implements ImageClassificationInputPreprocessor {
  readonly seenUris: Array<string> = [];
  private readonly inputBuffer: ArrayBuffer;

  constructor(inputBuffer: ArrayBuffer) {
    this.inputBuffer = inputBuffer;
  }

  async createInputBuffer(imageUri: string): Promise<ArrayBuffer> {
    this.seenUris.push(imageUri);
    return this.inputBuffer;
  }
}

class FixedTensorRunner implements ImageClassificationTensorRunner {
  readonly seenByteLengths: Array<number> = [];
  private readonly scores: Array<number>;

  constructor(scores: Array<number>) {
    this.scores = scores;
  }

  async predictScoresFromInput(inputBuffer: ArrayBuffer): Promise<Array<number>> {
    this.seenByteLengths.push(inputBuffer.byteLength);
    return this.scores;
  }
}

class FixedRawfileContentReader implements RawfileContentReader {
  readonly seenPaths: Array<string> = [];
  private readonly content: Uint8Array;

  constructor(content: Uint8Array) {
    this.content = content;
  }

  async getRawFileContent(path: string): Promise<Uint8Array> {
    this.seenPaths.push(path);
    return this.content;
  }
}

class ThrowingRawfileContentReader implements RawfileContentReader {
  async getRawFileContent(_path: string): Promise<Uint8Array> {
    throw new Error('unexpected rawfile access');
  }
}

class FixedFileUriContentBackend extends FileUriContentBackend {
  readonly events: Array<string> = [];
  private readonly content: Uint8Array;

  constructor(content: Uint8Array) {
    super();
    this.content = content;
  }

  async open(uri: string): Promise<FileUriDescriptor> {
    this.events.push(`open:${uri}`);
    return new FileUriDescriptor(42);
  }

  async size(file: FileUriDescriptor): Promise<number> {
    this.events.push(`size:${file.fd}`);
    return this.content.length + 2;
  }

  async read(file: FileUriDescriptor, buffer: ArrayBuffer): Promise<number> {
    this.events.push(`read:${file.fd}`);
    new Uint8Array(buffer).set(this.content);
    return this.content.length;
  }

  async close(file: FileUriDescriptor): Promise<void> {
    this.events.push(`close:${file.fd}`);
  }
}

class ThrowingFileUriContentBackend extends FixedFileUriContentBackend {
  async read(file: FileUriDescriptor, _buffer: ArrayBuffer): Promise<number> {
    this.events.push(`read:${file.fd}`);
    throw new Error('read failed');
  }
}

class FixedCustomModelPreprocessor implements CustomModelInputPreprocessor {
  readonly seenImageUris: Array<string> = [];
  private readonly inputBuffer: ArrayBuffer;

  constructor(inputBuffer: ArrayBuffer) {
    this.inputBuffer = inputBuffer;
  }

  async createInputBuffer(imageUri: string): Promise<ArrayBuffer> {
    this.seenImageUris.push(imageUri);
    return this.inputBuffer;
  }
}

class FixedCustomModelTensorRunner implements CustomModelTensorRunner {
  readonly seenModelUris: Array<string> = [];
  readonly seenInputBytes: Array<number> = [];
  private readonly outputScores: Array<number>;

  constructor(outputScores: Array<number>) {
    this.outputScores = outputScores;
  }

  async predictOutput(modelUri: string, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    this.seenModelUris.push(modelUri);
    this.seenInputBytes.push(inputBuffer.byteLength);
    return this.outputScores;
  }
}

class RejectingCustomModelTensorRunner implements CustomModelTensorRunner {
  async predictOutput(_modelUri: string, _inputBuffer: ArrayBuffer): Promise<Array<number>> {
    throw new Error('custom model failed');
  }
}

export default function localUnitTest() {
  describe('mindsporePortFoundation', () => {
    it('preservesAndroidRouteNames', 0, () => {
      expect(AppRoute.OBJECT_PHOTO.name).assertEqual('/imageobject/ObjectPhotoActivity');
      expect(AppRoute.STYLE_TRANSFER.name).assertEqual('/styletransfer/StyleMainActivity');
      expect(AppRoute.TEXT_TRANSLATION.name).assertEqual('/hms/TextTranslationActivity');
    });

    it('keepsHiddenAndroidFeaturesRouteReady', 0, () => {
      const dance = findFeatureByRoute('/dance/DanceMainActivity');
      const poetry = findFeatureByRoute('/app/IntelligentPoetryWritingActivity');
      expect(dance?.visibleByDefault).assertFalse();
      expect(poetry?.visibleByDefault).assertFalse();
    });

    it('showsExpectedVisibleExperienceFeatures', 0, () => {
      const visibleCount = visibleExperienceSections
        .map((section) => section.items.length)
        .reduce((sum, count) => sum + count, 0);
      expect(visibleCount).assertEqual(10);
      expect(allExperienceFeatures.length).assertEqual(12);
    });

    it('definesCollegeAndMeRows', 0, () => {
      expect(collegeItems.length).assertEqual(6);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].title).assertEqual('Version');
    });

    it('definesThreeMainTabsInAndroidOrder', 0, () => {
      expect(mainTabs.length).assertEqual(3);
      expect(mainTabs[0].id).assertEqual(MainTab.EXPERIENCE);
      expect(mainTabs[1].title).assertEqual('College');
      expect(mainTabs[2].title).assertEqual('Me');
    });

    it('mapsSemanticIconTokensToCompactLabels', 0, () => {
      expect(iconLabel('people')).assertEqual('P');
      expect(iconLabel('rocket')).assertEqual('E');
      expect(iconLabel('translate')).assertEqual('Tr');
      expect(iconLabel('image').length <= 2).assertTrue();
    });

    it('assignsI18nKeysToVisibleShellData', 0, () => {
      expect(hasAppStringKey(mainTabs[0].titleKey)).assertTrue();
      expect(hasAppStringKey(experienceSections[0].titleKey)).assertTrue();
      expect(hasAppStringKey(allExperienceFeatures[0].titleKey)).assertTrue();
      expect(hasAppStringKey(collegeItems[0].titleKey)).assertTrue();
      expect(hasAppStringKey(meItems[0].titleKey)).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_failed')).assertTrue();
    });

    it('doesNotNavigateQuickStartParentWithEmptyUrl', 0, () => {
      expect(isCollegeItemUrlNavigable(collegeItems[1])).assertTrue();
      expect(isCollegeItemUrlNavigable(collegeItems[2])).assertFalse();
    });

    it('definesRuntimeWorkflowForEveryVisibleExperienceFeature', 0, () => {
      visibleExperienceSections.forEach((section: FeatureSection) => {
        section.items.forEach((item: FeatureItem) => {
          const workflow = workflowForRoute(item.routeName);
          expect(workflow !== undefined).assertTrue();
          expect(workflow!.titleKey).assertEqual(item.titleKey);
        });
      });
    });

    it('mapsCoreFeatureRoutesToExpectedRuntimeCapabilities', 0, () => {
      const classification: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      expect(classification.aiMethod).assertEqual('classifyImage');
      expect(classification.inputKinds.indexOf('camera') >= 0).assertTrue();

      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      expect(styleTransfer.aiMethod).assertEqual('runStyleTransfer');
      expect(styleTransfer.inputKinds.indexOf('contentImage') >= 0).assertTrue();
      expect(styleTransfer.inputKinds.indexOf('styleImage') >= 0).assertTrue();

      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      expect(translation.aiMethod).assertEqual('translateText');
      expect(translation.inputKinds.indexOf('text') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(translation.requiredPermissions.indexOf('internet') >= 0).assertTrue();
    });

    it('recordsPlatformNeedsFromOriginalAndroidFlows', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      expect(posenet.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(posenet.inputKinds.indexOf('photo') >= 0).assertTrue();

      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(objectPhoto.inputKinds.indexOf('modelFile') >= 0).assertTrue();
      expect(objectPhoto.requiredPermissions.indexOf('media') >= 0).assertTrue();

      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      expect(objectCamera.inputKinds.indexOf('modelFile') >= 0).assertTrue();
      expect(objectCamera.requiredPermissions.indexOf('media') >= 0).assertTrue();

      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;
      expect(customModel.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('modelFile') >= 0).assertTrue();
    });

    it('definesRuntimeWorkflowForEveryRuntimeRoute', 0, () => {
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name) !== undefined).assertTrue();
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name) !== undefined).assertTrue();
    });

    it('routesVisibleFeaturesToRuntimePage', 0, () => {
      visibleExperienceSections.forEach((section: FeatureSection) => {
        section.items.forEach((item: FeatureItem) => {
          expect(findRouteByName(item.routeName)?.page).assertEqual('pages/FeatureRuntimePage');
        });
      });
    });

    it('aiServiceReturnsExplicitPendingAdapterFailure', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.aiMethod).assertEqual('detectObjects');
    });

    it('customModelRequiresModelAndImageInputs', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');

      const imageOnlyResult = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/input.png'
      });
      expect(imageOnlyResult.ok).assertFalse();
      expect(imageOnlyResult.code).assertEqual('MISSING_INPUT');

      const modelOnlyResult = await new DefaultAiService().run(workflow!, {
        modelUri: 'file://selected/custom_model.ms'
      });
      expect(modelOnlyResult.ok).assertFalse();
      expect(modelOnlyResult.code).assertEqual('MISSING_INPUT');
    });

    it('customModelReturnsSimulatedTensorSummary', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: 'file://selected/custom_model.ms'
      });
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CUSTOM_MODEL_SIMULATED');
      expect(result.detailText.indexOf('output[0]') >= 0).assertTrue();
      expect(result.detailText.indexOf('custom_model.ms') >= 0).assertTrue();
    });

    it('normalizesCustomModelRgbaToRgbUnitInput', 0, () => {
      const rgba: Uint8Array = new Uint8Array(customModelInputSize * customModelInputSize * 4);
      rgba[0] = 255;
      rgba[1] = 128;
      rgba[2] = 0;
      rgba[3] = 99;

      const input = new Float32Array(rgbUnitInputFromResizedRgba(rgba));
      expect(customModelInputSize).assertEqual(224);
      expect(input.length).assertEqual(customModelInputFloatCount);
      expect(input[0].toFixed(6)).assertEqual('1.000000');
      expect(input[1].toFixed(6)).assertEqual('0.501961');
      expect(input[2].toFixed(6)).assertEqual('0.000000');
    });

    it('requestsCustomModelDecodeAsAndroid224Rgba', 0, () => {
      const options: image.DecodingOptions = customModelDecodeOptions();
      expect(options.desiredSize!.width).assertEqual(224);
      expect(options.desiredSize!.height).assertEqual(224);
      expect(options.desiredPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
    });

    it('customModelServiceRunsSelectedModelWithAndroidInputContract', 0, async () => {
      const inputBuffer: ArrayBuffer = new ArrayBuffer(224 * 224 * 3 * 4);
      const preprocessor: FixedCustomModelPreprocessor = new FixedCustomModelPreprocessor(inputBuffer);
      const tensorRunner: FixedCustomModelTensorRunner = new FixedCustomModelTensorRunner([0.1, 0.2, 0.3]);
      const service = new CustomModelService({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      const result = await service.run('file://selected/custom_model.ms', 'file://selected/input.png');

      expect(result.ok).assertTrue();
      expect(result.output.length).assertEqual(3);
      expect(preprocessor.seenImageUris[0]).assertEqual('file://selected/input.png');
      expect(tensorRunner.seenModelUris[0]).assertEqual('file://selected/custom_model.ms');
      expect(tensorRunner.seenInputBytes[0]).assertEqual(inputBuffer.byteLength);
    });

    it('customModelMindSporeRunnerBridgesPreprocessorToSelectedModelRunner', 0, async () => {
      const inputBuffer: ArrayBuffer = new ArrayBuffer(12);
      const preprocessor: FixedCustomModelPreprocessor = new FixedCustomModelPreprocessor(inputBuffer);
      const tensorRunner: FixedCustomModelTensorRunner = new FixedCustomModelTensorRunner([0.4, 0.6]);
      const runner = new CustomModelMindSporeRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      const result = await runner.run('file://selected/custom_model.ms', 'file://selected/input.png');

      expect(result.ok).assertTrue();
      expect(result.output[1]).assertEqual(0.6);
      expect(preprocessor.seenImageUris[0]).assertEqual('file://selected/input.png');
      expect(tensorRunner.seenModelUris[0]).assertEqual('file://selected/custom_model.ms');
    });

    it('aiServiceUsesRealCustomModelServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedCustomModelTensorRunner([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1])
      });

      const result = await new DefaultAiService({ customModelService: customModelService }).run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: 'file://selected/custom_model.ms'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CUSTOM_MODEL_DONE');
      expect(result.detailText.indexOf('Model execution completed!') >= 0).assertTrue();
      expect(result.detailText.indexOf('Value[0]: 0.100000') >= 0).assertTrue();
      expect(result.detailText.indexOf('... (showing first 10 values)') >= 0).assertTrue();
    });

    it('aiServiceReportsCustomModelRunnerFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new RejectingCustomModelTensorRunner()
      });

      const result = await new DefaultAiService({ customModelService: customModelService }).run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: 'file://selected/custom_model.ms'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('CUSTOM_MODEL_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_custom_model_failed');
    });

    it('parsesAndroidImageClassificationLabels', 0, () => {
      const labels = parseImageCategoryLabels('tench\r\ngoldfish\n\ntoilet_tissue\n');
      expect(labels.length).assertEqual(3);
      expect(labels[0]).assertEqual('tench');
      expect(labels[2]).assertEqual('toilet_tissue');
      expect(imageCategoryLabelCount).assertEqual(1000);
    });

    it('usesAndroidMobilenetV2ModelAssetContract', 0, () => {
      expect(imageClassificationModelRawfilePath).assertEqual('model/mobilenetv2.ms');
      expect(imageClassificationModelDownloadUrl).assertEqual('https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms');
    });

    it('parsesAndroidObjectDetectionLabels', 0, () => {
      const labels = parseObjectCategoryLabels('background\r\nhuman\nbike\n\ntoothbrush\n');
      expect(labels.length).assertEqual(4);
      expect(labels[0]).assertEqual('background');
      expect(labels[1]).assertEqual('human');
      expect(labels[3]).assertEqual('toothbrush');
      expect(objectCategoryLabelCount).assertEqual(81);
    });

    it('usesAndroidSsdObjectDetectionAssetContract', 0, () => {
      expect(objectCategoryLabelRawfilePath).assertEqual('labels/object_category.txt');
      expect(objectDetectionModelRawfilePath).assertEqual('model/ssd.ms');
      expect(objectDetectionModelDownloadUrl).assertEqual('https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms');
    });

    it('copiesRawfileViewToExactModelBuffer', 0, () => {
      const backing: Uint8Array = new Uint8Array([9, 1, 2, 3, 8]);
      const view: Uint8Array = backing.subarray(1, 4);
      const buffer: ArrayBuffer = rawfileContentToArrayBuffer(view);
      const copied: Uint8Array = new Uint8Array(buffer);
      expect(copied.length).assertEqual(3);
      expect(copied[0]).assertEqual(1);
      expect(copied[2]).assertEqual(3);
    });

    it('readsSelectedModelUriContentToExactBytes', 0, async () => {
      const backend: FixedFileUriContentBackend = new FixedFileUriContentBackend(new Uint8Array([1, 2, 3]));
      const content = await new FileUriContentReader(backend).readFileContent('file://selected/custom_model.ms');

      expect(content.length).assertEqual(3);
      expect(content[0]).assertEqual(1);
      expect(content[2]).assertEqual(3);
      expect(backend.events.join('|')).assertEqual('open:file://selected/custom_model.ms|size:42|read:42|close:42');
    });

    it('closesSelectedModelUriWhenReadFails', 0, async () => {
      const backend: ThrowingFileUriContentBackend = new ThrowingFileUriContentBackend(new Uint8Array([1, 2, 3]));
      let failed = false;
      try {
        await new FileUriContentReader(backend).readFileContent('file://selected/bad.ms');
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(backend.events.join('|')).assertEqual('open:file://selected/bad.ms|size:42|read:42|close:42');
    });

    it('readsMindSporeFloatOutputScores', 0, () => {
      const output: Float32Array = new Float32Array([0.1, 0.9, 0.2]);
      const outputBuffer: ArrayBuffer = output.buffer as ArrayBuffer;
      const scores: Array<number> = floatScoresFromOutputBuffer(outputBuffer);
      expect(scores.length).assertEqual(3);
      expect(scores[1].toFixed(6)).assertEqual('0.900000');
    });

    it('definesAndroidImageClassificationPreprocessContract', 0, () => {
      expect(imageClassificationResizedSize).assertEqual(256);
      expect(imageClassificationCropSize).assertEqual(224);
      expect(imageClassificationCropOffset).assertEqual(16);
      expect(imageClassificationInputFloatCount).assertEqual(224 * 224 * 3);
      expect(imageClassificationMean[0].toFixed(3)).assertEqual('0.485');
      expect(imageClassificationStd[2].toFixed(3)).assertEqual('0.225');
    });

    it('normalizesCenterCroppedRgbaToRgbHwcInput', 0, () => {
      const rgba: Uint8Array = new Uint8Array(imageClassificationResizedSize * imageClassificationResizedSize * 4);
      const cropTopLeftRgbaOffset = ((imageClassificationCropOffset * imageClassificationResizedSize) +
        imageClassificationCropOffset) * 4;
      rgba[cropTopLeftRgbaOffset] = 255;
      rgba[cropTopLeftRgbaOffset + 1] = 0;
      rgba[cropTopLeftRgbaOffset + 2] = 0;
      rgba[cropTopLeftRgbaOffset + 3] = 13;

      const input = new Float32Array(normalizedRgbInputFromResizedRgba(rgba));
      expect(input.length).assertEqual(imageClassificationInputFloatCount);
      expect(input[0].toFixed(6)).assertEqual('2.248908');
      expect(input[1].toFixed(6)).assertEqual('-2.035714');
      expect(input[2].toFixed(6)).assertEqual('-1.804444');
    });

    it('requestsHarmonyDecodeAsResizedRgba', 0, () => {
      const options: image.DecodingOptions = imageClassificationDecodeOptions();
      expect(options.desiredSize!.width).assertEqual(imageClassificationResizedSize);
      expect(options.desiredSize!.height).assertEqual(imageClassificationResizedSize);
      expect(options.desiredPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
    });

    it('decodesRawfileAsciiContentForAndroidLabels', 0, () => {
      const content: Uint8Array = new Uint8Array([116, 101, 110, 99, 104, 13, 10, 103, 111, 108, 100, 102, 105, 115, 104]);
      expect(rawfileAsciiContentToText(content)).assertEqual('tench\r\ngoldfish');
    });

    it('mapsTopClassificationScoreToLabel', 0, () => {
      const result = topClassificationResult([0.1, 0.9, 0.2], ['tench', 'goldfish', 'great_white_shark']);
      expect(result.ok).assertTrue();
      expect(result.index).assertEqual(1);
      expect(result.label).assertEqual('goldfish');
      expect(result.score).assertEqual(0.9);
    });

    it('rejectsEmptyClassificationScores', 0, () => {
      const result = topClassificationResult([], ['tench']);
      expect(result.ok).assertFalse();
      expect(result.index).assertEqual(-1);
    });

    it('preservesAndroidClassificationDefaultForNonPositiveScores', 0, () => {
      const result = topClassificationResult([-0.2, -0.1], ['tench', 'goldfish']);
      expect(result.ok).assertTrue();
      expect(result.index).assertEqual(0);
      expect(result.label).assertEqual('tench');
      expect(result.score).assertEqual(0);
    });

    it('ignoresScoresAfterAndroidImageNetClassCount', 0, () => {
      const labels: Array<string> = [];
      const scores: Array<number> = [];
      for (let index = 0; index < imageCategoryLabelCount; index++) {
        labels.push(`label_${index}`);
        scores.push(0.1);
      }
      labels[999] = 'toilet_tissue';
      scores[999] = 0.8;
      scores.push(0.99);

      const result = topClassificationResult(scores, labels);
      expect(result.ok).assertTrue();
      expect(result.index).assertEqual(999);
      expect(result.label).assertEqual('toilet_tissue');
    });

    it('classificationRequiresImageInput', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('classificationReportsModelRunnerPendingWithoutAdapter', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/cat.jpg'
      });
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('CLASSIFICATION_MODEL_PENDING');
      expect(result.messageKey).assertEqual('feature_runtime_classification_pending');
    });

    it('classificationMapsRunnerScoresToAndroidLabel', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const scoreRunner: ImageClassificationScoreRunner = new FixedScoreRunner([0.1, 0.9, 0.2]);
      const service = new ImageClassificationService({
        labels: ['tench', 'goldfish', 'great_white_shark'],
        scoreRunner: scoreRunner
      });
      const result = await new DefaultAiService({ imageClassificationService: service }).run(workflow!, {
        imageUri: 'file://selected/fish.jpg'
      });
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CLASSIFICATION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_classification_done');
      expect(result.detailText.indexOf('label=goldfish') >= 0).assertTrue();
      expect(result.detailText.indexOf('score=0.900000') >= 0).assertTrue();
      expect(result.detailText.indexOf('fish.jpg') >= 0).assertTrue();
    });

    it('classificationFailsWhenRunnerScoresDoNotMapToLabel', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const scoreRunner: ImageClassificationScoreRunner = new FixedScoreRunner([0.1, 0.9]);
      const service = new ImageClassificationService({
        labels: ['tench'],
        scoreRunner: scoreRunner
      });
      const result = await new DefaultAiService({ imageClassificationService: service }).run(workflow!, {
        imageUri: 'file://selected/fish.jpg'
      });
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('CLASSIFICATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_classification_failed');
    });

    it('classificationHandlesRunnerRejectionAsFailedResult', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const service = new ImageClassificationService({
        labels: ['tench'],
        scoreRunner: new RejectingScoreRunner()
      });
      const result = await new DefaultAiService({ imageClassificationService: service }).run(workflow!, {
        imageUri: 'file://selected/fish.jpg'
      });
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('CLASSIFICATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_classification_failed');
    });

    it('classificationMindSporeRunnerBridgesImagePreprocessorToTensorRunner', 0, async () => {
      const inputBuffer: ArrayBuffer = new ArrayBuffer(12);
      const preprocessor: FixedInputPreprocessor = new FixedInputPreprocessor(inputBuffer);
      const tensorRunner: FixedTensorRunner = new FixedTensorRunner([0.3, 0.7]);
      const runner: ImageClassificationScoreRunner = new ImageClassificationMindSporeScoreRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      const scores: Array<number> = await runner.predictScores('file://selected/fish.jpg');
      expect(scores.length).assertEqual(2);
      expect(scores[1]).assertEqual(0.7);
      expect(preprocessor.seenUris[0]).assertEqual('file://selected/fish.jpg');
      expect(tensorRunner.seenByteLengths[0]).assertEqual(12);
    });

    it('createsHarmonyDefaultAiServiceWithRawfileLabelsAndRunner', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([116, 101, 110, 99, 104, 10, 103, 111, 108, 100, 102, 105, 115, 104]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await createHarmonyDefaultAiService({
        resourceManager: resourceManager,
        inputPreprocessor: new FixedInputPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedTensorRunner([0.1, 0.9])
      });

      const result = await service.run(workflow!, {
        imageUri: 'file://selected/fish.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/image_category_old.txt');
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CLASSIFICATION_DONE');
      expect(result.detailText.indexOf('label=goldfish') >= 0).assertTrue();
    });

    it('keepsNonClassificationWorkflowsOnDefaultPendingRuntime', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result = await service.run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
    });

    it('runtimeFactoryInjectsCustomModelServiceForCustomModelWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        customModelPreprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        customModelTensorRunner: new FixedCustomModelTensorRunner([0.2])
      });

      const result = await service.run(workflow!, {
        modelUri: 'file://selected/custom_model.ms',
        imageUri: 'file://selected/input.png'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CUSTOM_MODEL_DONE');
      expect(result.detailText.indexOf('Value[0]: 0.200000') >= 0).assertTrue();
    });

    it('mapsWorkflowPermissionsToHarmonyPermissionNames', 0, () => {
      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const permissionNames = runtimePermissionNamesForWorkflow(translation);
      expect(permissionNames.indexOf('ohos.permission.CAMERA') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.READ_IMAGEVIDEO') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.INTERNET')).assertEqual(-1);
      expect(declaredPermissionNames.indexOf('ohos.permission.INTERNET') >= 0).assertTrue();
    });

    it('mapsWorkflowInputsToPickerActions', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const actions = runtimeInputActionsForWorkflow(styleTransfer);
      expect(actions.indexOf('captureOrPickImage') >= 0).assertTrue();
      expect(actions.indexOf('pickModelFile') >= 0).assertTrue();
      expect(inputActionForKind('text')).assertEqual('enterText');
    });

    it('usesMindSporeModelFileSuffixForModelPicker', 0, () => {
      expect(modelFileSuffixFilters.length).assertEqual(1);
      expect(modelFileSuffixFilters[0]).assertEqual('.ms');
    });
  });
}
