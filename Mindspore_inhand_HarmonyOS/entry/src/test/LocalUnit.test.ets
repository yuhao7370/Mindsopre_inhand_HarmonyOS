import { describe, it, expect } from '@ohos/hypium';
import { AppRoute, findRouteByName } from '../main/ets/app/AppRoutes';
import { MainTab, mainTabs } from '../main/ets/app/AppState';
import { hasAppStringKey } from '../main/ets/common/i18n/AppStrings';
import { iconLabel } from '../main/ets/common/icons/IconSymbols';
import { AiRunResult, AiRunResultRow, DefaultAiService, aiRunResultRows, copyableTextForAiResult } from '../main/ets/services/ai/AiService';
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
  SegmentationService,
  segmentationRectanglePercent
} from '../main/ets/services/ai/SegmentationService';
import {
  PosePoint,
  PoseLine,
  PoseLinePercent,
  PoseResult,
  PoseRunner,
  PoseService,
  androidLiveSkeletonTemplatePoints,
  isPosePointVisible,
  poseLinePercent,
  posePointPercent,
  poseSimilarityToAndroidTemplate,
  poseSkeletonLines
} from '../main/ets/services/ai/PoseService';
import {
  GestureDetection,
  GestureRectangle,
  GestureRectanglePercent,
  GestureResult,
  GestureRunner,
  GestureService,
  gestureRectanglePercent
} from '../main/ets/services/ai/GestureService';
import {
  DanceFrameData,
  DanceSkeletonPoints,
  danceFrameFromPoints,
  danceNoActScore,
  danceNoPointScore,
  danceScoreFromFrames,
  danceTemplateFrames
} from '../main/ets/services/ai/DanceScoreService';
import {
  danceCountdownSequence,
  danceCountdownStepMs,
  dancePagePath,
  danceReferenceVideoLengthBytes,
  danceReferenceVideoUrl,
  danceResultComponentId,
  danceResultMessageKey,
  danceSamplingCompletionStatusKey,
  danceSamplingPageState,
  danceScoreText,
  danceTemplateDemoScore
} from '../main/ets/services/dance/DancePageService';
import {
  DanceFrameImageCapturer,
  DanceLivePoseFrameSource,
  DanceSamplingCancellation,
  DanceSamplingClock,
  DancePoseFrameSource,
  DancePoseDetector,
  DanceSamplingService,
  DanceSamplingDelay,
  DanceTimedSamplingService,
  danceDefaultSampleFrameCount,
  danceFrameFromPoseResult,
  dancePosePointType,
  danceSampleIntervalMs,
  danceSkeletonPointsFromPose
} from '../main/ets/services/dance/DanceSamplingService';
import {
  SceneDetection,
  SceneDetectionResult,
  SceneDetectionRunner,
  SceneDetectionService
} from '../main/ets/services/ai/SceneDetectionService';
import {
  StyleTransferInput,
  builtInStyleTransferStyleCount,
  builtInStyleTransferStyles,
  builtInStyleTransferUri,
  rawfilePathFromBuiltInStyleTransferUri,
  StyleTransferInputPreprocessor,
  StyleTransferModelUris,
  StyleTransferResult,
  StyleTransferRunner,
  StyleTransferService,
  StyleTransferTensorOutput,
  StyleTransferTensorRunner,
  StyleTransferMindSporeRunner,
  styleTransferMindSporeCpuThreadNum,
  stylePredictModelDownloadUrl,
  stylePredictModelRawfilePath,
  styleTransferContentImageSize,
  styleTransferDecodeOptions,
  styleTransferModelDownloadUrl,
  styleTransferModelRawfilePath,
  styleTransferOutputFloatCount,
  styleTransferPixelMapOptions,
  styleTransferRgbaOutputFromFloatOutput,
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
  mindSporeLiteCpuContext,
  mindSporeLiteCpuThreadNum,
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
  objectDetectionBoxPercent,
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
import {
  FeatureWorkflow,
  WorkflowInputReadyAction,
  inputKindReplacesPrimaryInput,
  runtimeInputKindsForWorkflow,
  shouldAutoRunWorkflowAfterInputReady,
  shouldClearTextInputAfterInputReady,
  workflowInputReadyAction,
  workflowForRoute
} from '../main/ets/features/runtime/FeatureWorkflowCatalog';
import {
  portraitSegmentationBackgroundPresets,
  portraitSegmentationBackgroundUri,
  portraitSegmentationCustomBackgroundId
} from '../main/ets/features/runtime/PortraitSegmentationBackgroundCatalog';
import { segmentationBackgroundReplacementComponentId } from '../main/ets/features/runtime/FeatureRuntimeViewIds';
import {
  declaredPermissionNames,
  runtimePermissionNamesForWorkflow,
  startupPermissionNames
} from '../main/ets/services/permissions/PermissionService';
import {
  inputActionForKind,
  modelFileSuffixFilters,
  runtimeInputActionForWorkflowInput,
  runtimeInputActionsForWorkflow
} from '../main/ets/services/picker/PickerService';
import {
  cachedModelFileNameForInputKind,
  modelFileCacheWriteSucceeded,
  ModelFileCacheWriter,
  RuntimeModelFileCacheService,
  shouldCachePickedModelFileForRoute
} from '../main/ets/services/picker/ModelFileCacheService';
import {
  LiveCameraPreviewDriver,
  LiveCameraPosition,
  LiveCameraPreviewService,
  LiveFrameImageEncoder,
  LiveFrameImageResult,
  LiveFrameImageService,
  LiveFrameImageStore,
  LiveRuntimeFrameRunner,
  LiveRuntimeLoopScheduler,
  LiveRuntimeLoopService,
  liveImageClassificationIntervalMs,
  liveRuntimeIntervalMs,
  liveCameraXComponentId,
  liveFrameImagePackingOption,
  nextLiveCameraPosition,
  shouldRunLiveRuntimeLoop,
  shouldAutoRunLiveRuntimeAfterPreview,
  shouldRunLiveImageClassificationLoop,
  shouldCaptureLiveFrameImage
} from '../main/ets/services/camera/LiveCameraService';
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
  helpImageClassificationUrl,
  helpObjectDetectionUrl,
  helpStyleTransferUrl,
  intelligentPoetryUrl,
  meApkUrl,
  userPrivacyRulesUrl,
  webDestinationForUrl,
  webUrlForRouteName,
  webPagePath
} from '../main/ets/common/data/WebDestination';
import { collegeItems, isCollegeItemUrlNavigable } from '../main/ets/common/data/CollegeCatalog';
import { MeItem, isMeItemUrlNavigable, meItems, visibleMeItems } from '../main/ets/common/data/MeCatalog';
import { AppVersionReader, AppVersionService, formattedAppVersionName } from '../main/ets/services/app/AppVersionService';
import {
  CollegeProgressService,
  CollegeProgressStore,
  collegeProgressKeyForItemId,
  collegeProgressKeyForQuickActionId
} from '../main/ets/services/storage/CollegeProgressService';
import {
  PrivacyConsentService,
  PrivacyConsentStore,
  privacyConsentPreferenceKey
} from '../main/ets/services/storage/PrivacyConsentService';
import {
  QrCodeAssetWriter,
  QrCodeMediaReader,
  isFullQrCodeWrite,
  QrCodeSaveService
} from '../main/ets/services/media/QrCodeSaveService';
import {
  ResultImageAssetWriter,
  ResultImagePixelMapEncoder,
  ResultImageSaveService,
  resultImagePackingOption,
  isFullResultImageWrite
} from '../main/ets/services/media/ResultImageSaveService';
import {
  ImageSharePayload,
  ImageShareWriter,
  ShareService,
  ShareTextPayload,
  TextShareWriter,
  mindSporeInhandShareText
} from '../main/ets/services/share/ShareService';
import {
  poetryJavascriptBridgeName,
  poetryJavascriptGenerateMethod,
  poetryPosterComponentId,
  poetryPosterPagePath,
  poetryPosterTextFromParam,
  shouldInstallPoetryJavascriptBridge
} from '../main/ets/services/poetry/PoetryPosterService';

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

class RecordingModelFileCacheWriter implements ModelFileCacheWriter {
  readonly seenCacheDirs: Array<string> = [];
  readonly seenFileNames: Array<string> = [];
  readonly writtenBytes: Array<number> = [];
  private readonly nextUri: string;

  constructor(nextUri: string) {
    this.nextUri = nextUri;
  }

  async writeModelFile(cacheDir: string, fileName: string, content: Uint8Array): Promise<string> {
    this.seenCacheDirs.push(cacheDir);
    this.seenFileNames.push(fileName);
    this.writtenBytes.push(content.length);
    return this.nextUri;
  }
}

