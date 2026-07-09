import { describe, it, expect } from '@ohos/hypium';
import { AppRoute, findRouteByName } from '../main/ets/app/AppRoutes';
import { MainTab, mainTabs } from '../main/ets/app/AppState';
import { hasAppStringKey } from '../main/ets/common/i18n/AppStrings';
import { iconLabel } from '../main/ets/common/icons/IconSymbols';
import { AiRunResult, DefaultAiService, aiRunResultRows, copyableTextForAiResult } from '../main/ets/services/ai/AiService';
import { ClipboardService, TextClipboardWriter } from '../main/ets/services/clipboard/ClipboardService';
import {
  androidDefaultTranslationTargetLanguage,
  containsAndroidChineseText,
  parseTranslationLanguagePairs,
  TextRecognitionResult,
  TextRecognitionRunner,
  TextRecognitionService,
  TextTranslationResult,
  TextTranslationRunner,
  TextTranslationService,
  textRecognitionOutputFromBlocks,
  translationLanguagePairsRawfilePath
} from '../main/ets/services/ai/TextRecognitionService';
import {
  SegmentationRectangle,
  SegmentationResult,
  SegmentationRunner,
  SegmentationService
} from '../main/ets/services/ai/SegmentationService';
import {
  PosePoint,
  PoseResult,
  PoseRunner,
  PoseService
} from '../main/ets/services/ai/PoseService';
import {
  StyleTransferInput,
  StyleTransferInputPreprocessor,
  StyleTransferResult,
  StyleTransferRunner,
  StyleTransferService,
  StyleTransferTensorOutput,
  StyleTransferTensorRunner,
  StyleTransferMindSporeRunner,
  stylePredictModelDownloadUrl,
  stylePredictModelRawfilePath,
  styleTransferContentImageSize,
  styleTransferDecodeOptions,
  styleTransferModelDownloadUrl,
  styleTransferModelRawfilePath,
  styleTransferOutputFloatCount,
  styleTransferRgbUnitInputFromRgba,
  styleTransferStyleImageSize
} from '../main/ets/services/ai/StyleTransferService';
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
  ObjectDetection,
  ObjectDetectionRunResult,
  ObjectDetectionRunner,
  ObjectDetectionService,
  ObjectDetectionInput,
  ObjectDetectionInputPreprocessor,
  ObjectDetectionMindSporeRunner,
  ObjectDetectionModelOutput,
  ObjectDetectionTensorRunner,
  decodeSsdObjectDetections,
  generateObjectDetectionDefaultBoxes,
  objectDetectionAnchorCount,
  objectDetectionClassCount,
  objectDetectionDecodeOptions,
  objectDetectionInputFloatCount,
  objectDetectionInputSize,
  ObjectDetectionNormalBox,
  objectDetectionModelOutputFromFloatArrays,
  normalizedObjectDetectionRgbInputFromRgba,
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
import {
  collegeMainCloudUrl,
  harmonyPrivacyRawfile,
  intelligentPoetryUrl,
  userPrivacyRulesUrl,
  webDestinationForUrl,
  webUrlForRouteName,
  webPagePath
} from '../main/ets/common/data/WebDestination';
import { collegeItems, isCollegeItemUrlNavigable } from '../main/ets/common/data/CollegeCatalog';
import { MeItem, isMeItemUrlNavigable, meItems, visibleMeItems } from '../main/ets/common/data/MeCatalog';
import { AppVersionReader, AppVersionService, formattedAppVersionName } from '../main/ets/services/app/AppVersionService';

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

class FixedObjectDetectionRunner implements ObjectDetectionRunner {
  readonly seenImageUris: Array<string> = [];
  readonly seenModelUris: Array<string> = [];
  private readonly detections: Array<ObjectDetection>;

  constructor(detections: Array<ObjectDetection>) {
    this.detections = detections;
  }

  async detectObjects(imageUri: string, modelUri?: string): Promise<Array<ObjectDetection>> {
    this.seenImageUris.push(imageUri);
    this.seenModelUris.push(modelUri ?? '');
    return this.detections;
  }
}

class RejectingObjectDetectionRunner implements ObjectDetectionRunner {
  async detectObjects(_imageUri: string, _modelUri?: string): Promise<Array<ObjectDetection>> {
    throw new Error('object detection failed');
  }
}

class FixedStyleTransferRunner implements StyleTransferRunner {
  readonly seenContentUris: Array<string> = [];
  readonly seenStyleUris: Array<string> = [];
  private readonly result: StyleTransferResult;

  constructor(result: StyleTransferResult) {
    this.result = result;
  }

  async run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult> {
    this.seenContentUris.push(contentImageUri);
    this.seenStyleUris.push(styleImageUri);
    return this.result;
  }
}

class RejectingStyleTransferRunner implements StyleTransferRunner {
  async run(_contentImageUri: string, _styleImageUri: string): Promise<StyleTransferResult> {
    throw new Error('style transfer failed');
  }
}

class FixedStyleTransferPreprocessor implements StyleTransferInputPreprocessor {
  readonly seenContentUris: Array<string> = [];
  readonly seenStyleUris: Array<string> = [];
  private readonly input: StyleTransferInput;

  constructor(input: StyleTransferInput) {
    this.input = input;
  }

  async createInput(contentImageUri: string, styleImageUri: string): Promise<StyleTransferInput> {
    this.seenContentUris.push(contentImageUri);
    this.seenStyleUris.push(styleImageUri);
    return this.input;
  }
}

class FixedStyleTransferTensorRunner implements StyleTransferTensorRunner {
  readonly seenContentBytes: Array<number> = [];
  readonly seenStyleBytes: Array<number> = [];
  private readonly output: StyleTransferTensorOutput;

  constructor(output: StyleTransferTensorOutput) {
    this.output = output;
  }

  async runStyleTransfer(input: StyleTransferInput): Promise<StyleTransferTensorOutput> {
    this.seenContentBytes.push(input.contentInputBuffer.byteLength);
    this.seenStyleBytes.push(input.styleInputBuffer.byteLength);
    return this.output;
  }
}

class FixedAppVersionReader implements AppVersionReader {
  private readonly versionName: string;

  constructor(versionName: string) {
    this.versionName = versionName;
  }

  getVersionName(): string {
    return this.versionName;
  }
}

class ThrowingAppVersionReader implements AppVersionReader {
  getVersionName(): string {
    throw new Error('bundle info unavailable');
  }
}

class FixedTextRecognitionRunner implements TextRecognitionRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly result: TextRecognitionResult;

  constructor(result: TextRecognitionResult) {
    this.result = result;
  }

  async recognizeText(imageUri: string): Promise<TextRecognitionResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingTextRecognitionRunner implements TextRecognitionRunner {
  async recognizeText(_imageUri: string): Promise<TextRecognitionResult> {
    throw new Error('text recognition failed');
  }
}

class FixedTextTranslationRunner implements TextTranslationRunner {
  readonly seenTexts: Array<string> = [];
  readonly seenTargetLanguages: Array<string> = [];
  private readonly translatedText: string;

  constructor(translatedText: string) {
    this.translatedText = translatedText;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    this.seenTexts.push(text);
    this.seenTargetLanguages.push(targetLanguage);
    return {
      ok: true,
      sourceText: text,
      translatedText: this.translatedText,
      targetLanguage: targetLanguage
    };
  }
}

class RejectingTextTranslationRunner implements TextTranslationRunner {
  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    return {
      ok: false,
      sourceText: text,
      translatedText: '',
      targetLanguage: targetLanguage
    };
  }
}