class RejectingModelFileCacheWriter implements ModelFileCacheWriter {
  async writeModelFile(_cacheDir: string, _fileName: string, _content: Uint8Array): Promise<string> {
    throw new Error('model cache write failed');
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
  readonly seenPredictModelUris: Array<string> = [];
  readonly seenTransferModelUris: Array<string> = [];
  private readonly result: StyleTransferResult;

  constructor(result: StyleTransferResult) {
    this.result = result;
  }

  async run(
    contentImageUri: string,
    styleImageUri: string,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferResult> {
    this.seenContentUris.push(contentImageUri);
    this.seenStyleUris.push(styleImageUri);
    this.seenPredictModelUris.push(modelUris?.predictModelUri ?? '');
    this.seenTransferModelUris.push(modelUris?.transferModelUri ?? '');
    return this.result;
  }
}

class RejectingStyleTransferRunner implements StyleTransferRunner {
  async run(
    _contentImageUri: string,
    _styleImageUri: string,
    _modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferResult> {
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
  readonly seenPredictModelUris: Array<string> = [];
  readonly seenTransferModelUris: Array<string> = [];
  private readonly output: StyleTransferTensorOutput;

  constructor(output: StyleTransferTensorOutput) {
    this.output = output;
  }

  async runStyleTransfer(
    input: StyleTransferInput,
    modelUris?: StyleTransferModelUris
  ): Promise<StyleTransferTensorOutput> {
    this.seenContentBytes.push(input.contentInputBuffer.byteLength);
    this.seenStyleBytes.push(input.styleInputBuffer.byteLength);
    this.seenPredictModelUris.push(modelUris?.predictModelUri ?? '');
    this.seenTransferModelUris.push(modelUris?.transferModelUri ?? '');
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

class MemoryCollegeProgressStore implements CollegeProgressStore {
  readonly values: Map<string, boolean> = new Map<string, boolean>();

  getBoolean(key: string, defaultValue: boolean): boolean {
    const value = this.values.get(key);
    return value === undefined ? defaultValue : value;
  }

  putBoolean(key: string, value: boolean): void {
    this.values.set(key, value);
  }

  flush(): void {
  }
}

class MemoryPrivacyConsentStore implements PrivacyConsentStore {
  readonly values: Map<string, boolean> = new Map<string, boolean>();

  getBoolean(key: string, defaultValue: boolean): boolean {
    const value = this.values.get(key);
    return value === undefined ? defaultValue : value;
  }

  putBoolean(key: string, value: boolean): void {
    this.values.set(key, value);
  }

  flush(): void {
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

class FixedDancePoseFrameSource implements DancePoseFrameSource {
  readonly requestedFrameIds: Array<number> = [];
  private readonly results: Array<PoseResult>;

  constructor(results: Array<PoseResult>) {
    this.results = results;
  }

  async poseFrame(frameId: number): Promise<PoseResult> {
    this.requestedFrameIds.push(frameId);
    return this.results[frameId - 1];
  }
}

class MutableDanceSamplingClock implements DanceSamplingClock {
  private currentMs: number;

  constructor(initialMs: number) {
    this.currentMs = initialMs;
  }

  now(): number {
    return this.currentMs;
  }

  advance(deltaMs: number): void {
    this.currentMs += deltaMs;
  }
}

class MutableDanceSamplingCancellation implements DanceSamplingCancellation {
  private cancelled: boolean = false;

  isCancelled(): boolean {
    return this.cancelled;
  }

  cancel(): void {
    this.cancelled = true;
  }
}

class ProcessingDancePoseFrameSource implements DancePoseFrameSource {
  readonly requestedFrameIds: Array<number> = [];
  readonly frameStartMs: Array<number> = [];
  private readonly results: Array<PoseResult>;
  private readonly clock: MutableDanceSamplingClock;
  private readonly processingMs: number;

  constructor(results: Array<PoseResult>, clock: MutableDanceSamplingClock, processingMs: number) {
    this.results = results;
    this.clock = clock;
    this.processingMs = processingMs;
  }

  async poseFrame(frameId: number): Promise<PoseResult> {
    this.requestedFrameIds.push(frameId);
    this.frameStartMs.push(this.clock.now());
    this.clock.advance(this.processingMs);
    return this.results[frameId - 1];
  }
}

class CancellingDancePoseFrameSource implements DancePoseFrameSource {
  readonly requestedFrameIds: Array<number> = [];
  private readonly result: PoseResult;
  private readonly cancellation: MutableDanceSamplingCancellation;

  constructor(result: PoseResult, cancellation: MutableDanceSamplingCancellation) {
    this.result = result;
    this.cancellation = cancellation;
  }

  async poseFrame(frameId: number): Promise<PoseResult> {
    this.requestedFrameIds.push(frameId);
    this.cancellation.cancel();
    return this.result;
  }
}

class RecordingDanceFrameImageCapturer implements DanceFrameImageCapturer {
  readonly seenSurfaceIds: Array<string> = [];
  readonly seenCacheDirs: Array<string> = [];
  private readonly results: Array<LiveFrameImageResult>;

  constructor(results: Array<LiveFrameImageResult>) {
    this.results = results;
  }

  async captureToCacheImage(surfaceId: string, cacheDir: string): Promise<LiveFrameImageResult> {
    this.seenSurfaceIds.push(surfaceId);
    this.seenCacheDirs.push(cacheDir);
    const index = this.seenSurfaceIds.length - 1;
    return this.results[index];
  }
}

class RecordingDancePoseDetector implements DancePoseDetector {
  readonly seenImageUris: Array<string> = [];
  private readonly results: Array<PoseResult>;

  constructor(results: Array<PoseResult>) {
    this.results = results;
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    this.seenImageUris.push(imageUri);
    const index = this.seenImageUris.length - 1;
    return this.results[index];
  }
}

class RecordingDanceSamplingDelay implements DanceSamplingDelay {
  readonly seenIntervals: Array<number> = [];
  private readonly clock: MutableDanceSamplingClock | undefined;

  constructor(clock?: MutableDanceSamplingClock) {
    this.clock = clock;
  }

  async wait(intervalMs: number): Promise<void> {
    this.seenIntervals.push(intervalMs);
    if (this.clock !== undefined) {
      this.clock.advance(intervalMs);
    }
  }
}

class FixedGestureRunner implements GestureRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly result: GestureResult;

  constructor(result: GestureResult) {
    this.result = result;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingGestureRunner implements GestureRunner {
  async detectGesture(_imageUri: string): Promise<GestureResult> {
    throw new Error('gesture detection failed');
  }
}

class FixedSceneDetectionRunner implements SceneDetectionRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly result: SceneDetectionResult;

  constructor(result: SceneDetectionResult) {
    this.result = result;
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingSceneDetectionRunner implements SceneDetectionRunner {
  async detectScenes(_imageUri: string): Promise<SceneDetectionResult> {
    throw new Error('scene detection failed');
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

class RecordingShareWriter implements TextShareWriter {
  readonly payloads: Array<ShareTextPayload> = [];

  async shareText(payload: ShareTextPayload): Promise<void> {
    this.payloads.push(payload);
  }
}

class RejectingShareWriter implements TextShareWriter {
  async shareText(_payload: ShareTextPayload): Promise<void> {
    throw new Error('share rejected');
  }
}

class RecordingImageShareWriter implements ImageShareWriter {
  readonly payloads: Array<ImageSharePayload> = [];

  async shareImage(payload: ImageSharePayload): Promise<void> {
    this.payloads.push(payload);
  }
}

class RejectingImageShareWriter implements ImageShareWriter {
  async shareImage(_payload: ImageSharePayload): Promise<void> {
    throw new Error('image share rejected');
  }
}

class FixedQrCodeMediaReader implements QrCodeMediaReader {
  private readonly imageBytes: ArrayBuffer;

  constructor(imageBytes: ArrayBuffer) {
    this.imageBytes = imageBytes;
  }

  readQrCodeImage(): ArrayBuffer {
    return this.imageBytes;
  }
}

class RejectingQrCodeMediaReader implements QrCodeMediaReader {
  readQrCodeImage(): ArrayBuffer {
    throw new Error('qr image missing');
  }
}

class RecordingQrCodeAssetWriter implements QrCodeAssetWriter {
  readonly writtenBytes: Array<Uint8Array> = [];
  private readonly nextUri: string;

  constructor(nextUri: string) {
    this.nextUri = nextUri;
  }

  async writeJpeg(bytes: ArrayBuffer): Promise<string> {
    this.writtenBytes.push(new Uint8Array(bytes));
    return this.nextUri;
  }
}

class RejectingQrCodeAssetWriter implements QrCodeAssetWriter {
  async writeJpeg(_bytes: ArrayBuffer): Promise<string> {
    throw new Error('gallery rejected');
  }
}

class FixedResultImagePixelMapEncoder implements ResultImagePixelMapEncoder {
  seenPixelMapCount: number = 0;
  private readonly imageBytes: ArrayBuffer;

  constructor(imageBytes: ArrayBuffer) {
    this.imageBytes = imageBytes;
  }

  async encodeJpeg(_pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    this.seenPixelMapCount += 1;
    return this.imageBytes;
  }
}

class RejectingResultImagePixelMapEncoder implements ResultImagePixelMapEncoder {
  async encodeJpeg(_pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    throw new Error('pixelmap encode failed');
  }
}

class RecordingResultImageAssetWriter implements ResultImageAssetWriter {
  readonly writtenBytes: Array<Uint8Array> = [];
  private readonly nextUri: string;

  constructor(nextUri: string) {
    this.nextUri = nextUri;
  }

  async writeJpeg(bytes: ArrayBuffer): Promise<string> {
    this.writtenBytes.push(new Uint8Array(bytes));
    return this.nextUri;
  }
}

class RejectingResultImageAssetWriter implements ResultImageAssetWriter {
  async writeJpeg(_bytes: ArrayBuffer): Promise<string> {
    throw new Error('gallery rejected');
  }
}

class RecordingLiveCameraPreviewDriver implements LiveCameraPreviewDriver {
  startedSurfaceIds: Array<string> = [];
  startedPositions: Array<LiveCameraPosition> = [];
  private readonly failStart: boolean;

  constructor(failStart: boolean) {
    this.failStart = failStart;
  }

  async start(surfaceId: string, position: LiveCameraPosition): Promise<void> {
    if (this.failStart) {
      throw new Error('camera failed');
    }
    this.startedSurfaceIds.push(surfaceId);
    this.startedPositions.push(position);
  }

  async stop(): Promise<void> {
  }
}

class FixedLiveFrameImageEncoder implements LiveFrameImageEncoder {
  seenSurfaceIds: Array<string> = [];
  private readonly imageBytes: ArrayBuffer;

  constructor(imageBytes: ArrayBuffer) {
    this.imageBytes = imageBytes;
  }

  async encodeSurfaceFrame(surfaceId: string): Promise<ArrayBuffer> {
    this.seenSurfaceIds.push(surfaceId);
    return this.imageBytes;
  }
}

class RejectingLiveFrameImageEncoder implements LiveFrameImageEncoder {
  async encodeSurfaceFrame(_surfaceId: string): Promise<ArrayBuffer> {
    throw new Error('frame unavailable');
  }
}

class RecordingLiveFrameImageStore implements LiveFrameImageStore {
  readonly seenCacheDirs: Array<string> = [];
  readonly seenBytes: Array<Uint8Array> = [];
  private readonly nextPath: string;

  constructor(nextPath: string) {
    this.nextPath = nextPath;
  }

  async writeJpeg(cacheDir: string, bytes: ArrayBuffer): Promise<string> {
    this.seenCacheDirs.push(cacheDir);
    this.seenBytes.push(new Uint8Array(bytes));
    return this.nextPath;
  }
}

class ManualLiveRuntimeLoopScheduler implements LiveRuntimeLoopScheduler {
  readonly intervalMsValues: Array<number> = [];
  readonly cancelledIds: Array<number> = [];
  private nextId: number = 1;
  private tickCallback: (() => void) | undefined = undefined;

  schedule(intervalMs: number, tick: () => void): number {
    this.intervalMsValues.push(intervalMs);
    this.tickCallback = tick;
    const id = this.nextId;
    this.nextId += 1;
    return id;
  }

  cancel(timerId: number): void {
    this.cancelledIds.push(timerId);
    this.tickCallback = undefined;
  }

  tick(): void {
    if (this.tickCallback !== undefined) {
      this.tickCallback();
    }
  }
}

class RecordingLiveRuntimeFrameRunner implements LiveRuntimeFrameRunner {
  runCount: number = 0;

  async runOnce(): Promise<void> {
    this.runCount += 1;
  }
}

class BlockingLiveRuntimeFrameRunner implements LiveRuntimeFrameRunner {
  runCount: number = 0;
  private resolver: (() => void) | undefined = undefined;

  async runOnce(): Promise<void> {
    this.runCount += 1;
    await new Promise<void>((resolve: () => void) => {
      this.resolver = resolve;
    });
  }

  finish(): void {
    if (this.resolver !== undefined) {
      this.resolver();
      this.resolver = undefined;
    }
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

    it('keepsAndroidSceneDetectionRoutesHiddenButRuntimeReady', 0, () => {
      expect(AppRoute.SCENE_STILL.name).assertEqual('/hms/SenceDetectionStillAnalyseActivity');
      expect(AppRoute.SCENE_LIVE.name).assertEqual('/hms/SenceDetectionLiveAnalyseActivity');
      expect(findRouteByName(AppRoute.SCENE_STILL.name)?.page).assertEqual('pages/FeatureRuntimePage');
      expect(findRouteByName(AppRoute.SCENE_LIVE.name)?.page).assertEqual('pages/FeatureRuntimePage');
      expect(findFeatureByRoute(AppRoute.SCENE_STILL.name) === undefined).assertTrue();
      expect(findFeatureByRoute(AppRoute.SCENE_LIVE.name) === undefined).assertTrue();
      expect(workflowForRoute(AppRoute.SCENE_STILL.name)?.aiMethod).assertEqual('detectScene');
      expect(workflowForRoute(AppRoute.SCENE_LIVE.name)?.liveMode).assertTrue();
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
      expect(meItems.length).assertEqual(8);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].title).assertEqual('Version');
      expect(meItems.find((item: MeItem) => item.id === 'privacy')?.visibleByDefault).assertFalse();
      expect(meItems.find((item: MeItem) => item.id === 'qr')?.visibleByDefault).assertFalse();
    });

    it('usesAndroidPreferenceKeysForCollegeProgress', 0, () => {
      expect(collegeProgressKeyForItemId('summary')).assertEqual('preferences_college_summary');
      expect(collegeProgressKeyForItemId('cloud')).assertEqual('preferences_college_cloud');
      expect(collegeProgressKeyForItemId('quick')).assertEqual('preferences_college_quick');
      expect(collegeProgressKeyForItemId('faq')).assertEqual('preferences_college_faq');
      expect(collegeProgressKeyForItemId('forum')).assertEqual('preferences_college_ask');
      expect(collegeProgressKeyForQuickActionId('train')).assertEqual('preferences_college_train');
      expect(collegeProgressKeyForQuickActionId('inference')).assertEqual('preferences_college_execute');
      expect(collegeProgressKeyForQuickActionId('applications')).assertEqual('preferences_college_app');
      expect(collegeProgressKeyForQuickActionId('video')).assertEqual('preferences_college_video');
    });

    it('collegeProgressMarksRowsAndQuickParentLikeAndroid', 0, () => {
      const store = new MemoryCollegeProgressStore();
      const service = new CollegeProgressService(store);

      service.markItemChecked('cloud');
      expect(service.isItemChecked('cloud')).assertTrue();
      expect(store.values.get('preferences_college_cloud')).assertTrue();

      service.markQuickActionChecked('train');
      service.markQuickActionChecked('inference');
      service.markQuickActionChecked('applications');
      expect(service.isItemChecked('quick')).assertFalse();

      service.markQuickActionChecked('video');
      expect(service.isQuickActionChecked('video')).assertTrue();
      expect(service.isItemChecked('quick')).assertTrue();
      expect(store.values.get('preferences_college_quick')).assertTrue();
    });

    it('usesAndroidPreferenceKeyForPrivacyConsent', 0, () => {
      expect(privacyConsentPreferenceKey).assertEqual('preferences_privacy');
    });

    it('privacyConsentPersistsSplashDecisionLikeAndroid', 0, () => {
      const store = new MemoryPrivacyConsentStore();
      const service = new PrivacyConsentService(store);

      expect(service.hasAcceptedPrivacy()).assertFalse();

      service.acceptPrivacy();
      expect(service.hasAcceptedPrivacy()).assertTrue();
      expect(store.values.get('preferences_privacy')).assertTrue();

      service.declinePrivacy();
      expect(service.hasAcceptedPrivacy()).assertFalse();
      expect(store.values.get('preferences_privacy')).assertFalse();
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
      expect(hasAppStringKey('feature_runtime_gesture_unsupported')).assertTrue();
      expect(hasAppStringKey('feature_runtime_gesture_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_gesture_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_gesture_overlay')).assertTrue();
      expect(hasAppStringKey('title_scene_detection')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_unsupported')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_failed')).assertTrue();
      expect(hasAppStringKey('workflow_summary_scene')).assertTrue();
      expect(hasAppStringKey('feature_runtime_translation_unsupported')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_recognition_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_translation_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_segmentation_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_preview_background')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_background')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_background_replacement')).assertTrue();
      expect(hasAppStringKey('feature_input_background_image')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_preview_title')).assertTrue();
      expect(hasAppStringKey('feature_runtime_switch_camera')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_count')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_similarity')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_pose_template')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_model_cache_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_missing')).assertTrue();
      expect(hasAppStringKey('qr_code_save_done')).assertTrue();
      expect(hasAppStringKey('qr_code_save_failed')).assertTrue();
      expect(hasAppStringKey('title_share')).assertTrue();
      expect(hasAppStringKey('title_share_commend')).assertTrue();
      expect(hasAppStringKey('me_share_done')).assertTrue();
      expect(hasAppStringKey('me_share_failed')).assertTrue();
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

    it('qrCodeSaveServiceWritesBundledQrCodeToGallery', 0, async () => {
      const writer = new RecordingQrCodeAssetWriter('file://media/gallery/qr.jpg');
      const result = await new QrCodeSaveService(
        new FixedQrCodeMediaReader(new Uint8Array([9, 8, 7]).buffer as ArrayBuffer),
        writer
      ).save();

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('file://media/gallery/qr.jpg');
      expect(result.messageKey).assertEqual('qr_code_save_done');
      expect(writer.writtenBytes[0][0]).assertEqual(9);
      expect(writer.writtenBytes[0][2]).assertEqual(7);
    });

    it('qrCodeSaveServiceReportsFailureWhenReadOrWriteFails', 0, async () => {
      const rejectedRead = await new QrCodeSaveService(
        new RejectingQrCodeMediaReader(),
        new RecordingQrCodeAssetWriter('file://media/gallery/qr.jpg')
      ).save();
      const rejectedWrite = await new QrCodeSaveService(
        new FixedQrCodeMediaReader(new Uint8Array([1]).buffer as ArrayBuffer),
        new RejectingQrCodeAssetWriter()
      ).save();
      const emptyUri = await new QrCodeSaveService(
        new FixedQrCodeMediaReader(new Uint8Array([1]).buffer as ArrayBuffer),
        new RecordingQrCodeAssetWriter('')
      ).save();

      expect(rejectedRead.ok).assertFalse();
      expect(rejectedWrite.ok).assertFalse();
      expect(emptyUri.ok).assertFalse();
      expect(rejectedRead.messageKey).assertEqual('qr_code_save_failed');
      expect(rejectedWrite.messageKey).assertEqual('qr_code_save_failed');
      expect(emptyUri.messageKey).assertEqual('qr_code_save_failed');
    });

    it('qrCodeWriteCompletesOnlyWhenAllBytesAreWritten', 0, () => {
      const bytes = new Uint8Array([1, 2, 3]).buffer as ArrayBuffer;

      expect(isFullQrCodeWrite(bytes, 3)).assertTrue();
      expect(isFullQrCodeWrite(bytes, 2)).assertFalse();
      expect(isFullQrCodeWrite(bytes, 4)).assertFalse();
    });

    it('resultImageSaveServiceEncodesProcessedPixelMapToGalleryJpeg', 0, async () => {
      const encoder = new FixedResultImagePixelMapEncoder(new Uint8Array([4, 5, 6]).buffer as ArrayBuffer);
      const writer = new RecordingResultImageAssetWriter('file://media/gallery/result.jpg');
      const pixelMap = {} as image.PixelMap;

      const result = await new ResultImageSaveService(encoder, writer).save(pixelMap);

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('file://media/gallery/result.jpg');
      expect(result.messageKey).assertEqual('feature_runtime_save_image_done');
      expect(encoder.seenPixelMapCount).assertEqual(1);
      expect(writer.writtenBytes[0][0]).assertEqual(4);
      expect(writer.writtenBytes[0][2]).assertEqual(6);
    });

    it('resultImageSaveServiceReportsMissingOrFailedProcessedImage', 0, async () => {
      const missing = await new ResultImageSaveService(
        new FixedResultImagePixelMapEncoder(new Uint8Array([1]).buffer as ArrayBuffer),
        new RecordingResultImageAssetWriter('file://media/gallery/result.jpg')
      ).save(undefined);
      const rejectedEncode = await new ResultImageSaveService(
        new RejectingResultImagePixelMapEncoder(),
        new RecordingResultImageAssetWriter('file://media/gallery/result.jpg')
      ).save({} as image.PixelMap);
      const rejectedWrite = await new ResultImageSaveService(
        new FixedResultImagePixelMapEncoder(new Uint8Array([1]).buffer as ArrayBuffer),
        new RejectingResultImageAssetWriter()
      ).save({} as image.PixelMap);
      const emptyUri = await new ResultImageSaveService(
        new FixedResultImagePixelMapEncoder(new Uint8Array([1]).buffer as ArrayBuffer),
        new RecordingResultImageAssetWriter('')
      ).save({} as image.PixelMap);

      expect(missing.ok).assertFalse();
      expect(rejectedEncode.ok).assertFalse();
      expect(rejectedWrite.ok).assertFalse();
      expect(emptyUri.ok).assertFalse();
      expect(missing.messageKey).assertEqual('feature_runtime_save_image_missing');
      expect(rejectedEncode.messageKey).assertEqual('feature_runtime_save_image_failed');
      expect(rejectedWrite.messageKey).assertEqual('feature_runtime_save_image_failed');
      expect(emptyUri.messageKey).assertEqual('feature_runtime_save_image_failed');
    });

    it('resultImageWriteCompletesOnlyWhenAllBytesAreWritten', 0, () => {
      const bytes = new Uint8Array([1, 2, 3]).buffer as ArrayBuffer;

      expect(isFullResultImageWrite(bytes, 3)).assertTrue();
      expect(isFullResultImageWrite(bytes, 2)).assertFalse();
      expect(isFullResultImageWrite(bytes, 4)).assertFalse();
    });

    it('resultImageSaveServiceUsesAndroidJpegQuality', 0, () => {
      expect(resultImagePackingOption.format).assertEqual('image/jpeg');
      expect(resultImagePackingOption.quality).assertEqual(100);
    });

    it('shareServiceUsesAndroidMindSporeTextPayload', 0, async () => {
      const writer = new RecordingShareWriter();
      const shareText = mindSporeInhandShareText('MindSpore inhand:');
      const result = await new ShareService(writer).shareText({
        title: 'Share',
        text: shareText
      });

      expect(shareText).assertEqual(`MindSpore inhand: ${meApkUrl}`);
      expect(result.ok).assertTrue();
      expect(result.messageKey).assertEqual('me_share_done');
      expect(result.sharedTextLength).assertEqual(shareText.length);
      expect(writer.payloads[0].title).assertEqual('Share');
      expect(writer.payloads[0].text).assertEqual(shareText);
    });

    it('shareServiceRejectsBlankOrFailedText', 0, async () => {
      const blankResult = await new ShareService(new RecordingShareWriter()).shareText({
        title: 'Share',
        text: ''
      });
      const failedResult = await new ShareService(new RejectingShareWriter()).shareText({
        title: 'Share',
        text: 'MindSpore'
      });

      expect(blankResult.ok).assertFalse();
      expect(failedResult.ok).assertFalse();
      expect(blankResult.messageKey).assertEqual('me_share_failed');
      expect(failedResult.messageKey).assertEqual('me_share_failed');
    });

    it('shareServiceSharesSavedPosterImagesByUri', 0, async () => {
      const writer = new RecordingImageShareWriter();
      const payload: ImageSharePayload = {
        title: 'Intelligent Poetry',
        uri: 'file://media/poemshare.jpg',
        description: 'MindSpore AI'
      };
      const result = await new ShareService(new RecordingShareWriter(), writer).shareImage(payload);

      expect(result.ok).assertTrue();
      expect(result.messageKey).assertEqual('poem_share_done');
      expect(result.sharedUri).assertEqual('file://media/poemshare.jpg');
      expect(writer.payloads[0].title).assertEqual('Intelligent Poetry');
      expect(writer.payloads[0].uri).assertEqual('file://media/poemshare.jpg');
    });

    it('shareServiceRejectsMissingOrFailedPosterImageShare', 0, async () => {
      const blankPayload: ImageSharePayload = {
        title: 'Intelligent Poetry',
        uri: '',
        description: 'MindSpore AI'
      };
      const failedPayload: ImageSharePayload = {
        title: 'Intelligent Poetry',
        uri: 'file://media/poemshare.jpg',
        description: 'MindSpore AI'
      };
      const blankResult = await new ShareService(new RecordingShareWriter(), new RecordingImageShareWriter()).shareImage(blankPayload);
      const failedResult = await new ShareService(new RecordingShareWriter(), new RejectingImageShareWriter()).shareImage(failedPayload);

      expect(blankResult.ok).assertFalse();
      expect(failedResult.ok).assertFalse();
      expect(blankResult.messageKey).assertEqual('poem_share_failed');
      expect(failedResult.messageKey).assertEqual('poem_share_failed');
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

    it('retainsHiddenNavigableMeWebEntries', 0, () => {
      const shareItem = meItems.find((item: MeItem) => item.id === 'share');
      expect(shareItem !== undefined).assertTrue();
      if (shareItem) {
        expect(shareItem.visibleByDefault).assertFalse();
        expect(isMeItemUrlNavigable(shareItem)).assertFalse();
      }

      const privacyItem = meItems.find((item: MeItem) => item.id === 'privacy');
      expect(privacyItem !== undefined).assertTrue();
      if (privacyItem) {
        expect(privacyItem.visibleByDefault).assertFalse();
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
      const qrItem = meItems.find((item: MeItem) => item.id === 'qr');
      expect(qrItem !== undefined).assertTrue();
      expect(AppRoute.MY_QR_CODE.page).assertEqual('pages/QrCodePage');
      if (qrItem) {
        expect(qrItem.visibleByDefault).assertFalse();
        expect(qrItem.page).assertEqual(AppRoute.MY_QR_CODE.page);
      }
    });

    it('routesIntelligentPoetryToOriginalWebExperience', 0, () => {
      expect(AppRoute.POETRY.page).assertEqual(webPagePath);
      expect(AppRoute.POETRY_POSTER.page).assertEqual(poetryPosterPagePath);
      expect(webUrlForRouteName(AppRoute.POETRY.name)).assertEqual(intelligentPoetryUrl);
      expect(workflowForRoute(AppRoute.POETRY.name) === undefined).assertTrue();
      const poetryDestination = webDestinationForUrl(intelligentPoetryUrl, 'me_official_title');
      expect(poetryDestination.titleKey).assertEqual('title_intelligent_poetry');
    });

    it('portsPoetryJavascriptBridgeAndPosterRoute', 0, () => {
      expect(AppRoute.POETRY_POSTER.name).assertEqual('/app/PoetryPosterActivity');
      expect(AppRoute.POETRY_POSTER.page).assertEqual(poetryPosterPagePath);
      expect(poetryJavascriptBridgeName).assertEqual('android');
      expect(poetryJavascriptGenerateMethod).assertEqual('getGeneratePoetry');
      expect(poetryPosterComponentId).assertEqual('poetryPosterContent');
      expect(shouldInstallPoetryJavascriptBridge(AppRoute.POETRY.name, intelligentPoetryUrl)).assertTrue();
      expect(shouldInstallPoetryJavascriptBridge(AppRoute.WEB.name, intelligentPoetryUrl)).assertTrue();
      expect(shouldInstallPoetryJavascriptBridge(AppRoute.PRIVACY.name, userPrivacyRulesUrl)).assertFalse();
    });

    it('preservesGeneratedPoetryTextForPosterLikeAndroid', 0, () => {
      const poem = '  Spring river tide\nMoon over the sea  ';

      expect(poetryPosterTextFromParam(poem)).assertEqual(poem);
      expect(poetryPosterTextFromParam(undefined)).assertEqual('');
      expect(hasAppStringKey('poem_save_poster')).assertTrue();
      expect(hasAppStringKey('poem_share_poster')).assertTrue();
      expect(hasAppStringKey('poem_save_success')).assertTrue();
      expect(hasAppStringKey('poem_save_failed')).assertTrue();
      expect(hasAppStringKey('poem_share_done')).assertTrue();
      expect(hasAppStringKey('poem_share_failed')).assertTrue();
      expect(hasAppStringKey('poem_ai_credit')).assertTrue();
    });

    it('portsAndroidDanceTemplateAndPerfectScoreContract', 0, () => {
      const template = danceTemplateFrames();

      expect(template.length).assertEqual(70);
      expect(template[0].id).assertEqual(1);
      expect(template[0].sinRightElbow.toFixed(9)).assertEqual('-0.447213595');
      expect(template[69].id).assertEqual(70);
      expect(danceScoreFromFrames(template)).assertEqual(98);
    });

    it('portsAndroidDanceNoActionAndNoPointScores', 0, () => {
      const template = danceTemplateFrames();
      const stillFrames: Array<DanceFrameData> = [];
      const missingPointFrames: Array<DanceFrameData> = [];
      const stillFrame = template[0];
      for (let index = 0; index < template.length; index++) {
        stillFrames.push({
          id: index + 1,
          sinRightElbow: stillFrame.sinRightElbow,
          sinRightWrist: stillFrame.sinRightWrist,
          sinLeftElbow: stillFrame.sinLeftElbow,
          sinLeftWrist: stillFrame.sinLeftWrist,
          sinLeftKnee: stillFrame.sinLeftKnee,
          sinLeftAnkle: stillFrame.sinLeftAnkle,
          rightElbowMissing: false,
          rightWristMissing: false,
          leftElbowMissing: false,
          leftWristMissing: false,
          leftKneeMissing: false,
          leftAnkleMissing: false
        });
        const frame = template[index];
        missingPointFrames.push({
          id: frame.id,
          sinRightElbow: frame.sinRightElbow,
          sinRightWrist: frame.sinRightWrist,
          sinLeftElbow: frame.sinLeftElbow,
          sinLeftWrist: frame.sinLeftWrist,
          sinLeftKnee: frame.sinLeftKnee,
          sinLeftAnkle: frame.sinLeftAnkle,
          rightElbowMissing: index < 28,
          rightWristMissing: false,
          leftElbowMissing: false,
          leftWristMissing: false,
          leftKneeMissing: false,
          leftAnkleMissing: false
        });
      }

      expect(danceScoreFromFrames(stillFrames)).assertEqual(danceNoActScore);
      expect(danceScoreFromFrames(missingPointFrames)).assertEqual(danceNoPointScore);
    });

    it('countsRightWristMovementAsDanceAction', 0, () => {
      const template = danceTemplateFrames();
      const baseFrame = template[0];
      const wristOnlyFrames: Array<DanceFrameData> = [];
      for (let index = 0; index < template.length; index++) {
        wristOnlyFrames.push({
          id: index + 1,
          sinRightElbow: baseFrame.sinRightElbow,
          sinRightWrist: index % 2 === 0 ? -1 : 1,
          sinLeftElbow: baseFrame.sinLeftElbow,
          sinLeftWrist: baseFrame.sinLeftWrist,
          sinLeftKnee: baseFrame.sinLeftKnee,
          sinLeftAnkle: baseFrame.sinLeftAnkle,
          rightElbowMissing: false,
          rightWristMissing: false,
          leftElbowMissing: false,
          leftWristMissing: false,
          leftKneeMissing: false,
          leftAnkleMissing: false
        });
      }

      const score = danceScoreFromFrames(wristOnlyFrames);

      expect(score === danceNoActScore).assertFalse();
      expect(score === danceNoPointScore).assertFalse();
    });

    it('createsDanceFrameFromGenericSkeletonPoints', 0, () => {
      const points: DanceSkeletonPoints = {
        neck: { x: 10, y: 10 },
        rightElbow: { x: 10, y: 0 },
        rightWrist: { x: 0, y: 0 },
        leftElbow: { x: 0, y: 10 },
        leftWrist: { x: 20, y: 10 },
        leftKnee: { x: 10, y: 20 },
        leftAnkle: { x: 20, y: 20 }
      };

      const frame = danceFrameFromPoints(7, points);

      expect(frame.id).assertEqual(7);
      expect(frame.sinRightElbow.toFixed(1)).assertEqual('-1.0');
      expect(frame.sinLeftElbow.toFixed(1)).assertEqual('0.0');
      expect(frame.sinLeftKnee.toFixed(1)).assertEqual('1.0');
      expect(frame.rightWristMissing).assertTrue();
      expect(frame.rightElbowMissing).assertFalse();
    });

    it('mapsHarmonyPosePointsToDanceSkeletonWithSyntheticNeck', 0, () => {
      const points: Array<PosePoint> = [
        { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
        { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
        { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
        { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
        { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
        { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
        { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
        { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
      ];

      const skeletonPoints = danceSkeletonPointsFromPose(points);
      const missingLeftAnkle = danceSkeletonPointsFromPose([
        { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
        { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
        { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
        { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
        { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
        { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
        { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 }
      ]);
      const lowScoreLeftAnkle = danceSkeletonPointsFromPose([
        { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
        { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
        { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
        { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
        { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
        { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
        { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
        { type: dancePosePointType.LEFT_ANKLE, score: 0.1, x: 30, y: 80 }
      ]);

      expect(skeletonPoints !== undefined).assertTrue();
      expect(skeletonPoints!.neck.x).assertEqual(30);
      expect(skeletonPoints!.neck.y).assertEqual(20);
      expect(skeletonPoints!.rightElbow.y).assertEqual(10);
      expect(skeletonPoints!.leftAnkle.y).assertEqual(80);
      expect(missingLeftAnkle === undefined).assertTrue();
      expect(lowScoreLeftAnkle === undefined).assertTrue();
    });

    it('createsDanceFramesFromPoseResultsAndSamplesDefaultWindow', 0, async () => {
      const poseResult: PoseResult = {
        ok: true,
        skeletonCount: 1,
        pointCount: 8,
        executionMs: 5,
        points: [
          { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
          { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
          { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
          { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
          { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
          { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
          { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
          { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
        ]
      };
      const emptyPoseResult: PoseResult = {
        ok: false,
        skeletonCount: 0,
        pointCount: 0,
        executionMs: 1,
        points: []
      };

      const frame = danceFrameFromPoseResult(3, poseResult);
      const source = new FixedDancePoseFrameSource([poseResult, emptyPoseResult]);
      const result = await new DanceSamplingService().sample(source, 2);

      expect(danceDefaultSampleFrameCount).assertEqual(70);
      expect(danceSampleIntervalMs).assertEqual(500);
      expect(frame !== undefined).assertTrue();
      expect(frame!.id).assertEqual(3);
      expect(frame!.sinRightElbow.toFixed(1)).assertEqual('-1.0');
      expect(danceFrameFromPoseResult(4, emptyPoseResult) === undefined).assertTrue();
      expect(source.requestedFrameIds[0]).assertEqual(1);
      expect(source.requestedFrameIds[1]).assertEqual(2);
      expect(result.frameCount).assertEqual(2);
      expect(result.validFrameCount).assertEqual(1);
      expect(result.frames.length).assertEqual(2);
      expect(result.frames[0] !== undefined).assertTrue();
      expect(result.frames[1] === undefined).assertTrue();
      expect(result.score).assertEqual(danceScoreFromFrames(result.frames));
    });

    it('capturesLiveDanceFrameBeforePoseDetection', 0, async () => {
      const poseResult: PoseResult = {
        ok: true,
        skeletonCount: 1,
        pointCount: 8,
        executionMs: 5,
        points: [
          { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
          { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
          { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
          { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
          { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
          { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
          { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
          { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
        ]
      };
      const capturer = new RecordingDanceFrameImageCapturer([{
        ok: true,
        uri: '/cache/dance-frame.jpg',
        messageKey: 'feature_runtime_image_ready'
      }]);
      const detector = new RecordingDancePoseDetector([poseResult]);
      const source = new DanceLivePoseFrameSource('surface-1', '/cache', capturer, detector);

      const result = await source.poseFrame(1);

      expect(result.ok).assertTrue();
      expect(capturer.seenSurfaceIds[0]).assertEqual('surface-1');
      expect(capturer.seenCacheDirs[0]).assertEqual('/cache');
      expect(detector.seenImageUris[0]).assertEqual('/cache/dance-frame.jpg');
    });

    it('rejectsLiveDanceFrameCaptureFailureBeforePoseDetection', 0, async () => {
      const capturer = new RecordingDanceFrameImageCapturer([{
        ok: false,
        uri: '',
        messageKey: 'feature_runtime_live_frame_failed'
      }]);
      const detector = new RecordingDancePoseDetector([]);
      const source = new DanceLivePoseFrameSource('surface-1', '/cache', capturer, detector);
      let failed = false;

      try {
        await source.poseFrame(1);
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(detector.seenImageUris.length).assertEqual(0);
    });

    it('samplesDanceFramesWithAndroidIntervalForLiveFlow', 0, async () => {
      const poseResult: PoseResult = {
        ok: true,
        skeletonCount: 1,
        pointCount: 8,
        executionMs: 5,
        points: [
          { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
          { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
          { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
          { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
          { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
          { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
          { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
          { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
        ]
      };
      const emptyPoseResult: PoseResult = {
        ok: false,
        skeletonCount: 0,
        pointCount: 0,
        executionMs: 1,
        points: []
      };
      const source = new FixedDancePoseFrameSource([poseResult, poseResult, emptyPoseResult]);
      const clock = new MutableDanceSamplingClock(1000);
      const delay = new RecordingDanceSamplingDelay(clock);

      const result = await new DanceTimedSamplingService(delay, clock).sample(source, 3);

      expect(source.requestedFrameIds[0]).assertEqual(1);
      expect(source.requestedFrameIds[1]).assertEqual(2);
      expect(source.requestedFrameIds[2]).assertEqual(3);
      expect(delay.seenIntervals.length).assertEqual(2);
      expect(delay.seenIntervals[0]).assertEqual(danceSampleIntervalMs);
      expect(delay.seenIntervals[1]).assertEqual(danceSampleIntervalMs);
      expect(result.frameCount).assertEqual(3);
      expect(result.validFrameCount).assertEqual(2);
      expect(result.failedFrameCount).assertEqual(0);
      expect(result.cancelled).assertFalse();
      expect(result.frames[2] === undefined).assertTrue();
    });

    it('keepsDanceSamplingOnWallClockCadence', 0, async () => {
      const poseResult: PoseResult = {
        ok: true,
        skeletonCount: 1,
        pointCount: 8,
        executionMs: 5,
        points: [
          { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
          { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
          { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
          { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
          { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
          { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
          { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
          { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
        ]
      };
      const clock = new MutableDanceSamplingClock(1000);
      const delay = new RecordingDanceSamplingDelay(clock);
      const source = new ProcessingDancePoseFrameSource([poseResult, poseResult, poseResult], clock, 120);

      await new DanceTimedSamplingService(delay, clock).sample(source, 3);

      expect(source.frameStartMs[0]).assertEqual(1000);
      expect(source.frameStartMs[1]).assertEqual(1500);
      expect(source.frameStartMs[2]).assertEqual(2000);
      expect(delay.seenIntervals[0]).assertEqual(380);
      expect(delay.seenIntervals[1]).assertEqual(380);
    });

    it('stopsDanceSamplingAfterCancellation', 0, async () => {
      const poseResult: PoseResult = {
        ok: true,
        skeletonCount: 1,
        pointCount: 8,
        executionMs: 5,
        points: [
          { type: dancePosePointType.LEFT_SHOULDER, score: 0.9, x: 10, y: 20 },
          { type: dancePosePointType.RIGHT_SHOULDER, score: 0.9, x: 50, y: 20 },
          { type: dancePosePointType.RIGHT_ELBOW, score: 0.9, x: 30, y: 10 },
          { type: dancePosePointType.RIGHT_WRIST, score: 0.9, x: 30, y: 40 },
          { type: dancePosePointType.LEFT_ELBOW, score: 0.9, x: 10, y: 30 },
          { type: dancePosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 40 },
          { type: dancePosePointType.LEFT_KNEE, score: 0.9, x: 30, y: 60 },
          { type: dancePosePointType.LEFT_ANKLE, score: 0.9, x: 30, y: 80 }
        ]
      };
      const clock = new MutableDanceSamplingClock(1000);
      const delay = new RecordingDanceSamplingDelay(clock);
      const cancellation = new MutableDanceSamplingCancellation();
      const source = new CancellingDancePoseFrameSource(poseResult, cancellation);

      const result = await new DanceTimedSamplingService(delay, clock, cancellation).sample(source, 3);

      expect(source.requestedFrameIds.length).assertEqual(1);
      expect(delay.seenIntervals.length).assertEqual(0);
      expect(result.cancelled).assertTrue();
      expect(result.validFrameCount).assertEqual(1);
    });

    it('reportsDanceSamplingFailureWhenEveryLiveFrameCaptureFails', 0, async () => {
      const capturer = new RecordingDanceFrameImageCapturer([
        { ok: false, uri: '', messageKey: 'feature_runtime_live_frame_failed' },
        { ok: false, uri: '', messageKey: 'feature_runtime_live_frame_failed' }
      ]);
      const detector = new RecordingDancePoseDetector([]);
      const source = new DanceLivePoseFrameSource('surface-1', '/cache', capturer, detector);
      const clock = new MutableDanceSamplingClock(1000);
      const delay = new RecordingDanceSamplingDelay(clock);

      const result = await new DanceTimedSamplingService(delay, clock).sample(source, 2);

      expect(result.failedFrameCount).assertEqual(2);
      expect(result.validFrameCount).assertEqual(0);
      expect(danceSamplingCompletionStatusKey(result)).assertEqual('feature_runtime_live_frame_failed');
      expect(detector.seenImageUris.length).assertEqual(0);
    });

    it('summarizesDanceSamplingResultForPageState', 0, () => {
      const frames = danceTemplateFrames();
      const pageState = danceSamplingPageState({
        frameCount: 70,
        validFrameCount: frames.length,
        failedFrameCount: 0,
        cancelled: false,
        frames: frames,
        score: danceScoreFromFrames(frames)
      });

      expect(pageState.hasResult).assertTrue();
      expect(pageState.scoreText).assertEqual(danceScoreText(danceScoreFromFrames(frames)));
      expect(pageState.resultMessageKey).assertEqual(danceResultMessageKey(danceScoreFromFrames(frames)));
      expect(pageState.summaryText).assertEqual(`${frames.length}/70`);
    });

    it('routesDanceToDedicatedHarmonyPage', 0, () => {
      expect(AppRoute.DANCE.name).assertEqual('/dance/DanceMainActivity');
      expect(AppRoute.DANCE.page).assertEqual(dancePagePath);
      expect(findRouteByName(AppRoute.DANCE.name)?.page).assertEqual(dancePagePath);
      expect(danceResultComponentId).assertEqual('danceResultPanel');
      expect(danceReferenceVideoUrl).assertEqual(
        'https://download.mindspore.cn/model_zoo/official/lite/apk/danceFactory/dance_factory_demo2.mp4'
      );
      expect(danceReferenceVideoLengthBytes).assertEqual(41282333);
      expect(danceCountdownSequence().join(',')).assertEqual('3,2,1');
      expect(danceCountdownStepMs).assertEqual(1000);
      expect(hasAppStringKey('dance_prepare_summary')).assertTrue();
      expect(hasAppStringKey('dance_reference_video')).assertTrue();
      expect(hasAppStringKey('dance_countdown')).assertTrue();
      expect(hasAppStringKey('dance_reference_video_failed')).assertTrue();
      expect(hasAppStringKey('dance_start_demo')).assertTrue();
      expect(hasAppStringKey('dance_result_title')).assertTrue();
      expect(hasAppStringKey('dance_platform_note')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_missing')).assertTrue();
    });

    it('mapsDanceScoresToAndroidResultStates', 0, () => {
      expect(danceTemplateDemoScore()).assertEqual(98);
      expect(danceScoreText(98)).assertEqual('98');
      expect(danceScoreText(danceNoActScore)).assertEqual('--');
      expect(danceResultMessageKey(danceNoActScore)).assertEqual('dance_score_level_no_action');
      expect(danceResultMessageKey(danceNoPointScore)).assertEqual('dance_score_level_no_point');
      expect(danceResultMessageKey(63)).assertEqual('dance_score_level_warmup');
      expect(danceResultMessageKey(76)).assertEqual('dance_score_level_good');
      expect(danceResultMessageKey(88)).assertEqual('dance_score_level_great');
      expect(danceResultMessageKey(93)).assertEqual('dance_score_level_excellent');
      expect(danceResultMessageKey(98)).assertEqual('dance_score_level_perfect');
      expect(danceResultMessageKey(100)).assertEqual('dance_score_level_full');
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
      expect(styleTransfer.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(styleTransfer.inputKinds.indexOf('contentImage') >= 0).assertTrue();
      expect(styleTransfer.inputKinds.indexOf('styleImage') >= 0).assertTrue();
      expect(styleTransfer.inputKinds.indexOf('stylePredictModelFile')).assertEqual(-1);
      expect(styleTransfer.inputKinds.indexOf('styleTransferModelFile')).assertEqual(-1);
      expect((styleTransfer.optionalInputKinds ?? []).indexOf('stylePredictModelFile') >= 0).assertTrue();
      expect((styleTransfer.optionalInputKinds ?? []).indexOf('styleTransferModelFile') >= 0).assertTrue();

      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      expect(translation.aiMethod).assertEqual('translateText');
      expect(translation.inputKinds.indexOf('text') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(translation.requiredPermissions.indexOf('internet') >= 0).assertTrue();

      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      expect(portraitSegmentation.aiMethod).assertEqual('segmentPerson');
      expect(portraitSegmentation.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect((portraitSegmentation.optionalInputKinds ?? []).indexOf('backgroundImage') >= 0).assertTrue();
    });

    it('portsAndroidPortraitSegmentationBackgroundPresets', 0, () => {
      expect(portraitSegmentationBackgroundPresets.length).assertEqual(5);
      expect(portraitSegmentationBackgroundPresets[0].id).assertEqual('portrait1');
      expect(portraitSegmentationBackgroundPresets[0].mediaName).assertEqual('portrait1');
      expect(portraitSegmentationBackgroundUri(portraitSegmentationBackgroundPresets[0]))
        .assertEqual('rawfile://portrait/portrait1.jpg');
      expect(portraitSegmentationBackgroundPresets[4].id).assertEqual('portrait5');
      expect(portraitSegmentationCustomBackgroundId).assertEqual('custom');
      expect(hasAppStringKey('feature_runtime_portrait_background_presets')).assertTrue();
      expect(hasAppStringKey('feature_runtime_portrait_background_custom')).assertTrue();
    });

    it('targetsPortraitBackgroundReplacementPreviewForCompositeSave', 0, () => {
      expect(segmentationBackgroundReplacementComponentId).assertEqual('segmentationBackgroundReplacementPreview');
      expect(hasAppStringKey('feature_runtime_result_background_replacement')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_failed')).assertTrue();
    });

    it('recordsPlatformNeedsFromOriginalAndroidFlows', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      expect(posenet.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(posenet.inputKinds.indexOf('photo') >= 0).assertTrue();

      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(objectPhoto.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(objectPhoto.inputKinds.indexOf('modelFile')).assertEqual(-1);
      expect((objectPhoto.optionalInputKinds ?? []).indexOf('modelFile') >= 0).assertTrue();
      expect(objectPhoto.requiredPermissions.indexOf('media') >= 0).assertTrue();

      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      expect(objectCamera.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(objectCamera.inputKinds.indexOf('modelFile')).assertEqual(-1);
      expect((objectCamera.optionalInputKinds ?? []).indexOf('modelFile') >= 0).assertTrue();
      expect(objectCamera.requiredPermissions.indexOf('camera') >= 0).assertTrue();
      expect(objectCamera.requiredPermissions.indexOf('media')).assertEqual(-1);

      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;
      expect(customModel.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('modelFile') >= 0).assertTrue();
    });

    it('mapsAndroidHelpUrlsForRuntimeWorkflows', 0, () => {
      expect(workflowForRoute(AppRoute.IMAGE_CAMERA.name)?.helpUrl).assertEqual(helpImageClassificationUrl);
      expect(workflowForRoute(AppRoute.OBJECT_PHOTO.name)?.helpUrl).assertEqual(helpObjectDetectionUrl);
      expect(workflowForRoute(AppRoute.OBJECT_CAMERA.name)?.helpUrl).assertEqual(helpObjectDetectionUrl);
      expect(workflowForRoute(AppRoute.STYLE_TRANSFER.name)?.helpUrl).assertEqual(helpStyleTransferUrl);
    });

    it('definesRuntimeWorkflowForEveryRuntimeRoute', 0, () => {
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name) !== undefined).assertTrue();
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name) !== undefined).assertTrue();
    });

    it('keepsHiddenDanceRouteReadyOnDedicatedPage', 0, () => {
      const dance = findFeatureByRoute(AppRoute.DANCE.name);
      expect(dance?.visibleByDefault).assertFalse();
      expect(findRouteByName(AppRoute.DANCE.name)?.page).assertEqual(dancePagePath);
      expect(workflowForRoute(AppRoute.DANCE.name) === undefined).assertTrue();
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

    it('aiServiceRecognizesImageTextBeforeUnsupportedTranslation', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'MindSpore\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 8
      });

      const result = await new DefaultAiService({
        textRecognitionService: new TextRecognitionService({ runner: recognitionRunner })
      }).run(workflow!, {
        imageUri: 'file://selected/text.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('PLATFORM_UNSUPPORTED');
      expect(result.messageKey).assertEqual('feature_runtime_translation_unsupported');
      expect(result.detailText.indexOf('targetLanguage=zh') >= 0).assertTrue();
      expect(result.detailText.indexOf('source=MindSpore') >= 0).assertTrue();
      expect(result.data?.kind).assertEqual('textTranslation');
      expect(aiRunResultRows(result)[1].labelKey).assertEqual('feature_runtime_result_text');
      expect(aiRunResultRows(result)[1].value).assertEqual('MindSpore\n');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('MindSpore\n');
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/text.jpg');
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
        foregroundImageRgba: new Uint8Array([255, 0, 0, 255]).buffer as ArrayBuffer,
        foregroundImageWidth: 1,
        foregroundImageHeight: 1,
        rectangles: [rectangle],
        executionMs: 13
      });
      const service = new SegmentationService({
        runner: runner
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/person.jpg',
        backgroundImageUri: 'file://selected/background.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SEGMENTATION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_segmentation_done');
      expect(result.detailText.indexOf('subjectCount=1') >= 0).assertTrue();
      expect(result.detailText.indexOf('background=background.jpg') >= 0).assertTrue();
      expect(result.detailText.indexOf('[1,2,100,200]') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_subjects');
      expect(aiRunResultRows(result)[0].value).assertEqual('1');
      expect(aiRunResultRows(result).filter((row: AiRunResultRow) =>
        row.labelKey === 'feature_runtime_result_background')[0].value).assertEqual('background.jpg');
      expect(result.data?.kind).assertEqual('segmentation');
      if (result.data?.kind === 'segmentation') {
        expect(result.data.backgroundImageUri).assertEqual('file://selected/background.jpg');
        expect(result.data.result.foregroundImageWidth).assertEqual(1);
        expect(result.data.result.foregroundImageHeight).assertEqual(1);
        expect(result.data.result.foregroundImageRgba?.byteLength).assertEqual(4);
      }
      expect(runner.seenImageUris[0]).assertEqual('file://selected/person.jpg');
    });

    it('mapsSegmentationRectangleToPercentOverlay', 0, () => {
      const rectangle: SegmentationRectangle = {
        left: 20,
        top: -10,
        width: 160,
        height: 220
      };

      const box = segmentationRectanglePercent(rectangle, 200, 200);

      expect(box.left.toFixed(1)).assertEqual('10.0');
      expect(box.top.toFixed(1)).assertEqual('0.0');
      expect(box.width.toFixed(1)).assertEqual('80.0');
      expect(box.height.toFixed(1)).assertEqual('100.0');
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

    it('poseServiceAddsAndroidLiveSkeletonTemplateSimilarity', 0, async () => {
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: androidLiveSkeletonTemplatePoints.length,
        points: androidLiveSkeletonTemplatePoints,
        executionMs: 9
      });

      const result = await new PoseService({
        runner: runner
      }).detectPose('file://selected/live-pose.jpg');
      const similarity: number = result.similarity ?? -1;

      expect(similarity.toFixed(2)).assertEqual('1.00');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/live-pose.jpg');
    });

    it('aiServiceShowsLiveSkeletonSimilarityLikeAndroidRuntime', 0, async () => {
      const workflow = workflowForRoute(AppRoute.LIVE_SKELETON.name);
      expect(workflow !== undefined).assertTrue();
      const service = new PoseService({
        runner: new FixedPoseRunner({
          ok: true,
          skeletonCount: 1,
          pointCount: androidLiveSkeletonTemplatePoints.length,
          points: androidLiveSkeletonTemplatePoints,
          executionMs: 16
        })
      });

      const result = await new DefaultAiService({ poseService: service }).run(workflow!, {
        imageUri: 'file://selected/live-pose.jpg'
      });
      const rows: Array<AiRunResultRow> = aiRunResultRows(result);

      expect(result.ok).assertTrue();
      expect(result.detailText.indexOf('similarity=100%') >= 0).assertTrue();
      expect(rows[2].labelKey).assertEqual('feature_runtime_result_similarity');
      expect(rows[2].value).assertEqual('100%');
    });

    it('mapsPosePointToPercentOverlay', 0, () => {
      const point: PosePoint = {
        type: 0,
        score: 0.95,
        x: 25,
        y: 175
      };

      const marker = posePointPercent(point, 200, 200);

      expect(marker.x.toFixed(1)).assertEqual('12.5');
      expect(marker.y.toFixed(1)).assertEqual('87.5');
    });

    it('filtersInvalidPoseOverlayPoints', 0, () => {
      const visible: PosePoint = {
        type: 0,
        score: 0.2,
        x: 1,
        y: 1
      };
      const lowScore: PosePoint = {
        type: 1,
        score: 0.19,
        x: 2,
        y: 2
      };
      const zeroPoint: PosePoint = {
        type: 2,
        score: 0.9,
        x: 0,
        y: 0
      };

      expect(isPosePointVisible(visible)).assertTrue();
      expect(isPosePointVisible(lowScore)).assertFalse();
      expect(isPosePointVisible(zeroPoint)).assertFalse();
    });

    it('mapsPosePointsToSkeletonLineOverlay', 0, () => {
      const points: Array<PosePoint> = [
        { type: 0, score: 0.9, x: 100, y: 20 },
        { type: 5, score: 0.9, x: 60, y: 80 },
        { type: 6, score: 0.9, x: 140, y: 80 },
        { type: 7, score: 0.9, x: 40, y: 130 },
        { type: 9, score: 0.9, x: 20, y: 180 },
        { type: 11, score: 0.9, x: 70, y: 180 },
        { type: 13, score: 0.9, x: 70, y: 250 },
        { type: 15, score: 0.9, x: 70, y: 310 },
        { type: 8, score: 0.1, x: 160, y: 130 },
        { type: 10, score: 0.9, x: 180, y: 180 }
      ];

      const lines: Array<PoseLine> = poseSkeletonLines(points);
      const firstLine: PoseLinePercent = poseLinePercent(lines[0], 200, 400);

      expect(lines.length).assertEqual(7);
      expect(lines[0].start.type).assertEqual(0);
      expect(lines[0].end.type).assertEqual(5);
      expect(lines.find((line: PoseLine) => line.start.type === 8 || line.end.type === 8) === undefined).assertTrue();
      expect(firstLine.startX.toFixed(1)).assertEqual('50.0');
      expect(firstLine.startY.toFixed(1)).assertEqual('5.0');
      expect(firstLine.endX.toFixed(1)).assertEqual('30.0');
      expect(firstLine.endY.toFixed(1)).assertEqual('20.0');
      expect(firstLine.length.toFixed(1)).assertEqual('36.1');
      expect(firstLine.angle.toFixed(1)).assertEqual('123.7');
    });

    it('calculatesAndroidLiveSkeletonTemplateSimilarityFromMatchedPointTypes', 0, () => {
      const shiftedPoints: Array<PosePoint> = androidLiveSkeletonTemplatePoints.map((point: PosePoint): PosePoint => {
        return {
          type: point.type,
          score: point.score,
          x: point.x * 0.5 + 12,
          y: point.y * 0.5 + 30
        };
      });

      const similarity: number = poseSimilarityToAndroidTemplate(shiftedPoints) ?? -1;

      expect(androidLiveSkeletonTemplatePoints.length).assertEqual(14);
      expect(similarity.toFixed(2)).assertEqual('1.00');
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

    it('gestureDetectionRequiresImageInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new GestureService({
        runner: new FixedGestureRunner({
          ok: true,
          gestures: [],
          executionMs: 3
        })
      });

      const result = await new DefaultAiService({ gestureService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesRealGestureServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const gesture: GestureDetection = {
        category: 12,
        label: 'Thumb up',
        score: 0.88,
        rect: {
          left: 4,
          top: 8,
          width: 40,
          height: 60
        }
      };
      const runner: FixedGestureRunner = new FixedGestureRunner({
        ok: true,
        gestures: [gesture],
        executionMs: 15
      });
      const service = new GestureService({
        runner: runner
      });

      const result = await new DefaultAiService({ gestureService: service }).run(workflow!, {
        imageUri: 'file://selected/hand.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('GESTURE_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_done');
      expect(result.detailText.indexOf('count=1') >= 0).assertTrue();
      expect(result.detailText.indexOf('Thumb up 88.00% [4,8,40,60]') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_label');
      expect(aiRunResultRows(result)[0].value).assertEqual('Thumb up');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/hand.jpg');
    });

    it('aiServiceFallsBackToAndroidGestureLabelWhenRunnerLabelIsEmpty', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedGestureRunner = new FixedGestureRunner({
        ok: true,
        gestures: [{
          category: 11,
          label: '',
          score: 0.88
        }],
        executionMs: 15
      });
      const service = new GestureService({
        runner: runner
      });

      const result = await new DefaultAiService({ gestureService: service }).run(workflow!, {
        imageUri: 'file://selected/hand.jpg'
      });

      expect(result.detailText.indexOf('Thumb up 88.00%') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].value).assertEqual('Thumb up');
    });

    it('mapsGestureRectangleToPercentOverlay', 0, () => {
      const rectangle: GestureRectangle = {
        left: 10,
        top: -5,
        width: 60,
        height: 55
      };

      const box: GestureRectanglePercent = gestureRectanglePercent(rectangle, 100, 50);

      expect(box.left.toFixed(1)).assertEqual('10.0');
      expect(box.top.toFixed(1)).assertEqual('0.0');
      expect(box.width.toFixed(1)).assertEqual('60.0');
      expect(box.height.toFixed(1)).assertEqual('100.0');
    });

    it('aiServiceReportsGestureFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new GestureService({
        runner: new RejectingGestureRunner()
      });

      const result = await new DefaultAiService({ gestureService: service }).run(workflow!, {
        imageUri: 'file://selected/hand.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('GESTURE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_failed');
    });

    it('aiServiceReportsEmptyGestureResultAsFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new GestureService({
        runner: new FixedGestureRunner({
          ok: true,
          gestures: [],
          executionMs: 5
        })
      });

      const result = await new DefaultAiService({ gestureService: service }).run(workflow!, {
        imageUri: 'file://selected/empty-hand.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('GESTURE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_failed');
    });

    it('sceneDetectionRequiresImageInputWhenServiceIsProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SceneDetectionService({
        runner: new FixedSceneDetectionRunner({
          ok: true,
          scenes: [],
          executionMs: 3
        })
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
    });

    it('aiServiceUsesSceneDetectionServiceWhenProvided', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const scene: SceneDetection = {
        label: 'beach',
        score: 0.96
      };
      const runner = new FixedSceneDetectionRunner({
        ok: true,
        scenes: [scene],
        executionMs: 9
      });
      const service = new SceneDetectionService({
        runner: runner
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/beach.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SCENE_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_scene_done');
      expect(result.detailText.indexOf('beach 96.00%') >= 0).assertTrue();
      expect(aiRunResultRows(result)[0].labelKey).assertEqual('feature_runtime_result_label');
      expect(aiRunResultRows(result)[0].value).assertEqual('beach');
      expect(result.data?.kind).assertEqual('scenes');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/beach.jpg');
    });

    it('aiServiceReportsSceneDetectionFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SceneDetectionService({
        runner: new RejectingSceneDetectionRunner()
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/unknown.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SCENE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_scene_failed');
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

    it('customModelRequiresNativeRunnerInsteadOfSimulatedOutput', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: 'file://selected/custom_model.ms'
      });
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.messageKey).assertEqual('feature_runtime_pending_adapter');
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

    it('aiServiceReportsEmptyCustomModelOutputAsFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedCustomModelTensorRunner([])
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

    it('aiServicePassesSelectedStyleTransferModels', 0, async () => {
      const workflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedStyleTransferRunner = new FixedStyleTransferRunner({
        ok: true,
        outputFloatCount: 384 * 384 * 3,
        predictMs: 4,
        transferMs: 5,
        executionMs: 9
      });
      const styleTransferService = new StyleTransferService({
        runner: runner
      });

      await new DefaultAiService({ styleTransferService: styleTransferService }).run(workflow!, {
        contentImageUri: 'file://selected/content.jpg',
        styleImageUri: 'file://selected/style.jpg',
        stylePredictModelUri: 'file://selected/custom_predict.ms',
        styleTransferModelUri: 'file://selected/custom_transfer.ms'
      });

      expect(runner.seenPredictModelUris[0]).assertEqual('file://selected/custom_predict.ms');
      expect(runner.seenTransferModelUris[0]).assertEqual('file://selected/custom_transfer.ms');
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

    it('usesAndroidStyleTransferMindSporeCpuThreadContract', 0, () => {
      const context = mindSporeLiteCpuContext(styleTransferMindSporeCpuThreadNum);
      expect(styleTransferMindSporeCpuThreadNum).assertEqual(4);
      expect(context.cpu!.threadNum).assertEqual(4);
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

    it('convertsAndroidStyleTransferFloatOutputToRgbaPixels', 0, () => {
      const output = new Float32Array([0, 0.5, 1, 2, -1, 0.25]);
      const rgba = new Uint8Array(styleTransferRgbaOutputFromFloatOutput(output, 2, 1));
      expect(rgba.length).assertEqual(8);
      expect(rgba[0]).assertEqual(0);
      expect(rgba[1]).assertEqual(127);
      expect(rgba[2]).assertEqual(255);
      expect(rgba[3]).assertEqual(255);
      expect(rgba[4]).assertEqual(255);
      expect(rgba[5]).assertEqual(0);
      expect(rgba[6]).assertEqual(63);
      expect(rgba[7]).assertEqual(255);
    });

    it('requestsStyleTransferOutputPixelMapAsRgba', 0, () => {
      const options: image.InitializationOptions = styleTransferPixelMapOptions(384, 256);
      expect(options.size.width).assertEqual(384);
      expect(options.size.height).assertEqual(256);
      expect(options.srcPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
      expect(options.pixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
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
      expect(result.outputImageRgba?.byteLength).assertEqual(styleTransferContentImageSize * styleTransferContentImageSize * 4);
      expect(result.outputImageWidth).assertEqual(styleTransferContentImageSize);
      expect(result.outputImageHeight).assertEqual(styleTransferContentImageSize);
      expect(result.predictMs).assertEqual(7);
      expect(result.transferMs).assertEqual(9);
      expect(preprocessor.seenContentUris[0]).assertEqual('file://selected/content.jpg');
      expect(tensorRunner.seenStyleBytes[0]).assertEqual(256 * 256 * 3 * 4);
    });

    it('styleTransferMindSporeRunnerForwardsSelectedModelUris', 0, async () => {
      const input: StyleTransferInput = {
        contentInputBuffer: new ArrayBuffer(12),
        styleInputBuffer: new ArrayBuffer(8)
      };
      const preprocessor: FixedStyleTransferPreprocessor = new FixedStyleTransferPreprocessor(input);
      const tensorRunner: FixedStyleTransferTensorRunner = new FixedStyleTransferTensorRunner({
        output: new Float32Array(styleTransferOutputFloatCount),
        predictMs: 1,
        transferMs: 2
      });
      const runner = new StyleTransferMindSporeRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner
      });

      await runner.run('file://selected/content.jpg', 'file://selected/style.jpg', {
        predictModelUri: 'file://selected/custom_predict.ms',
        transferModelUri: 'file://selected/custom_transfer.ms'
      });

      expect(tensorRunner.seenPredictModelUris[0]).assertEqual('file://selected/custom_predict.ms');
      expect(tensorRunner.seenTransferModelUris[0]).assertEqual('file://selected/custom_transfer.ms');
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

    it('usesAndroidMindSporeCpuThreadContract', 0, () => {
      const context = mindSporeLiteCpuContext();
      expect(mindSporeLiteCpuThreadNum).assertEqual(2);
      expect(context.target![0]).assertEqual('cpu');
      expect(context.cpu!.threadNum).assertEqual(2);
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

    it('mapsObjectDetectionBoxToPercentOverlay', 0, () => {
      const detection: ObjectDetection = {
        imageId: 1,
        labelId: 1,
        label: 'person',
        score: 0.72,
        left: 20,
        top: -10,
        right: 180,
        bottom: 210
      };

      const box = objectDetectionBoxPercent(detection, 200, 200);

      expect(box.left.toFixed(1)).assertEqual('10.0');
      expect(box.top.toFixed(1)).assertEqual('0.0');
      expect(box.width.toFixed(1)).assertEqual('80.0');
      expect(box.height.toFixed(1)).assertEqual('100.0');
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

    it('reportsGestureAsPlatformUnsupported', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result = await service.run(workflow!);

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('PLATFORM_UNSUPPORTED');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_unsupported');
    });

    it('reportsSceneDetectionAsPlatformUnsupportedWithoutRunner', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result = await service.run(workflow!, {
        imageUri: 'file://selected/scene.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('PLATFORM_UNSUPPORTED');
      expect(result.messageKey).assertEqual('feature_runtime_scene_unsupported');
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

    it('definesAndroidBuiltInStyleTransferStyles', 0, () => {
      expect(builtInStyleTransferStyles.length).assertEqual(builtInStyleTransferStyleCount);
      expect(builtInStyleTransferStyleCount).assertEqual(19);
      expect(builtInStyleTransferStyles[0].rawfilePath).assertEqual('styletransfer/style0.jpg');
      expect(builtInStyleTransferStyles[18].rawfilePath).assertEqual('styletransfer/style18.jpg');
      expect(builtInStyleTransferUri(builtInStyleTransferStyles[0]))
        .assertEqual('rawfile://styletransfer/style0.jpg');
      expect(rawfilePathFromBuiltInStyleTransferUri('rawfile://styletransfer/style18.jpg'))
        .assertEqual('styletransfer/style18.jpg');
      expect(rawfilePathFromBuiltInStyleTransferUri('file://selected/style.jpg')).assertEqual('');
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

    it('runtimeFactoryInjectsOcrForImageTranslationWithoutTranslator', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'MindSpore\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 7
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        textRecognitionRunner: recognitionRunner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/translation.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('PLATFORM_UNSUPPORTED');
      expect(result.messageKey).assertEqual('feature_runtime_translation_unsupported');
      expect(result.detailText.indexOf('source=MindSpore') >= 0).assertTrue();
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/translation.jpg');
    });

    it('runtimeFactoryReportsTranslationUnsupportedWithoutTranslator', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result: AiRunResult = await service.run(workflow!, {
        text: 'hello'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('PLATFORM_UNSUPPORTED');
      expect(result.messageKey).assertEqual('feature_runtime_translation_unsupported');
    });

    it('runtimeFactoryInjectsGestureServiceForGestureWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedGestureRunner = new FixedGestureRunner({
        ok: true,
        gestures: [{
          category: 10,
          label: 'Fist',
          score: 0.91
        }],
        executionMs: 6
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        gestureRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/gesture.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('GESTURE_DETECTION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/gesture.jpg');
    });

    it('runtimeFactoryInjectsSceneDetectionServiceForSceneWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const runner = new FixedSceneDetectionRunner({
        ok: true,
        scenes: [{
          label: 'food',
          score: 0.82
        }],
        executionMs: 7
      });
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        sceneDetectionRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/food.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SCENE_DETECTION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/food.jpg');
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
      expect(declaredPermissionNames.indexOf('ohos.permission.SHORT_TERM_WRITE_IMAGEVIDEO') >= 0).assertTrue();
    });

    it('requestsAndroidStartupRuntimePermissionsWithoutInternet', 0, () => {
      const permissionNames = startupPermissionNames();
      expect(permissionNames.length).assertEqual(2);
      expect(permissionNames.indexOf('ohos.permission.CAMERA') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.READ_IMAGEVIDEO') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.INTERNET')).assertEqual(-1);
      expect(permissionNames.indexOf('ohos.permission.SHORT_TERM_WRITE_IMAGEVIDEO')).assertEqual(-1);
    });

    it('mapsWorkflowInputsToPickerActions', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const actions = runtimeInputActionsForWorkflow(styleTransfer);
      expect(actions.indexOf('captureImage') >= 0).assertTrue();
      expect(actions.indexOf('pickImage') >= 0).assertTrue();
      expect(actions.indexOf('pickModelFile')).assertEqual(-1);
      expect(runtimeInputKindsForWorkflow(styleTransfer).indexOf('stylePredictModelFile') >= 0).assertTrue();
      expect(runtimeInputKindsForWorkflow(styleTransfer).indexOf('styleTransferModelFile') >= 0).assertTrue();
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(runtimeInputActionsForWorkflow(objectPhoto).indexOf('pickModelFile')).assertEqual(-1);
      expect(runtimeInputKindsForWorkflow(objectPhoto).indexOf('modelFile') >= 0).assertTrue();
      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      expect(runtimeInputKindsForWorkflow(portraitSegmentation).indexOf('backgroundImage') >= 0).assertTrue();
      expect(inputActionForKind('camera')).assertEqual('captureImage');
      expect(inputActionForKind('photo')).assertEqual('pickImage');
      expect(inputActionForKind('backgroundImage')).assertEqual('pickImage');
      expect(inputActionForKind('text')).assertEqual('enterText');
      expect(inputActionForKind('stylePredictModelFile')).assertEqual('pickModelFile');
      expect(inputActionForKind('styleTransferModelFile')).assertEqual('pickModelFile');
      expect(inputKindReplacesPrimaryInput('modelFile')).assertFalse();
      expect(inputKindReplacesPrimaryInput('stylePredictModelFile')).assertFalse();
      expect(inputKindReplacesPrimaryInput('backgroundImage')).assertFalse();
      expect(inputKindReplacesPrimaryInput('photo')).assertTrue();
    });

    it('autoRunsTextImageInputsAfterAndroidImageInputReadyOnly', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'text')).assertFalse();

      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'text')).assertFalse();

      expect(shouldAutoRunWorkflowAfterInputReady(styleTransfer, 'camera')).assertFalse();
      expect(shouldAutoRunWorkflowAfterInputReady(styleTransfer, 'contentImage')).assertFalse();
      expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'photo')).assertFalse();
      expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'camera')).assertFalse();
      expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'modelFile')).assertFalse();

      const futureOcrWorkflow: FeatureWorkflow = {
        routeName: '/future/OcrActivity',
        titleKey: 'title_text_extraction',
        summaryKey: 'workflow_summary_text_recognition',
        aiMethod: 'recognizeText',
        inputKinds: ['photo'],
        requiredPermissions: ['media'],
        resultKind: 'recognizedText',
        liveMode: false
      };
      expect(shouldAutoRunWorkflowAfterInputReady(futureOcrWorkflow, 'photo')).assertFalse();
    });

    it('clearsTypedTranslationTextWhenAndroidImageTranslationInputIsReady', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

      expect(shouldClearTextInputAfterInputReady(textTranslation, 'photo')).assertTrue();
      expect(shouldClearTextInputAfterInputReady(textTranslation, 'camera')).assertTrue();
      expect(shouldClearTextInputAfterInputReady(textTranslation, 'text')).assertFalse();
      expect(shouldClearTextInputAfterInputReady(textRecognition, 'photo')).assertFalse();
    });

    it('computesTextImageInputReadyPageActionBeforeAutoRun', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      const imageTranslationAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textTranslation, 'photo', 'typed first');
      expect(imageTranslationAction.userText).assertEqual('');
      expect(imageTranslationAction.shouldRunWorkflow).assertTrue();

      const typedTranslationAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textTranslation, 'text', 'typed first');
      expect(typedTranslationAction.userText).assertEqual('typed first');
      expect(typedTranslationAction.shouldRunWorkflow).assertFalse();

      const imageOcrAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textRecognition, 'camera', 'typed first');
      expect(imageOcrAction.userText).assertEqual('typed first');
      expect(imageOcrAction.shouldRunWorkflow).assertTrue();

      const styleTransferAction: WorkflowInputReadyAction =
        workflowInputReadyAction(styleTransfer, 'photo', 'typed first');
      expect(styleTransferAction.userText).assertEqual('typed first');
      expect(styleTransferAction.shouldRunWorkflow).assertFalse();
    });

    it('mapsLiveCameraWorkflowsToLivePreviewAction', 0, () => {
      const imageCamera: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;

      expect(runtimeInputActionForWorkflowInput(imageCamera, 'camera')).assertEqual('startLiveCamera');
      expect(runtimeInputActionsForWorkflow(objectCamera).indexOf('startLiveCamera') >= 0).assertTrue();
      expect(runtimeInputActionForWorkflowInput(textRecognition, 'camera')).assertEqual('captureImage');
      expect(gestureLive.liveMode).assertTrue();
      expect(runtimeInputActionForWorkflowInput(gestureLive, 'camera')).assertEqual('startLiveCamera');
    });

    it('liveCameraPreviewServiceRequiresSurfaceIdBeforeStarting', 0, async () => {
      const driver = new RecordingLiveCameraPreviewDriver(false);
      const result = await new LiveCameraPreviewService(driver).start('');

      expect(result.ok).assertFalse();
      expect(result.messageKey).assertEqual('feature_runtime_live_camera_surface_missing');
      expect(driver.startedSurfaceIds.length).assertEqual(0);
    });

    it('liveCameraPreviewServiceReportsReadyAndFailure', 0, async () => {
      const readyDriver = new RecordingLiveCameraPreviewDriver(false);
      const readyResult = await new LiveCameraPreviewService(readyDriver).start('surface-1');
      const failedResult = await new LiveCameraPreviewService(new RecordingLiveCameraPreviewDriver(true)).start('surface-2');

      expect(liveCameraXComponentId.length > 0).assertTrue();
      expect(readyResult.ok).assertTrue();
      expect(readyResult.surfaceId).assertEqual('surface-1');
      expect(readyResult.messageKey).assertEqual('feature_runtime_live_camera_ready');
      expect(readyDriver.startedSurfaceIds[0]).assertEqual('surface-1');
      expect(readyDriver.startedPositions[0]).assertEqual('back');
      expect(failedResult.ok).assertFalse();
      expect(failedResult.messageKey).assertEqual('feature_runtime_live_camera_failed');
    });

    it('liveCameraPreviewServiceUsesRequestedCameraPositionLikeAndroidSwitch', 0, async () => {
      const driver = new RecordingLiveCameraPreviewDriver(false);
      const result = await new LiveCameraPreviewService(driver).start('surface-3', 'front');

      expect(result.ok).assertTrue();
      expect(driver.startedSurfaceIds[0]).assertEqual('surface-3');
      expect(driver.startedPositions[0]).assertEqual('front');
      expect(nextLiveCameraPosition('back')).assertEqual('front');
      expect(nextLiveCameraPosition('front')).assertEqual('back');
    });

    it('liveFrameImageServiceCapturesSurfaceToCacheImageUri', 0, async () => {
      const encoder = new FixedLiveFrameImageEncoder(new Uint8Array([1, 2, 3]).buffer as ArrayBuffer);
      const store = new RecordingLiveFrameImageStore('/cache/live-frame.jpg');
      const result = await new LiveFrameImageService(encoder, store).captureToCacheImage('surface-1', '/cache');

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('/cache/live-frame.jpg');
      expect(result.messageKey).assertEqual('feature_runtime_image_ready');
      expect(encoder.seenSurfaceIds[0]).assertEqual('surface-1');
      expect(store.seenCacheDirs[0]).assertEqual('/cache');
      expect(store.seenBytes[0][2]).assertEqual(3);
    });

    it('liveFrameImageEncoderUsesAndroidLikeJpegPacking', 0, () => {
      expect(liveFrameImagePackingOption.format).assertEqual('image/jpeg');
      expect(liveFrameImagePackingOption.quality).assertEqual(90);
    });

    it('liveFrameImageServiceReportsCaptureFailureWithoutWritingCache', 0, async () => {
      const missingSurfaceStore = new RecordingLiveFrameImageStore('/cache/live-frame.jpg');
      const missingSurface = await new LiveFrameImageService(
        new FixedLiveFrameImageEncoder(new ArrayBuffer(1)),
        missingSurfaceStore
      ).captureToCacheImage('', '/cache');
      const rejected = await new LiveFrameImageService(
        new RejectingLiveFrameImageEncoder(),
        new RecordingLiveFrameImageStore('/cache/live-frame.jpg')
      ).captureToCacheImage('surface-1', '/cache');

      expect(missingSurface.ok).assertFalse();
      expect(missingSurface.messageKey).assertEqual('feature_runtime_live_camera_surface_missing');
      expect(missingSurfaceStore.seenCacheDirs.length).assertEqual(0);
      expect(rejected.ok).assertFalse();
      expect(rejected.messageKey).assertEqual('feature_runtime_live_frame_failed');
    });

    it('capturesLiveFrameOnlyWhenLiveCameraIsTheActiveImageSource', 0, () => {
      expect(shouldCaptureLiveFrameImage(false, '', false)).assertFalse();
      expect(shouldCaptureLiveFrameImage(false, '/cache/selected.jpg', true)).assertFalse();
      expect(shouldCaptureLiveFrameImage(true, '', false)).assertTrue();
      expect(shouldCaptureLiveFrameImage(true, '/cache/selected.jpg', false)).assertFalse();
      expect(shouldCaptureLiveFrameImage(true, '/cache/previous.jpg', true)).assertTrue();
    });

    it('startsLiveLoopOnlyForActiveImageClassificationCameraWorkflow', 0, () => {
      expect(shouldRunLiveImageClassificationLoop('classifyImage', true, true)).assertTrue();
      expect(shouldRunLiveImageClassificationLoop('classifyImage', true, false)).assertFalse();
      expect(shouldRunLiveImageClassificationLoop('detectObjects', true, true)).assertFalse();
      expect(shouldRunLiveImageClassificationLoop('classifyImage', false, true)).assertFalse();
      expect(liveImageClassificationIntervalMs).assertEqual(1000);
      expect(liveRuntimeIntervalMs).assertEqual(1000);
    });

    it('runsLiveLoopForImplementedLiveCameraAiMethodsOnly', 0, () => {
      expect(shouldRunLiveRuntimeLoop('classifyImage', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectObjects', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('segmentPerson', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectPose', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectGesture', true, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('runStyleTransfer', true, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('translateText', true, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('runCustomModel', true, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('runStyleTransfer', false, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('detectObjects', false, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('detectObjects', true, false, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('detectObjects', true, true, false)).assertFalse();
    });

    it('autoRunsLiveRuntimeAfterPreviewIsReadyLikeAndroidLensEnginePages', 0, () => {
      expect(shouldAutoRunLiveRuntimeAfterPreview('classifyImage', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectObjects', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('segmentPerson', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectPose', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectGesture', false, true)).assertFalse();
      expect(shouldAutoRunLiveRuntimeAfterPreview('runStyleTransfer', false, true)).assertFalse();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectObjects', true, false)).assertFalse();
    });

    it('liveRuntimeLoopRunsImmediatelyThenOnEachInterval', 0, async () => {
      const scheduler = new ManualLiveRuntimeLoopScheduler();
      const runner = new RecordingLiveRuntimeFrameRunner();
      const service = new LiveRuntimeLoopService(scheduler);

      service.start(liveImageClassificationIntervalMs, runner);
      await Promise.resolve();
      scheduler.tick();
      await Promise.resolve();

      expect(scheduler.intervalMsValues[0]).assertEqual(1000);
      expect(runner.runCount).assertEqual(2);
    });

    it('liveRuntimeLoopSkipsReentryAndCancelsOnStop', 0, async () => {
      const scheduler = new ManualLiveRuntimeLoopScheduler();
      const runner = new BlockingLiveRuntimeFrameRunner();
      const service = new LiveRuntimeLoopService(scheduler);

      service.start(liveImageClassificationIntervalMs, runner);
      await Promise.resolve();
      scheduler.tick();
      await Promise.resolve();
      expect(runner.runCount).assertEqual(1);

      runner.finish();
      await Promise.resolve();
      await Promise.resolve();
      scheduler.tick();
      await Promise.resolve();
      expect(runner.runCount).assertEqual(2);

      service.stop();
      scheduler.tick();
      await Promise.resolve();
      expect(scheduler.cancelledIds[0]).assertEqual(1);
      expect(runner.runCount).assertEqual(2);
    });

    it('usesMindSporeModelFileSuffixForModelPicker', 0, () => {
      expect(modelFileSuffixFilters.length).assertEqual(1);
      expect(modelFileSuffixFilters[0]).assertEqual('.ms');
    });

    it('usesAndroidModelCacheFileNamesForPickedModelInputs', 0, () => {
      expect(cachedModelFileNameForInputKind(AppRoute.CUSTOM_MODEL.name, 'modelFile')).assertEqual('custom_model.ms');
      expect(cachedModelFileNameForInputKind(AppRoute.STYLE_TRANSFER.name, 'stylePredictModelFile')).assertEqual('custom_predict.ms');
      expect(cachedModelFileNameForInputKind(AppRoute.STYLE_TRANSFER.name, 'styleTransferModelFile')).assertEqual('custom_transfer.ms');
    });

    it('keepsObjectDetectionPickedModelUriInsteadOfCustomModelCacheSlot', 0, () => {
      expect(shouldCachePickedModelFileForRoute(AppRoute.OBJECT_PHOTO.name, 'modelFile')).assertFalse();
      expect(shouldCachePickedModelFileForRoute(AppRoute.OBJECT_CAMERA.name, 'modelFile')).assertFalse();
      expect(cachedModelFileNameForInputKind(AppRoute.OBJECT_PHOTO.name, 'modelFile')).assertEqual('');
      expect(cachedModelFileNameForInputKind(AppRoute.CUSTOM_MODEL.name, 'modelFile')).assertEqual('custom_model.ms');
    });

    it('cachesPickedModelFileContentBeforeRuntimeUse', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4])));
      const writer = new RecordingModelFileCacheWriter('/cache/custom_model.ms');
      const service = new RuntimeModelFileCacheService(reader, writer);

      const result = await service.cachePickedModelFile('file://selected/custom.ms', '/cache', AppRoute.CUSTOM_MODEL.name, 'modelFile');

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('/cache/custom_model.ms');
      expect(result.messageKey).assertEqual('feature_runtime_model_ready');
      expect(writer.seenCacheDirs[0]).assertEqual('/cache');
      expect(writer.seenFileNames[0]).assertEqual('custom_model.ms');
      expect(writer.writtenBytes[0]).assertEqual(4);
    });

    it('reportsPickedModelFileCacheFailureWithI18nKey', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4])));
      const writer = new RejectingModelFileCacheWriter();
      const service = new RuntimeModelFileCacheService(reader, writer);

      const result = await service.cachePickedModelFile('file://selected/custom.ms', '/cache', AppRoute.CUSTOM_MODEL.name, 'modelFile');

      expect(result.ok).assertFalse();
      expect(result.uri).assertEqual('');
      expect(result.messageKey).assertEqual('feature_runtime_model_cache_failed');
    });

    it('rejectsShortModelFileCacheWrites', 0, () => {
      expect(modelFileCacheWriteSucceeded(4, new Uint8Array([1, 2, 3, 4]))).assertTrue();
      expect(modelFileCacheWriteSucceeded(3, new Uint8Array([1, 2, 3, 4]))).assertFalse();
    });
  });
}