class FixedSegmentationRunner implements SegmentationRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly result: SegmentationResult;

  constructor(result: SegmentationResult) {
    this.result = result;
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingSegmentationRunner implements SegmentationRunner {
  async segmentPerson(_imageUri: string): Promise<SegmentationResult> {
    throw new Error('segmentation failed');
  }
}

class FixedPoseRunner implements PoseRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly result: PoseResult;

  constructor(result: PoseResult) {
    this.result = result;
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingPoseRunner implements PoseRunner {
  async detectPose(_imageUri: string): Promise<PoseResult> {
    throw new Error('pose detection failed');
  }
}

class RecordingClipboardWriter implements TextClipboardWriter {
  readonly copiedTexts: Array<string> = [];

  async copyText(text: string): Promise<void> {
    this.copiedTexts.push(text);
  }
}

class RejectingClipboardWriter implements TextClipboardWriter {
  async copyText(_text: string): Promise<void> {
    throw new Error('clipboard rejected');
  }
}

class FixedObjectDetectionPreprocessor implements ObjectDetectionInputPreprocessor {
  readonly seenImageUris: Array<string> = [];
  private readonly input: ObjectDetectionInput;

  constructor(input: ObjectDetectionInput) {
    this.input = input;
  }

  async createInput(imageUri: string): Promise<ObjectDetectionInput> {
    this.seenImageUris.push(imageUri);
    return this.input;
  }
}

class FixedObjectDetectionTensorRunner implements ObjectDetectionTensorRunner {
  readonly seenByteLengths: Array<number> = [];
  readonly seenModelUris: Array<string> = [];
  private readonly output: ObjectDetectionModelOutput;

  constructor(output: ObjectDetectionModelOutput) {
    this.output = output;
  }

  async predictOutput(inputBuffer: ArrayBuffer, modelUri?: string): Promise<ObjectDetectionModelOutput> {
    this.seenByteLengths.push(inputBuffer.byteLength);
    this.seenModelUris.push(modelUri ?? '');
    return this.output;
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
      expect(visibleMeItems.length).assertEqual(7);
      expect(visibleMeItems[5].title).assertEqual('Version');
    });

    it('formatsAppVersionNameLikeAndroidPackageInfo', 0, () => {
      expect(formattedAppVersionName('2.10.0')).assertEqual('V2.10.0');
      expect(formattedAppVersionName(' V3.0.1 ')).assertEqual('V3.0.1');
      expect(formattedAppVersionName('')).assertEqual('V1.0.0');
    });

    it('appVersionServiceReadsBundleVersionNameWithFallback', 0, () => {
      expect(new AppVersionService(new FixedAppVersionReader('2.10.0')).currentVersionLabel()).assertEqual('V2.10.0');
      expect(new AppVersionService(new ThrowingAppVersionReader()).currentVersionLabel()).assertEqual('V1.0.0');
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
      expect(hasAppStringKey('feature_runtime_text_recognition_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_translation_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_segmentation_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_preview_title')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_count')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_done')).assertTrue();
    });

    it('clipboardServiceCopiesRecognizedText', 0, async () => {
      const writer = new RecordingClipboardWriter();
      const result = await new ClipboardService(writer).copyText('MindSpore\nHarmonyOS');

      expect(result.ok).assertTrue();
      expect(result.copiedTextLength).assertEqual(19);
      expect(writer.copiedTexts[0]).assertEqual('MindSpore\nHarmonyOS');
    });

    it('clipboardServiceRejectsBlankOrFailedText', 0, async () => {
      const blankResult = await new ClipboardService(new RecordingClipboardWriter()).copyText('');
      const failedResult = await new ClipboardService(new RejectingClipboardWriter()).copyText('MindSpore');

      expect(blankResult.ok).assertFalse();
      expect(failedResult.ok).assertFalse();
    });

    it('doesNotNavigateQuickStartParentWithEmptyUrl', 0, () => {
      expect(isCollegeItemUrlNavigable(collegeItems[1])).assertTrue();
      expect(isCollegeItemUrlNavigable(collegeItems[2])).assertFalse();
    });

    it('mapsCollegeAndPrivacyLinksToHarmonyWebPage', 0, () => {
      expect(AppRoute.PRIVACY.page).assertEqual(webPagePath);
      expect(collegeItems[1].url).assertEqual(collegeMainCloudUrl);

      const privacyDestination = webDestinationForUrl(userPrivacyRulesUrl, 'me_official_title');
      expect(privacyDestination.titleKey).assertEqual('me_user_agreements');
      expect(privacyDestination.localRawfile).assertEqual(harmonyPrivacyRawfile);

      const collegeDestination = webDestinationForUrl(collegeMainCloudUrl, 'me_official_title');
      expect(collegeDestination.titleKey).assertEqual('college_cloud_title');
      expect(collegeDestination.url).assertEqual(collegeMainCloudUrl);
    });

    it('restoresNavigableMeWebEntries', 0, () => {
      const privacyItem = visibleMeItems.find((item: MeItem) => item.id === 'privacy');
      expect(privacyItem !== undefined).assertTrue();
      if (privacyItem) {
        expect(isMeItemUrlNavigable(privacyItem)).assertTrue();
        expect(privacyItem.url).assertEqual(userPrivacyRulesUrl);
      }

      const versionItem = visibleMeItems.find((item: MeItem) => item.id === 'version');
      expect(versionItem !== undefined).assertTrue();
      if (versionItem) {
        expect(isMeItemUrlNavigable(versionItem)).assertFalse();
      }
    });

    it('routesMyQrCodeToNativeHarmonyPage', 0, () => {
      const qrItem = visibleMeItems.find((item: MeItem) => item.id === 'qr');
      expect(qrItem !== undefined).assertTrue();
      expect(AppRoute.MY_QR_CODE.page).assertEqual('pages/QrCodePage');
      if (qrItem) {
        expect(qrItem.page).assertEqual(AppRoute.MY_QR_CODE.page);
      }
    });

    it('routesIntelligentPoetryToOriginalWebExperience', 0, () => {
      expect(AppRoute.POETRY.page).assertEqual(webPagePath);
      expect(webUrlForRouteName(AppRoute.POETRY.name)).assertEqual(intelligentPoetryUrl);
      const poetryDestination = webDestinationForUrl(intelligentPoetryUrl, 'me_official_title');
      expect(poetryDestination.titleKey).assertEqual('title_intelligent_poetry');
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

    it('formatsCoreVisionTextBlocksLikeAndroidLineOutput', 0, () => {
      const text = textRecognitionOutputFromBlocks([
        {
          value: 'ignored block value',
          lines: [
            { value: 'MindSpore' },
            { value: 'HarmonyOS' }
          ]
        },
        {
          value: 'second block',
          lines: [
            { value: 'AI' }
          ]
        }
      ]);

      expect(text).assertEqual('MindSpore\nHarmonyOS\nAI\n');
    });

    it('detectsAndroidChineseRangesForTranslationTarget', 0, () => {
      expect(containsAndroidChineseText('hello')).assertFalse();
      expect(containsAndroidChineseText('你好')).assertTrue();
      expect(containsAndroidChineseText('hello，')).assertTrue();
      expect(containsAndroidChineseText('⺀')).assertTrue();
      expect(androidDefaultTranslationTargetLanguage('你好')).assertEqual('en');
      expect(androidDefaultTranslationTargetLanguage('hello')).assertEqual('zh');
    });

    it('parsesAndroidTranslationLanguagePairs', 0, () => {
      const pairs = parseTranslationLanguagePairs('English en\nChinese zh\nChinese(Traditional) zh-HK\n');

      expect(translationLanguagePairsRawfilePath).assertEqual('hms/Country_pair_new.txt');
      expect(pairs.length).assertEqual(3);
      expect(pairs[0].name).assertEqual('English');
      expect(pairs[0].code).assertEqual('en');
      expect(pairs[2].code).assertEqual('zh-HK');
    });

    it('textRecognitionRequiresImageInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextRecognitionService({
        runner: new FixedTextRecognitionRunner({
          ok: true,
          text: 'MindSpore\n',
          lineCount: 1,
          blockCount: 1,
          executionMs: 4
        })
      });

      const result = await new DefaultAiService({ textRecognitionService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesRealTextRecognitionServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'MindSpore\nHarmonyOS\n',
        lineCount: 2,
        blockCount: 1,
        executionMs: 9
      });
      const service = new TextRecognitionService({
        runner: runner
      });

      const result = await new DefaultAiService({ textRecognitionService: service }).run(workflow!, {
        imageUri: 'file://selected/text.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_RECOGNITION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_text_recognition_done');
      expect(result.detailText.indexOf('MindSpore') >= 0).assertTrue();
      expect(result.detailText.indexOf('lineCount=2') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_lines');
      expect(aiRunResultRows(result)[2].value.indexOf('MindSpore') >= 0).assertTrue();
      expect(runner.seenImageUris[0]).assertEqual('file://selected/text.jpg');
    });

    it('aiServiceReportsTextRecognitionFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextRecognitionService({
        runner: new RejectingTextRecognitionRunner()
      });

      const result = await new DefaultAiService({ textRecognitionService: service }).run(workflow!, {
        imageUri: 'file://selected/text.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('TEXT_RECOGNITION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_recognition_failed');
    });

    it('textTranslationRequiresTextInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextTranslationService({
        runner: new FixedTextTranslationRunner('translated')
      });

      const result = await new DefaultAiService({ textTranslationService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesAndroidTargetLanguageRuleForTextTranslation', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedTextTranslationRunner = new FixedTextTranslationRunner('hello');
      const service = new TextTranslationService({
        runner: runner
      });

      const result = await new DefaultAiService({ textTranslationService: service }).run(workflow!, {
        text: '你好'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_done');
      expect(result.detailText.indexOf('targetLanguage=en') >= 0).assertTrue();
      expect(result.detailText.indexOf('translated=hello') >= 0).assertTrue();
      expect(runner.seenTexts[0]).assertEqual('你好');
      expect(runner.seenTargetLanguages[0]).assertEqual('en');
    });

    it('aiServiceRecognizesImageTextBeforeTextTranslationLikeAndroid', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: '你好\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 8
      });
      const translationRunner: FixedTextTranslationRunner = new FixedTextTranslationRunner('hello');

      const result = await new DefaultAiService({
        textRecognitionService: new TextRecognitionService({ runner: recognitionRunner }),
        textTranslationService: new TextTranslationService({ runner: translationRunner })
      }).run(workflow!, {
        imageUri: 'file://selected/text.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/text.jpg');
      expect(translationRunner.seenTexts[0]).assertEqual('你好\n');
      expect(translationRunner.seenTargetLanguages[0]).assertEqual('en');
    });

    it('copyableTextForTranslationReturnsTranslatedTextLikeAndroidCopyButton', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextTranslationService({
        runner: new FixedTextTranslationRunner('hello')
      });

      const result = await new DefaultAiService({ textTranslationService: service }).run(workflow!, {
        text: '你好'
      });

      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('hello');
    });

    it('aiServiceReportsTextTranslationFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextTranslationService({
        runner: new RejectingTextTranslationRunner()
      });

      const result = await new DefaultAiService({ textTranslationService: service }).run(workflow!, {
        text: 'hello'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
    });

    it('segmentationRequiresImageInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SegmentationService({
        runner: new FixedSegmentationRunner({
          ok: true,
          subjectCount: 1,
          detailCount: 0,
          foregroundAvailable: true,
          rectangles: [],
          executionMs: 3
        })
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesRealSegmentationServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const rectangle: SegmentationRectangle = {
        left: 1,
        top: 2,
        width: 100,
        height: 200
      };
      const runner: FixedSegmentationRunner = new FixedSegmentationRunner({
        ok: true,
        subjectCount: 1,
        detailCount: 1,
        foregroundAvailable: true,
        rectangles: [rectangle],
        executionMs: 13
      });
      const service = new SegmentationService({
        runner: runner
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/person.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SEGMENTATION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_segmentation_done');
      expect(result.detailText.indexOf('subjectCount=1') >= 0).assertTrue();
      expect(result.detailText.indexOf('[1,2,100,200]') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_subjects');
      expect(aiRunResultRows(result)[0].value).assertEqual('1');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/person.jpg');
    });

    it('aiServiceReportsSegmentationFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SegmentationService({
        runner: new RejectingSegmentationRunner()
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/person.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SEGMENTATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_segmentation_failed');
    });

    it('poseDetectionRequiresImageInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const service = new PoseService({
        runner: new FixedPoseRunner({
          ok: true,
          skeletonCount: 1,
          pointCount: 17,
          points: [],
          executionMs: 3
        })
      });

      const result = await new DefaultAiService({ poseService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesRealPoseServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const nose: PosePoint = {
        type: 0,
        score: 0.95,
        x: 10,
        y: 20
      };
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: 1,
        points: [nose],
        executionMs: 14
      });
      const service = new PoseService({
        runner: runner
      });

      const result = await new DefaultAiService({ poseService: service }).run(workflow!, {
        imageUri: 'file://selected/pose.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('POSE_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_pose_done');
      expect(result.detailText.indexOf('skeletonCount=1') >= 0).assertTrue();
      expect(result.detailText.indexOf('0 95.00% [10,20]') >= 0).assertTrue();
      expect(aiRunResultRows(result)[1].labelKey).assertEqual('feature_runtime_result_points');
      expect(aiRunResultRows(result)[1].value).assertEqual('1');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/pose.jpg');
    });

    it('aiServiceReportsPoseFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const service = new PoseService({
        runner: new RejectingPoseRunner()
      });

      const result = await new DefaultAiService({ poseService: service }).run(workflow!, {
        imageUri: 'file://selected/pose.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('POSE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_pose_failed');
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

    it('styleTransferRequiresContentAndStyleInputsWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      expect(workflow !== undefined).assertTrue();
      const styleTransferService = new StyleTransferService({
        runner: new FixedStyleTransferRunner({
          ok: true,
          outputFloatCount: 384 * 384 * 3,
          predictMs: 1,
          transferMs: 2,
          executionMs: 3
        })
      });

      const result: AiRunResult = await new DefaultAiService({ styleTransferService: styleTransferService }).run(workflow!, {
        contentImageUri: 'file://selected/content.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesRealStyleTransferServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedStyleTransferRunner = new FixedStyleTransferRunner({
        ok: true,
        outputFloatCount: 384 * 384 * 3,
        predictMs: 11,
        transferMs: 22,
        executionMs: 40
      });
      const styleTransferService = new StyleTransferService({
        runner: runner
      });

      const result: AiRunResult = await new DefaultAiService({ styleTransferService: styleTransferService }).run(workflow!, {
        contentImageUri: 'file://selected/content.jpg',
        styleImageUri: 'file://selected/style.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('STYLE_TRANSFER_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_style_transfer_done');
      expect(result.detailText.indexOf('outputFloats=442368') >= 0).assertTrue();
      expect(result.detailText.indexOf('predictMs=11') >= 0).assertTrue();
      expect(runner.seenContentUris[0]).assertEqual('file://selected/content.jpg');
      expect(runner.seenStyleUris[0]).assertEqual('file://selected/style.jpg');
    });

    it('aiServiceReportsStyleTransferRunnerFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      expect(workflow !== undefined).assertTrue();
      const styleTransferService = new StyleTransferService({
        runner: new RejectingStyleTransferRunner()
      });

      const result: AiRunResult = await new DefaultAiService({ styleTransferService: styleTransferService }).run(workflow!, {
        contentImageUri: 'file://selected/content.jpg',
        styleImageUri: 'file://selected/style.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('STYLE_TRANSFER_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_style_transfer_failed');
    });

    it('usesAndroidStyleTransferModelAssetContract', 0, () => {
      expect(stylePredictModelRawfilePath).assertEqual('model/style_predict_quant.ms');
      expect(styleTransferModelRawfilePath).assertEqual('model/style_transfer_quant.ms');
      expect(stylePredictModelDownloadUrl).assertEqual('https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms');
      expect(styleTransferModelDownloadUrl).assertEqual('https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms');
    });

    it('definesAndroidStyleTransferPreprocessContract', 0, () => {
      expect(styleTransferStyleImageSize).assertEqual(256);
      expect(styleTransferContentImageSize).assertEqual(384);
      expect(styleTransferOutputFloatCount).assertEqual(384 * 384 * 3);
    });

    it('normalizesStyleTransferRgbaToRgbUnitInput', 0, () => {
      const rgba: Uint8Array = new Uint8Array(styleTransferStyleImageSize * styleTransferStyleImageSize * 4);
      rgba[0] = 255;
      rgba[1] = 128;
      rgba[2] = 0;
      rgba[3] = 99;

      const input = new Float32Array(styleTransferRgbUnitInputFromRgba(rgba, styleTransferStyleImageSize));

      expect(input.length).assertEqual(styleTransferStyleImageSize * styleTransferStyleImageSize * 3);
      expect(input[0].toFixed(6)).assertEqual('1.000000');
      expect(input[1].toFixed(6)).assertEqual('0.501961');
      expect(input[2].toFixed(6)).assertEqual('0.000000');
    });

    it('requestsStyleTransferDecodeAsAndroidRgbaSizes', 0, () => {
      const styleOptions: image.DecodingOptions = styleTransferDecodeOptions(styleTransferStyleImageSize);
      const contentOptions: image.DecodingOptions = styleTransferDecodeOptions(styleTransferContentImageSize);
      expect(styleOptions.desiredSize!.width).assertEqual(256);
      expect(styleOptions.desiredPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
      expect(contentOptions.desiredSize!.height).assertEqual(384);
    });

    it('styleTransferMindSporeRunnerBridgesPreprocessorToTensorRunner', 0, async () => {
      const input: StyleTransferInput = {
        contentInputBuffer: new ArrayBuffer(384 * 384 * 3 * 4),
        styleInputBuffer: new ArrayBuffer(256 * 256 * 3 * 4)
      };
      const preprocessor: FixedStyleTransferPreprocessor = new FixedStyleTransferPreprocessor(input);
      const tensorRunner: FixedStyleTransferTensorRunner = new FixedStyleTransferTensorRunner({
        output: new Float32Array(styleTransferOutputFloatCount),
        predictMs: 7,
        transferMs: 9
      });
      const runner = new StyleTransferMindSporeRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      const result: StyleTransferResult =
        await runner.run('file://selected/content.jpg', 'file://selected/style.jpg');

      expect(result.ok).assertTrue();
      expect(result.outputFloatCount).assertEqual(styleTransferOutputFloatCount);
      expect(result.predictMs).assertEqual(7);
      expect(result.transferMs).assertEqual(9);
      expect(preprocessor.seenContentUris[0]).assertEqual('file://selected/content.jpg');
      expect(tensorRunner.seenStyleBytes[0]).assertEqual(256 * 256 * 3 * 4);
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

    it('definesAndroidObjectDetectionPreprocessContract', 0, () => {
      expect(objectDetectionInputSize).assertEqual(300);
      expect(objectDetectionInputFloatCount).assertEqual(300 * 300 * 3);
    });

    it('normalizesObjectDetectionRgbaToRgbHwcInput', 0, () => {
      const rgba: Uint8Array = new Uint8Array(objectDetectionInputSize * objectDetectionInputSize * 4);
      rgba[0] = 255;
      rgba[1] = 0;
      rgba[2] = 0;
      rgba[3] = 77;

      const input = new Float32Array(normalizedObjectDetectionRgbInputFromRgba(rgba));

      expect(input.length).assertEqual(objectDetectionInputFloatCount);
      expect(input[0].toFixed(6)).assertEqual('2.248908');
      expect(input[1].toFixed(6)).assertEqual('-2.035714');
      expect(input[2].toFixed(6)).assertEqual('-1.804444');
    });

    it('requestsObjectDetectionDecodeAsAndroid300Rgba', 0, () => {
      const options: image.DecodingOptions = objectDetectionDecodeOptions();
      expect(options.desiredSize!.width).assertEqual(300);
      expect(options.desiredSize!.height).assertEqual(300);
      expect(options.desiredPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
    });

    it('objectDetectionServiceMapsRunnerDetectionsToAndroidLabels', 0, async () => {
      const detection: ObjectDetection = {
        imageId: 7,
        labelId: 1,
        label: '',
        score: 0.875,
        left: 10,
        top: 20,
        right: 110,
        bottom: 120
      };
      const runner: FixedObjectDetectionRunner = new FixedObjectDetectionRunner([detection]);
      const service = new ObjectDetectionService({
        labels: ['background', 'person'],
        runner: runner
      });

      const result: ObjectDetectionRunResult = await service.detectObjects('file://selected/street.jpg', 'file://selected/ssd.ms');

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('DETECTION_DONE');
      expect(result.detections.length).assertEqual(1);
      expect(result.detections[0].label).assertEqual('person');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/street.jpg');
      expect(runner.seenModelUris[0]).assertEqual('file://selected/ssd.ms');
    });

    it('objectDetectionServiceHandlesRunnerFailureAsInvalidOutput', 0, async () => {
      const service = new ObjectDetectionService({
        labels: ['background'],
        runner: new RejectingObjectDetectionRunner()
      });

      const result: ObjectDetectionRunResult = await service.detectObjects('file://selected/street.jpg');

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('DETECTION_INVALID_OUTPUT');
    });

    it('aiServiceUsesRealObjectDetectionServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const detection: ObjectDetection = {
        imageId: 4,
        labelId: 1,
        label: '',
        score: 0.75,
        left: 1,
        top: 2,
        right: 101,
        bottom: 202
      };
      const service = new ObjectDetectionService({
        labels: ['background', 'person'],
        runner: new FixedObjectDetectionRunner([detection])
      });

      const result: AiRunResult = await new DefaultAiService({ objectDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/street.jpg',
        modelUri: 'file://selected/ssd.ms'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('OBJECT_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_object_detection_done');
      expect(result.detailText.indexOf('person') >= 0).assertTrue();
      expect(result.detailText.indexOf('75.00%') >= 0).assertTrue();
      expect(result.detailText.indexOf('street.jpg') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_count');
      expect(aiRunResultRows(result)[1].value.indexOf('person') >= 0).assertTrue();
    });

    it('runtimeFactoryInjectsObjectDetectionServiceForObjectWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([98, 97, 99, 107, 103, 114, 111, 117, 110, 100, 10, 112, 101, 114, 115, 111, 110]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const detection: ObjectDetection = {
        imageId: 1,
        labelId: 1,
        label: '',
        score: 0.8,
        left: 3,
        top: 4,
        right: 103,
        bottom: 204
      };
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: resourceManager,
        objectDetectionRunner: new FixedObjectDetectionRunner([detection])
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/street.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/object_category.txt');
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('OBJECT_DETECTION_DONE');
      expect(result.detailText.indexOf('person') >= 0).assertTrue();
    });

    it('generatesAndroidSsdDefaultBoxes', 0, () => {
      const boxes: Array<ObjectDetectionNormalBox> = generateObjectDetectionDefaultBoxes();

      expect(objectDetectionAnchorCount).assertEqual(1917);
      expect(objectDetectionClassCount).assertEqual(81);
      expect(boxes.length).assertEqual(objectDetectionAnchorCount);
      expect(boxes[0].x.toFixed(6)).assertEqual('0.026667');
      expect(boxes[0].y.toFixed(6)).assertEqual('0.026667');
      expect(boxes[0].w.toFixed(6)).assertEqual('0.100000');
      expect(boxes[0].h.toFixed(6)).assertEqual('0.100000');
      expect(boxes[1916].x.toFixed(6)).assertEqual('0.500000');
      expect(boxes[1916].h.toFixed(6)).assertEqual('0.974679');
    });

    it('decodesAndroidSsdBoxesToOriginalImageCoordinates', 0, () => {
      const scores: Float32Array = new Float32Array(objectDetectionAnchorCount * objectDetectionClassCount);
      const boxes: Float32Array = new Float32Array(objectDetectionAnchorCount * 4);
      scores[1] = 0.7;

      const detections: Array<ObjectDetection> =
        decodeSsdObjectDetections(scores, boxes, ['background', 'person'], 600, 300);

      expect(detections.length).assertEqual(1);
      expect(detections[0].imageId).assertEqual(0);
      expect(detections[0].labelId).assertEqual(1);
      expect(detections[0].label).assertEqual('person');
      expect(detections[0].left.toFixed(0)).assertEqual('0');
      expect(detections[0].top.toFixed(0)).assertEqual('0');
      expect(detections[0].right.toFixed(0)).assertEqual('46');
      expect(detections[0].bottom.toFixed(0)).assertEqual('23');
    });

    it('appliesAndroidSsdThresholdsAndNmsPerClass', 0, () => {
      const scores: Float32Array = new Float32Array(objectDetectionAnchorCount * objectDetectionClassCount);
      const boxes: Float32Array = new Float32Array(objectDetectionAnchorCount * 4);
      scores[1] = 0.9;
      scores[objectDetectionClassCount + 1] = 0.8;

      const detections: Array<ObjectDetection> =
        decodeSsdObjectDetections(scores, boxes, ['background', 'person'], 300, 300);

      expect(detections.length).assertEqual(1);
      expect(detections[0].imageId).assertEqual(0);
      expect(detections[0].score.toFixed(1)).assertEqual('0.9');
    });

    it('identifiesObjectDetectionModelOutputsByAndroidElementCount', 0, () => {
      const boxes: Float32Array = new Float32Array(objectDetectionAnchorCount * 4);
      const scores: Float32Array = new Float32Array(objectDetectionAnchorCount * objectDetectionClassCount);
      boxes[3] = 0.25;
      scores[1] = 0.7;

      const output: ObjectDetectionModelOutput = objectDetectionModelOutputFromFloatArrays([boxes, scores]);

      expect(output.boxes.length).assertEqual(objectDetectionAnchorCount * 4);
      expect(output.scores.length).assertEqual(objectDetectionAnchorCount * objectDetectionClassCount);
      expect(output.boxes[3]).assertEqual(0.25);
      expect(output.scores[1].toFixed(1)).assertEqual('0.7');
    });

    it('objectDetectionMindSporeRunnerBridgesPreprocessorTensorRunnerAndSsdDecode', 0, async () => {
      const scores: Float32Array = new Float32Array(objectDetectionAnchorCount * objectDetectionClassCount);
      const boxes: Float32Array = new Float32Array(objectDetectionAnchorCount * 4);
      scores[1] = 0.7;
      const input: ObjectDetectionInput = {
        inputBuffer: new ArrayBuffer(12),
        imageWidth: 600,
        imageHeight: 300
      };
      const preprocessor: FixedObjectDetectionPreprocessor = new FixedObjectDetectionPreprocessor(input);
      const tensorRunner: FixedObjectDetectionTensorRunner = new FixedObjectDetectionTensorRunner({
        scores: scores,
        boxes: boxes
      });
      const runner = new ObjectDetectionMindSporeRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      const detections: Array<ObjectDetection> =
        await runner.detectObjects('file://selected/street.jpg', 'file://selected/ssd.ms');

      expect(detections.length).assertEqual(1);
      expect(detections[0].right.toFixed(0)).assertEqual('46');
      expect(preprocessor.seenImageUris[0]).assertEqual('file://selected/street.jpg');
      expect(tensorRunner.seenByteLengths[0]).assertEqual(12);
      expect(tensorRunner.seenModelUris[0]).assertEqual('file://selected/ssd.ms');
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
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_label');
      expect(aiRunResultRows(result)[0].value).assertEqual('goldfish');
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
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
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

    it('runtimeFactoryInjectsStyleTransferServiceForStyleWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        styleTransferRunner: new FixedStyleTransferRunner({
          ok: true,
          outputFloatCount: 384 * 384 * 3,
          predictMs: 5,
          transferMs: 6,
          executionMs: 12
        })
      });

      const result: AiRunResult = await service.run(workflow!, {
        contentImageUri: 'file://selected/content.jpg',
        styleImageUri: 'file://selected/style.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('STYLE_TRANSFER_DONE');
      expect(result.detailText.indexOf('transferMs=6') >= 0).assertTrue();
    });

    it('runtimeFactoryInjectsTextRecognitionServiceForOcrWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'MindSpore\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 7
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        textRecognitionRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/ocr.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_RECOGNITION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/ocr.jpg');
    });

    it('runtimeFactoryInjectsOcrAndTranslatorForImageTranslationWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: '你好\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 7
      });
      const translationRunner: FixedTextTranslationRunner = new FixedTextTranslationRunner('hello');
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        textRecognitionRunner: recognitionRunner,
        textTranslationRunner: translationRunner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/translation.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/translation.jpg');
      expect(translationRunner.seenTexts[0]).assertEqual('你好\n');
    });

    it('runtimeFactoryKeepsTranslationPendingWithoutTranslator', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result: AiRunResult = await service.run(workflow!, {
        text: 'hello'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
    });

    it('runtimeFactoryInjectsSegmentationServiceForSegmentationWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedSegmentationRunner = new FixedSegmentationRunner({
        ok: true,
        subjectCount: 1,
        detailCount: 0,
        foregroundAvailable: false,
        rectangles: [],
        executionMs: 8
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        segmentationRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/person.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SEGMENTATION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/person.jpg');
    });

    it('runtimeFactoryInjectsPoseServiceForPoseWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: 0,
        points: [],
        executionMs: 6
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        poseRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/pose.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('POSE_DETECTION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/pose.jpg');
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
      expect(actions.indexOf('captureImage') >= 0).assertTrue();
      expect(actions.indexOf('pickImage') >= 0).assertTrue();
      expect(actions.indexOf('pickModelFile') >= 0).assertTrue();
      expect(inputActionForKind('camera')).assertEqual('captureImage');
      expect(inputActionForKind('photo')).assertEqual('pickImage');
      expect(inputActionForKind('text')).assertEqual('enterText');
    });

    it('usesMindSporeModelFileSuffixForModelPicker', 0, () => {
      expect(modelFileSuffixFilters.length).assertEqual(1);
      expect(modelFileSuffixFilters[0]).assertEqual('.ms');
    });
  });
}
