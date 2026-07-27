import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import request from '@ohos.request';
import { AppRoute, findRouteByName } from '../main/ets/app/AppRoutes';
import { MainTab, mainTabs } from '../main/ets/app/AppState';
import { hasAppStringKey } from '../main/ets/common/i18n/AppStrings';
import { webPageFailedAfterRequest } from '../main/ets/features/web/WebPageLoadState';
import { iconLabel, iconMediaName } from '../main/ets/common/icons/IconSymbols';
import {
  AiRunResult,
  AiRunResultRow,
  DefaultAiService,
  SegmentationBackgroundMetadata,
  androidStillSceneResultRows,
  aiRunResultRows,
  copyableTextForAiResult,
  textRecognitionOutputForAiResult,
  translatedTextForAiResult,
  segmentationMetadataWithBackground,
  sceneDetectionOverlayRows
} from '../main/ets/services/ai/AiService';
import { ClipboardService, TextClipboardWriter } from '../main/ets/services/clipboard/ClipboardService';
import {
  androidDefaultTranslationTargetLanguage,
  containsAndroidChineseText,
  LocalTextTranslationRunner,
  parseTranslationLanguagePairs,
  TextRecognitionResult,
  TextRecognitionRunner,
  TextRecognitionService,
  TextTranslationResult,
  TextTranslationRunner,
  TextTranslationRuntimeSource,
  TextTranslationService,
  ocrCtcText,
  textRecognitionOutputFromBlocks,
  translationLanguagePairSupportsTarget,
  translationLanguagePairsRawfilePath
} from '../main/ets/services/ai/TextRecognitionService';
import {
  SegmentationRectangle,
  SegmentationResult,
  SegmentationRunner,
  SegmentationService,
  segmentationConfigForAndroidScene,
  segmentationRectanglePercent
} from '../main/ets/services/ai/SegmentationService';
import {
  PosePoint,
  PoseLine,
  PoseLinePercent,
  PoseDetectionMode,
  PoseResult,
  PoseRunner,
  PoseService,
  androidLiveSkeletonTemplatePoints,
  createPoseImageSourceForUri,
  isPosePointVisible,
  poseLinePercent,
  posePointPercent,
  PoseImageFileOpener,
  PoseImageSourceInput,
  PoseImageSourceFactory,
  rawfilePathFromPoseImageUri,
  poseSimilarityToAndroidTemplate,
  poseSkeletonLines
} from '../main/ets/services/ai/PoseService';
import { PosePointType } from '../main/ets/services/ai/PosePointType';
import {
  GestureDetection,
  AndroidGestureModelDetection,
  AndroidGestureModelDetector,
  AndroidGestureModelRunner,
  AndroidGestureModelResult,
  GestureRectangle,
  GestureRectanglePercent,
  GestureResult,
  ImageClassificationGestureRunner,
  GestureRegionEstimate,
  GestureRegionEstimator,
  GestureRunner,
  GestureService,
  androidGestureLabelKey,
  gestureDetectionLabel,
  gestureDetectionLabelKey,
  gestureCategoryForImageClassificationLabel,
  gestureRectangleFromRgbaForeground,
  gestureRectanglePercent,
  localGestureDetectionMaxGestureCount
} from '../main/ets/services/ai/GestureService';
import {
  hmsGestureConfidenceThresholdForLiveMode
} from '../main/ets/services/ai/HmsGestureModelDetector';
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
  danceReferenceVideoCanStartLive,
  danceReferenceVideoProgressText,
  danceReferenceVideoPlayerPreparedAfterCacheResult,
  dancePrepareBackgroundMediaName,
  danceResultActionButtonHeightPx,
  danceResultActionButtonWidthPx,
  danceResultBackgroundAspectRatio,
  danceResultBackButtonHeightPx,
  danceResultBackButtonWidthPx,
  danceResultBackgroundHeightPx,
  danceResultBackgroundMediaName,
  danceResultBackgroundWidthPx,
  danceResultBackMediaName,
  danceRunBackgroundMediaName,
  danceResultComponentId,
  danceResultPlayAgainLabelKey,
  danceResultPlayAgainMediaName,
  danceResultSaveMediaName,
  danceResultScoreLabelKey,
  danceResultMessageKey,
  danceSaveStatusKey,
  danceSamplingCompletionStatusKey,
  danceSamplingPageState,
  danceSamplingResultStopsLiveCameraPreview,
  danceScoreText,
  danceTemplateDemoScore
} from '../main/ets/services/dance/DancePageService';
import {
  DanceReferenceVideoCacheService,
  DanceReferenceVideoDownloader,
  DanceReferenceVideoDownloadTask,
  DanceReferenceVideoFileStore,
  DanceReferenceVideoProgress,
  DanceReferenceVideoProgressCallback,
  danceReferenceVideoCacheFileName,
  danceReferenceVideoCachePath,
  danceReferenceVideoDownloadStatusPaused,
  danceReferenceVideoDownloadStatusRunning,
  danceReferenceVideoDownloadStatusSuccessful,
  danceReferenceVideoProgressPercent,
  isCompleteDanceReferenceVideo,
  waitForDanceReferenceVideoDownload
} from '../main/ets/services/dance/DanceReferenceVideoService';
import {
  DanceKeepScreenOnService,
  DanceKeepScreenOnWindow,
  DanceKeepScreenOnWindowProvider
} from '../main/ets/services/dance/DanceKeepScreenOnService';
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
  AndroidSceneModelDetection,
  AndroidSceneModelDetector,
  AndroidSceneModelResult,
  AndroidSceneModelRunner,
  androidSceneDetectionLabels,
  androidSceneDetectionLabelsZh,
  ImageClassificationSceneDetectionRunner,
  localSceneDetectionMaxSceneCount,
  parseSceneDetectionLabels,
  places365SceneLabelCount,
  SceneDetection,
  SceneDetectionResult,
  SceneDetectionRunner,
  SceneDetectionService,
  sceneDetectionDisplayLabel,
  sceneDetectionLabelRawfilePath,
  sceneDetectionModelRawfilePath,
  sceneLabelForImageClassificationLabel,
  topLocalSceneDetections
} from '../main/ets/services/ai/SceneDetectionService';
import {
  StyleTransferInput,
  builtInStyleTransferStyleCount,
  builtInStyleTransferStyles,
  builtInStyleTransferMediaName,
  builtInStyleTransferUri,
  isCustomStyleTransferUri,
  rawfilePathFromBuiltInStyleTransferUri,
  StyleTransferInputPreprocessor,
  StyleTransferModelUris,
  StyleTransferResult,
  StyleTransferRunner,
  StyleTransferService,
  StyleTransferImageSize,
  StyleTransferOutputImageResizer,
  StyleTransferTensorOutput,
  StyleTransferTensorRunner,
  LocalMnnStyleTransferTensorRunner,
  StyleTransferMnnRuntime,
  StyleTransferNativeOutput,
  StyleTransferMindSporeRunner,
  styleTransferMaxOutputImageSize,
  styleTransferMindSporeCpuThreadNum,
  stylePredictModelDownloadUrl,
  stylePredictModelRawfilePath,
  styleTransferContentImageSize,
  styleTransferCenterCropRegion,
  styleTransferDecodeOptions,
  styleTransferModelDownloadUrl,
  styleTransferModelRawfilePath,
  styleTransferOutputImageSizeForContent,
  styleTransferOutputFloatCount,
  styleTransferPixelMapOptions,
  styleTransferRgbaOutputFromFloatOutput,
  styleTransferRgbUnitInputFromRgba,
  styleTransferSaveReady,
  styleTransferCustomStylePickerIndex,
  styleTransferStylePickerItemCount,
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
  CustomModelBufferRuntime,
  CustomModelDefaultOrSelectedRunner,
  CustomModelInputPreprocessor,
  CustomModelMindSporeRunner,
  CustomModelSelectedFileRunner,
  CustomModelService,
  CustomModelTensorRunner,
  customModelDecodeOptions,
  customModelDefaultModelUri,
  customModelInputFloatCount,
  customModelInputSize,
  customModelOutputCanDecode,
  customModelOutputValuesFromMetadata,
  rgbUnitInputFromResizedRgba
} from '../main/ets/services/ai/CustomModelService';
import {
  cachedRuntimeAiServiceForWorkflow,
  createHarmonyDefaultAiService,
  createRuntimeAiServiceForWorkflow,
  HarmonyImageClassificationRuntimeOptions,
  imageCategoryLabelRawfilePathForLocale,
  objectCategoryLabelRawfilePathForLocale,
  rawfileAsciiContentToText,
  rawfileUtf8ContentToText,
  resetHarmonyRuntimeAiServiceCachesForTests,
  segmentationAndroidSceneForWorkflow,
  setHarmonyRuntimeLabelLocaleForTests
} from '../main/ets/services/ai/ImageClassificationRuntimeFactory';
import { RuntimeAiServiceSession } from '../main/ets/services/ai/RuntimeAiServiceSession';
import { RuntimeRequestGeneration } from '../main/ets/features/runtime/RuntimeRequestGeneration';
import { configureTranslationTokenizerForTests } from '../main/ets/services/ai/TinyTranslationTokenizer';
import { TOKENIZER_RUNTIME_FIXTURE } from './TranslationTokenizerFixture';
import {
  RuntimePixelMapOwner,
  clearRuntimePixelMapState
} from '../main/ets/features/runtime/RuntimePixelMapOwner';
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
  ObjectDetectionLiveOverlayBox,
  ObjectDetectionLiveLabelPlacement,
  LocalMnnObjectDetectionRunner,
  ObjectDetectionMnnRuntime,
  ObjectDetectionMindSporeRunner,
  ObjectDetectionModelOutput,
  ObjectDetectionTensorRunner,
  objectDetectionBoxPercent,
  objectDetectionLiveOverlayBox,
  objectDetectionLiveLabelPlacement,
  decodeNanoDetObjectDetections,
  decodeSsdObjectDetections,
  generateObjectDetectionDefaultBoxes,
  objectDetectionAnchorCount,
  objectDetectionClassCount,
  objectDetectionDecodeOptions,
  objectDetectionInputFloatCount,
  objectDetectionInputSize,
  objectDetectionOutputChannelCount,
  objectDetectionOutputFloatCount,
  ObjectDetectionNormalBox,
  objectDetectionModelOutputFromFloatArrays,
  objectDetectionOverlayColor,
  objectDetectionOverlayTextColor,
  objectDetectionOverlayLabel,
  shouldLogObjectDetectionLiveFrame,
  normalizedObjectDetectionRgbInputFromRgba,
  parseObjectCategoryLabels
} from '../main/ets/services/ai/ObjectDetectionService';
import { image } from '@kit.ImageKit';
import {
  decodingOptionsWithImageRotation,
  imageRotationDegreesFromOrientationProperty,
  rotatedImageSize
} from '../main/ets/services/ai/ImageDecodeOrientation';
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
  FeatureInputKind,
  FeatureWorkflow,
  featureWorkflows,
  fixedLiveCameraPositionForWorkflow,
  shouldDeferRuntimeResultClearUntilPickResult,
  WorkflowInputReadyAction,
  autoStartInputKindForWorkflow,
  inputKindReplacesPrimaryInput,
  inputLabelKey,
  isInputPreparationRequestCurrent,
  liveRuntimeModeForWorkflow,
  initialInputKindForWorkflow,
  initialPreviewActionForWorkflow,
  initialLiveCameraPositionForWorkflow,
  rememberedLiveCameraPositionForWorkflow,
  rememberLiveCameraPositionForRoute,
  resetRememberedLiveCameraPositionsForTests,
  runtimeInputKindsForWorkflow,
  visibleInputKindsForWorkflow,
  specializedAndroidLiveLayoutForWorkflow,
  customModelExecutePreflightToastKey,
  customModelModelCacheToastKey,
  customModelOutputFallbackKey,
  objectPhotoFollowupInputKindAfterModelCacheSuccess,
  objectPhotoResultToastKey,
  shouldResetStyleTransferPageAfterModelCacheResult,
  shouldShowGestureStillFailureToast,
  poseNetStillToastKey,
  shouldRestoreCachedModelFileInputs,
  usesAndroidCustomModelLayout,
  usesAndroidObjectPhotoLayout,
  usesAndroidStyleTransferLayout,
  usesAndroidStillSceneLayout,
  usesAndroidStillSegmentationLayout,
  usesAndroidPortraitSegmentationLayout,
  usesAndroidGestureStillLayout,
  usesAndroidPoseNetStillLayout,
  usesAndroidTextRecognitionLayout,
  usesAndroidTextTranslationLayout,
  usesAndroidLiveSceneLayout,
  usesAndroidLiveSkeletonLayout,
  usesSimpleAndroidLiveLayout,
  shouldShowPrimaryImageInputPreview,
  sampleImageUriForWorkflow,
  shouldAutoRunWorkflowAfterInputReady,
  shouldAutoRunStyleTransferAfterStyleReady,
  styleTransferStyleReadyStatusKey,
  shouldClearTextInputAfterInputReady,
  shouldLeaveRuntimeAfterCancelledInitialPick,
  cancelledPickStatusKeyForWorkflow,
  cancelledPickToastStatusKeyForWorkflow,
  shouldStartWorkflowRun,
  shouldPreserveRuntimeResultAfterInputReady,
  shouldPreserveRuntimeTextResultOnAiResult,
  shouldPreserveRuntimeVisualResultOnAiResult,
  shouldPreserveRuntimeVisualResultOnLiveFrameFailure,
  shouldShowStyleOriginalAfterInputReady,
  styleTransferModelCacheToastKey,
  styleTransferResultToastKey,
  styleTransferStyleSelectionToastKey,
  stillSegmentationResultToastKey,
  stillSceneResultToastKey,
  runtimeSegmentationBackgroundImageUri,
  shouldHideTextInputWhenPreparingInput,
  textInputVisibleAfterCancelledPick,
  shouldAllowRuntimeInputChange,
  shouldClearRuntimeResultAtWorkflowStart,
  shouldKeepScreenOnForWorkflow,
  shouldMirrorLiveGestureCameraOverlay,
  shouldShowCopyTextAction,
  textRecognitionActionEnabled,
  textRecognitionRunActionLabelKey,
  textTranslationRunActionLabelKey,
  shouldShowCompositeSegmentationSaveAction,
  compositeSegmentationSaveReady,
  shouldShowResultSaveAction,
  shouldShowStandaloneSegmentationForegroundPreview,
  shouldShowStandaloneSegmentationOverlayPreview,
  shouldShowLiveClassificationCameraOverlay,
  liveClassificationRetryActionForStatus,
  shouldPublishLiveClassificationPreparingStatus,
  liveGestureRetryActionForStatus,
  shouldPublishLiveGesturePreparingStatus,
  liveSceneRetryActionForStatus,
  shouldPublishLiveScenePreparingStatus,
  shouldPreserveLiveCameraInputOnFailure,
  liveObjectDetectionRetryActionForStatus,
  shouldPublishLiveObjectDetectionPreparingStatus,
  shouldShowLiveGestureCameraOverlay,
  usesAndroidLiveGestureLayout,
  shouldShowLiveObjectDetectionCameraOverlay,
  shouldShowLivePoseCameraOverlay,
  shouldShowLivePoseTemplateOverlay,
  shouldShowPrimaryRunAction,
  shouldShowLiveSegmentationCameraOverlay,
  liveSegmentationRetryActionForStatus,
  shouldPublishLiveSegmentationPreparingStatus,
  shouldRenderLiveCameraPreview,
  liveClassificationEmptyPromptKey,
  shouldMirrorSegmentationForeground,
  shouldUseLongTextInput,
  shouldUseLongTextResultRow,
  textInputPlaceholderKeyForWorkflow,
  shouldShowStyleRecoveryControl,
  shouldShowStyleTransferStyledPreview,
  styleTransferRecoveryStatusKey,
  poseModeForWorkflow,
  workflowInputReadyAction,
  workflowInitialStatusKey,
  workflowInputLabelKey,
  workflowGoLiveLabelKey,
  workflowResultTitleKey,
  workflowRuntimeTitleKey,
  workflowRunActionKey,
  workflowForRoute
} from '../main/ets/features/runtime/FeatureWorkflowCatalog';
import {
  FeatureRuntimePickedInputState,
  runtimePickedInputStateAfterModelCacheFailure,
  runtimePickedInputStateAfterCancelledPick
} from '../main/ets/features/runtime/FeatureRuntimeInputState';
import {
  defaultPortraitSegmentationBackgroundPreset,
  defaultPortraitSegmentationBackgroundUri,
  initialPortraitSegmentationBackgroundState,
  PortraitSegmentationBackgroundState,
  portraitSegmentationBackgroundStateAfterCancelledPick,
  portraitSegmentationBackgroundPresets,
  portraitSegmentationBackgroundUri,
  portraitSegmentationCustomBackgroundId
} from '../main/ets/features/runtime/PortraitSegmentationBackgroundCatalog';
import {
  segmentationBackgroundReplacementComponentId
} from '../main/ets/features/runtime/FeatureRuntimeViewIds';
import { featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees } from '../main/ets/features/runtime/FeatureRuntimeOverlayPreview';
import {
  declaredPermissionNames,
  harmonySettingsFallbackWant,
  permissionRequestSummary,
  runtimeOpenPermissionSettingsAction,
  runtimePermissionRecoveryActionForWorkflow,
  runtimePermissionRunActionForWorkflow,
  runtimePermissionNamesForWorkflow
} from '../main/ets/services/permissions/PermissionService';
import {
  shouldConsumeIndexBackPress
} from '../main/ets/services/splash/SplashStartupService';
import {
  splashLogoHeightVp,
  splashLogoWidthVp
} from '../main/ets/common/data/SplashBranding';
import {
  experienceHeaderMinHeightVp
} from '../main/ets/common/data/ExperienceHeaderBranding';
import {
  experienceCardBorderColor,
  experienceCardBorderWidthVp,
  experienceCardPressedScale,
  experienceCardRadiusVp,
  experienceContentBottomPaddingVp,
  experienceGridCardMinHeightVp,
  experienceGridColumnCount,
  experienceGridColumnGapVp,
  experienceGridMinHeightVp,
  experienceGridRowGapVp,
  experienceGridSideInsetVp,
  experienceStickyTitleMinHeightVp,
  experienceStickyTitleThresholdVp,
  experienceStickyTitleVisible
} from '../main/ets/common/data/ExperienceLayoutSpec';
import {
  PickResult,
  inputActionForKind,
  isApi24EmulatorCameraPickerUnsupported,
  modelFileSuffixFilters,
  runtimeInputActionForWorkflowInput,
  runtimeInputActionsForWorkflow,
  shouldUseInlineCameraFallback
} from '../main/ets/services/picker/PickerService';
import {
  BasicModelFileCompatibilityChecker,
  CachedModelFileExistenceChecker,
  cachedModelFileInputStateForRoute,
  cachedModelFileNameForInputKind,
  HarmonyModelFileCacheWriter,
  NativeStyleTransferModelPairCompatibilityChecker,
  ModelFileCacheFileBackend,
  ModelFileTensorMetadata,
  ModelFileCompatibilityChecker,
  ModelFileCompatibilityLoader,
  CustomModelContentValidator,
  customModelInputContractCompatible,
  ObjectDetectionModelContentValidator,
  StyleTransferModelContentValidator,
  StyleTransferModelPairCompatibilityChecker,
  modelFileCacheWriteSucceeded,
  ModelFileCacheWriter,
  RuntimeModelFileCacheService,
  shouldCachePickedModelFileForRoute
} from '../main/ets/services/picker/ModelFileCacheService';
import {
  LiveCameraPreviewDriver,
  LiveCameraDevicePositionProvider,
  LiveCameraPosition,
  LiveCameraPreviewService,
  LiveCameraSwitchCapabilityService,
  LiveDisplayRotationProvider,
  LivePreviewRotationOutput,
  LivePreviewRotationTracker,
  LiveFrameImageEncoder,
  LiveFrameImageResult,
  LiveFrameImageService,
  LiveFrameImageStore,
  LiveRuntimeFrameRunner,
  LiveRuntimeLoopScheduler,
  LiveRuntimeLoopService,
  isLiveRuntimeGenerationCurrent,
  liveImageClassificationIntervalMs,
  liveFrameImageCachePath,
  liveRuntimeIntervalForAiMethod,
  liveRuntimeIntervalMs,
  livePreviewAspectRatioForRotation,
  livePreviewWidthForAspectRatio,
  livePreviewContentRotationDegrees,
  liveCameraXComponentId,
  liveFrameImagePackingOption,
  liveCameraPreferredPositionForAvailablePositions,
  liveCameraSwitchAvailableForPositions,
  nextLiveCameraPosition,
  shouldRunLiveRuntimeLoop,
  shouldAutoRunLiveRuntimeAfterPreview,
  shouldRunLiveImageClassificationLoop,
  shouldCaptureLiveFrameImage
} from '../main/ets/services/camera/LiveCameraService';
import {
  LiveGestureResultState,
  projectLiveGestureResult
} from '../main/ets/features/runtime/LiveGestureResultProjector';
import {
  allExperienceFeatures,
  FeatureItem,
  FeatureSection,
  findFeatureByRoute,
  experienceSections,
  visibleExperienceSections
} from '../main/ets/common/data/FeatureCatalog';
import {
  collegeMainAskUrl,
  collegeMainCloudUrl,
  collegeMainFaqUrl,
  collegeQuickAppUrl,
  collegeQuickExecuteUrl,
  collegeQuickTrainUrl,
  collegeQuickVideoUrl,
  customModelMoreUrl,
  harmonyPrivacyRawfile,
  helpImageClassificationUrl,
  helpImageSegmentationUrl,
  helpObjectDetectionUrl,
  helpPoseNetUrl,
  helpSceneDetectionUrl,
  helpStyleTransferUrl,
  intelligentPoetryUrl,
  meCodeUrl,
  meHelpUrl,
  meStarUrl,
  mindSporeBaseUrl,
  userPrivacyRulesUrl,
  webDestinationForUrl,
  webUrlForRouteName,
  webPagePath
} from '../main/ets/common/data/WebDestination';
import {
  ExternalHelpLinkContext,
  ExternalHelpLinkOpenOptions,
  ExternalHelpNavigator,
  RuntimeHelpRouteOptions,
  openRuntimeHelpSource
} from '../main/ets/services/web/RuntimeHelpLinkService';
import {
  collegeItems,
  collegeAdapterViewTitleKey,
  collegeSummaryDialogTitleKey,
  isCollegeItemUrlNavigable
} from '../main/ets/common/data/CollegeCatalog';
import {
  collegeCardRadiusVp,
  collegeDialogConfirmMinHeightVp,
  collegeEntryMinHeightVp,
  collegeHeaderMinHeightVp,
  collegePageInsetVp,
  collegeQuickActionMinHeightVp
} from '../main/ets/common/data/CollegeLayoutSpec';
import {
  androidCollegeSummaryDialogSpec,
  CollegeSummaryDialogSpec,
  collegeSummaryDialogLogoMedia
} from '../main/ets/common/data/CollegeSummaryDialog';
import {
  MeItem,
  isMeItemPageNavigable,
  isMeItemUrlNavigable,
  meItems,
  visibleMeItems
} from '../main/ets/common/data/MeCatalog';
import {
  meInfoCardMinHeightVp,
  meInfoCardRadiusVp,
  meLogoSizeVp,
  mePageInsetVp,
  meTitleMinHeightVp
} from '../main/ets/common/data/MeLayoutSpec';
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
  qrCodeSheetActionForNativeDismiss,
  qrCodeSaveSheetVisibleAfterAction,
  shouldStartQrCodeSave
} from '../main/ets/features/qrcode/QrCodeActionSheetState';
import {
  ResultImageAssetWriter,
  ResultImagePixelMapEncoder,
  ResultImageSaveService,
  withCallerOwnedPixelMap,
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
  poetryPosterImageSharePayload,
  poetryPosterComponentId,
  poetryPosterPagePath,
  poetryPosterTextFromParam,
  poetryPosterVisualSpec,
  shouldStartPoetryPosterAction,
  shouldInstallPoetryJavascriptBridge
} from '../main/ets/services/poetry/PoetryPosterService';

class FakeReleasablePixelMap {
  releaseCount: number = 0;
  private readonly rejects: boolean;

  constructor(rejects: boolean = false) {
    this.rejects = rejects;
  }

  async release(): Promise<void> {
    this.releaseCount++;
    if (this.rejects) {
      throw new Error('release failed');
    }
  }
}

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

class FixedGestureRegionEstimator implements GestureRegionEstimator {
  readonly seenImageUris: Array<string> = [];
  private readonly estimate?: GestureRegionEstimate;

  constructor(rect?: GestureRectangle, width: number = 0, height: number = 0) {
    if (rect !== undefined) {
      this.estimate = {
        rect: rect,
        imageWidth: width,
        imageHeight: height
      };
    }
  }

  async estimateRegion(imageUri: string): Promise<GestureRegionEstimate | undefined> {
    this.seenImageUris.push(imageUri);
    return this.estimate;
  }
}

class RejectingGestureRegionEstimator implements GestureRegionEstimator {
  readonly seenImageUris: Array<string> = [];

  async estimateRegion(imageUri: string): Promise<GestureRegionEstimate | undefined> {
    this.seenImageUris.push(imageUri);
    throw new Error('region estimation failed');
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

class RecordingPoseImageSourceFactory implements PoseImageSourceFactory {
  readonly rawfileByteLengths: Array<number> = [];
  readonly fileDescriptors: Array<number> = [];

  createSourceFromRawfileContent(content: Uint8Array): image.ImageSource {
    this.rawfileByteLengths.push(content.length);
    return {} as image.ImageSource;
  }

  createSourceFromFile(imageFile: fileIo.File): image.ImageSource {
    this.fileDescriptors.push(imageFile.fd);
    return {} as image.ImageSource;
  }
}

class ThrowingPoseImageSourceFactory implements PoseImageSourceFactory {
  createSourceFromRawfileContent(_content: Uint8Array): image.ImageSource {
    return {} as image.ImageSource;
  }

  createSourceFromFile(_imageFile: fileIo.File): image.ImageSource {
    throw new Error('image source failed');
  }
}

class RecordingPoseImageFileOpener implements PoseImageFileOpener {
  readonly seenUris: Array<string> = [];
  readonly closedFds: Array<number> = [];

  async open(imageUri: string): Promise<fileIo.File> {
    this.seenUris.push(imageUri);
    return { fd: 7 } as fileIo.File;
  }

  async close(imageFile: fileIo.File): Promise<void> {
    this.closedFds.push(imageFile.fd);
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
    return this.content.length;
  }

  async read(file: FileUriDescriptor, buffer: ArrayBuffer, _offset: number): Promise<number> {
    this.events.push(`read:${file.fd}`);
    new Uint8Array(buffer).set(this.content);
    return this.content.length;
  }

  async close(file: FileUriDescriptor): Promise<void> {
    this.events.push(`close:${file.fd}`);
  }
}

class ThrowingFileUriContentBackend extends FixedFileUriContentBackend {
  async read(file: FileUriDescriptor, _buffer: ArrayBuffer, _offset: number): Promise<number> {
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

  async writeModelFile(
    cacheDir: string,
    fileName: string,
    content: Uint8Array,
    _requestToken: number,
    _isCurrent: () => boolean
  ): Promise<string | undefined> {
    this.seenCacheDirs.push(cacheDir);
    this.seenFileNames.push(fileName);
    this.writtenBytes.push(content.length);
    return this.nextUri;
  }
}

class RejectingModelFileCacheWriter implements ModelFileCacheWriter {
  async writeModelFile(
    _cacheDir: string,
    _fileName: string,
    _content: Uint8Array,
    _requestToken: number,
    _isCurrent: () => boolean
  ): Promise<string | undefined> {
    throw new Error('model cache write failed');
  }
}

class MemoryModelFileCacheFileBackend implements ModelFileCacheFileBackend {
  readonly events: Array<string> = [];
  readonly openedPaths: Array<string> = [];
  readonly replacedStablePaths: Array<string> = [];
  failStage: string = '';
  delayedFirstByte: number = -1;
  private readonly files: Map<string, Uint8Array> = new Map<string, Uint8Array>();
  private readonly openPaths: Map<number, string> = new Map<number, string>();
  private nextFd: number = 1;
  private delayedWriteResolver: (() => void) | undefined = undefined;

  seed(path: string, content: Uint8Array): void {
    this.files.set(path, content);
  }

  bytes(path: string): Uint8Array {
    return this.files.get(path) ?? new Uint8Array(0);
  }

  has(path: string): boolean {
    return this.files.has(path);
  }

  async open(path: string, mode: number): Promise<fileIo.File> {
    this.events.push(`open:${path}:${mode}`);
    this.openedPaths.push(path);
    this.files.set(path, new Uint8Array(0));
    const file = { fd: this.nextFd++ } as fileIo.File;
    this.openPaths.set(file.fd, path);
    return file;
  }

  async write(file: fileIo.File, content: Uint8Array): Promise<number> {
    const path = this.openPaths.get(file.fd) ?? '';
    this.events.push(`write:${path}`);
    if (content.length > 0 && content[0] === this.delayedFirstByte) {
      await new Promise<void>((resolve: () => void) => {
        this.delayedWriteResolver = resolve;
      });
    }
    if (this.failStage === 'write') {
      throw new Error('write failed');
    }
    const written = this.failStage === 'partial' ? Math.max(0, content.length - 1) : content.length;
    this.files.set(path, content.slice(0, written));
    return written;
  }

  async close(file: fileIo.File): Promise<void> {
    const path = this.openPaths.get(file.fd) ?? '';
    this.events.push(`close:${path}`);
    this.openPaths.delete(file.fd);
    if (this.failStage === 'close') {
      throw new Error('close failed');
    }
  }

  replace(sourcePath: string, targetPath: string): void {
    this.events.push(`replace:${sourcePath}:${targetPath}`);
    this.replacedStablePaths.push(targetPath);
    if (this.failStage === 'replace') {
      throw new Error('replace failed');
    }
    this.files.set(targetPath, this.bytes(sourcePath));
    this.files.delete(sourcePath);
  }

  remove(path: string): void {
    this.events.push(`remove:${path}`);
    this.files.delete(path);
  }

  releaseDelayedWrite(): void {
    if (this.delayedWriteResolver !== undefined) {
      this.delayedWriteResolver();
      this.delayedWriteResolver = undefined;
    }
  }
}

class FixedCachedModelFileExistenceChecker implements CachedModelFileExistenceChecker {
  private readonly existingPaths: Array<string>;

  constructor(existingPaths: Array<string>) {
    this.existingPaths = existingPaths;
  }

  async modelFileExists(path: string): Promise<boolean> {
    return this.existingPaths.indexOf(path) >= 0;
  }
}

class RecordingModelFileCompatibilityChecker implements ModelFileCompatibilityChecker {
  readonly seenRouteNames: Array<string> = [];
  readonly seenInputKinds: Array<string> = [];
  readonly seenUris: Array<string> = [];
  readonly seenByteLengths: Array<number> = [];
  private readonly compatible: boolean;

  constructor(compatible: boolean) {
    this.compatible = compatible;
  }

  async isCompatible(
    routeName: string,
    inputKind: FeatureInputKind,
    cachedUri: string,
    content: Uint8Array
  ): Promise<boolean> {
    this.seenRouteNames.push(routeName);
    this.seenInputKinds.push(inputKind);
    this.seenUris.push(cachedUri);
    this.seenByteLengths.push(content.byteLength);
    return this.compatible;
  }
}

class ThrowingModelFileCompatibilityChecker implements ModelFileCompatibilityChecker {
  async isCompatible(
    _routeName: string,
    _inputKind: FeatureInputKind,
    _cachedUri: string,
    _content: Uint8Array
  ): Promise<boolean> {
    throw new Error('selected model cannot be loaded');
  }
}

class RecordingModelFileCompatibilityLoader implements ModelFileCompatibilityLoader {
  readonly seenByteLengths: Array<number> = [];
  private readonly shouldThrow: boolean;
  private readonly inputs: Array<ModelFileTensorMetadata>;

  constructor(shouldThrow: boolean, inputs: Array<ModelFileTensorMetadata> = []) {
    this.shouldThrow = shouldThrow;
    this.inputs = inputs;
  }

  async loadModel(content: Uint8Array): Promise<Array<ModelFileTensorMetadata>> {
    this.seenByteLengths.push(content.byteLength);
    if (this.shouldThrow) {
      throw new Error('invalid MindSpore model');
    }
    return this.inputs;
  }
}

class ChunkedFileUriContentBackend extends FileUriContentBackend {
  readonly events: Array<string> = [];
  private readonly content: Uint8Array;
  private readonly chunkSize: number;
  private position: number = 0;

  constructor(content: Uint8Array, chunkSize: number) {
    super();
    this.content = content;
    this.chunkSize = chunkSize;
  }

  async open(uri: string): Promise<FileUriDescriptor> {
    this.events.push(`open:${uri}`);
    this.position = 0;
    return new FileUriDescriptor(44);
  }

  async size(file: FileUriDescriptor): Promise<number> {
    this.events.push(`size:${file.fd}`);
    return this.content.length;
  }

  async read(file: FileUriDescriptor, buffer: ArrayBuffer, relativeOffset: number): Promise<number> {
    this.events.push(`read:${file.fd}:${relativeOffset}`);
    const start = this.position + relativeOffset;
    const count = Math.min(this.chunkSize, this.content.length - start, buffer.byteLength);
    if (count <= 0) {
      return 0;
    }
    new Uint8Array(buffer).set(this.content.subarray(start, start + count));
    this.position = start + count;
    return count;
  }

  async close(file: FileUriDescriptor): Promise<void> {
    this.events.push(`close:${file.fd}`);
  }
}

class RecordingCustomModelContentValidator implements CustomModelContentValidator {
  readonly seenByteLengths: Array<number> = [];
  private readonly compatible: boolean;

  constructor(compatible: boolean) {
    this.compatible = compatible;
  }

  async validate(content: Uint8Array): Promise<boolean> {
    this.seenByteLengths.push(content.byteLength);
    return this.compatible;
  }
}

class MutableFileUriContentBackend extends FileUriContentBackend {
  private content: Uint8Array;

  constructor(content: Uint8Array) {
    super();
    this.content = content;
  }

  setContent(content: Uint8Array): void {
    this.content = content;
  }

  async open(_uri: string): Promise<FileUriDescriptor> {
    return new FileUriDescriptor(43);
  }

  async size(_file: FileUriDescriptor): Promise<number> {
    return this.content.length;
  }

  async read(_file: FileUriDescriptor, buffer: ArrayBuffer, _offset: number): Promise<number> {
    new Uint8Array(buffer).set(this.content);
    return this.content.length;
  }

  async close(_file: FileUriDescriptor): Promise<void> {
  }
}

class RecordingObjectDetectionModelContentValidator implements ObjectDetectionModelContentValidator {
  readonly seenByteLengths: Array<number> = [];
  private readonly compatible: boolean;

  constructor(compatible: boolean) {
    this.compatible = compatible;
  }

  async validate(content: Uint8Array): Promise<boolean> {
    this.seenByteLengths.push(content.byteLength);
    return this.compatible;
  }
}

class RecordingStyleTransferModelContentValidator implements StyleTransferModelContentValidator {
  readonly predictByteLengths: Array<number> = [];
  readonly transferByteLengths: Array<number> = [];
  readonly pairByteLengths: Array<string> = [];
  private readonly compatible: boolean;

  constructor(compatible: boolean) {
    this.compatible = compatible;
  }

  async validatePredict(content: Uint8Array): Promise<boolean> {
    this.predictByteLengths.push(content.byteLength);
    return this.compatible;
  }

  async validateTransfer(content: Uint8Array): Promise<boolean> {
    this.transferByteLengths.push(content.byteLength);
    return this.compatible;
  }

  async validatePair(predict: Uint8Array, transfer: Uint8Array): Promise<boolean> {
    this.pairByteLengths.push(`${predict.byteLength}:${transfer.byteLength}`);
    return this.compatible;
  }
}

class RecordingStyleTransferModelPairCompatibilityChecker implements StyleTransferModelPairCompatibilityChecker {
  readonly candidateByteLengths: Array<number> = [];
  private readonly compatible: boolean;

  constructor(compatible: boolean) {
    this.compatible = compatible;
  }

  async isCompatible(
    _inputKind: FeatureInputKind,
    _cacheDir: string,
    candidate: Uint8Array
  ): Promise<boolean> {
    this.candidateByteLengths.push(candidate.byteLength);
    return this.compatible;
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

class RecordingCustomModelBufferRuntime implements CustomModelBufferRuntime {
  readonly seenModelFirstBytes: Array<number> = [];
  readonly seenInputBytes: Array<number> = [];

  async run(modelContent: Uint8Array, inputBuffer: ArrayBuffer): Promise<Array<number>> {
    this.seenModelFirstBytes.push(modelContent[0]);
    this.seenInputBytes.push(inputBuffer.byteLength);
    return [modelContent[0]];
  }
}

class DelayedCustomModelBufferRuntime implements CustomModelBufferRuntime {
  active: number = 0;
  maxActive: number = 0;

  async run(_modelContent: Uint8Array, _inputBuffer: ArrayBuffer): Promise<Array<number>> {
    this.active++;
    this.maxActive = Math.max(this.maxActive, this.active);
    await new Promise<void>((resolve: () => void) => setTimeout(resolve, 5));
    this.active--;
    return [1];
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

class FixedSizedStyleTransferInput implements StyleTransferInput {
  readonly contentInputBuffer: ArrayBuffer;
  readonly styleInputBuffer: ArrayBuffer;
  readonly contentImageWidth: number;
  readonly contentImageHeight: number;

  constructor(width: number, height: number) {
    this.contentInputBuffer = new ArrayBuffer(384 * 384 * 3 * 4);
    this.styleInputBuffer = new ArrayBuffer(256 * 256 * 3 * 4);
    this.contentImageWidth = width;
    this.contentImageHeight = height;
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

class RecordingStyleTransferOutputImageResizer implements StyleTransferOutputImageResizer {
  readonly seenSourceWidths: Array<number> = [];
  readonly seenSourceHeights: Array<number> = [];
  readonly seenTargetWidths: Array<number> = [];
  readonly seenTargetHeights: Array<number> = [];

  async resize(
    _rgba: ArrayBuffer,
    sourceWidth: number,
    sourceHeight: number,
    targetWidth: number,
    targetHeight: number
  ): Promise<ArrayBuffer> {
    this.seenSourceWidths.push(sourceWidth);
    this.seenSourceHeights.push(sourceHeight);
    this.seenTargetWidths.push(targetWidth);
    this.seenTargetHeights.push(targetHeight);
    return new ArrayBuffer(targetWidth * targetHeight * 4);
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
  private readonly runtimeSource?: TextTranslationRuntimeSource;

  constructor(translatedText: string, runtimeSource?: TextTranslationRuntimeSource) {
    this.translatedText = translatedText;
    this.runtimeSource = runtimeSource;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    this.seenTexts.push(text);
    this.seenTargetLanguages.push(targetLanguage);
    return {
      ok: true,
      sourceText: text,
      translatedText: this.translatedText,
      targetLanguage: targetLanguage,
      runtimeSource: this.runtimeSource
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
  readonly seenModes: Array<PoseDetectionMode | undefined> = [];
  private readonly result: PoseResult;

  constructor(result: PoseResult) {
    this.result = result;
  }

  async detectPose(imageUri: string, mode?: PoseDetectionMode): Promise<PoseResult> {
    this.seenImageUris.push(imageUri);
    this.seenModes.push(mode);
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

class RecordingDanceKeepScreenOnWindow implements DanceKeepScreenOnWindow {
  readonly seenValues: Array<boolean> = [];

  async setWindowKeepScreenOn(isKeepScreenOn: boolean): Promise<void> {
    this.seenValues.push(isKeepScreenOn);
  }
}

class RejectingDanceKeepScreenOnWindow implements DanceKeepScreenOnWindow {
  async setWindowKeepScreenOn(_isKeepScreenOn: boolean): Promise<void> {
    throw new Error('keep screen on failed');
  }
}

class DelayedEnableDanceKeepScreenOnWindow implements DanceKeepScreenOnWindow {
  readonly completedValues: Array<string> = [];
  private enableResolver: (() => void) | undefined = undefined;

  async setWindowKeepScreenOn(isKeepScreenOn: boolean): Promise<void> {
    if (isKeepScreenOn) {
      await new Promise<void>((resolve: () => void) => {
        this.enableResolver = resolve;
      });
    }
    this.completedValues.push(isKeepScreenOn ? 'true' : 'false');
  }

  releaseEnable(): void {
    if (this.enableResolver !== undefined) {
      this.enableResolver();
    }
  }
}

class FixedDanceKeepScreenOnWindowProvider implements DanceKeepScreenOnWindowProvider {
  private readonly mainWindowValue: DanceKeepScreenOnWindow | undefined;

  constructor(mainWindowValue?: DanceKeepScreenOnWindow) {
    this.mainWindowValue = mainWindowValue;
  }

  async mainWindow(): Promise<DanceKeepScreenOnWindow | undefined> {
    return this.mainWindowValue;
  }
}

class MemoryDanceReferenceVideoFileStore implements DanceReferenceVideoFileStore {
  readonly removedPaths: Array<string> = [];
  readonly replacedPaths: Array<string> = [];
  private readonly sizes: Map<string, number> = new Map<string, number>();

  setFileSize(path: string, size: number): void {
    this.sizes.set(path, size);
  }

  async fileSize(path: string): Promise<number> {
    const size = this.sizes.get(path);
    return size === undefined ? -1 : size;
  }

  async remove(path: string): Promise<void> {
    this.removedPaths.push(path);
    this.sizes.delete(path);
  }

  async replace(sourcePath: string, destinationPath: string): Promise<void> {
    this.replacedPaths.push(`${sourcePath}->${destinationPath}`);
    const size = await this.fileSize(sourcePath);
    this.sizes.delete(sourcePath);
    this.sizes.set(destinationPath, size);
  }
}

class RecordingDanceReferenceVideoDownloader implements DanceReferenceVideoDownloader {
  readonly seenUrls: Array<string> = [];
  readonly seenDestinationPaths: Array<string> = [];
  private readonly store: MemoryDanceReferenceVideoFileStore;
  private readonly downloadedSize: number;
  private readonly progressEvents: Array<DanceReferenceVideoProgress>;

  constructor(
    store: MemoryDanceReferenceVideoFileStore,
    downloadedSize: number,
    progressEvents: Array<DanceReferenceVideoProgress> = []
  ) {
    this.store = store;
    this.downloadedSize = downloadedSize;
    this.progressEvents = progressEvents;
  }

  async download(
    url: string,
    destinationPath: string,
    _context?: common.BaseContext,
    onProgress?: DanceReferenceVideoProgressCallback
  ): Promise<void> {
    this.seenUrls.push(url);
    this.seenDestinationPaths.push(destinationPath);
    if (onProgress !== undefined) {
      this.progressEvents.forEach((progress: DanceReferenceVideoProgress) => onProgress(progress));
    }
    this.store.setFileSize(destinationPath, this.downloadedSize);
  }
}

type DanceReferenceVideoDownloadEvent = 'progress' | 'complete' | 'pause' | 'remove' | 'fail';
type DanceReferenceVideoProgressListener = (receivedBytes: number, totalBytes: number) => void;
type DanceReferenceVideoEmptyListener = () => void;
type DanceReferenceVideoFailureListener = (errorCode: number) => void;
type DanceReferenceVideoDownloadListener =
  DanceReferenceVideoProgressListener | DanceReferenceVideoEmptyListener | DanceReferenceVideoFailureListener;

class ManualDanceReferenceVideoDownloadTask implements DanceReferenceVideoDownloadTask {
  readonly onEvents: Array<DanceReferenceVideoDownloadEvent> = [];
  readonly onCallbacks: Array<DanceReferenceVideoDownloadListener> = [];
  readonly offEvents: Array<DanceReferenceVideoDownloadEvent> = [];
  readonly offCallbacks: Array<DanceReferenceVideoDownloadListener> = [];
  private readonly progressCallbacks: Array<DanceReferenceVideoProgressListener> = [];
  private readonly completeCallbacks: Array<DanceReferenceVideoEmptyListener> = [];
  private readonly pauseCallbacks: Array<DanceReferenceVideoEmptyListener> = [];
  private readonly removeCallbacks: Array<DanceReferenceVideoEmptyListener> = [];
  private readonly failCallbacks: Array<DanceReferenceVideoFailureListener> = [];
  private readonly status: number;
  private readonly failedReason: number;
  private readonly failTaskInfo: boolean;
  private readonly completeAfterFailedTaskInfo: boolean;

  constructor(
    status: number = 1,
    failedReason: number = 0,
    failTaskInfo: boolean = false,
    completeAfterFailedTaskInfo: boolean = false
  ) {
    this.status = status;
    this.failedReason = failedReason;
    this.failTaskInfo = failTaskInfo;
    this.completeAfterFailedTaskInfo = completeAfterFailedTaskInfo;
  }

  on(event: DanceReferenceVideoDownloadEvent, callback: DanceReferenceVideoDownloadListener): void {
    this.onEvents.push(event);
    this.onCallbacks.push(callback);
    if (event === 'progress') {
      this.progressCallbacks.push(callback as DanceReferenceVideoProgressListener);
      return;
    }
    if (event === 'complete') {
      this.completeCallbacks.push(callback as DanceReferenceVideoEmptyListener);
      return;
    }
    if (event === 'pause') {
      this.pauseCallbacks.push(callback as DanceReferenceVideoEmptyListener);
      return;
    }
    if (event === 'remove') {
      this.removeCallbacks.push(callback as DanceReferenceVideoEmptyListener);
      return;
    }
    this.failCallbacks.push(callback as DanceReferenceVideoFailureListener);
  }

  off(event: DanceReferenceVideoDownloadEvent, callback: DanceReferenceVideoDownloadListener): void {
    this.offEvents.push(event);
    this.offCallbacks.push(callback);
  }

  async getTaskInfo(): Promise<request.DownloadInfo> {
    if (this.failTaskInfo) {
      if (this.completeAfterFailedTaskInfo) {
        setTimeout(() => this.emitComplete(), 0);
      }
      throw new Error('Task info unavailable.');
    }
    return {
      status: this.status,
      failedReason: this.failedReason
    } as request.DownloadInfo;
  }

  emitPause(): void {
    this.pauseCallbacks.forEach((callback: () => void) => callback());
  }

  emitRemove(): void {
    this.removeCallbacks.forEach((callback: () => void) => callback());
  }

  emitProgress(receivedBytes: number, totalBytes: number): void {
    this.progressCallbacks.forEach((callback: DanceReferenceVideoProgressListener) =>
      callback(receivedBytes, totalBytes));
  }

  emitComplete(): void {
    this.completeCallbacks.forEach((callback: () => void) => callback());
  }
}

async function danceReferenceVideoPromiseRejected(promise: Promise<void>): Promise<boolean> {
  return promise.then(
    (): boolean => false,
    (_error: Error): boolean => true
  );
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

class FixedAndroidGestureModelDetector implements AndroidGestureModelDetector {
  readonly seenImageUris: Array<string> = [];
  private readonly result: AndroidGestureModelResult;

  constructor(result: AndroidGestureModelResult) {
    this.result = result;
  }

  async detectAndroidGestures(imageUri: string): Promise<AndroidGestureModelResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingAndroidGestureModelDetector implements AndroidGestureModelDetector {
  async detectAndroidGestures(_imageUri: string): Promise<AndroidGestureModelResult> {
    throw new Error('android gesture model failed');
  }
}

class StoppingGestureRunner implements GestureRunner {
  stopCount: number = 0;

  async detectGesture(_imageUri: string): Promise<GestureResult> {
    return {
      ok: true,
      gestures: [{ category: 10, label: 'Fist', score: 0.9 }],
      executionMs: 1
    };
  }

  stop(): void {
    this.stopCount++;
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

class FixedAndroidSceneModelDetector implements AndroidSceneModelDetector {
  readonly seenImageUris: Array<string> = [];
  private readonly result: AndroidSceneModelResult;

  constructor(result: AndroidSceneModelResult) {
    this.result = result;
  }

  async detectAndroidScenes(imageUri: string): Promise<AndroidSceneModelResult> {
    this.seenImageUris.push(imageUri);
    return this.result;
  }
}

class RejectingAndroidSceneModelDetector implements AndroidSceneModelDetector {
  async detectAndroidScenes(_imageUri: string): Promise<AndroidSceneModelResult> {
    throw new Error('android scene model failed');
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

class RecordingExternalHelpLinkContext implements ExternalHelpLinkContext {
  readonly openedLinks: Array<string> = [];
  readonly hiddenFailureDialogs: Array<boolean> = [];

  async openLink(link: string, options?: ExternalHelpLinkOpenOptions): Promise<void> {
    this.openedLinks.push(link);
    this.hiddenFailureDialogs.push(options?.hideFailureTipDialog === true);
  }
}

class RejectingExternalHelpLinkContext implements ExternalHelpLinkContext {
  async openLink(_link: string, _options?: ExternalHelpLinkOpenOptions): Promise<void> {
    throw new Error('no external browser');
  }
}

class RecordingExternalHelpNavigator implements ExternalHelpNavigator {
  readonly routes: Array<RuntimeHelpRouteOptions> = [];

  pushUrl(options: RuntimeHelpRouteOptions): void {
    this.routes.push(options);
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
  private rotationDegrees: number;
  private readonly aspectRatio: number;

  constructor(failStart: boolean, rotationDegrees: number = 0, aspectRatio: number = 4 / 3) {
    this.failStart = failStart;
    this.rotationDegrees = rotationDegrees;
    this.aspectRatio = aspectRatio;
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

  previewRotationDegrees(): number {
    return this.rotationDegrees;
  }

  previewAspectRatio(): number {
    return this.aspectRatio;
  }

  setRotationDegrees(rotationDegrees: number): void {
    this.rotationDegrees = rotationDegrees;
  }
}

class SequenceGestureRunner implements GestureRunner {
  readonly seenImageUris: Array<string> = [];
  private readonly results: Array<GestureResult>;
  private nextResult: number = 0;

  constructor(results: Array<GestureResult>) {
    this.results = results;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    this.seenImageUris.push(imageUri);
    const result = this.results[Math.min(this.nextResult, this.results.length - 1)];
    this.nextResult += 1;
    return result;
  }
}

class RecordingStyleTransferMnnRuntime implements StyleTransferMnnRuntime {
  readonly loadedPredictByteLengths: Array<number> = [];
  readonly loadedTransferByteLengths: Array<number> = [];
  readonly seenStyleFloatCounts: Array<number> = [];
  readonly seenContentFloatCounts: Array<number> = [];
  private readonly output: StyleTransferNativeOutput;

  constructor(output: StyleTransferNativeOutput) {
    this.output = output;
  }

  async loadModels(predictModel: Uint8Array, transferModel: Uint8Array): Promise<void> {
    this.loadedPredictByteLengths.push(predictModel.byteLength);
    this.loadedTransferByteLengths.push(transferModel.byteLength);
  }

  async run(styleInput: Float32Array, contentInput: Float32Array): Promise<StyleTransferNativeOutput> {
    this.seenStyleFloatCounts.push(styleInput.length);
    this.seenContentFloatCounts.push(contentInput.length);
    return this.output;
  }
}

class MutableLiveDisplayRotationProvider implements LiveDisplayRotationProvider {
  rotation: number;

  constructor(rotation: number) {
    this.rotation = rotation;
  }

  currentDisplayRotation(): number {
    return this.rotation;
  }
}

class RecordingLivePreviewRotationOutput implements LivePreviewRotationOutput {
  readonly displayRotations: Array<number> = [];
  private readonly rotations: Array<number>;
  fail: boolean = false;

  constructor(rotations: Array<number>) {
    this.rotations = rotations;
  }

  getPreviewRotation(displayRotation: number): number {
    this.displayRotations.push(displayRotation);
    if (this.fail) {
      throw new Error('preview rotation unavailable');
    }
    return this.rotations[this.displayRotations.length - 1] ?? 0;
  }
}

class FixedLiveCameraDevicePositionProvider implements LiveCameraDevicePositionProvider {
  private readonly positions: Array<LiveCameraPosition>;

  constructor(positions: Array<LiveCameraPosition>) {
    this.positions = positions;
  }

  supportedCameraPositions(): Array<LiveCameraPosition> {
    return this.positions;
  }
}

class ThrowingLiveCameraDevicePositionProvider implements LiveCameraDevicePositionProvider {
  supportedCameraPositions(): Array<LiveCameraPosition> {
    throw new Error('camera capability unavailable');
  }
}

class FixedLiveFrameImageEncoder implements LiveFrameImageEncoder {
  seenSurfaceIds: Array<string> = [];
  seenRotationDegrees: Array<number> = [];
  private readonly imageBytes: ArrayBuffer;

  constructor(imageBytes: ArrayBuffer) {
    this.imageBytes = imageBytes;
  }

  async encodeSurfaceFrame(surfaceId: string, rotationDegrees: number): Promise<ArrayBuffer> {
    this.seenSurfaceIds.push(surfaceId);
    this.seenRotationDegrees.push(rotationDegrees);
    return this.imageBytes;
  }
}

class RejectingLiveFrameImageEncoder implements LiveFrameImageEncoder {
  async encodeSurfaceFrame(_surfaceId: string, _rotationDegrees: number): Promise<ArrayBuffer> {
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

class LiveGestureAiFrameRunner implements LiveRuntimeFrameRunner {
  private readonly service: DefaultAiService;
  private readonly workflow: FeatureWorkflow;
  private readonly imageUris: Array<string>;
  private readonly generation: number;
  private nextFrame: number = 0;
  private completedFrames: number = 0;
  private frameWaiters: Array<() => void> = [];
  private latestState: LiveGestureResultState | undefined = undefined;

  constructor(
    service: DefaultAiService,
    workflow: FeatureWorkflow,
    imageUris: Array<string>,
    generation: number
  ) {
    this.service = service;
    this.workflow = workflow;
    this.imageUris = imageUris;
    this.generation = generation;
  }

  async runOnce(): Promise<void> {
    const imageUri = this.imageUris[Math.min(this.nextFrame, this.imageUris.length - 1)];
    this.nextFrame += 1;
    const result = await this.service.run(this.workflow, { imageUri: imageUri });
    const state = projectLiveGestureResult(result, this.generation, this.generation);
    if (state !== undefined) {
      this.latestState = state;
    }
    this.completedFrames += 1;
    this.frameWaiters.forEach((resolve: () => void) => resolve());
    this.frameWaiters = [];
  }

  current(): LiveGestureResultState {
    return this.latestState!;
  }

  async waitForFrameCount(count: number): Promise<void> {
    while (this.completedFrames < count) {
      await new Promise<void>((resolve: () => void) => this.frameWaiters.push(resolve));
    }
  }
}

class RejectingOnceLiveRuntimeFrameRunner implements LiveRuntimeFrameRunner {
  runCount: number = 0;
  successCount: number = 0;

  async runOnce(): Promise<void> {
    this.runCount += 1;
    if (this.runCount === 1) {
      throw new Error('first live frame failed');
    }
    this.successCount += 1;
  }
}

class RecordingObjectDetectionMnnRuntime implements ObjectDetectionMnnRuntime {
  readonly events: Array<string> = [];
  private activeModel: number = 0;
  private blockFirstPredict: boolean;
  private firstPredictStartedResolver: (() => void) | undefined = undefined;
  private firstPredictStarted: Promise<void>;
  private firstPredictRelease: (() => void) | undefined = undefined;

  constructor(blockFirstPredict: boolean = false) {
    this.blockFirstPredict = blockFirstPredict;
    this.firstPredictStarted = new Promise<void>((resolve: () => void) => {
      this.firstPredictStartedResolver = resolve;
    });
  }

  async loadModel(content: Uint8Array): Promise<void> {
    this.activeModel = content[0] ?? 0;
    this.events.push(`load:${this.activeModel}`);
  }

  async predict(_input: Float32Array): Promise<Float32Array> {
    const modelAtStart = this.activeModel;
    this.events.push(`predict-start:${modelAtStart}`);
    if (this.blockFirstPredict) {
      this.blockFirstPredict = false;
      if (this.firstPredictStartedResolver !== undefined) {
        this.firstPredictStartedResolver();
        this.firstPredictStartedResolver = undefined;
      }
      await new Promise<void>((resolve: () => void) => {
        this.firstPredictRelease = resolve;
      });
    }
    this.events.push(`predict-end:${this.activeModel}`);
    return new Float32Array(objectDetectionOutputFloatCount);
  }

  async waitForFirstPredict(): Promise<void> {
    await this.firstPredictStarted;
  }

  releaseFirstPredict(): void {
    if (this.firstPredictRelease !== undefined) {
      this.firstPredictRelease();
      this.firstPredictRelease = undefined;
    }
  }
}

class FixedOutputObjectDetectionMnnRuntime implements ObjectDetectionMnnRuntime {
  private readonly output: Float32Array;

  constructor(output: Float32Array) {
    this.output = output;
  }

  async loadModel(_content: Uint8Array): Promise<void> {
  }

  async predict(_input: Float32Array): Promise<Float32Array> {
    return this.output;
  }
}

export default function localUnitTest() {
  describe('mindsporePortFoundation', () => {
    it('preservesAndroidRouteNames', 0, () => {
      expect(AppRoute.OBJECT_PHOTO.name).assertEqual('/imageobject/ObjectPhotoActivity');
      expect(AppRoute.STYLE_TRANSFER.name).assertEqual('/styletransfer/StyleMainActivity');
      expect(AppRoute.TEXT_TRANSLATION.name).assertEqual('/hms/TextTranslationActivity');
      expect(AppRoute.VISION_FRAGMENT.name).assertEqual('/app/VisionFragment');
      expect(findRouteByName(AppRoute.VISION_FRAGMENT.name)?.page).assertEqual('pages/ExperienceRoutePage');
      expect(workflowForRoute(AppRoute.VISION_FRAGMENT.name) === undefined).assertTrue();
    });

    it('exposesAndroidSceneDetectionStillRouteAndKeepsLiveRouteRuntimeReady', 0, () => {
      expect(AppRoute.SCENE_STILL.name).assertEqual('/hms/SenceDetectionStillAnalyseActivity');
      expect(AppRoute.SCENE_LIVE.name).assertEqual('/hms/SenceDetectionLiveAnalyseActivity');
      expect(findRouteByName(AppRoute.SCENE_STILL.name)?.page).assertEqual('pages/FeatureRuntimePage');
      expect(findRouteByName(AppRoute.SCENE_LIVE.name)?.page).assertEqual('pages/FeatureRuntimePage');
      expect(findFeatureByRoute(AppRoute.SCENE_STILL.name)?.visibleByDefault).assertFalse();
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
      const scene = allExperienceFeatures.find((item: FeatureItem) => item.id === 'scene');
      const custom = allExperienceFeatures.find((item: FeatureItem) => item.id === 'custom');
      const visibleSceneCount = visibleExperienceSections
        .map((section) => section.items.filter((item: FeatureItem) => item.id === 'scene').length)
        .reduce((sum, count) => sum + count, 0);
      expect(visibleCount).assertEqual(9);
      expect(allExperienceFeatures.length).assertEqual(13);
      expect(scene === undefined).assertFalse();
      expect(scene?.visibleByDefault).assertFalse();
      expect(custom?.visibleByDefault).assertFalse();
      expect(visibleSceneCount).assertEqual(0);
    });

    it('mapsExperienceFeaturesToGeneratedMedia', 0, () => {
      const missingIconFeatures = allExperienceFeatures
        .filter((item: FeatureItem) => iconMediaName(item.icon).length === 0)
        .map((item: FeatureItem) => item.id)
        .join(',');
      const featureIconNames = allExperienceFeatures
        .map((item: FeatureItem) => iconMediaName(item.icon));
      const duplicateIconNames = featureIconNames.filter((name: string, index: number) => {
        return featureIconNames.indexOf(name) !== index;
      });
      expect(missingIconFeatures).assertEqual('');
      expect(duplicateIconNames.join(',')).assertEqual('');
      expect(iconMediaName('people')).assertEqual('feature_posenet');
      expect(iconMediaName('image')).assertEqual('feature_segmentation');
      expect(iconMediaName('grid')).assertEqual('feature_classification');
      expect(iconMediaName('hand')).assertEqual('feature_gesture');
      expect(iconMediaName('dance')).assertEqual('feature_dance');
      expect(iconMediaName('poetry')).assertEqual('feature_poetry');
      expect(iconMediaName('text')).assertEqual('feature_text_extraction');
      expect(iconMediaName('translate')).assertEqual('feature_translation');
      expect(iconMediaName('scene')).assertEqual('feature_scene');
      expect(iconMediaName('photo')).assertEqual('feature_object_photo');
      expect(iconMediaName('camera')).assertEqual('feature_object_camera');
      expect(iconMediaName('style')).assertEqual('feature_style_transfer');
      expect(iconMediaName('model')).assertEqual('feature_custom_model');
    });

    it('definesCollegeAndMeRows', 0, () => {
      expect(collegeItems.length).assertEqual(6);
      expect(meItems.length).assertEqual(8);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].title).assertEqual('Version');
      expect(meItems.find((item: MeItem) => item.id === 'privacy')?.visibleByDefault).assertFalse();
      expect(meItems.find((item: MeItem) => item.id === 'qr')?.visibleByDefault).assertFalse();
      expect(meItems.find((item: MeItem) => item.id === 'star')?.title).assertEqual('Like');
      expect(meItems.find((item: MeItem) => item.id === 'code')?.title).assertEqual('Official Code');
      expect(meItems.find((item: MeItem) => item.id === 'feedback')?.title).assertEqual('Feedback');
    });

    it('definesHarmonyMeLayoutMinimums', 0, () => {
      expect(mePageInsetVp).assertEqual(16);
      expect(meTitleMinHeightVp).assertEqual(72);
      expect(meInfoCardMinHeightVp).assertEqual(88);
      expect(meInfoCardRadiusVp).assertEqual(16);
      expect(meLogoSizeVp).assertEqual(56);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].id).assertEqual('version');
      expect(isMeItemUrlNavigable(visibleMeItems[0])).assertFalse();
      expect(isMeItemPageNavigable(visibleMeItems[0])).assertFalse();
    });

    it('usesAndroidCollegeSummaryDialogTitleKey', 0, () => {
      expect(collegeSummaryDialogTitleKey).assertEqual('college_dialog_title');
      expect(hasAppStringKey(collegeSummaryDialogTitleKey)).assertTrue();
    });

    it('definesHarmonyCollegeLayoutMinimums', 0, () => {
      expect(collegePageInsetVp).assertEqual(16);
      expect(collegeHeaderMinHeightVp).assertEqual(112);
      expect(collegeEntryMinHeightVp).assertEqual(72);
      expect(collegeQuickActionMinHeightVp).assertEqual(64);
      expect(collegeCardRadiusVp).assertEqual(16);
      expect(collegeDialogConfirmMinHeightVp).assertEqual(44);
      expect(collegeAdapterViewTitleKey).assertEqual('college_adapter_view');
      expect(hasAppStringKey(collegeAdapterViewTitleKey)).assertTrue();
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

    it('consumesSplashBackPressLikeAndroidStartupActivity', 0, () => {
      expect(shouldConsumeIndexBackPress(false)).assertTrue();
      expect(shouldConsumeIndexBackPress(true)).assertFalse();
    });

    it('usesAndroidSplashLogoProportions', 0, () => {
      expect(splashLogoWidthVp).assertEqual(160);
      expect(splashLogoHeightVp).assertEqual(90);
    });

    it('usesCompactHarmonyExperienceHeaderAndStickyTitle', 0, () => {
      expect(experienceHeaderMinHeightVp).assertEqual(132);
      expect(experienceStickyTitleMinHeightVp).assertEqual(56);
      expect(experienceStickyTitleThresholdVp).assertEqual(76);
      expect(experienceStickyTitleVisible(75)).assertFalse();
      expect(experienceStickyTitleVisible(76)).assertTrue();
      expect(experienceStickyTitleVisible(132)).assertTrue();
    });

    it('usesHarmonyExperienceCardGeometry', 0, () => {
      expect(experienceGridColumnCount).assertEqual(2);
      expect(experienceGridCardMinHeightVp).assertEqual(72);
      expect(experienceGridRowGapVp).assertEqual(12);
      expect(experienceGridSideInsetVp).assertEqual(16);
      expect(experienceGridColumnGapVp).assertEqual(12);
      expect(experienceCardRadiusVp).assertEqual(16);
      expect(experienceCardBorderWidthVp).assertEqual(1);
      expect(experienceCardBorderColor).assertEqual('#E8EDF5');
      expect(experienceCardPressedScale).assertEqual(0.98);
      expect(experienceContentBottomPaddingVp).assertEqual(28);
      expect(experienceGridMinHeightVp(-1)).assertEqual(0);
      expect(experienceGridMinHeightVp(0)).assertEqual(0);
      expect(experienceGridMinHeightVp(1)).assertEqual(72);
      expect(experienceGridMinHeightVp(2)).assertEqual(72);
      expect(experienceGridMinHeightVp(3)).assertEqual(156);
      expect(experienceGridMinHeightVp(4)).assertEqual(156);
      expect(experienceGridMinHeightVp(5)).assertEqual(240);
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

    it('definesDefaultMainTabsInAndroidOrder', 0, () => {
      expect(mainTabs.length).assertEqual(2);
      expect(mainTabs[0].id).assertEqual(MainTab.EXPERIENCE);
      expect(mainTabs[1].id).assertEqual(MainTab.ME);
    });

    it('mapsSemanticIconTokensToCompactLabels', 0, () => {
      expect(iconLabel('people')).assertEqual('P');
      expect(iconLabel('rocket')).assertEqual('E');
      expect(iconLabel('translate')).assertEqual('Tr');
      expect(iconLabel('image').length <= 2).assertTrue();
    });

    it('assignsI18nKeysToVisibleShellData', 0, () => {
      expect(hasAppStringKey(mainTabs[0].titleKey)).assertTrue();
      expect(hasAppStringKey('experience_group_experience')).assertTrue();
      expect(hasAppStringKey('experience_group_advanced')).assertTrue();
      expect(hasAppStringKey(experienceSections[0].titleKey)).assertTrue();
      expect(hasAppStringKey(allExperienceFeatures[0].titleKey)).assertTrue();
      expect(hasAppStringKey(collegeItems[0].titleKey)).assertTrue();
      expect(hasAppStringKey(meItems[0].titleKey)).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_gesture_runner_unavailable')).assertTrue();
      expect(hasAppStringKey('feature_runtime_gesture_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_gesture_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_gesture_overlay')).assertTrue();
      expect(hasAppStringKey('gesture_label_one')).assertTrue();
      expect(hasAppStringKey('gesture_label_two')).assertTrue();
      expect(hasAppStringKey('gesture_label_three')).assertTrue();
      expect(hasAppStringKey('gesture_label_four')).assertTrue();
      expect(hasAppStringKey('gesture_label_five')).assertTrue();
      expect(hasAppStringKey('gesture_label_six')).assertTrue();
      expect(hasAppStringKey('gesture_label_seven')).assertTrue();
      expect(hasAppStringKey('gesture_label_eight')).assertTrue();
      expect(hasAppStringKey('gesture_label_nine')).assertTrue();
      expect(hasAppStringKey('gesture_label_dislike')).assertTrue();
      expect(hasAppStringKey('gesture_label_fist')).assertTrue();
      expect(hasAppStringKey('gesture_label_thumb_up')).assertTrue();
      expect(hasAppStringKey('gesture_label_heart')).assertTrue();
      expect(hasAppStringKey('gesture_label_ok')).assertTrue();
      expect(hasAppStringKey('gesture_label_other')).assertTrue();
      expect(hasAppStringKey('title_scene_detection')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_runner_unavailable')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_scene_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_scenes')).assertTrue();
      expect(hasAppStringKey('workflow_summary_scene')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_recognition_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_translation_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_translation_offline_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_text_translation_offline_unsupported')).assertTrue();
      expect(hasAppStringKey('feature_runtime_segmentation_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_preview_background')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_background')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_background_replacement')).assertTrue();
      expect(hasAppStringKey('feature_input_background_image')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_preview_title')).assertTrue();
      expect(hasAppStringKey('feature_runtime_switch_camera')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_count')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_detections')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_similarity')).assertTrue();
      expect(hasAppStringKey('feature_runtime_result_pose_template')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_text')).assertTrue();
      expect(hasAppStringKey('feature_runtime_copy_done')).assertTrue();
      expect(hasAppStringKey('feature_input_photo_android')).assertTrue();
      expect(hasAppStringKey('feature_input_camera_android')).assertTrue();
      expect(hasAppStringKey('feature_runtime_model_cache_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_model_incompatible')).assertTrue();
      expect(hasAppStringKey('feature_runtime_image_invalid')).assertTrue();
      expect(hasAppStringKey('feature_runtime_classification_runner_unavailable')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_missing')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_recovery')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_recovered')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_album')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_take_photo')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_select_predict_model')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_select_transfer_model')).assertTrue();
      expect(hasAppStringKey('feature_runtime_go_live_android_hms')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_image_classification')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_object_photo')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_object_camera')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_pose_net')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_image_segmentation')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_scene_detection')).assertTrue();
      expect(hasAppStringKey('feature_runtime_help_style_transfer')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_help')).assertTrue();
      expect(hasAppStringKey('workflow_summary_gesture_still_android_prompt')).assertTrue();
      expect(hasAppStringKey('workflow_summary_scene_still_android_prompt')).assertTrue();
      expect(hasAppStringKey('workflow_summary_text_recognition_android_prompt')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_model_required')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_image_required')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_select_model')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_select_photo')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_take_photo')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_output_title')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_output_placeholder')).assertTrue();
      expect(hasAppStringKey('qr_code_save_done')).assertTrue();
      expect(hasAppStringKey('qr_code_save_failed')).assertTrue();
      expect(hasAppStringKey('app_cancel')).assertTrue();
      expect(hasAppStringKey('title_share')).assertTrue();
      expect(hasAppStringKey('title_share_commend')).assertTrue();
      expect(hasAppStringKey('me_share_done')).assertTrue();
      expect(hasAppStringKey('me_share_failed')).assertTrue();
      expect(hasAppStringKey('permission_camera_reason')).assertTrue();
      expect(hasAppStringKey('permission_media_reason')).assertTrue();
      expect(hasAppStringKey('permission_save_image_reason')).assertTrue();
    });

    it('groupsExperienceCatalogLikeAndroidVisionFragment', 0, () => {
      expect(visibleExperienceSections[0].id).assertEqual('experience-vision');
      expect(visibleExperienceSections[0].groupTitleKey).assertEqual('experience_group_experience');
      expect(visibleExperienceSections[1].id).assertEqual('experience-speech');
      expect(visibleExperienceSections[1].groupTitleKey).assertUndefined();
      expect(visibleExperienceSections[2].id).assertEqual('advanced-vision');
      expect(visibleExperienceSections[2].groupTitleKey).assertEqual('experience_group_advanced');
    });

    it('opensPortraitSegmentationWithBackgroundCapableRoute', 0, () => {
      const portraitFeature = visibleExperienceSections[0].items.find((item: FeatureItem) => {
        return item.id === 'segmentation';
      });
      expect(portraitFeature?.routeName).assertEqual(AppRoute.PORTRAIT_SEGMENTATION.name);
    });

    it('keepsSceneDetectionEntryRouteReadyButHiddenByDefault', 0, () => {
      const sceneFeature = findFeatureByRoute(AppRoute.SCENE_STILL.name);
      expect(sceneFeature?.id).assertEqual('scene');
      expect(sceneFeature?.titleKey).assertEqual('title_scene_detection');
      expect(sceneFeature?.routeName).assertEqual(AppRoute.SCENE_STILL.name);
      expect(sceneFeature?.visibleByDefault).assertFalse();

      const advancedVisionSection = visibleExperienceSections.find((section: FeatureSection) => {
        return section.id === 'advanced-vision';
      });
      const visibleSceneFeature = advancedVisionSection?.items.find((item: FeatureItem) => {
        return item.id === 'scene';
      });
      expect(visibleSceneFeature).assertUndefined();
    });

    it('usesAndroidNoticeDialogTreatmentForCollegeSummary', 0, () => {
      const dialog: CollegeSummaryDialogSpec = androidCollegeSummaryDialogSpec();

      expect(dialog.titleKey).assertEqual(collegeSummaryDialogTitleKey);
      expect(dialog.contentKey).assertEqual('college_dialog_content');
      expect(dialog.confirmKey).assertEqual('dialog_btn_confirm');
      expect(hasAppStringKey('dialog_btn_confirm')).assertTrue();
      expect(dialog.contentAlignment).assertEqual('start');
      expect(dialog.showBottomLogo).assertTrue();
      expect(dialog.logoMedia).assertEqual(collegeSummaryDialogLogoMedia);
      expect(dialog.logoMedia).assertEqual('app.media.logo_with_title');
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
      expect(result.messageKey).assertEqual('image_save_success');
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
      expect(rejectedRead.messageKey).assertEqual('image_save_failed');
      expect(rejectedWrite.messageKey).assertEqual('image_save_failed');
      expect(emptyUri.messageKey).assertEqual('image_save_failed');
    });

    it('qrCodeWriteCompletesOnlyWhenAllBytesAreWritten', 0, () => {
      const bytes = new Uint8Array([1, 2, 3]).buffer as ArrayBuffer;

      expect(isFullQrCodeWrite(bytes, 3)).assertTrue();
      expect(isFullQrCodeWrite(bytes, 2)).assertFalse();
      expect(isFullQrCodeWrite(bytes, 4)).assertFalse();
    });

    it('qrCodeSaveSheetMatchesAndroidMoreSaveCancelFlow', 0, () => {
      expect(qrCodeSaveSheetVisibleAfterAction(false, 'open')).assertTrue();
      expect(qrCodeSaveSheetVisibleAfterAction(true, 'cancel')).assertFalse();
      expect(qrCodeSaveSheetVisibleAfterAction(true, 'saveSuccess')).assertFalse();
      expect(qrCodeSaveSheetVisibleAfterAction(true, 'saveFailed')).assertTrue();
      expect(qrCodeSaveSheetVisibleAfterAction(false, 'saveFailed')).assertFalse();
      expect(qrCodeSaveSheetVisibleAfterAction(true, 'backdrop')).assertFalse();
      expect(qrCodeSaveSheetVisibleAfterAction(true, 'back')).assertFalse();
    });

    it('qrCodeMapsNativeSheetDismissReasonsToExistingReducerActions', 0, () => {
      expect(qrCodeSheetActionForNativeDismiss(true)).assertEqual('back');
      expect(qrCodeSheetActionForNativeDismiss(false)).assertEqual('backdrop');
    });

    it('qrCodeSaveStartsOnlyWhenNoSaveIsAlreadyInFlight', 0, () => {
      expect(shouldStartQrCodeSave(false)).assertTrue();
      expect(shouldStartQrCodeSave(true)).assertFalse();
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

    it('shareServiceSkipsAndroidApkDownloadUrl', 0, async () => {
      const writer = new RecordingShareWriter();
      const shareText = mindSporeInhandShareText('MindSpore inhand:');
      const result = await new ShareService(writer).shareText({
        title: 'Share',
        text: shareText
      });

      expect(shareText.indexOf('download.mindspore.cn')).assertEqual(-1);
      expect(shareText.indexOf('/apk/')).assertEqual(-1);
      expect(shareText).assertEqual(`MindSpore inhand: ${mindSporeBaseUrl}`);
      expect(mindSporeInhandShareText('')).assertEqual(mindSporeBaseUrl);
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
        title: 'Intelligent poetry',
        uri: 'file://media/poemshare.jpg',
        description: 'MindSpore AI'
      };
      const result = await new ShareService(new RecordingShareWriter(), writer).shareImage(payload);

      expect(result.ok).assertTrue();
      expect(result.messageKey).assertEqual('empty');
      expect(result.sharedUri).assertEqual('file://media/poemshare.jpg');
      expect(writer.payloads[0].title).assertEqual('Intelligent poetry');
      expect(writer.payloads[0].uri).assertEqual('file://media/poemshare.jpg');
    });

    it('poetryPosterSharePayloadUsesLocalizedCopyFromCaller', 0, () => {
      const localizedPayload = poetryPosterImageSharePayload(
        'file://media/poemshare.jpg',
        '智能写诗',
        '由 MindSpore AI 技术生成'
      );

      expect(localizedPayload.title).assertEqual('智能写诗');
      expect(localizedPayload.description).assertEqual('由 MindSpore AI 技术生成');
      expect(localizedPayload.uri).assertEqual('file://media/poemshare.jpg');
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
      expect(collegeDestination.titleKey).assertEqual('title_college_one_hour');
      expect(collegeDestination.url).assertEqual(collegeMainCloudUrl);
    });

    it('webPageOnlyTreatsMainDocumentErrorsAsPageFailure', 0, () => {
      expect(webPageFailedAfterRequest(false, false)).assertFalse();
      expect(webPageFailedAfterRequest(false, true)).assertTrue();
      expect(webPageFailedAfterRequest(true, false)).assertTrue();
    });

    it('mapsAndroidWebViewToolbarTitlesForCollegeAndMeUrls', 0, () => {
      expect(webDestinationForUrl(collegeMainFaqUrl, 'me_official_title').titleKey).assertEqual('title_college_faq');
      expect(webDestinationForUrl(collegeMainAskUrl, 'me_official_title').titleKey).assertEqual('title_college_forum');
      expect(webDestinationForUrl(collegeQuickTrainUrl, 'me_official_title').titleKey).assertEqual('title_college_training');
      expect(webDestinationForUrl(collegeQuickExecuteUrl, 'me_official_title').titleKey).assertEqual('title_college_perform');
      expect(webDestinationForUrl(collegeQuickAppUrl, 'me_official_title').titleKey).assertEqual('title_college_broken_side');
      expect(webDestinationForUrl(collegeQuickVideoUrl, 'me_official_title').titleKey).assertEqual('title_college_video');
      expect(webDestinationForUrl(meStarUrl, 'me_official_title').titleKey).assertEqual('me_up_title');
      expect(webDestinationForUrl(mindSporeBaseUrl, 'me_qa_title').titleKey).assertEqual('me_official_title');
      expect(webDestinationForUrl(meCodeUrl, 'me_official_title').titleKey).assertEqual('me_official_code_title');
      expect(webDestinationForUrl(meHelpUrl, 'me_official_title').titleKey).assertEqual('me_qa_title');
      expect(webDestinationForUrl(helpImageClassificationUrl, 'me_official_title').titleKey).assertEqual('title_image');
      expect(webDestinationForUrl(helpObjectDetectionUrl, 'me_official_title').titleKey).assertEqual('title_object');
      expect(webDestinationForUrl(helpPoseNetUrl, 'me_official_title').titleKey).assertEqual('title_pose_net');
      expect(webDestinationForUrl(helpImageSegmentationUrl, 'me_official_title').titleKey).assertEqual('title_segmentation');
      expect(webDestinationForUrl(helpSceneDetectionUrl, 'me_official_title').titleKey).assertEqual('title_scene_detection');
      expect(webDestinationForUrl(helpStyleTransferUrl, 'me_official_title').titleKey).assertEqual('title_style_transfer');
      expect(customModelMoreUrl.indexOf('mindspore.cn/lite/docs/zh-CN/master/infer/device_infer_example.html') >= 0)
        .assertTrue();
      expect(webDestinationForUrl(customModelMoreUrl, 'me_official_title').titleKey).assertEqual('title_custom_model');
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
      expect(hasAppStringKey('poem_share_failed')).assertTrue();
      expect(hasAppStringKey('poem_ai_credit')).assertTrue();
      expect(hasAppStringKey('poem_save_in_progress')).assertTrue();
      expect(hasAppStringKey('poem_share_in_progress')).assertTrue();
    });

    it('poetryPosterStartsOnlyOneSaveOrShareAction', 0, () => {
      expect(shouldStartPoetryPosterAction(false)).assertTrue();
      expect(shouldStartPoetryPosterAction(true)).assertFalse();
    });

    it('portsAndroidPoetryPosterVisualAssetsAndLayoutSpec', 0, () => {
      expect(poetryPosterVisualSpec.backgroundMediaName).assertEqual('poem_bg');
      expect(poetryPosterVisualSpec.frameMediaName).assertEqual('poem_frame');
      expect(poetryPosterVisualSpec.logoMediaName).assertEqual('poem_logo2');
      expect(poetryPosterVisualSpec.outerPaddingVp).assertEqual(20);
      expect(poetryPosterVisualSpec.poemTopMarginVp).assertEqual(20);
      expect(poetryPosterVisualSpec.poemTextPaddingVp).assertEqual(20);
      expect(poetryPosterVisualSpec.posterMinHeightVp).assertEqual(520);
      expect(poetryPosterVisualSpec.posterMaxWidthVp).assertEqual(420);
      expect(poetryPosterVisualSpec.poemTextFontSizeFp).assertEqual(15);
      expect(poetryPosterVisualSpec.poemTextMaxFontScale > 1).assertTrue();
      expect(poetryPosterVisualSpec.poemTextMaxFontScale <= 2).assertTrue();
      expect(poetryPosterVisualSpec.logoWidthVp).assertEqual(76);
      expect(poetryPosterVisualSpec.logoHeightVp).assertEqual(57);
      expect(poetryPosterVisualSpec.qrCodeSizeVp).assertEqual(80);
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
      expect(pageState.scoreLabelKey).assertEqual(danceResultScoreLabelKey(danceScoreFromFrames(frames)));
      expect(pageState.scoreText).assertEqual(danceScoreText(danceScoreFromFrames(frames)));
      expect(pageState.resultMessageKey).assertEqual(danceResultMessageKey(danceScoreFromFrames(frames)));
      expect(pageState.summaryText).assertEqual(`${frames.length}/70`);
    });

    it('stopsDanceLiveCameraPreviewWhenSamplingShowsResultPage', 0, () => {
      const frames = danceTemplateFrames();

      expect(danceSamplingResultStopsLiveCameraPreview({
        frameCount: 70,
        validFrameCount: frames.length,
        failedFrameCount: 0,
        cancelled: false,
        frames: frames,
        score: danceScoreFromFrames(frames)
      })).assertTrue();
      expect(danceSamplingResultStopsLiveCameraPreview({
        frameCount: 70,
        validFrameCount: 0,
        failedFrameCount: 0,
        cancelled: false,
        frames: [],
        score: danceNoPointScore
      })).assertTrue();
      expect(danceSamplingResultStopsLiveCameraPreview({
        frameCount: 2,
        validFrameCount: 0,
        failedFrameCount: 2,
        cancelled: false,
        frames: [],
        score: danceNoPointScore
      })).assertFalse();
      expect(danceSamplingResultStopsLiveCameraPreview({
        frameCount: 70,
        validFrameCount: 1,
        failedFrameCount: 0,
        cancelled: true,
        frames: frames,
        score: danceScoreFromFrames(frames)
      })).assertFalse();
    });

    it('danceKeepScreenOnServiceTogglesMainWindowLikeAndroid', 0, async () => {
      const mainWindow = new RecordingDanceKeepScreenOnWindow();
      const service = new DanceKeepScreenOnService(
        new FixedDanceKeepScreenOnWindowProvider(mainWindow)
      );

      expect(await service.setKeepScreenOn(true)).assertTrue();
      expect(await service.setKeepScreenOn(false)).assertTrue();

      expect(mainWindow.seenValues.join(',')).assertEqual('true,false');
    });

    it('danceKeepScreenOnServiceFailsSafelyWithoutWindow', 0, async () => {
      const missingWindowResult = await new DanceKeepScreenOnService(
        new FixedDanceKeepScreenOnWindowProvider()
      ).setKeepScreenOn(true);
      const rejectingWindowResult = await new DanceKeepScreenOnService(
        new FixedDanceKeepScreenOnWindowProvider(new RejectingDanceKeepScreenOnWindow())
      ).setKeepScreenOn(true);

      expect(missingWindowResult).assertFalse();
      expect(rejectingWindowResult).assertFalse();
    });

    it('danceKeepScreenOnServiceSerializesRapidLifecycleUpdates', 0, async () => {
      const mainWindow = new DelayedEnableDanceKeepScreenOnWindow();
      const provider = new FixedDanceKeepScreenOnWindowProvider(mainWindow);

      const enableResult = new DanceKeepScreenOnService(provider).setKeepScreenOn(true);
      await Promise.resolve();
      await Promise.resolve();
      const disableResult = new DanceKeepScreenOnService(provider).setKeepScreenOn(false);
      await Promise.resolve();
      await Promise.resolve();
      mainWindow.releaseEnable();

      expect(await enableResult).assertTrue();
      expect(await disableResult).assertTrue();
      expect(mainWindow.completedValues.join(',')).assertEqual('true,false');
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
      expect(dancePrepareBackgroundMediaName).assertEqual('app.media.dance_prepare_bk');
      expect(danceRunBackgroundMediaName).assertEqual('app.media.dance_run_bk');
      expect(danceResultBackgroundMediaName).assertEqual('app.media.dance_result_bk');
      expect(danceResultSaveMediaName).assertEqual('app.media.dance_result_save');
      expect(danceResultPlayAgainMediaName).assertEqual('app.media.dance_result_play_again');
      expect(danceResultBackMediaName).assertEqual('app.media.dance_result_back');
      expect(danceResultBackgroundWidthPx).assertEqual(1920);
      expect(danceResultBackgroundHeightPx).assertEqual(1080);
      expect(danceResultBackgroundAspectRatio()).assertEqual(16 / 9);
      expect(danceResultActionButtonWidthPx).assertEqual(492);
      expect(danceResultActionButtonHeightPx).assertEqual(145);
      expect(danceResultBackButtonWidthPx).assertEqual(140);
      expect(danceResultBackButtonHeightPx).assertEqual(140);
      expect(danceResultPlayAgainLabelKey).assertEqual('dance_reset');
      expect(hasAppStringKey('dance_prepare_summary')).assertTrue();
      expect(hasAppStringKey('dance_reference_video')).assertTrue();
      expect(hasAppStringKey('dance_countdown')).assertTrue();
      expect(hasAppStringKey('dance_reference_video_downloading')).assertTrue();
      expect(hasAppStringKey('dance_reference_video_ready')).assertTrue();
      expect(hasAppStringKey('dance_reference_video_failed')).assertTrue();
      expect(hasAppStringKey('dance_start_demo')).assertTrue();
      expect(hasAppStringKey('dance_result_title')).assertTrue();
      expect(hasAppStringKey('dance_platform_note')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image')).assertTrue();
      expect(danceSaveStatusKey(true)).assertEqual('image_save_success');
      expect(danceSaveStatusKey(false)).assertEqual('image_save_failed');
      expect(hasAppStringKey('image_save_success')).assertTrue();
      expect(hasAppStringKey('image_save_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_missing')).assertTrue();
    });

    it('reusesCachedDanceReferenceVideoWhenAndroidLengthMatches', 0, async () => {
      const cacheDir = '/cache/';
      const expectedPath = '/cache/danceVideo2.mp4';
      const fileStore = new MemoryDanceReferenceVideoFileStore();
      fileStore.setFileSize(expectedPath, danceReferenceVideoLengthBytes);
      const downloader = new RecordingDanceReferenceVideoDownloader(fileStore, danceReferenceVideoLengthBytes);

      const result = await new DanceReferenceVideoCacheService(fileStore, downloader).prepare(cacheDir);

      expect(danceReferenceVideoCacheFileName).assertEqual('danceVideo2.mp4');
      expect(danceReferenceVideoCachePath(cacheDir)).assertEqual(expectedPath);
      expect(isCompleteDanceReferenceVideo(danceReferenceVideoLengthBytes)).assertTrue();
      expect(isCompleteDanceReferenceVideo(danceReferenceVideoLengthBytes - 1)).assertFalse();
      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('file:///cache/danceVideo2.mp4');
      expect(result.messageKey).assertEqual('dance_reference_video_ready');
      expect(result.downloaded).assertFalse();
      expect(downloader.seenUrls.length).assertEqual(0);
    });

    it('downloadsDanceReferenceVideoWhenCacheIsMissing', 0, async () => {
      const fileStore = new MemoryDanceReferenceVideoFileStore();
      const downloader = new RecordingDanceReferenceVideoDownloader(fileStore, danceReferenceVideoLengthBytes);

      const result = await new DanceReferenceVideoCacheService(fileStore, downloader).prepare('/cache');

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('file:///cache/danceVideo2.mp4');
      expect(result.downloaded).assertTrue();
      expect(downloader.seenUrls.join(',')).assertEqual(danceReferenceVideoUrl);
      expect(downloader.seenDestinationPaths[0].startsWith('/cache/danceVideo2.mp4.download.')).assertTrue();
      expect(fileStore.replacedPaths.join(',')).assertEqual(`${downloader.seenDestinationPaths[0]}->/cache/danceVideo2.mp4`);
    });

    it('reportsDanceReferenceVideoPrepareProgress', 0, async () => {
      const fileStore = new MemoryDanceReferenceVideoFileStore();
      const downloader = new RecordingDanceReferenceVideoDownloader(
        fileStore,
        danceReferenceVideoLengthBytes,
        [
          { receivedBytes: 1024, totalBytes: 4096 },
          { receivedBytes: 2048, totalBytes: 4096 }
        ]
      );
      const progressEvents: Array<DanceReferenceVideoProgress> = [];

      await new DanceReferenceVideoCacheService(fileStore, downloader).prepare(
        '/cache',
        undefined,
        (progress: DanceReferenceVideoProgress) => {
          progressEvents.push(progress);
        }
      );

      expect(progressEvents.length).assertEqual(2);
      expect(danceReferenceVideoProgressPercent(progressEvents[0])).assertEqual(25);
      expect(danceReferenceVideoProgressPercent(progressEvents[1])).assertEqual(50);
    });

    it('rejectsIncompleteDanceReferenceVideoDownload', 0, async () => {
      const fileStore = new MemoryDanceReferenceVideoFileStore();
      const downloader = new RecordingDanceReferenceVideoDownloader(fileStore, danceReferenceVideoLengthBytes - 1);

      const result = await new DanceReferenceVideoCacheService(fileStore, downloader).prepare('/cache');

      expect(result.ok).assertFalse();
      expect(result.uri).assertEqual('');
      expect(result.messageKey).assertEqual('dance_reference_video_failed');
      expect(result.downloaded).assertFalse();
      expect(fileStore.removedPaths.join(',')).assertEqual(downloader.seenDestinationPaths[0]);
      expect(downloader.seenDestinationPaths[0].startsWith('/cache/danceVideo2.mp4.download.')).assertTrue();
    });

    it('formatsDanceReferenceVideoDownloadProgressPercent', 0, () => {
      expect(danceReferenceVideoProgressPercent({ receivedBytes: 0, totalBytes: 200 })).assertEqual(0);
      expect(danceReferenceVideoProgressPercent({ receivedBytes: 50, totalBytes: 200 })).assertEqual(25);
      expect(danceReferenceVideoProgressPercent({ receivedBytes: 100, totalBytes: 200 })).assertEqual(50);
      expect(danceReferenceVideoProgressPercent({ receivedBytes: 250, totalBytes: 200 })).assertEqual(100);
      expect(danceReferenceVideoProgressPercent({ receivedBytes: -10, totalBytes: 200 })).assertEqual(0);
      expect(danceReferenceVideoProgressPercent({ receivedBytes: 10, totalBytes: 0 })).assertEqual(0);
      expect(danceReferenceVideoProgressText(25)).assertEqual('25%');
      expect(danceReferenceVideoProgressText(100)).assertEqual('100%');
    });

    it('forwardsDanceReferenceVideoDownloadProgressEvents', 0, async () => {
      const task = new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusRunning);
      const progressEvents: Array<DanceReferenceVideoProgress> = [];
      const promise = waitForDanceReferenceVideoDownload(task, (progress: DanceReferenceVideoProgress) => {
        progressEvents.push(progress);
      });

      task.emitProgress(50, 200);
      task.emitProgress(100, 200);
      task.emitComplete();
      await promise;

      expect(progressEvents.length).assertEqual(2);
      expect(progressEvents[0].receivedBytes).assertEqual(50);
      expect(progressEvents[0].totalBytes).assertEqual(200);
      expect(progressEvents[1].receivedBytes).assertEqual(100);
      expect(progressEvents[1].totalBytes).assertEqual(200);
    });

    it('removesDanceReferenceVideoDownloadListenersWithTheirRegisteredCallbacks', 0, async () => {
      const task = new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusRunning);
      const promise = waitForDanceReferenceVideoDownload(task);

      task.emitComplete();
      await promise;

      expect(task.onEvents.join(',')).assertEqual('progress,complete,pause,remove,fail');
      expect(task.offEvents.join(',')).assertEqual('progress,complete,pause,remove,fail');
      expect(task.offCallbacks.length).assertEqual(task.onCallbacks.length);
      for (let index = 0; index < task.onCallbacks.length; index++) {
        expect(task.offCallbacks[index] === task.onCallbacks[index]).assertTrue();
      }
    });

    it('settlesDanceReferenceVideoDownloadWhenTaskAlreadyEnded', 0, async () => {
      await waitForDanceReferenceVideoDownload(
        new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusSuccessful)
      );

      const rejectedPausedTask = await danceReferenceVideoPromiseRejected(
        waitForDanceReferenceVideoDownload(
          new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusPaused)
        )
      );

      expect(rejectedPausedTask).assertTrue();
    });

    it('rejectsDanceReferenceVideoDownloadWhenTaskInfoCannotBeRead', 0, async () => {
      const rejectedTask = await danceReferenceVideoPromiseRejected(
        waitForDanceReferenceVideoDownload(
          new ManualDanceReferenceVideoDownloadTask(
            danceReferenceVideoDownloadStatusRunning,
            0,
            true,
            true
          )
        )
      );

      expect(rejectedTask).assertTrue();
    });

    it('rejectsDanceReferenceVideoDownloadOnPauseOrRemoveEvents', 0, async () => {
      const pausedTask = new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusRunning);
      const pausedPromise = waitForDanceReferenceVideoDownload(pausedTask);
      pausedTask.emitPause();
      const pauseRejected = await danceReferenceVideoPromiseRejected(pausedPromise);

      const removedTask = new ManualDanceReferenceVideoDownloadTask(danceReferenceVideoDownloadStatusRunning);
      const removedPromise = waitForDanceReferenceVideoDownload(removedTask);
      removedTask.emitRemove();
      const removeRejected = await danceReferenceVideoPromiseRejected(removedPromise);

      expect(pauseRejected).assertTrue();
      expect(removeRejected).assertTrue();
    });

    it('startsDanceOnlyAfterReferenceVideoCacheAndPlayerAreReady', 0, () => {
      expect(danceReferenceVideoCanStartLive({
        cached: true,
        playerPrepared: false,
        preparing: false,
        failed: false
      })).assertFalse();
      expect(danceReferenceVideoCanStartLive({
        cached: false,
        playerPrepared: true,
        preparing: false,
        failed: false
      })).assertFalse();
      expect(danceReferenceVideoCanStartLive({
        cached: true,
        playerPrepared: true,
        preparing: false,
        failed: false
      })).assertTrue();
    });

    it('keepsPreparedDanceReferenceVideoWhenResetReusesSameCachedSource', 0, () => {
      expect(danceReferenceVideoPlayerPreparedAfterCacheResult(
        true,
        'file:///cache/danceVideo2.mp4',
        'file:///cache/danceVideo2.mp4',
        true
      )).assertTrue();
      expect(danceReferenceVideoPlayerPreparedAfterCacheResult(
        true,
        'file:///cache/danceVideo2.mp4',
        'file:///cache/other.mp4',
        true
      )).assertFalse();
      expect(danceReferenceVideoPlayerPreparedAfterCacheResult(
        false,
        'file:///cache/danceVideo2.mp4',
        'file:///cache/danceVideo2.mp4',
        true
      )).assertFalse();
    });

    it('mapsDanceScoresToAndroidResultStates', 0, () => {
      expect(danceTemplateDemoScore()).assertEqual(98);
      expect(danceResultScoreLabelKey(98)).assertEqual('dance_score_prefix');
      expect(danceResultScoreLabelKey(danceNoActScore)).assertEqual('dance_score_level_no_action');
      expect(danceResultScoreLabelKey(danceNoPointScore)).assertEqual('dance_score_level_no_point');
      expect(danceScoreText(98)).assertEqual('98');
      expect(danceScoreText(danceNoActScore)).assertEqual('');
      expect(danceScoreText(danceNoPointScore)).assertEqual('');
      expect(danceResultMessageKey(danceNoActScore)).assertEqual('empty');
      expect(danceResultMessageKey(danceNoPointScore)).assertEqual('empty');
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
      expect(translation.inputKinds.length).assertEqual(3);
      expect(translation.inputKinds[0]).assertEqual('text');
      expect(translation.inputKinds[1]).assertEqual('camera');
      expect(translation.inputKinds[2]).assertEqual('photo');
      expect(translation.liveMode).assertFalse();
      expect(runtimeInputActionForWorkflowInput(translation, 'camera')).assertEqual('captureImage');
      expect(runtimeInputActionsForWorkflow(translation).join(',')).assertEqual('enterText,captureImage,pickImage');
      expect(liveRuntimeModeForWorkflow(translation)).assertFalse();
      expect(shouldRenderLiveCameraPreview(translation, false)).assertFalse();
      expect(shouldRenderLiveCameraPreview(translation, true)).assertTrue();
      expect(isInputPreparationRequestCurrent(7, 7)).assertTrue();
      expect(isInputPreparationRequestCurrent(6, 7)).assertFalse();
      expect(hasAppStringKey('feature_input_live_translation')).assertTrue();
      expect(translation.requiredPermissions.indexOf('internet')).assertEqual(-1);

      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      expect(portraitSegmentation.aiMethod).assertEqual('segmentPerson');
      expect(portraitSegmentation.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(portraitSegmentation.inputKinds.indexOf('photo')).assertEqual(-1);
      expect((portraitSegmentation.optionalInputKinds ?? []).indexOf('backgroundImage') >= 0).assertTrue();
      expect(portraitSegmentation.requiredPermissions.indexOf('camera') >= 0).assertTrue();
      expect(portraitSegmentation.requiredPermissions.indexOf('media')).assertEqual(-1);
      expect(portraitSegmentation.liveMode).assertTrue();
      expect(liveRuntimeModeForWorkflow(portraitSegmentation)).assertTrue();
      expect(shouldRenderLiveCameraPreview(portraitSegmentation, false)).assertTrue();
    });

    it('matchesAndroidStyleTransferInputSurfaceWithoutDuplicateStyleChip', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const runtimeInputKinds: Array<FeatureInputKind> = runtimeInputKindsForWorkflow(styleTransfer);
      const visibleInputKinds: Array<FeatureInputKind> = visibleInputKindsForWorkflow(styleTransfer);

      expect(JSON.stringify(styleTransfer.inputKinds))
        .assertEqual(JSON.stringify(['contentImage', 'camera', 'styleImage']));
      expect(JSON.stringify(runtimeInputKinds)).assertEqual(JSON.stringify([
        'contentImage', 'camera', 'styleImage', 'stylePredictModelFile', 'styleTransferModelFile'
      ]));
      expect(JSON.stringify(visibleInputKinds)).assertEqual(JSON.stringify([
        'contentImage', 'camera', 'stylePredictModelFile', 'styleTransferModelFile'
      ]));
      expect(runtimeInputKinds.includes('styleImage')).assertTrue();
      expect(visibleInputKinds.includes('styleImage')).assertFalse();
    });

    it('usesAndroidStillImagePromptSummariesWhereAndroidLayoutsShowPrompts', 0, () => {
      const gestureStill: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;
      const sceneStill: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_STILL.name)!;
      const sceneLive: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_LIVE.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const poseNet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;

      expect(gestureStill.summaryKey).assertEqual('workflow_summary_gesture_still_android_prompt');
      expect(sceneStill.summaryKey).assertEqual('workflow_summary_scene_still_android_prompt');
      expect(textRecognition.summaryKey).assertEqual('workflow_summary_text_recognition_android_prompt');
      expect(gestureLive.summaryKey).assertEqual('workflow_summary_gesture');
      expect(sceneLive.summaryKey).assertEqual('workflow_summary_scene');
      expect(poseNet.summaryKey).assertEqual('workflow_summary_pose');
      expect(segmentationStill.summaryKey).assertEqual('workflow_summary_segmentation');
    });

    it('usesAndroidSpecificPrimaryActionCopyForTextTranslation', 0, () => {
      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      expect(workflowRunActionKey(translation)).assertEqual('feature_runtime_run_translation');
      expect(hasAppStringKey(workflowRunActionKey(translation))).assertTrue();
      expect(workflowRunActionKey(styleTransfer)).assertEqual('feature_runtime_run');
    });

    it('preservesTranslationInputsAndLastValidResultDuringRunAndFailure', 0, () => {
      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

      expect(shouldClearRuntimeResultAtWorkflowStart(translation)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(translation, false)).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(translation, true)).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(translation, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(translation, 'camera')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(translation, 'text')).assertFalse();
      expect(shouldAllowRuntimeInputChange(translation, 'text', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(translation, 'photo', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(translation, 'camera', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(translation, 'text', false)).assertTrue();
      expect(shouldAllowRuntimeInputChange(translation, 'photo', false)).assertTrue();
      expect(shouldAllowRuntimeInputChange(translation, 'camera', false)).assertTrue();
    });

    it('labelsTranslationFailuresAsRetryWithoutChangingStableLabels', 0, () => {
      const runKey = 'feature_runtime_run_translation';
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_text_translation_failed', runKey)).assertEqual('web_retry');
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_text_recognition_failed', runKey)).assertEqual('web_retry');
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_run_failed', runKey)).assertEqual('web_retry');
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_text_translation_offline_unsupported', runKey)).assertEqual('web_retry');
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_status_idle', runKey)).assertEqual(runKey);
      expect(textTranslationRunActionLabelKey(
        'feature_runtime_copy_done', runKey)).assertEqual(runKey);
    });

    it('usesAndroidObjectDetectionActivityTitlesOnRuntimePages', 0, () => {
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      const imageCamera: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;

      expect(workflowRuntimeTitleKey(objectPhoto, 'title_object')).assertEqual('title_object_photo_detection');
      expect(workflowRuntimeTitleKey(objectCamera, 'title_object_camera')).assertEqual('title_object_camera_detection');
      expect(workflowRuntimeTitleKey(imageCamera, 'title_image')).assertEqual('title_image');
      expect(hasAppStringKey(workflowRuntimeTitleKey(objectPhoto, 'title_object'))).assertTrue();
      expect(hasAppStringKey(workflowRuntimeTitleKey(objectCamera, 'title_object_camera'))).assertTrue();
    });

    it('usesAndroidStyleTransferInitialChooseImagePrompt', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

      expect(workflowInitialStatusKey(styleTransfer)).assertEqual('feature_runtime_style_choose_image');
      expect(hasAppStringKey(workflowInitialStatusKey(styleTransfer))).assertTrue();
      expect(workflowInitialStatusKey(customModel)).assertEqual('feature_runtime_custom_model_output_placeholder');
    });

    it('usesAndroidLongTextPresentationForTextWorkflows', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

      expect(shouldUseLongTextInput(textTranslation)).assertTrue();
      expect(shouldUseLongTextInput(textRecognition)).assertFalse();
      expect(shouldUseLongTextInput(styleTransfer)).assertFalse();
      expect(shouldUseLongTextResultRow(textRecognition.aiMethod, 'feature_runtime_result_text')).assertTrue();
      expect(shouldUseLongTextResultRow(textTranslation.aiMethod, 'feature_runtime_result_text')).assertTrue();
      expect(shouldUseLongTextResultRow(textTranslation.aiMethod, 'feature_runtime_result_translated_text')).assertTrue();
      expect(shouldUseLongTextResultRow(textTranslation.aiMethod, 'feature_runtime_result_target_language')).assertFalse();
      expect(shouldUseLongTextResultRow(styleTransfer.aiMethod, 'feature_runtime_result_output')).assertFalse();
      expect(shouldUseLongTextResultRow(customModel.aiMethod, 'feature_runtime_result_output')).assertTrue();
    });

    it('showsDirectResultSaveOnlyForAndroidStillImageResultRoutes', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const segmentationLive: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!;
      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      const classification: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;

      expect(shouldShowResultSaveAction(styleTransfer, false)).assertTrue();
      expect(shouldShowResultSaveAction(styleTransfer, true)).assertTrue();
      expect(shouldShowResultSaveAction(segmentationStill, false)).assertFalse();
      expect(shouldShowResultSaveAction(segmentationStill, true)).assertTrue();
      expect(shouldShowResultSaveAction(portraitSegmentation, false)).assertFalse();
      expect(shouldShowResultSaveAction(portraitSegmentation, true)).assertFalse();
      expect(shouldShowResultSaveAction(segmentationLive, false)).assertFalse();
      expect(shouldShowResultSaveAction(segmentationLive, true)).assertFalse();
      expect(shouldShowResultSaveAction(textRecognition, false)).assertFalse();
      expect(shouldShowResultSaveAction(textRecognition, true)).assertFalse();
      expect(shouldShowResultSaveAction(textTranslation, false)).assertFalse();
      expect(shouldShowResultSaveAction(textTranslation, true)).assertFalse();
      expect(shouldShowResultSaveAction(objectPhoto, false)).assertFalse();
      expect(shouldShowResultSaveAction(objectPhoto, true)).assertFalse();
      expect(shouldShowResultSaveAction(classification, false)).assertFalse();
      expect(shouldShowResultSaveAction(classification, true)).assertFalse();
      expect(shouldShowResultSaveAction(undefined, false)).assertFalse();
      expect(shouldShowResultSaveAction(undefined, true)).assertFalse();
    });

    it('keepsAndroidTranslationCopyWithoutResultImageSave', 0, () => {
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

      expect(shouldShowCopyTextAction('translateText')).assertTrue();
      expect(shouldShowResultSaveAction(textTranslation, false)).assertFalse();
      expect(shouldShowResultSaveAction(textTranslation, true)).assertFalse();
    });

    it('showsStandaloneSegmentationForegroundOnlyForAndroidStillResult', 0, () => {
      expect(shouldShowStandaloneSegmentationForegroundPreview(
        workflowForRoute(AppRoute.SEGMENTATION_STILL.name))).assertTrue();
      expect(shouldShowStandaloneSegmentationForegroundPreview(
        workflowForRoute(AppRoute.SEGMENTATION_LIVE.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationForegroundPreview(
        workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationForegroundPreview(
        workflowForRoute(AppRoute.STYLE_TRANSFER.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationForegroundPreview(undefined)).assertFalse();
    });

    it('showsStandaloneSegmentationOverlayOnlyForAndroidStillResult', 0, () => {
      expect(shouldShowStandaloneSegmentationOverlayPreview(
        workflowForRoute(AppRoute.SEGMENTATION_STILL.name))).assertTrue();
      expect(shouldShowStandaloneSegmentationOverlayPreview(
        workflowForRoute(AppRoute.SEGMENTATION_LIVE.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationOverlayPreview(
        workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationOverlayPreview(
        workflowForRoute(AppRoute.STYLE_TRANSFER.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationOverlayPreview(
        workflowForRoute(AppRoute.OBJECT_PHOTO.name))).assertFalse();
      expect(shouldShowStandaloneSegmentationOverlayPreview(undefined)).assertFalse();
    });

    it('showsCompositeSegmentationSaveOnlyForAndroidPortraitResult', 0, () => {
      expect(shouldShowCompositeSegmentationSaveAction(
        workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name))).assertTrue();
      expect(shouldShowCompositeSegmentationSaveAction(
        workflowForRoute(AppRoute.SEGMENTATION_STILL.name))).assertFalse();
      expect(shouldShowCompositeSegmentationSaveAction(
        workflowForRoute(AppRoute.SEGMENTATION_LIVE.name))).assertFalse();
      expect(shouldShowCompositeSegmentationSaveAction(
        workflowForRoute(AppRoute.STYLE_TRANSFER.name))).assertFalse();
      expect(shouldShowCompositeSegmentationSaveAction(undefined)).assertFalse();
    });

    it('mirrorsPortraitAndLiveSegmentationForegroundOnlyForFrontCamera', 0, () => {
      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      const segmentationLive: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!;
      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;

      expect(shouldMirrorSegmentationForeground(portraitSegmentation, 'front')).assertTrue();
      expect(shouldMirrorSegmentationForeground(portraitSegmentation, 'back')).assertFalse();
      expect(shouldMirrorSegmentationForeground(segmentationLive, 'front')).assertTrue();
      expect(shouldMirrorSegmentationForeground(segmentationLive, 'back')).assertFalse();
      expect(shouldMirrorSegmentationForeground(segmentationStill, 'front')).assertFalse();
      expect(shouldMirrorSegmentationForeground(undefined, 'front')).assertFalse();
    });

    it('mirrorsGestureOverlayOnlyForFrontCameraLiveWorkflow', 0, () => {
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;
      const gestureStill: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;

      expect(shouldMirrorLiveGestureCameraOverlay(gestureLive, 'front')).assertTrue();
      expect(shouldMirrorLiveGestureCameraOverlay(gestureLive, 'back')).assertFalse();
      expect(shouldMirrorLiveGestureCameraOverlay(gestureStill, 'front')).assertFalse();
      expect(shouldMirrorLiveGestureCameraOverlay(undefined, 'front')).assertFalse();
    });

    it('showsAndroidCopyButtonForTextWorkflowsEvenWhenContentIsEmpty', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      expect(shouldShowCopyTextAction(textRecognition.aiMethod)).assertTrue();
      expect(shouldShowCopyTextAction(textTranslation.aiMethod)).assertTrue();
      expect(shouldShowCopyTextAction(styleTransfer.aiMethod)).assertFalse();
    });

    it('disablesEveryTextRecognitionActionWhileInferenceIsRunning', 0, () => {
      expect(textRecognitionActionEnabled(false)).assertTrue();
      expect(textRecognitionActionEnabled(true)).assertFalse();
    });

    it('labelsTextRecognitionFailuresAsRetryWithoutChangingOtherRunLabels', 0, () => {
      expect(textRecognitionRunActionLabelKey(
        'feature_runtime_text_recognition_failed',
        'feature_runtime_run'
      )).assertEqual('web_retry');
      expect(textRecognitionRunActionLabelKey(
        'feature_runtime_run_failed',
        'feature_runtime_run'
      )).assertEqual('web_retry');
      expect(textRecognitionRunActionLabelKey(
        'feature_runtime_copy_failed',
        'feature_runtime_run'
      )).assertEqual('feature_runtime_run');
    });

    it('usesAndroidTextTranslationInputHint', 0, () => {
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;

      expect(textInputPlaceholderKeyForWorkflow(textTranslation))
        .assertEqual('feature_runtime_text_translation_placeholder');
      expect(textInputPlaceholderKeyForWorkflow(textRecognition)).assertEqual('feature_runtime_text_placeholder');
      expect(hasAppStringKey(textInputPlaceholderKeyForWorkflow(textTranslation))).assertTrue();
    });

    it('portsAndroidPortraitSegmentationBackgroundPresets', 0, () => {
      expect(portraitSegmentationBackgroundPresets.length).assertEqual(5);
      expect(portraitSegmentationBackgroundPresets[0].id).assertEqual('original');
      expect(portraitSegmentationBackgroundPresets[0].mediaName).assertEqual('original');
      expect(portraitSegmentationBackgroundUri(portraitSegmentationBackgroundPresets[0]))
        .assertEqual('');
      expect(portraitSegmentationBackgroundPresets[4].id).assertEqual('portrait5');
      expect(portraitSegmentationCustomBackgroundId).assertEqual('custom');
      expect(hasAppStringKey('feature_runtime_portrait_background_presets')).assertTrue();
      expect(hasAppStringKey('feature_runtime_portrait_background_custom')).assertTrue();
    });

    it('defaultsPortraitSegmentationToAndroidFirstBackground', 0, () => {
      expect(defaultPortraitSegmentationBackgroundPreset.id).assertEqual('original');
      expect(defaultPortraitSegmentationBackgroundPreset.rawfilePath).assertEqual('');
      expect(defaultPortraitSegmentationBackgroundUri()).assertEqual('');
    });

    it('initializesOnlyPortraitSegmentationWithDefaultBackground', 0, () => {
      const emptyPortraitState: PortraitSegmentationBackgroundState = initialPortraitSegmentationBackgroundState(
        AppRoute.PORTRAIT_SEGMENTATION.name,
        '',
        ''
      );
      expect(emptyPortraitState.backgroundImageUri).assertEqual('');
      expect(emptyPortraitState.selectedPresetId).assertEqual('original');

      const selectedPortraitState: PortraitSegmentationBackgroundState = initialPortraitSegmentationBackgroundState(
        AppRoute.PORTRAIT_SEGMENTATION.name,
        'file://album/custom.jpg',
        portraitSegmentationCustomBackgroundId
      );
      expect(selectedPortraitState.backgroundImageUri).assertEqual('file://album/custom.jpg');
      expect(selectedPortraitState.selectedPresetId).assertEqual(portraitSegmentationCustomBackgroundId);

      const stillSegmentationState: PortraitSegmentationBackgroundState = initialPortraitSegmentationBackgroundState(
        AppRoute.SEGMENTATION_STILL.name,
        '',
        ''
      );
      expect(stillSegmentationState.backgroundImageUri).assertEqual('');
      expect(stillSegmentationState.selectedPresetId).assertEqual('');
    });

    it('preservesPortraitSegmentationBackgroundWhenCustomPickIsCancelled', 0, () => {
      const presetState: PortraitSegmentationBackgroundState = portraitSegmentationBackgroundStateAfterCancelledPick(
        AppRoute.PORTRAIT_SEGMENTATION.name,
        'rawfile://portrait/portrait1.jpg',
        'portrait1'
      );
      expect(presetState.backgroundImageUri).assertEqual('rawfile://portrait/portrait1.jpg');
      expect(presetState.selectedPresetId).assertEqual('portrait1');

      const customState: PortraitSegmentationBackgroundState = portraitSegmentationBackgroundStateAfterCancelledPick(
        AppRoute.PORTRAIT_SEGMENTATION.name,
        'file://album/custom.jpg',
        portraitSegmentationCustomBackgroundId
      );
      expect(customState.backgroundImageUri).assertEqual('file://album/custom.jpg');
      expect(customState.selectedPresetId).assertEqual(portraitSegmentationCustomBackgroundId);
    });

    it('defersRuntimeResultClearingUntilCancellablePickerInputsSucceed', 0, () => {
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(shouldDeferRuntimeResultClearUntilPickResult(objectPhoto, 'photo')).assertTrue();
      expect(shouldDeferRuntimeResultClearUntilPickResult(objectPhoto, 'modelFile')).assertTrue();

      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      expect(shouldDeferRuntimeResultClearUntilPickResult(styleTransfer, 'contentImage')).assertTrue();
      expect(shouldDeferRuntimeResultClearUntilPickResult(styleTransfer, 'styleImage')).assertTrue();
      expect(shouldDeferRuntimeResultClearUntilPickResult(styleTransfer, 'camera')).assertTrue();

      const liveObject: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      expect(shouldDeferRuntimeResultClearUntilPickResult(liveObject, 'camera')).assertFalse();

      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      expect(shouldDeferRuntimeResultClearUntilPickResult(textTranslation, 'text')).assertFalse();
    });

    it('preservesPortraitSegmentationResultsWhenOnlyBackgroundInputChanges', 0, () => {
      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      const stillSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const liveSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'backgroundImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'camera')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'backgroundImage')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'styleImage')).assertTrue();

      expect(shouldPreserveRuntimeVisualResultOnAiResult(portraitSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(portraitSegmentation, false, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(portraitSegmentation, true, '')).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(stillSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(liveSegmentation, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(liveSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveLiveCameraInputOnFailure(portraitSegmentation)).assertTrue();
      expect(liveSegmentationRetryActionForStatus(
        portraitSegmentation,
        'feature_runtime_segmentation_failed'
      )).assertEqual('restartInference');
      expect(liveSegmentationRetryActionForStatus(
        portraitSegmentation,
        'feature_runtime_segmentation_no_subject'
      )).assertEqual('restartInference');
      expect(shouldPublishLiveSegmentationPreparingStatus(portraitSegmentation, true)).assertFalse();
    });

    it('usesCurrentPortraitBackgroundWhenApplyingStaleSegmentationResult', 0, () => {
      const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      const stillSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;

      expect(runtimeSegmentationBackgroundImageUri(
        portraitSegmentation,
        'file://album/new-background.jpg',
        'rawfile://portrait/portrait1.jpg'
      )).assertEqual('file://album/new-background.jpg');
      expect(runtimeSegmentationBackgroundImageUri(
        portraitSegmentation,
        '',
        'rawfile://portrait/portrait1.jpg'
      )).assertEqual('rawfile://portrait/portrait1.jpg');
      expect(runtimeSegmentationBackgroundImageUri(
        stillSegmentation,
        'file://album/new-background.jpg',
        'rawfile://portrait/portrait1.jpg'
      )).assertEqual('rawfile://portrait/portrait1.jpg');
    });

    it('preservesPickedInputStateWhenNonBackgroundPickIsCancelled', 0, () => {
      const state: FeatureRuntimePickedInputState = {
        selectedInputSummary: 'file://album/old-content.jpg',
        imageInputUri: 'file://album/old-image.jpg',
        contentImageUri: 'file://album/old-content.jpg',
        styleImageUri: 'file://album/old-style.jpg',
        backgroundImageUri: 'file://album/old-background.jpg',
        selectedPortraitBackgroundPresetId: portraitSegmentationCustomBackgroundId,
        modelInputUri: 'file://model/custom.ms',
        stylePredictModelInputUri: 'file://model/predict.ms',
        styleTransferModelInputUri: 'file://model/transfer.ms'
      };

      const contentState: FeatureRuntimePickedInputState = runtimePickedInputStateAfterCancelledPick(
        AppRoute.STYLE_TRANSFER.name,
        'contentImage',
        state
      );
      expect(contentState.selectedInputSummary).assertEqual('file://album/old-content.jpg');
      expect(contentState.contentImageUri).assertEqual('file://album/old-content.jpg');
      expect(contentState.styleImageUri).assertEqual('file://album/old-style.jpg');

      const modelState: FeatureRuntimePickedInputState = runtimePickedInputStateAfterCancelledPick(
        AppRoute.CUSTOM_MODEL.name,
        'modelFile',
        state
      );
      expect(modelState.modelInputUri).assertEqual('file://model/custom.ms');
      expect(modelState.imageInputUri).assertEqual('file://album/old-image.jpg');

      const objectPhotoState: FeatureRuntimePickedInputState = runtimePickedInputStateAfterCancelledPick(
        AppRoute.OBJECT_PHOTO.name,
        'photo',
        state
      );
      expect(objectPhotoState.selectedInputSummary).assertEqual('file://album/old-content.jpg');
      expect(objectPhotoState.imageInputUri).assertEqual('file://album/old-image.jpg');
      expect(objectPhotoState.modelInputUri).assertEqual('file://model/custom.ms');

      const stillSegmentationPhotoState: FeatureRuntimePickedInputState =
        runtimePickedInputStateAfterCancelledPick(
          AppRoute.SEGMENTATION_STILL.name,
          'photo',
          state
        );
      expect(stillSegmentationPhotoState).assertEqual(state);
      expect(stillSegmentationPhotoState.selectedInputSummary).assertEqual('file://album/old-content.jpg');
      expect(stillSegmentationPhotoState.imageInputUri).assertEqual('file://album/old-image.jpg');

      const stillSegmentationCameraState: FeatureRuntimePickedInputState =
        runtimePickedInputStateAfterCancelledPick(
          AppRoute.SEGMENTATION_STILL.name,
          'camera',
          state
        );
      expect(stillSegmentationCameraState).assertEqual(state);
      expect(stillSegmentationCameraState.imageInputUri).assertEqual('file://album/old-image.jpg');
    });

    it('preservesPreviousModelOverrideWhenPickedModelCacheFails', 0, () => {
      const state: FeatureRuntimePickedInputState = {
        selectedInputSummary: 'file://model/old-selected.ms',
        imageInputUri: 'file://album/old-image.jpg',
        contentImageUri: 'file://album/old-content.jpg',
        styleImageUri: 'file://album/old-style.jpg',
        backgroundImageUri: '',
        selectedPortraitBackgroundPresetId: '',
        modelInputUri: 'file://cache/object_detection_model.mnn',
        stylePredictModelInputUri: 'file://cache/custom_predict.mnn',
        styleTransferModelInputUri: 'file://cache/custom_transfer.mnn'
      };

      const objectState: FeatureRuntimePickedInputState = runtimePickedInputStateAfterModelCacheFailure(
        'modelFile',
        state
      );
      expect(objectState.modelInputUri).assertEqual('file://cache/object_detection_model.mnn');
      expect(objectState.imageInputUri).assertEqual('file://album/old-image.jpg');
      expect(objectState.selectedInputSummary).assertEqual('');

      const stylePredictState: FeatureRuntimePickedInputState = runtimePickedInputStateAfterModelCacheFailure(
        'stylePredictModelFile',
        state
      );
      expect(stylePredictState.stylePredictModelInputUri).assertEqual('file://cache/custom_predict.mnn');
      expect(stylePredictState.styleTransferModelInputUri).assertEqual('file://cache/custom_transfer.mnn');
      expect(stylePredictState.selectedInputSummary).assertEqual('');
    });

    it('targetsPortraitBackgroundReplacementPreviewForCompositeSave', 0, () => {
      expect(segmentationBackgroundReplacementComponentId).assertEqual('segmentationBackgroundReplacementPreview');
      expect(hasAppStringKey('feature_runtime_result_background_replacement')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_done')).assertTrue();
      expect(hasAppStringKey('feature_runtime_save_image_failed')).assertTrue();
    });

    it('recordsPlatformNeedsFromOriginalAndroidFlows', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      const posenetInputKinds = runtimeInputKindsForWorkflow(posenet);
      expect(posenet.liveMode).assertFalse();
      expect(posenetInputKinds.length).assertEqual(2);
      expect(posenetInputKinds.indexOf('photo') >= 0).assertTrue();
      expect(posenetInputKinds.indexOf('camera') >= 0).assertTrue();
      expect(posenetInputKinds.indexOf('sampleImage')).assertEqual(-1);
      expect(posenet.linkedLiveRouteName).assertEqual(AppRoute.LIVE_SKELETON.name);
      expect(sampleImageUriForWorkflow(posenet)).assertEqual('rawfile://posenet/skeleton_image.JPG');

      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      expect(segmentationStill.linkedLiveRouteName).assertEqual(AppRoute.SEGMENTATION_LIVE.name);

      const gestureStill: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      expect(gestureStill.linkedLiveRouteName).assertEqual(AppRoute.GESTURE_LIVE.name);

      const sceneStill: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_STILL.name)!;
      expect(sceneStill.linkedLiveRouteName).assertEqual(AppRoute.SCENE_LIVE.name);

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
      expect((customModel.optionalInputKinds ?? []).indexOf('modelFile')).assertEqual(-1);
    });

    it('mapsAndroidHelpUrlsForRuntimeWorkflows', 0, () => {
      expect(workflowForRoute(AppRoute.IMAGE_CAMERA.name)?.helpUrl).assertEqual(helpImageClassificationUrl);
      expect(workflowForRoute(AppRoute.OBJECT_PHOTO.name)?.helpUrl).assertEqual(helpObjectDetectionUrl);
      expect(workflowForRoute(AppRoute.OBJECT_CAMERA.name)?.helpUrl).assertEqual(helpObjectDetectionUrl);
      expect(workflowForRoute(AppRoute.POSENET.name)?.helpUrl).assertEqual(helpPoseNetUrl);
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name)?.helpUrl).assertEqual(helpPoseNetUrl);
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name)?.helpUrl).assertEqual(helpImageSegmentationUrl);
      expect(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)?.helpUrl).assertEqual(helpImageSegmentationUrl);
      expect(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)?.helpUrl).assertEqual(helpImageSegmentationUrl);
      expect(workflowForRoute(AppRoute.SCENE_STILL.name)?.helpUrl).assertEqual(helpSceneDetectionUrl);
      expect(workflowForRoute(AppRoute.SCENE_LIVE.name)?.helpUrl).assertEqual(helpSceneDetectionUrl);
      expect(workflowForRoute(AppRoute.STYLE_TRANSFER.name)?.helpUrl).assertEqual(helpStyleTransferUrl);
      expect(workflowForRoute(AppRoute.CUSTOM_MODEL.name)?.helpUrl).assertEqual(customModelMoreUrl);
    });

    it('usesAndroidMindSporeHelpUrlsFromMsLinkUtils', 0, () => {
      expect(helpImageClassificationUrl).assertEqual(
        'https://www.mindspore.cn/doc/note/zh-CN/master/image_classification_lite.html');
      expect(helpObjectDetectionUrl).assertEqual(
        'https://www.mindspore.cn/doc/note/zh-CN/master/object_detection_lite.html');
      expect(helpPoseNetUrl).assertEqual('https://www.mindspore.cn/doc/note/zh-CN/master/posenet_lite.html');
      expect(helpImageSegmentationUrl).assertEqual(
        'https://www.mindspore.cn/doc/note/zh-CN/master/image_segmentation_lite.html');
      expect(helpSceneDetectionUrl).assertEqual(
        'https://www.mindspore.cn/doc/note/zh-CN/master/scene_detection_lite.html');
      expect(helpStyleTransferUrl).assertEqual(
        'https://www.mindspore.cn/doc/note/zh-CN/master/style_transfer_lite.html');
    });

    it('opensRuntimeHelpSourceExternallyLikeAndroid', 0, async () => {
      const context = new RecordingExternalHelpLinkContext();
      const navigator = new RecordingExternalHelpNavigator();

      const result = await openRuntimeHelpSource(context, helpImageClassificationUrl, 'title_image', navigator);

      expect(result).assertEqual('external');
      expect(context.openedLinks[0]).assertEqual(helpImageClassificationUrl);
      expect(context.hiddenFailureDialogs[0]).assertTrue();
      expect(navigator.routes.length).assertEqual(0);
    });

    it('fallsBackToHarmonyWebPageWhenRuntimeHelpSourceCannotOpenExternally', 0, async () => {
      const navigator = new RecordingExternalHelpNavigator();

      const result = await openRuntimeHelpSource(
        new RejectingExternalHelpLinkContext(),
        helpImageClassificationUrl,
        'title_image',
        navigator
      );

      expect(result).assertEqual('fallback');
      expect(navigator.routes[0].url).assertEqual(webPagePath);
      expect(navigator.routes[0].params.titleKey).assertEqual('title_image');
      expect(navigator.routes[0].params.url).assertEqual(helpImageClassificationUrl);
    });

    it('fallsBackToHarmonyWebPageWhenRuntimeHelpSourceHasNoContext', 0, async () => {
      const navigator = new RecordingExternalHelpNavigator();

      const result = await openRuntimeHelpSource(undefined, helpImageClassificationUrl, 'title_image', navigator);

      expect(result).assertEqual('fallback');
      expect(navigator.routes[0].url).assertEqual(webPagePath);
      expect(navigator.routes[0].params.titleKey).assertEqual('title_image');
      expect(navigator.routes[0].params.url).assertEqual(helpImageClassificationUrl);
    });

    it('mapsAndroidLocalHelpDialogsToRuntimeWorkflows', 0, () => {
      expect(workflowForRoute(AppRoute.IMAGE_CAMERA.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_image_classification');
      expect(workflowForRoute(AppRoute.OBJECT_PHOTO.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_object_photo');
      expect(workflowForRoute(AppRoute.OBJECT_CAMERA.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_object_camera');
      expect(workflowForRoute(AppRoute.POSENET.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_pose_net');
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_pose_net');
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_image_segmentation');
      expect(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_image_segmentation');
      expect(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_image_segmentation');
      expect(workflowForRoute(AppRoute.SCENE_STILL.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_scene_detection');
      expect(workflowForRoute(AppRoute.SCENE_LIVE.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_scene_detection');
      expect(workflowForRoute(AppRoute.STYLE_TRANSFER.name)?.helpContentKey)
        .assertEqual('feature_runtime_help_style_transfer');
      expect(workflowForRoute(AppRoute.CUSTOM_MODEL.name)?.helpContentKey)
        .assertEqual('feature_runtime_custom_model_help');
    });

    it('showsAndroidStyleTransferRecoveryWheneverStyleTransferPageIsOpen', 0, () => {
      expect(shouldShowStyleRecoveryControl('runStyleTransfer', true)).assertTrue();
      expect(shouldShowStyleRecoveryControl('runStyleTransfer', false)).assertTrue();
      expect(shouldShowStyleRecoveryControl('classifyImage', true)).assertFalse();
    });

    it('usesAndroidStyleTransferRecoveryPromptUntilOriginalImageExists', 0, () => {
      expect(styleTransferRecoveryStatusKey(false)).assertEqual('feature_runtime_style_original_required');
      expect(styleTransferRecoveryStatusKey(true)).assertEqual('feature_runtime_style_recovered');
    });

    it('styleTransferRecoveryKeepsLastStyledImageSaveableLikeAndroid', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      expect(shouldShowStyleTransferStyledPreview(true, false)).assertTrue();
      expect(shouldShowStyleTransferStyledPreview(true, true)).assertFalse();
      expect(shouldShowResultSaveAction(styleTransfer, true)).assertTrue();
    });

    it('definesRuntimeWorkflowForEveryRuntimeRoute', 0, () => {
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name) !== undefined).assertTrue();
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name) !== undefined).assertTrue();
    });

    it('keepsAndroidLiveSkeletonRouteSeparateFromPoseStillRoute', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      const liveSkeleton: FeatureWorkflow = workflowForRoute(AppRoute.LIVE_SKELETON.name)!;

      expect(posenet.liveMode).assertFalse();
      expect(runtimeInputActionForWorkflowInput(posenet, 'camera')).assertEqual('captureImage');
      expect(shouldAutoRunWorkflowAfterInputReady(posenet, 'sampleImage')).assertFalse();
      expect(shouldAutoRunWorkflowAfterInputReady(posenet, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(posenet, 'camera')).assertTrue();
      expect(inputLabelKey('sampleImage')).assertEqual('feature_input_sample_image');
      expect(liveSkeleton.liveMode).assertTrue();
      expect(liveSkeleton.inputKinds.length).assertEqual(1);
      expect(liveSkeleton.inputKinds[0]).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(liveSkeleton)).assertEqual('camera');
    });

    it('mapsPoseSampleRawfileUriToResourcePathForBundledAndroidSample', 0, () => {
      expect(rawfilePathFromPoseImageUri('rawfile://posenet/skeleton_image.JPG'))
        .assertEqual('posenet/skeleton_image.JPG');
      expect(rawfilePathFromPoseImageUri('file://selected/pose.jpg')).assertEqual('');
    });

    it('poseRawfileImageSourceUsesResourceManagerWithoutOpeningFileUri', 0, async () => {
      const reader: FixedRawfileContentReader = new FixedRawfileContentReader(new Uint8Array([1, 2, 3, 4]));
      const sourceFactory: RecordingPoseImageSourceFactory = new RecordingPoseImageSourceFactory();
      const fileOpener: RecordingPoseImageFileOpener = new RecordingPoseImageFileOpener();

      const input: PoseImageSourceInput = await createPoseImageSourceForUri('rawfile://posenet/skeleton_image.JPG', {
        resourceManager: reader,
        sourceFactory: sourceFactory,
        fileOpener: fileOpener
      });

      expect(input.imageSource !== undefined).assertTrue();
      expect(input.imageFile === undefined).assertTrue();
      expect(reader.seenPaths[0]).assertEqual('posenet/skeleton_image.JPG');
      expect(sourceFactory.rawfileByteLengths[0]).assertEqual(4);
      expect(sourceFactory.fileDescriptors.length).assertEqual(0);
      expect(fileOpener.seenUris.length).assertEqual(0);
    });

    it('poseFileImageSourceClosesOpenedFileWhenSourceCreationFails', 0, async () => {
      const fileOpener: RecordingPoseImageFileOpener = new RecordingPoseImageFileOpener();
      let rejected = false;

      try {
        await createPoseImageSourceForUri('file://selected/pose.jpg', {
          sourceFactory: new ThrowingPoseImageSourceFactory(),
          fileOpener: fileOpener
        });
      } catch (_) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(fileOpener.seenUris[0]).assertEqual('file://selected/pose.jpg');
      expect(fileOpener.closedFds[0]).assertEqual(7);
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

    it('featureRuntimeMapsOverlayPreviewOrientationWithoutMirroring', 0, () => {
      expect(featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(0)).assertEqual(ImageRotateOrientation.UP);
      expect(featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(90)).assertEqual(ImageRotateOrientation.RIGHT);
      expect(featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(180)).assertEqual(ImageRotateOrientation.DOWN);
      expect(featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(270)).assertEqual(ImageRotateOrientation.LEFT);
      expect(featureRuntimeOverlayPreviewImageOrientationFromRotationDegrees(45)).assertEqual(ImageRotateOrientation.UP);
    });

    it('aiServiceReturnsExplicitPendingAdapterFailure', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.aiMethod).assertEqual('detectObjects');
    });

    it('aiServiceReportsMissingGestureRunnerAsUnavailableAdapter', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name);
      expect(workflow !== undefined).assertTrue();

      const result = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/hand.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_runner_unavailable');
    });

    it('aiServiceReportsMissingSceneRunnerAsUnavailableAdapter', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();

      const result = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/scene.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.messageKey).assertEqual('feature_runtime_scene_runner_unavailable');
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

    it('collapsesAdjacentCtcRepeatsAndResetsAfterBlankTokens', 0, () => {
      const scores = new Float32Array(40 * 6625);
      const dictionary: Array<string> = [];
      for (let index = 0; index < 6625; index++) {
        dictionary.push(index === 1 ? 'A' : index === 2 ? 'B' : '');
      }
      scores[1] = 1;
      scores[1 * 6625 + 1] = 1;
      scores[3 * 6625 + 1] = 1;
      scores[4 * 6625 + 2] = 1;
      expect(ocrCtcText(scores, dictionary)).assertEqual('AAB');
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
      expect(translationLanguagePairSupportsTarget(pairs, 'zh-HK')).assertTrue();
      expect(translationLanguagePairSupportsTarget(pairs, 'fr')).assertFalse();
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
      const rows = aiRunResultRows(result);
      expect(rows.length).assertEqual(1);
      expect(rows[0].labelKey).assertEqual('feature_runtime_result_text');
      expect(rows[0].valueKey).assertEqual('feature_runtime_text_recognition_failed');
      expect(copyableTextForAiResult('recognizeText', rows)).assertEqual('feature_runtime_text_recognition_failed');
      expect(textRecognitionOutputForAiResult(rows, () => 'Text extraction failed.'))
        .assertEqual('Text extraction failed.');
    });

    it('aiServiceReportsBlankTextRecognitionAsFailure', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new TextRecognitionService({
        runner: new FixedTextRecognitionRunner({
          ok: true,
          text: '   \n',
          lineCount: 1,
          blockCount: 1,
          executionMs: 5
        })
      });

      const result = await new DefaultAiService({ textRecognitionService: service }).run(workflow!, {
        imageUri: 'file://selected/blank-text.jpg'
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

    it('textTranslationTreatsBlankTextAsMissingInput', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedTextTranslationRunner = new FixedTextTranslationRunner('translated');
      const service = new TextTranslationService({
        runner: runner
      });

      const result = await new DefaultAiService({ textTranslationService: service }).run(workflow!, {
        text: '   \n'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
      expect(runner.seenTexts.length).assertEqual(0);
    });

    it('defaultAiServiceDoesNotUseLegacyDictionaryWithoutExplicitInjection', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();

      const result = await new DefaultAiService().run(workflow!, {
        text: 'Hello, MindSpore!'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
    });

    it('callerOwnedPixelMapReleasesExactlyOnceAfterSuccessfulUse', 0, async () => {
      const pixelMap = new FakeReleasablePixelMap();
      const result = await withCallerOwnedPixelMap(pixelMap, async (value: FakeReleasablePixelMap | undefined) => {
        expect(value === pixelMap).assertTrue();
        return 'saved';
      });

      expect(result).assertEqual('saved');
      expect(pixelMap.releaseCount).assertEqual(1);
    });

    it('callerOwnedPixelMapReleasesAfterFailedUseWithoutMaskingFailure', 0, async () => {
      const pixelMap = new FakeReleasablePixelMap(true);
      const saveError = new Error('save failed');
      const preserved = await withCallerOwnedPixelMap(
        pixelMap,
        async (_value: FakeReleasablePixelMap | undefined): Promise<number> => {
          throw saveError;
        }
      ).then(
        (_value: number): boolean => false,
        (error: Error): boolean => error === saveError
      );

      expect(preserved).assertTrue();
      expect(pixelMap.releaseCount).assertEqual(1);
    });

    it('callerOwnedPixelMapSwallowsReleaseFailureAfterSuccessfulUse', 0, async () => {
      const pixelMap = new FakeReleasablePixelMap(true);
      const result = await withCallerOwnedPixelMap(pixelMap, async (_value: FakeReleasablePixelMap | undefined) => 7);

      expect(result).assertEqual(7);
      expect(pixelMap.releaseCount).assertEqual(1);
    });

    it('defaultAiServiceDoesNotExposeLegacyDictionaryFailureMessaging', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();

      const result = await new DefaultAiService().run(workflow!, {
        text: 'unmapped phrase'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.messageKey).assertEqual('feature_runtime_pending_adapter');
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

    it('textTranslationServiceRejectsUnsupportedTargetWhenAndroidLanguagePairsAreLoaded', 0, async () => {
      const runner: FixedTextTranslationRunner = new FixedTextTranslationRunner('\u4F60\u597D');
      const service = new TextTranslationService({
        runner: runner,
        languagePairs: parseTranslationLanguagePairs('English en\n')
      });

      const result = await service.translateText('hello');

      expect(result.ok).assertFalse();
      expect(result.targetLanguage).assertEqual('zh');
      expect(result.translatedText).assertEqual('');
      expect(runner.seenTexts.length).assertEqual(0);
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
      const translationRunner: FixedTextTranslationRunner = new FixedTextTranslationRunner('hello', 'localModel');

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

    it('aiServiceRecognizesImageTextBeforeInjectedLocalModelTranslation', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'MindSpore\n',
        lineCount: 1,
        blockCount: 1,
        executionMs: 8
      });
      const translationRunner = new FixedTextTranslationRunner('\u6607\u601D', 'localModel');

      const result = await new DefaultAiService({
        textRecognitionService: new TextRecognitionService({ runner: recognitionRunner }),
        textTranslationService: new TextTranslationService({ runner: translationRunner })
      }).run(workflow!, {
        imageUri: 'file://selected/text.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_done');
      expect(result.detailText.indexOf('targetLanguage=zh') >= 0).assertTrue();
      expect(result.detailText.indexOf('source=MindSpore') >= 0).assertTrue();
      expect(result.detailText.indexOf('translated=\u6607\u601D') >= 0).assertTrue();
      expect(result.data?.kind).assertEqual('textTranslation');
      expect(aiRunResultRows(result)[1].labelKey).assertEqual('feature_runtime_result_text');
      expect(aiRunResultRows(result)[1].value).assertEqual('MindSpore\n');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('\u6607\u601D');
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/text.jpg');
      expect(translationRunner.seenTexts[0]).assertEqual('MindSpore\n');
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

    it('projectsOnlyCompleteTranslatedTextForAndroidTranslationOutput', 0, () => {
      const sourceAndTranslation: Array<AiRunResultRow> = [
        { labelKey: 'feature_runtime_result_text', value: 'source\ntext\n' },
        { labelKey: 'feature_runtime_result_translated_text', value: '译文第一行\ntranslation line 2\n' }
      ];
      const sourceOnly: Array<AiRunResultRow> = [
        { labelKey: 'feature_runtime_result_text', value: 'must not be copied' }
      ];

      expect(translatedTextForAiResult(sourceAndTranslation))
        .assertEqual('译文第一行\ntranslation line 2\n');
      expect(translatedTextForAiResult(sourceOnly)).assertEqual('');
      expect(translatedTextForAiResult([])).assertEqual('');
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
      expect(aiRunResultRows(result)[1].value).assertEqual('hello');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('hello');
    });

    it('localTextTranslationRunnerTranslatesKnownDemoPhrasesOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const chineseResult = await runner.translate('\u4F60\u597D\n', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.sourceText).assertEqual('\u4F60\u597D\n');
      expect(chineseResult.translatedText).assertEqual('hello');
      expect(chineseResult.targetLanguage).assertEqual('en');
      expect(chineseResult.runtimeSource).assertEqual('offlineDictionary');

      const englishResult = await runner.translate('MindSpore', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u6607\u601D');

      const unknownResult = await runner.translate('unmapped phrase', 'zh');
      expect(unknownResult.ok).assertFalse();
      expect(unknownResult.translatedText).assertEqual('');
      expect(unknownResult.runtimeSource).assertEqual('offlineDictionary');
    });

    it('localTextTranslationRunnerComposesKnownDemoPhrasesOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const chineseResult = await runner.translate('\u4F60\u597D\u6607\u601D', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText).assertEqual('hello MindSpore');

      const englishResult = await runner.translate('Hello, MindSpore!', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u4F60\u597D\u6607\u601D');

      const phraseResult = await runner.translate('text translation', 'zh');
      expect(phraseResult.ok).assertTrue();
      expect(phraseResult.translatedText).assertEqual('\u6587\u672C\u7FFB\u8BD1');

      const unknownResult = await runner.translate('hello unknown', 'zh');
      expect(unknownResult.ok).assertFalse();
      expect(unknownResult.translatedText).assertEqual('');
    });

    it('localTextTranslationRunnerTranslatesCommonMindSporeSentencesOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishResult = await runner.translate('This is a MindSpore model.', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u8FD9\u662F\u4E00\u4E2A\u6607\u601D\u6A21\u578B');

      const chineseResult = await runner.translate('\u8FD9\u662F\u4E00\u4E2A\u6607\u601D\u6A21\u578B\u3002', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText).assertEqual('this is a MindSpore model');
    });

    it('localTextTranslationRunnerTranslatesCommonVisionWorkflowLinesOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const chineseResult = await runner.translate('\u56FE\u50CF\u5206\u7C7B\n\u76EE\u6807\u68C0\u6D4B', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText).assertEqual('image classification\nobject detection');

      const englishResult = await runner.translate('image classification\nobject detection', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u56FE\u50CF\u5206\u7C7B\n\u76EE\u6807\u68C0\u6D4B');
    });

    it('localTextTranslationRunnerHandlesAndroidSeparatedTitlesOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishTitles = await runner.translate(
        'Object Detection(Photo)\nObject Detection(Real-time)\nReal-time translation',
        'zh'
      );
      expect(englishTitles.ok).assertTrue();
      expect(englishTitles.translatedText)
        .assertEqual('\u5BF9\u8C61\u68C0\u6D4B(\u56FE\u7247)\n' +
          '\u5BF9\u8C61\u68C0\u6D4B(\u5B9E\u65F6)\n\u5B9E\u65F6\u7FFB\u8BD1');

      const chineseTitles = await runner.translate(
        '\u5BF9\u8C61\u68C0\u6D4B(\u56FE\u7247)\n\u5BF9\u8C61\u68C0\u6D4B(\u5B9E\u65F6)\n\u5B9E\u65F6\u7FFB\u8BD1',
        'en'
      );
      expect(chineseTitles.ok).assertTrue();
      expect(chineseTitles.translatedText)
        .assertEqual('Object Detection(Photo)\nObject Detection(Real-time)\nreal-time translation');
    });

    it('localTextTranslationRunnerKeepsCommonAiPhoneSentencesNaturalOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const chineseResult = await runner.translate('\u673A\u5668\u5B66\u4E60\u53EF\u4EE5\u5728\u624B\u673A\u4E0A\u8FD0\u884C', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText).assertEqual('machine learning can run on phone');

      const englishResult = await runner.translate('MindSpore can run on the phone.', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u6607\u601D\u53EF\u4EE5\u5728\u624B\u673A\u4E0A\u8FD0\u884C');
    });

    it('localTextTranslationRunnerCoversCommonAppIntroCopyOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const appNameResult = await runner.translate('MindSpore Inhand', 'zh');
      expect(appNameResult.ok).assertTrue();
      expect(appNameResult.translatedText).assertEqual('MindSpore \u638C\u4E2D\u5B9D');

      const chineseAppNameResult = await runner.translate('MindSpore \u638C\u4E2D\u5B9D', 'en');
      expect(chineseAppNameResult.ok).assertTrue();
      expect(chineseAppNameResult.translatedText).assertEqual('MindSpore Inhand');

      const experienceSubtitleResult = await runner.translate('AI demos ready for the HarmonyOS shell', 'zh');
      expect(experienceSubtitleResult.ok).assertTrue();
      expect(experienceSubtitleResult.translatedText)
        .assertEqual('HarmonyOS \u7248 AI \u793A\u4F8B\u5DF2\u5C31\u7EEA');

      const chineseExperienceSubtitleResult =
        await runner.translate('HarmonyOS \u7248 AI \u793A\u4F8B\u5DF2\u5C31\u7EEA', 'en');
      expect(chineseExperienceSubtitleResult.ok).assertTrue();
      expect(chineseExperienceSubtitleResult.translatedText).assertEqual('AI demos ready for the HarmonyOS shell');

      const introResult = await runner.translate(
        'A one-stop platform of collaborative learning, demonstrating, and experiencing for AI users.',
        'zh'
      );
      expect(introResult.ok).assertTrue();
      expect(introResult.translatedText)
        .assertEqual('AI \u7231\u597D\u8005\u7684\u4E00\u7AD9\u5F0F\u534F\u540C\u5B66\u4E60\u3001\u6F14\u793A\u3001\u4F53\u9A8C\u5E73\u53F0');

      const collegeResult = await runner.translate(
        'MindSpore is a full-scenario AI computing framework.\n' +
          'This page provides local learning entries and opens external resources in a web page.',
        'zh'
      );
      expect(collegeResult.ok).assertTrue();
      expect(collegeResult.translatedText)
        .assertEqual('MindSpore \u662F\u5168\u573A\u666F AI \u8BA1\u7B97\u6846\u67B6\n' +
          '\u672C\u9875\u63D0\u4F9B\u672C\u5730\u5B66\u4E60\u5165\u53E3\uFF0C\u5E76\u901A\u8FC7\u7F51\u9875\u6253\u5F00\u5916\u90E8\u8D44\u6E90');
    });

    it('localTextTranslationCoversAndroidMeAndCollegeNavigationCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishNavigation = await runner.translate(
        'My QR Code\nOfficial Website\nOfficial Code\nFeedback\nUser Agreement and Privacy Policy\n' +
          'Quick Start\nTrain\nInference\nApplications\nAsk on forum\nReference video',
        'zh'
      );
      expect(englishNavigation.ok).assertTrue();
      expect(englishNavigation.translatedText)
        .assertEqual('\u6211\u7684\u4E8C\u7EF4\u7801\n\u5B98\u65B9\u7F51\u7AD9\n\u5B98\u65B9\u4EE3\u7801\u4ED3\n' +
          '\u95EE\u9898\u53CD\u9988\n\u7528\u6237\u534F\u8BAE\u548C\u9690\u79C1\u653F\u7B56\n' +
          '\u5FEB\u901F\u5165\u95E8\n\u8BAD\u7EC3\u6A21\u578B\n\u6267\u884C\u63A8\u7406\n' +
          '\u7AEF\u4FA7\u5E94\u7528\n\u8BBA\u575B\u63D0\u95EE\n\u53C2\u8003\u89C6\u9891');

      const chineseNavigation = await runner.translate(
        '\u6211\u7684\u4E8C\u7EF4\u7801\n\u5B98\u65B9\u7F51\u7AD9\n\u5B98\u65B9\u4EE3\u7801\u4ED3\n' +
          '\u95EE\u9898\u53CD\u9988\n\u7528\u6237\u534F\u8BAE\u548C\u9690\u79C1\u653F\u7B56\n' +
          '\u5FEB\u901F\u5165\u95E8\n\u8BAD\u7EC3\u6A21\u578B\n\u6267\u884C\u63A8\u7406\n' +
          '\u7AEF\u4FA7\u5E94\u7528\n\u8BBA\u575B\u63D0\u95EE\n\u53C2\u8003\u89C6\u9891',
        'en'
      );
      expect(chineseNavigation.ok).assertTrue();
      expect(chineseNavigation.translatedText)
        .assertEqual('My QR Code\nOfficial Website\nOfficial Code\nFeedback\nUser Agreement and Privacy Policy\n' +
          'Quick Start\nTrain\nInference\nApplications\nAsk on forum\nReference video');
    });

    it('localTextTranslationRunnerCoversMainShellAndSectionCopyOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishResult = await runner.translate(
        'Experience\nComputer Vision\nSpeech Semantic Technology\nCollege\nMe',
        'zh'
      );
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText)
        .assertEqual('\u4F53\u9A8C\n\u89C6\u89C9\u56FE\u50CF\u6280\u672F\n\u8BED\u97F3\u8BED\u4E49\u6280\u672F\n\u5B66\u9662\n\u6211\u7684');

      const chineseResult = await runner.translate(
        '\u4F53\u9A8C\n\u89C6\u89C9\u56FE\u50CF\u6280\u672F\n\u8BED\u97F3\u8BED\u4E49\u6280\u672F\n\u5B66\u9662\n\u6211\u7684',
        'en'
      );
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText)
        .assertEqual('experience\ncomputer vision\nspeech semantic technology\ncollege\nme');
    });

    it('localTextTranslationRunnerCoversExperienceHeaderAndCollegeFooterCopyOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishResult = await runner.translate(
        'Experience Center\n' +
          'Invite you to explore a new generation of ALL-Scenario AI Computing Framework\n' +
          'View\n~Illuminate your learning trip~',
        'zh'
      );
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText)
        .assertEqual('\u4F53\u9A8C\u4E2D\u5FC3\n' +
          '\u65B0\u4E00\u4EE3\u5168\u573A\u666FAI\u8BA1\u7B97\u6846\u67B6\uFF0C\u9080\u60A8\u9A6C\u4E0A\u4F53\u9A8C\n' +
          '\u67E5\u770B\n~\u70B9\u4EAE\u60A8\u7684\u5B66\u4E60\u4E4B\u65C5~');

      const chineseResult = await runner.translate(
        '\u4F53\u9A8C\u4E2D\u5FC3\n' +
          '\u65B0\u4E00\u4EE3\u5168\u573A\u666FAI\u8BA1\u7B97\u6846\u67B6\uFF0C\u9080\u60A8\u9A6C\u4E0A\u4F53\u9A8C\n' +
          '\u67E5\u770B\n~\u70B9\u4EAE\u60A8\u7684\u5B66\u4E60\u4E4B\u65C5~',
        'en'
      );
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText)
        .assertEqual('Experience Center\n' +
          'Invite you to explore a new generation of ALL-Scenario AI Computing Framework\n' +
          'View\n~Illuminate your learning trip~');
    });

    it('localTextTranslationRunnerCoversAndroidHmsShortTitleCopyOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishResult = await runner.translate('PoseNet\nSummary', 'zh');
      expect(englishResult.ok).assertTrue();
      expect(englishResult.translatedText).assertEqual('\u9AA8\u9ABC\u68C0\u6D4B\n\u7B80\u8981\u8BF4\u660E');

      const chineseResult = await runner.translate('\u9AA8\u9ABC\u68C0\u6D4B\n\u7B80\u8981\u8BF4\u660E', 'en');
      expect(chineseResult.ok).assertTrue();
      expect(chineseResult.translatedText).assertEqual('PoseNet\nSummary');
    });

    it('localTextTranslationRunnerCoversRuntimePermissionAndStatusCopyOffline', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const permissionResult = await runner.translate(
        'MindSpore needs camera and media access. Grant these permissions to continue.',
        'zh'
      );
      expect(permissionResult.ok).assertTrue();
      expect(permissionResult.translatedText)
        .assertEqual('MindSpore \u9700\u8981\u76F8\u673A\u548C\u5A92\u4F53\u8BBF\u95EE\u6743\u9650\uFF0C\u6388\u6743\u540E\u624D\u80FD\u7EE7\u7EED\u4F7F\u7528');

      const chinesePermissionResult = await runner.translate(
        'MindSpore \u9700\u8981\u76F8\u673A\u548C\u5A92\u4F53\u8BBF\u95EE\u6743\u9650\uFF0C\u6388\u6743\u540E\u624D\u80FD\u7EE7\u7EED\u4F7F\u7528',
        'en'
      );
      expect(chinesePermissionResult.ok).assertTrue();
      expect(chinesePermissionResult.translatedText)
        .assertEqual('MindSpore needs camera and media access. Grant these permissions to continue');

      const statusResult = await runner.translate('Text translation completed.', 'zh');
      expect(statusResult.ok).assertTrue();
      expect(statusResult.translatedText).assertEqual('\u6587\u672C\u7FFB\u8BD1\u5DF2\u5B8C\u6210');

      const chineseStatusResult = await runner.translate('\u6587\u672C\u7FFB\u8BD1\u5DF2\u5B8C\u6210\u3002', 'en');
      expect(chineseStatusResult.ok).assertTrue();
      expect(chineseStatusResult.translatedText).assertEqual('text translation completed');
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

    it('updatesPreservedSegmentationBackgroundMetadataWhenPortraitBackgroundChanges', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedSegmentationRunner = new FixedSegmentationRunner({
        ok: true,
        subjectCount: 1,
        detailCount: 0,
        foregroundAvailable: true,
        foregroundImageRgba: new Uint8Array([255, 0, 0, 255]).buffer as ArrayBuffer,
        foregroundImageWidth: 1,
        foregroundImageHeight: 1,
        rectangles: [{
          left: 1,
          top: 2,
          width: 3,
          height: 4
        }],
        executionMs: 9
      });
      const service = new SegmentationService({
        runner: runner
      });

      const result: AiRunResult = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/person.jpg',
        backgroundImageUri: 'rawfile://portrait/portrait1.jpg'
      });
      const metadata: SegmentationBackgroundMetadata = segmentationMetadataWithBackground(
        aiRunResultRows(result),
        result.detailText,
        'file://album/custom-background.jpg'
      );

      expect(metadata.rows.filter((row: AiRunResultRow) =>
        row.labelKey === 'feature_runtime_result_background')[0].value).assertEqual('custom-background.jpg');
      expect(metadata.rows.filter((row: AiRunResultRow) =>
        row.value === 'portrait1.jpg').length).assertEqual(0);
      expect(metadata.detailText.indexOf('background=custom-background.jpg') >= 0).assertTrue();
      expect(metadata.detailText.indexOf('background=portrait1.jpg')).assertEqual(-1);
      expect(metadata.detailText.indexOf('[1,2,3,4]') >= 0).assertTrue();
    });

    it('doesNotUpdateBackgroundMetadataWithoutSuccessfulSegmentationRows', 0, () => {
      const metadata: SegmentationBackgroundMetadata = segmentationMetadataWithBackground(
        [],
        'image=person.jpg\nsubjectCount=1\nforegroundAvailable=false\nbackground=portrait1.jpg',
        'file://album/custom-background.jpg'
      );

      expect(metadata.rows.length).assertEqual(0);
      expect(metadata.detailText.indexOf('background=portrait1.jpg') >= 0).assertTrue();
      expect(metadata.detailText.indexOf('background=custom-background.jpg')).assertEqual(-1);
    });

    it('segmentationServiceTreatsMissingForegroundAsAndroidFailure', 0, async () => {
      const service = new SegmentationService({
        runner: new FixedSegmentationRunner({
          ok: true,
          subjectCount: 1,
          detailCount: 0,
          foregroundAvailable: false,
          imageWidth: 100,
          imageHeight: 200,
          rectangles: [{
            left: 1,
            top: 2,
            width: 3,
            height: 4
          }],
          executionMs: 9
        })
      });

      const result: SegmentationResult = await service.segmentPerson('file://selected/person.jpg');

      expect(result.ok).assertFalse();
      expect(result.subjectCount).assertEqual(1);
      expect(result.detailCount).assertEqual(0);
      expect(result.foregroundAvailable).assertFalse();
      expect(result.imageWidth).assertEqual(100);
      expect(result.imageHeight).assertEqual(200);
      expect(result.rectangles.length).assertEqual(1);
      expect(result.executionMs).assertEqual(9);
    });

    it('aiServiceReportsSegmentationFailureWhenForegroundImageIsMissing', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SegmentationService({
        runner: new FixedSegmentationRunner({
          ok: true,
          subjectCount: 1,
          detailCount: 0,
          foregroundAvailable: false,
          rectangles: [{
            left: 1,
            top: 2,
            width: 3,
            height: 4
          }],
          executionMs: 9
        })
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/person.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SEGMENTATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_segmentation_failed');
      expect(result.detailText.indexOf('subjectCount=1') >= 0).assertTrue();
      expect(result.detailText.indexOf('foregroundAvailable=false') >= 0).assertTrue();
      expect(result.detailText.indexOf('executionMs=9') >= 0).assertTrue();
      expect(result.detailText.indexOf('[1,2,3,4]') >= 0).assertTrue();
    });

    it('aiServiceMapsNoSubjectSegmentationFailureToLocalizedRetryStatus', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SegmentationService({
        runner: new FixedSegmentationRunner({
          ok: false,
          subjectCount: 0,
          detailCount: 0,
          foregroundAvailable: false,
          rectangles: [],
          executionMs: 7,
          failureReason: 'noSubject'
        })
      });

      const result = await new DefaultAiService({ segmentationService: service }).run(workflow!, {
        imageUri: 'file://selected/no-person.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SEGMENTATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_segmentation_no_subject');
      expect(result.detailText.indexOf('subjectCount=0') >= 0).assertTrue();
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

    it('segmentationServiceMapsRunnerExceptionToGenericFailureReason', 0, async () => {
      const service = new SegmentationService({
        runner: new RejectingSegmentationRunner()
      });

      const result: SegmentationResult = await service.segmentPerson('file://selected/person.jpg');

      expect(result.ok).assertFalse();
      expect(result.failureReason).assertEqual('runtimeException');
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
        runner: runner,
        mode: 'yoga'
      }).detectPose('file://selected/live-pose.jpg');
      const similarity: number = result.similarity ?? -1;

      expect(similarity.toFixed(2)).assertEqual('1.00');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/live-pose.jpg');
      expect(runner.seenModes[0]).assertEqual('yoga');
    });

    it('poseServiceLeavesNormalPoseWithoutAndroidLiveSkeletonTemplateSimilarity', 0, async () => {
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: androidLiveSkeletonTemplatePoints.length,
        points: androidLiveSkeletonTemplatePoints,
        executionMs: 9
      });

      const result = await new PoseService({
        runner: runner
      }).detectPose('file://selected/pose.jpg');

      expect(result.similarity === undefined).assertTrue();
      expect(runner.seenImageUris[0]).assertEqual('file://selected/pose.jpg');
      expect(runner.seenModes[0]).assertEqual('normal');
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
        }),
        mode: 'yoga'
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

    it('gatesSegmentationSaveForCurrentReadyIdleResult', 0, () => {
      expect(compositeSegmentationSaveReady(false, true, false)).assertTrue();
      expect(compositeSegmentationSaveReady(true, true, false)).assertFalse();
      expect(compositeSegmentationSaveReady(false, false, false)).assertFalse();
      expect(compositeSegmentationSaveReady(false, true, true)).assertFalse();
    });

    it('rejectsSegmentationDoubleClickAfterFirstSaveOwnsTheGate', 0, () => {
      let saveInFlight: boolean = false;
      const firstClickAccepted = compositeSegmentationSaveReady(false, true, saveInFlight);
      if (firstClickAccepted) {
        saveInFlight = true;
      }
      expect(firstClickAccepted).assertTrue();
      expect(compositeSegmentationSaveReady(false, true, saveInFlight)).assertFalse();
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

    it('exposesSdkStablePosePointTypeValuesWithoutNativeEnumReads', 0, () => {
      expect(PosePointType.NOSE).assertEqual(0);
      expect(PosePointType.LEFT_SHOULDER).assertEqual(5);
      expect(PosePointType.RIGHT_SHOULDER).assertEqual(6);
      expect(PosePointType.LEFT_ELBOW).assertEqual(7);
      expect(PosePointType.RIGHT_ELBOW).assertEqual(8);
      expect(PosePointType.LEFT_WRIST).assertEqual(9);
      expect(PosePointType.RIGHT_WRIST).assertEqual(10);
      expect(PosePointType.LEFT_HIP).assertEqual(11);
      expect(PosePointType.RIGHT_HIP).assertEqual(12);
      expect(PosePointType.LEFT_KNEE).assertEqual(13);
      expect(PosePointType.RIGHT_KNEE).assertEqual(14);
      expect(PosePointType.LEFT_ANKLE).assertEqual(15);
      expect(PosePointType.RIGHT_ANKLE).assertEqual(16);
    });

    it('usesStablePosePointTypesForLineAndDanceMappings', 0, () => {
      const points: Array<PosePoint> = [
        { type: PosePointType.NOSE, score: 0.9, x: 100, y: 20 },
        { type: PosePointType.LEFT_SHOULDER, score: 0.9, x: 60, y: 80 },
        { type: PosePointType.RIGHT_SHOULDER, score: 0.9, x: 140, y: 80 },
        { type: PosePointType.LEFT_ELBOW, score: 0.9, x: 40, y: 130 },
        { type: PosePointType.RIGHT_ELBOW, score: 0.9, x: 160, y: 130 },
        { type: PosePointType.LEFT_WRIST, score: 0.9, x: 20, y: 180 },
        { type: PosePointType.RIGHT_WRIST, score: 0.9, x: 180, y: 180 },
        { type: PosePointType.LEFT_HIP, score: 0.9, x: 70, y: 180 },
        { type: PosePointType.RIGHT_HIP, score: 0.9, x: 130, y: 180 },
        { type: PosePointType.LEFT_KNEE, score: 0.9, x: 70, y: 250 },
        { type: PosePointType.RIGHT_KNEE, score: 0.9, x: 130, y: 250 },
        { type: PosePointType.LEFT_ANKLE, score: 0.9, x: 70, y: 310 },
        { type: PosePointType.RIGHT_ANKLE, score: 0.9, x: 130, y: 310 }
      ];

      expect(poseSkeletonLines(points).length).assertEqual(12);
      expect(dancePosePointType.LEFT_SHOULDER).assertEqual(PosePointType.LEFT_SHOULDER);
      expect(dancePosePointType.RIGHT_SHOULDER).assertEqual(PosePointType.RIGHT_SHOULDER);
      expect(dancePosePointType.RIGHT_ELBOW).assertEqual(PosePointType.RIGHT_ELBOW);
      expect(dancePosePointType.RIGHT_WRIST).assertEqual(PosePointType.RIGHT_WRIST);
      expect(dancePosePointType.LEFT_ELBOW).assertEqual(PosePointType.LEFT_ELBOW);
      expect(dancePosePointType.LEFT_WRIST).assertEqual(PosePointType.LEFT_WRIST);
      expect(dancePosePointType.LEFT_KNEE).assertEqual(PosePointType.LEFT_KNEE);
      expect(dancePosePointType.LEFT_ANKLE).assertEqual(PosePointType.LEFT_ANKLE);
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

    it('calculatesAndroidLiveSkeletonTemplateSimilarityFromCoreVisionPointTypes', 0, () => {
      const coreVisionBodyTypes: Array<number> = [5, 7, 9, 6, 8, 10, 11, 13, 15, 12, 14, 16];
      const shiftedPoints: Array<PosePoint> =
        androidLiveSkeletonTemplatePoints.slice(0, coreVisionBodyTypes.length).map((
          point: PosePoint,
          index: number
        ): PosePoint => {
          return {
            type: coreVisionBodyTypes[index],
            score: point.score,
            x: point.x * 0.5 + 12,
            y: point.y * 0.5 + 30
          };
        });

      const similarity: number = poseSimilarityToAndroidTemplate(shiftedPoints) ?? -1;

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

    it('aiServiceReportsEmptyPoseSuccessAsFailureLikeAndroid', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const service = new PoseService({
        runner: new FixedPoseRunner({
          ok: true,
          skeletonCount: 0,
          pointCount: 0,
          points: [],
          executionMs: 11
        })
      });

      const result = await new DefaultAiService({ poseService: service }).run(workflow!, {
        imageUri: 'file://selected/empty-pose.jpg'
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
      expect(aiRunResultRows(result)[0].valueKey).assertUndefined();
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
      expect(aiRunResultRows(result)[0].valueKey).assertEqual('gesture_label_thumb_up');
    });

    it('mapsAndroidGestureCategoriesToI18nKeys', 0, () => {
      expect(androidGestureLabelKey(0)).assertEqual('gesture_label_one');
      expect(androidGestureLabelKey(1)).assertEqual('gesture_label_two');
      expect(androidGestureLabelKey(2)).assertEqual('gesture_label_three');
      expect(androidGestureLabelKey(3)).assertEqual('gesture_label_four');
      expect(androidGestureLabelKey(4)).assertEqual('gesture_label_five');
      expect(androidGestureLabelKey(5)).assertEqual('gesture_label_six');
      expect(androidGestureLabelKey(6)).assertEqual('gesture_label_seven');
      expect(androidGestureLabelKey(7)).assertEqual('gesture_label_eight');
      expect(androidGestureLabelKey(8)).assertEqual('gesture_label_nine');
      expect(androidGestureLabelKey(9)).assertEqual('gesture_label_dislike');
      expect(androidGestureLabelKey(10)).assertEqual('gesture_label_fist');
      expect(androidGestureLabelKey(11)).assertEqual('gesture_label_thumb_up');
      expect(androidGestureLabelKey(12)).assertEqual('gesture_label_heart');
      expect(androidGestureLabelKey(13)).assertEqual('gesture_label_ok');
      expect(androidGestureLabelKey(999)).assertEqual('gesture_label_other');
    });

    it('localizesInjectedGestureAliasLabelsToAndroidCategories', 0, () => {
      const fist: GestureDetection = {
        category: 10,
        label: 'Closed_Fist',
        score: 0.91
      };
      const custom: GestureDetection = {
        category: 10,
        label: 'custom fist result',
        score: 0.88
      };
      const mismatchedAlias: GestureDetection = {
        category: 11,
        label: 'Closed_Fist',
        score: 0.9
      };

      expect(gestureDetectionLabel(fist)).assertEqual('Fist');
      expect(gestureDetectionLabelKey(fist)).assertEqual('gesture_label_fist');
      expect(gestureDetectionLabel(custom)).assertEqual('custom fist result');
      expect(gestureDetectionLabelKey(custom) === undefined).assertTrue();
      expect(gestureDetectionLabel(mismatchedAlias)).assertEqual('Closed_Fist');
      expect(gestureDetectionLabelKey(mismatchedAlias) === undefined).assertTrue();
    });

    it('androidGestureModelRunnerNormalizesRawModelOutputToAndroidGestureDetections', 0, async () => {
      const thumbUp: AndroidGestureModelDetection = {
        category: 11,
        score: 0.91,
        rect: {
          left: 3,
          top: 5,
          width: 31,
          height: 37
        }
      };
      const unknown: AndroidGestureModelDetection = {
        category: 99,
        score: 0.5
      };
      const detector = new FixedAndroidGestureModelDetector({
        gestures: [thumbUp, unknown],
        imageWidth: 120,
        imageHeight: 90,
        executionMs: 17
      });

      const result = await new AndroidGestureModelRunner(detector).detectGesture('file://selected/hand.jpg');

      expect(result.ok).assertTrue();
      expect(result.imageWidth).assertEqual(120);
      expect(result.imageHeight).assertEqual(90);
      expect(result.executionMs).assertEqual(17);
      expect(result.gestures.length).assertEqual(2);
      expect(result.gestures[0].category).assertEqual(11);
      expect(result.gestures[0].label).assertEqual('Thumb up');
      expect(result.gestures[0].score.toFixed(2)).assertEqual('0.91');
      expect(result.gestures[0].rect?.left).assertEqual(3);
      expect(result.gestures[1].category).assertEqual(14);
      expect(result.gestures[1].label).assertEqual('Other gesture');
      expect(detector.seenImageUris[0]).assertEqual('file://selected/hand.jpg');
    });

    it('androidGestureModelRunnerFailsSafelyWhenDetectorThrows', 0, async () => {
      const result = await new AndroidGestureModelRunner(
        new RejectingAndroidGestureModelDetector()
      ).detectGesture('file://selected/hand.jpg');

      expect(result.ok).assertFalse();
      expect(result.gestures.length).assertEqual(0);
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

    it('usesAndroidHmsGestureThresholdsForStillAndLiveProduction', 0, () => {
      expect(hmsGestureConfidenceThresholdForLiveMode(false)).assertEqual(0.6);
      expect(hmsGestureConfidenceThresholdForLiveMode(true)).assertEqual(0.1);
    });

    it('mirrorsOnlyFrontCameraLiveGestureRectangleHorizontally', 0, () => {
      const rectangle: GestureRectangle = {
        left: 10,
        top: 5,
        width: 60,
        height: 20
      };

      const stillBox = gestureRectanglePercent(rectangle, 100, 50);
      const frontLiveBox = gestureRectanglePercent(rectangle, 100, 50, true);

      expect(stillBox.left).assertEqual(10);
      expect(frontLiveBox.left).assertEqual(30);
      expect(frontLiveBox.top).assertEqual(stillBox.top);
      expect(frontLiveBox.width).assertEqual(stillBox.width);
      expect(frontLiveBox.height).assertEqual(stillBox.height);
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

    it('sceneDetectionServiceDistinguishesEmptyResultsFromRuntimeFailures', 0, async () => {
      const emptyResult = await new SceneDetectionService({
        runner: new FixedSceneDetectionRunner({
          ok: true,
          scenes: [],
          executionMs: 3
        })
      }).detectScenes('file://selected/empty.jpg');
      const runtimeFailure = await new SceneDetectionService({
        runner: new RejectingSceneDetectionRunner()
      }).detectScenes('file://selected/broken.jpg');

      expect(emptyResult.failureKind).assertEqual('empty');
      expect(runtimeFailure.failureKind).assertEqual('runtime');
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
      const rows = aiRunResultRows(result);
      expect(rows[0].labelKey).assertEqual('feature_runtime_result_scene_count');
      expect(rows[0].value).assertEqual('1');
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value).assertEqual('1. beach 96.00%');
      expect(result.data?.kind).assertEqual('scenes');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/beach.jpg');
    });

    it('sceneDetectionResultRowsListAllScenesLikeAndroid', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const runner = new FixedSceneDetectionRunner({
        ok: true,
        scenes: [
          { label: 'beach', score: 0.96 },
          { label: 'mountain', score: 0.82 },
          { label: 'restaurant', score: 0.7 }
        ],
        executionMs: 9
      });
      const service = new SceneDetectionService({
        runner: runner
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/scenes.jpg'
      });
      const rows = aiRunResultRows(result);

      expect(rows[0].labelKey).assertEqual('feature_runtime_result_scene_count');
      expect(rows[0].value).assertEqual('3');
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value).assertEqual('1. beach 96.00%\n2. mountain 82.00%\n3. restaurant 70.00%');
      expect(rows[2].labelKey).assertEqual('feature_runtime_result_image');
      expect(rows[3].labelKey).assertEqual('feature_runtime_result_execution_time');
    });

    it('androidStillSceneResultRowsUseSeparateSceneAndTrimmedScoreLines', 0, () => {
      const rows = androidStillSceneResultRows({
        ok: true,
        scenes: [
          { label: 'beach', score: 0.5 },
          { label: 'mountain', score: 0.741 },
          { label: 'restaurant', score: 0.7412 }
        ],
        executionMs: 9
      });

      expect(rows.length).assertEqual(7);
      expect(rows[0].labelKey).assertEqual('feature_runtime_result_scene_count');
      expect(rows[0].value).assertEqual('3');
      expect(rows[1].labelKey).assertEqual('feature_runtime_scene_overlay_scene');
      expect(rows[1].value).assertEqual('beach');
      expect(rows[2].labelKey).assertEqual('feature_runtime_scene_overlay_score');
      expect(rows[2].value).assertEqual('50%');
      expect(rows[3].labelKey).assertEqual('feature_runtime_scene_overlay_scene');
      expect(rows[3].value).assertEqual('mountain');
      expect(rows[4].labelKey).assertEqual('feature_runtime_scene_overlay_score');
      expect(rows[4].value).assertEqual('74.1%');
      expect(rows[5].labelKey).assertEqual('feature_runtime_scene_overlay_scene');
      expect(rows[5].value).assertEqual('restaurant');
      expect(rows[6].labelKey).assertEqual('feature_runtime_scene_overlay_score');
      expect(rows[6].value).assertEqual('74.12%');
    });

    it('sceneDetectionOverlayRowsMirrorAndroidLiveGraphicLabels', 0, () => {
      const rows = sceneDetectionOverlayRows({
        ok: true,
        scenes: [
          { label: 'beach', score: 0.96 },
          { label: 'mountain', score: 0.82 }
        ],
        executionMs: 9
      });

      expect(rows.length).assertEqual(5);
      expect(rows[0].id).assertEqual('count');
      expect(rows[0].labelKey).assertEqual('feature_runtime_scene_overlay_count');
      expect(rows[0].value).assertEqual('2');
      expect(rows[1].id).assertEqual('scene-0');
      expect(rows[1].labelKey).assertEqual('feature_runtime_scene_overlay_scene');
      expect(rows[1].value).assertEqual('beach');
      expect(rows[2].id).assertEqual('score-0');
      expect(rows[2].labelKey).assertEqual('feature_runtime_scene_overlay_score');
      expect(rows[2].value).assertEqual('96.00%');
      expect(rows[3].id).assertEqual('scene-1');
      expect(rows[3].value).assertEqual('mountain');
      expect(rows[4].id).assertEqual('score-1');
      expect(rows[4].value).assertEqual('82.00%');
    });

    it('aiServiceReportsSceneDetectionRuntimeFailureWithDistinctCode', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SceneDetectionService({
        runner: new RejectingSceneDetectionRunner()
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/unknown.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SCENE_DETECTION_RUNTIME_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_scene_failed');
    });

    it('aiServiceReportsEmptySceneResultWithToastEligibleCode', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SceneDetectionService({
        runner: new FixedSceneDetectionRunner({
          ok: true,
          scenes: [],
          executionMs: 4
        })
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/empty.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('SCENE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_scene_failed');
    });

    it('androidSceneModelRunnerNormalizesRawModelOutputToSceneDetections', 0, async () => {
      const diningRoom: AndroidSceneModelDetection = {
        result: 'Dining room',
        confidence: 0.87
      };
      const unknownScene: AndroidSceneModelDetection = {
        result: 'unknown scene',
        confidence: 0.35
      };
      const detector = new FixedAndroidSceneModelDetector({
        scenes: [diningRoom, unknownScene],
        imageWidth: 160,
        imageHeight: 120,
        executionMs: 21
      });

      const result = await new AndroidSceneModelRunner(detector).detectScenes('file://selected/scene.jpg');

      expect(result.ok).assertTrue();
      expect(result.imageWidth).assertEqual(160);
      expect(result.imageHeight).assertEqual(120);
      expect(result.executionMs).assertEqual(21);
      expect(result.scenes.length).assertEqual(2);
      expect(result.scenes[0].label).assertEqual('diningroom');
      expect(result.scenes[0].score.toFixed(2)).assertEqual('0.87');
      expect(result.scenes[1].label).assertEqual('other');
      expect(result.scenes[1].score.toFixed(2)).assertEqual('0.35');
      expect(detector.seenImageUris[0]).assertEqual('file://selected/scene.jpg');
    });

    it('androidSceneModelRunnerFailsSafelyWhenDetectorThrows', 0, async () => {
      const result = await new AndroidSceneModelRunner(
        new RejectingAndroidSceneModelDetector()
      ).detectScenes('file://selected/scene.jpg');

      expect(result.ok).assertFalse();
      expect(result.scenes.length).assertEqual(0);
      expect(result.failureKind).assertEqual('runtime');
    });

    it('sceneDetectionRunnersRetainEmptyAndRuntimeFailureProvenance', 0, async () => {
      const androidEmpty = await new AndroidSceneModelRunner(
        new FixedAndroidSceneModelDetector({ scenes: [], executionMs: 2 })
      ).detectScenes('file://selected/empty.jpg');
      const localEmpty = await new ImageClassificationSceneDetectionRunner({
        labels: ['beach'],
        scoreRunner: new FixedScoreRunner([])
      }).detectScenes('file://selected/empty.jpg');
      const localRuntimeFailure = await new ImageClassificationSceneDetectionRunner({
        labels: ['beach'],
        scoreRunner: new RejectingScoreRunner()
      }).detectScenes('file://selected/broken.jpg');

      expect(androidEmpty.failureKind).assertEqual('empty');
      expect(localEmpty.failureKind).assertEqual('empty');
      expect(localRuntimeFailure.failureKind).assertEqual('runtime');
    });

    it('localSceneDetectionRunnerMapsClassificationLabelsToScenes', 0, async () => {
      expect(androidSceneDetectionLabels.length).assertEqual(104);
      for (let index = 0; index < androidSceneDetectionLabels.length; index++) {
        const label = androidSceneDetectionLabels[index];
        expect(sceneLabelForImageClassificationLabel(label)).assertEqual(label);
      }
      expect(sceneLabelForImageClassificationLabel('espresso')).assertEqual('food');
      expect(sceneLabelForImageClassificationLabel('seashore')).assertEqual('beach');
      expect(sceneLabelForImageClassificationLabel('sports_car')).assertEqual('car');
      expect(sceneLabelForImageClassificationLabel('bathroom')).assertEqual('washroom');
      expect(sceneLabelForImageClassificationLabel('dining_room')).assertEqual('diningroom');
      expect(sceneLabelForImageClassificationLabel('living_room')).assertEqual('livingroom');
      expect(sceneLabelForImageClassificationLabel('bowling_alley')).assertEqual('bowlingalley');
      expect(sceneLabelForImageClassificationLabel('conference_room')).assertEqual('meetingroom');
      expect(sceneLabelForImageClassificationLabel('tiger_cat')).assertEqual('cat');
      expect(sceneLabelForImageClassificationLabel('tiger_shark')).assertEqual('ornamentalfish');
      expect(sceneLabelForImageClassificationLabel('coffee_shop')).assertEqual('restaurant');
      expect(sceneLabelForImageClassificationLabel('bookstore')).assertEqual('library');
      expect(sceneLabelForImageClassificationLabel('lecture_room')).assertEqual('classroom');
      expect(sceneLabelForImageClassificationLabel('sky')).assertEqual('bluesky');
      expect(sceneLabelForImageClassificationLabel('river')).assertEqual('watersurface');
      expect(sceneLabelForImageClassificationLabel('runway')).assertEqual('aircraft');
      expect(sceneLabelForImageClassificationLabel('subway_station')).assertEqual('train');
      expect(sceneLabelForImageClassificationLabel('florist_shop')).assertEqual('flower');
      expect(sceneLabelForImageClassificationLabel('pizzeria')).assertEqual('restaurant');
      expect(sceneLabelForImageClassificationLabel('apartment_building')).assertEqual('widebuildings');
      expect(sceneLabelForImageClassificationLabel('hotel_room')).assertEqual('bedroom');
      expect(sceneLabelForImageClassificationLabel('pub')).assertEqual('bar');
      expect(sceneLabelForImageClassificationLabel('aquarium')).assertEqual('ornamentalfish');
      expect(sceneLabelForImageClassificationLabel('fishpond')).assertEqual('ornamentalfish');
      expect(sceneLabelForImageClassificationLabel('snowfield')).assertEqual('snow');
      expect(sceneLabelForImageClassificationLabel('ski_slope')).assertEqual('snow');
      expect(sceneLabelForImageClassificationLabel('mountain_snowy')).assertEqual('snow');
      expect(sceneLabelForImageClassificationLabel('alley')).assertEqual('corridor');
      expect(sceneLabelForImageClassificationLabel('market')).assertEqual('supermarket');
      expect(sceneLabelForImageClassificationLabel('bazaar')).assertEqual('supermarket');
      expect(sceneLabelForImageClassificationLabel('flea_market')).assertEqual('supermarket');
      expect(sceneLabelForImageClassificationLabel('heliport')).assertEqual('helicopter');
      expect(sceneLabelForImageClassificationLabel('boat_deck')).assertEqual('ship');
      expect(sceneLabelForImageClassificationLabel('lighthouse')).assertEqual('waterside');
      expect(sceneLabelForImageClassificationLabel('glacier')).assertEqual('snow');
      expect(sceneLabelForImageClassificationLabel('iceberg')).assertEqual('snow');
      expect(sceneLabelForImageClassificationLabel('canyon')).assertEqual('mountain');
      expect(sceneLabelForImageClassificationLabel('lobby')).assertEqual('corridor');
      expect(sceneLabelForImageClassificationLabel('parking_lot')).assertEqual('car');
      expect(sceneLabelForImageClassificationLabel('parking_garage')).assertEqual('car');
      expect(sceneLabelForImageClassificationLabel('garage')).assertEqual('car');
      expect(sceneLabelForImageClassificationLabel('field')).assertEqual('greenplant');
      expect(sceneLabelForImageClassificationLabel('farm')).assertEqual('greenplant');
      expect(sceneLabelForImageClassificationLabel('lawn')).assertEqual('greenplant');
      expect(sceneLabelForImageClassificationLabel('basketball_court/indoor')).assertEqual('indoorbasketballco');
      expect(sceneLabelForImageClassificationLabel('bakery/shop')).assertEqual('food');
      expect(sceneLabelForImageClassificationLabel('bazaar/indoor')).assertEqual('supermarket');
      expect(sceneLabelForImageClassificationLabel('bazaar/outdoor')).assertEqual('supermarket');
      expect(sceneLabelForImageClassificationLabel('cabin/outdoor')).assertEqual('cabin');
      expect(sceneLabelForImageClassificationLabel('apartment_building/outdoor')).assertEqual('widebuildings');
      expect(sceneLabelForImageClassificationLabel('house')).assertEqual('widebuildings');
      expect(sceneLabelForImageClassificationLabel('cottage')).assertEqual('widebuildings');
      expect(sceneLabelForImageClassificationLabel('mansion')).assertEqual('widebuildings');
      expect(sceneLabelForImageClassificationLabel('tiger_beetle')).assertEqual('other');
      expect(sceneLabelForImageClassificationLabel('sea_lion')).assertEqual('other');
      expect(sceneLabelForImageClassificationLabel('crane')).assertEqual('other');
      expect(sceneLabelForImageClassificationLabel('accordion')).assertEqual('other');
      const runner = new ImageClassificationSceneDetectionRunner({
        labels: ['tench', 'espresso', 'seashore', 'sports_car'],
        scoreRunner: new FixedScoreRunner([0.05, 0.91, 0.82, 0.33]),
        maxScenes: 2
      });

      const result = await runner.detectScenes('file://selected/cafe.jpg');

      expect(result.ok).assertTrue();
      expect(result.scenes.length).assertEqual(2);
      expect(result.scenes[0].label).assertEqual('food');
      expect(result.scenes[0].score.toFixed(4)).assertEqual('0.3452');
      expect(result.scenes[1].label).assertEqual('beach');
      expect(result.scenes[1].score.toFixed(4)).assertEqual('0.3155');
    });

    it('localSceneDetectionRunnerKeepsCommonPlaces365Aliases', 0, () => {
      const scenes = topLocalSceneDetections(
        [0.95, 0.88, 0.81, 0.7],
        ['parking_lot', 'field', 'house', 'accordion'],
        3
      );

      expect(scenes.length).assertEqual(3);
      expect(scenes[0].label).assertEqual('car');
      expect(scenes[1].label).assertEqual('greenplant');
      expect(scenes[2].label).assertEqual('widebuildings');
    });

    it('localSceneDetectionRunnerKeepsMoreAndroidSceneCandidatesByDefault', 0, async () => {
      const runner = new ImageClassificationSceneDetectionRunner({
        labels: ['espresso', 'seashore', 'sports_car', 'bathroom', 'lecture_room', 'runway'],
        scoreRunner: new FixedScoreRunner([0.91, 0.82, 0.77, 0.66, 0.55, 0.44])
      });

      const result = await runner.detectScenes('file://selected/multi-scene.jpg');

      expect(localSceneDetectionMaxSceneCount).assertEqual(5);
      expect(result.scenes.length).assertEqual(5);
      expect(result.scenes[0].label).assertEqual('food');
      expect(result.scenes[1].label).assertEqual('beach');
      expect(result.scenes[2].label).assertEqual('car');
      expect(result.scenes[3].label).assertEqual('washroom');
      expect(result.scenes[4].label).assertEqual('classroom');
    });

    it('localSceneDetectionRunnerAppliesStableSoftmaxBeforeSelectingScenes', 0, async () => {
      const runner = new ImageClassificationSceneDetectionRunner({
        labels: ['field', 'sky', 'mountain'],
        scoreRunner: new FixedScoreRunner([13.8679, 9.8894, 7.5723]),
        maxScenes: 3
      });

      const result = await runner.detectScenes('file://selected/landscape.jpg');

      expect(result.ok).assertTrue();
      expect(result.scenes.length).assertEqual(3);
      expect(result.scenes[0].score.toFixed(4)).assertEqual('0.9799');
      expect(result.scenes[1].score.toFixed(4)).assertEqual('0.0183');
      expect(result.scenes[2].score.toFixed(4)).assertEqual('0.0018');
      const scoreSum = result.scenes.reduce((sum: number, scene: SceneDetection) => sum + scene.score, 0);
      expect(scoreSum.toFixed(6)).assertEqual('1.000000');
    });

    it('localSceneDetectionSoftmaxAcceptsNegativeLogitsWithoutForcingTopOneToHundredPercent', 0, () => {
      const scenes = topLocalSceneDetections(
        [-1, -2, -3],
        ['field', 'sky', 'mountain'],
        1
      );

      expect(scenes.length).assertEqual(1);
      expect(scenes[0].label).assertEqual('greenplant');
      expect(scenes[0].score.toFixed(4)).assertEqual('0.6652');
    });

    it('parseSceneDetectionLabelsReadsPlaces365List', 0, () => {
      expect(sceneDetectionLabelRawfilePath).assertEqual('labels/places365.txt');
      expect(sceneDetectionModelRawfilePath).assertEqual('model/resnet18-place365.ms');
      expect(places365SceneLabelCount).assertEqual(365);
      const labels = parseSceneDetectionLabels('airfield\r\nairplane_cabin\n\nzen_garden\n');
      expect(labels.length).assertEqual(3);
      expect(labels[0]).assertEqual('airfield');
      expect(labels[1]).assertEqual('airplane_cabin');
      expect(labels[2]).assertEqual('zen_garden');
    });

    it('topLocalSceneDetectionsUsesAllProvidedSceneLabels', 0, () => {
      const labels: Array<string> = [];
      const scores: Array<number> = [];
      for (let index = 0; index < 1002; index++) {
        labels.push(`placeholder_${index}`);
        scores.push(0);
      }
      labels[1001] = 'stage';
      scores[1001] = 0.77;

      const scenes = topLocalSceneDetections(scores, labels, 1);

      expect(scenes.length).assertEqual(1);
      expect(scenes[0].label).assertEqual('stage');
      expect(scenes[0].score.toFixed(6)).assertEqual('0.002153');
    });

    it('topLocalSceneDetectionsSkipsOtherWhenUsefulSceneExists', 0, () => {
      const scenes = topLocalSceneDetections(
        [0.99, 0.91, 0.82, 0.7],
        ['accordion', 'beach', 'unknown_scene', 'dining_room'],
        2
      );

      expect(scenes.length).assertEqual(2);
      expect(scenes[0].label).assertEqual('beach');
      expect(scenes[0].score.toFixed(4)).assertEqual('0.2626');
      expect(scenes[1].label).assertEqual('diningroom');
      expect(scenes[1].score.toFixed(4)).assertEqual('0.2129');
    });

    it('topLocalSceneDetectionsIgnoresNanScores', 0, () => {
      const scenes = topLocalSceneDetections(
        [Number.NaN, 0.64],
        ['accordion', 'beach'],
        2
      );

      expect(scenes.length).assertEqual(1);
      expect(scenes[0].label).assertEqual('beach');
      expect(scenes[0].score).assertEqual(1);

      const onlyNanOtherScenes = topLocalSceneDetections(
        [Number.NaN],
        ['accordion'],
        1
      );
      expect(onlyNanOtherScenes.length).assertEqual(0);
    });

    it('sceneDetectionKeepsAndroidOtherWhenOnlyOtherCandidatesRemain', 0, async () => {
      const scenes = topLocalSceneDetections([0.99, 0.88], ['accordion', 'unknown_scene'], 2);
      expect(scenes.length).assertEqual(1);
      expect(scenes[0].label).assertEqual('other');
      expect(scenes[0].score.toFixed(4)).assertEqual('0.5275');

      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const service = new SceneDetectionService({
        runner: new ImageClassificationSceneDetectionRunner({
          labels: ['accordion', 'unknown_scene'],
          scoreRunner: new FixedScoreRunner([0.99, 0.88]),
          maxScenes: 2
        })
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/unknown.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SCENE_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_scene_done');
      const rows = aiRunResultRows(result);
      expect(rows[0].labelKey).assertEqual('feature_runtime_result_scene_count');
      expect(rows[0].value).assertEqual('1');
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value).assertEqual('1. other 52.75%');
    });

    it('mapsAndroidSceneLabelsToChineseDisplayLabelsWithoutChangingUnknownLabels', 0, () => {
      expect(androidSceneDetectionLabels.length).assertEqual(androidSceneDetectionLabelsZh.length);
      expect(sceneDetectionDisplayLabel('stage', 'zh-CN')).assertEqual('舞台');
      expect(sceneDetectionDisplayLabel('beach', 'zh-Hans-CN')).assertEqual('沙滩');
      expect(sceneDetectionDisplayLabel('aircraft', 'zh-CN')).assertEqual('飞机');
      expect(sceneDetectionDisplayLabel('fucharacter', 'zh-CN')).assertEqual('福字');
      expect(sceneDetectionDisplayLabel('transformer', 'zh-CN')).assertEqual('变形金刚');
      expect(sceneDetectionDisplayLabel('other', 'zh-CN')).assertEqual('其他');
      expect(sceneDetectionDisplayLabel('stage', 'en-US')).assertEqual('stage');
      expect(sceneDetectionDisplayLabel('unknown_scene', 'zh-CN')).assertEqual('unknown_scene');
    });

    it('keepsEveryAndroidSceneChineseLabelReadable', 0, () => {
      expect(androidSceneDetectionLabels.length).assertEqual(104);
      expect(androidSceneDetectionLabelsZh.length).assertEqual(104);
      for (let index = 0; index < androidSceneDetectionLabelsZh.length; index++) {
        const label = androidSceneDetectionLabelsZh[index];
        expect(label.length > 0).assertTrue();
        expect(label.indexOf('?')).assertEqual(-1);
        expect(label.indexOf('\uFFFD')).assertEqual(-1);
        expect(label.indexOf('閸')).assertEqual(-1);
        expect(label.indexOf('缁')).assertEqual(-1);
        expect(label.indexOf('閻')).assertEqual(-1);
        expect(label.indexOf('鍦')).assertEqual(-1);
        expect(label.indexOf('绠')).assertEqual(-1);
        expect(label.indexOf('鐨')).assertEqual(-1);
        expect(label.indexOf('鑸')).assertEqual(-1);
      }
    });

    it('sceneDetectionServiceLocalizesAndroidSceneLabelsForChineseResultDisplay', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const scene: SceneDetection = { label: 'stage', score: 0.88 };
      const sceneResult: SceneDetectionResult = {
        ok: true,
        scenes: [scene],
        executionMs: 6
      };
      const service = new SceneDetectionService({
        labelLocale: 'zh-CN',
        runner: new FixedSceneDetectionRunner(sceneResult)
      });

      const result = await new DefaultAiService({ sceneDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/scene.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.detailText.indexOf('舞台 88.00%') >= 0).assertTrue();
      const rows = aiRunResultRows(result);
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value).assertEqual('1. 舞台 88.00%');
    });

    it('customModelRequiresModelAndImageInputs', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
      expect(result.messageKey).assertEqual('feature_runtime_custom_model_image_required');

      const imageOnlyResult = await new DefaultAiService().run(workflow!, {
        imageUri: 'file://selected/input.png'
      });
      expect(imageOnlyResult.ok).assertFalse();
      expect(imageOnlyResult.code).assertEqual('MISSING_INPUT');
      expect(imageOnlyResult.messageKey).assertEqual('feature_runtime_custom_model_model_required');

      const modelOnlyResult = await new DefaultAiService().run(workflow!, {
        modelUri: 'file://selected/custom_model.ms'
      });
      expect(modelOnlyResult.ok).assertFalse();
      expect(modelOnlyResult.code).assertEqual('MISSING_INPUT');
      expect(modelOnlyResult.messageKey).assertEqual('feature_runtime_custom_model_image_required');
    });

    it('customModelUsesAndroidSpecificInputAndOutputCopy', 0, () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const imageClassification = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      expect(imageClassification !== undefined).assertTrue();

      expect(workflowInputLabelKey(workflow, 'modelFile')).assertEqual('feature_runtime_custom_model_select_model');
      expect(workflowInputLabelKey(workflow, 'photo')).assertEqual('feature_runtime_custom_model_select_photo');
      expect(workflowInputLabelKey(workflow, 'camera')).assertEqual('feature_runtime_custom_model_take_photo');
      expect(workflowInputLabelKey(imageClassification, 'camera')).assertEqual('feature_input_camera');
      expect(workflowResultTitleKey(workflow)).assertEqual('feature_runtime_custom_model_output_title');
      expect(workflowResultTitleKey(imageClassification)).assertEqual('feature_runtime_result_title');
      expect(workflowInitialStatusKey(workflow)).assertEqual('feature_runtime_custom_model_output_placeholder');
      expect(workflowInitialStatusKey(imageClassification)).assertEqual('feature_runtime_status_idle');
    });

    it('hmsStillPhotoWorkflowsUseAndroidPhotoButtonCopy', 0, () => {
      const poseNet = workflowForRoute(AppRoute.POSENET.name);
      const segmentationStill = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const gestureStill = workflowForRoute(AppRoute.GESTURE_STILL.name);
      const sceneStill = workflowForRoute(AppRoute.SCENE_STILL.name);
      const textRecognition = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      const textTranslation = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);

      expect(workflowInputLabelKey(poseNet, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(poseNet, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(segmentationStill, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(segmentationStill, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(gestureStill, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(gestureStill, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(sceneStill, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(sceneStill, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(textRecognition, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(textRecognition, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(textTranslation, 'photo')).assertEqual('feature_input_photo_android');
      expect(workflowInputLabelKey(textTranslation, 'camera')).assertEqual('feature_input_camera_android');
      expect(workflowInputLabelKey(objectPhoto, 'photo')).assertEqual('feature_input_photo');
      expect(workflowInputLabelKey(objectPhoto, 'camera')).assertEqual('feature_input_camera');
      expect(workflowInputLabelKey(objectPhoto, 'modelFile')).assertEqual('feature_runtime_object_select_model');
      expect(workflowInputLabelKey(workflowForRoute(AppRoute.OBJECT_CAMERA.name), 'modelFile'))
        .assertEqual('feature_runtime_object_select_model');
      expect(workflowInputLabelKey(workflowForRoute(AppRoute.IMAGE_CAMERA.name), 'modelFile'))
        .assertEqual('feature_input_model_file');
      expect(workflowInputLabelKey(customModel, 'photo')).assertEqual('feature_runtime_custom_model_select_photo');
      expect(workflowInputLabelKey(customModel, 'camera')).assertEqual('feature_runtime_custom_model_take_photo');
    });

    it('hmsStillLinkedLiveWorkflowsUseAndroidRealTimeButtonCopy', 0, () => {
      const poseNet = workflowForRoute(AppRoute.POSENET.name);
      const segmentationStill = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const gestureStill = workflowForRoute(AppRoute.GESTURE_STILL.name);
      const sceneStill = workflowForRoute(AppRoute.SCENE_STILL.name);
      const textRecognition = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);
      const imageClassification = workflowForRoute(AppRoute.IMAGE_CAMERA.name);

      expect(workflowGoLiveLabelKey(poseNet)).assertEqual('feature_runtime_go_live_android_hms');
      expect(workflowGoLiveLabelKey(segmentationStill)).assertEqual('feature_runtime_go_live_android_hms');
      expect(workflowGoLiveLabelKey(gestureStill)).assertEqual('feature_runtime_go_live_android_hms');
      expect(workflowGoLiveLabelKey(sceneStill)).assertEqual('feature_runtime_go_live_android_hms');
      expect(workflowGoLiveLabelKey(textRecognition)).assertEqual('feature_runtime_go_live');
      expect(workflowGoLiveLabelKey(imageClassification)).assertEqual('feature_runtime_go_live');
    });

    it('styleTransferUsesAndroidSpecificInputCopy', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const imageClassification = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(styleTransfer !== undefined).assertTrue();
      expect(imageClassification !== undefined).assertTrue();

      expect(workflowInputLabelKey(styleTransfer, 'contentImage')).assertEqual('feature_runtime_style_album');
      expect(workflowInputLabelKey(styleTransfer, 'camera')).assertEqual('feature_runtime_style_take_photo');
      expect(workflowInputLabelKey(styleTransfer, 'stylePredictModelFile'))
        .assertEqual('feature_runtime_style_select_predict_model');
      expect(workflowInputLabelKey(styleTransfer, 'styleTransferModelFile'))
        .assertEqual('feature_runtime_style_select_transfer_model');
      expect(workflowInputLabelKey(styleTransfer, 'styleImage')).assertEqual('feature_input_style_image');
      expect(workflowInputLabelKey(imageClassification, 'camera')).assertEqual('feature_input_camera');
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

    it('decodesOnlyNonEmptyFloat32CustomModelOutputs', 0, () => {
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        new ArrayBuffer(4)
      )).assertTrue();
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_INT8,
        new ArrayBuffer(4)
      )).assertFalse();
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        new ArrayBuffer(0)
      )).assertFalse();
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        new ArrayBuffer(2)
      )).assertFalse();
      const nonFinite = new Float32Array(1);
      nonFinite[0] = Number.NaN;
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        nonFinite.buffer as ArrayBuffer
      )).assertFalse();
      expect(customModelOutputCanDecode(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        new ArrayBuffer(1024 * 1024 + 4)
      )).assertFalse();
    });

    it('rejectsIncoherentCustomModelOutputMetadataBeforeReadingTensorData', 0, () => {
      let getDataCalls = 0;
      const readData = (): ArrayBuffer => {
        getDataCalls++;
        return new ArrayBuffer(12);
      };

      expect(customModelOutputValuesFromMetadata(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32, 2, 12, [1, 3], readData
      ).length).assertEqual(0);
      expect(customModelOutputValuesFromMetadata(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32, 3, 8, [1, 3], readData
      ).length).assertEqual(0);
      expect(customModelOutputValuesFromMetadata(
        mindSporeLite.DataType.NUMBER_TYPE_FLOAT32, 3, 12, [1, 2], readData
      ).length).assertEqual(0);
      expect(getDataCalls).assertEqual(0);
    });

    it('rejectsCustomModelInputThatDoesNotMatchTheExactTensorByteContract', 0, async () => {
      const tensorRunner = new FixedCustomModelTensorRunner([0.1]);
      const service = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        tensorRunner: tensorRunner
      });

      const result = await service.run('file://selected/custom_model.ms', 'file://selected/input.png');

      expect(result.ok).assertFalse();
      expect(result.output.length).assertEqual(0);
      expect(tensorRunner.seenModelUris.length).assertEqual(0);
    });

    it('rejectsNonFiniteCustomModelOutputBeforePublishingSuccess', 0, async () => {
      const inputBuffer = new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT);
      const service = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(inputBuffer),
        tensorRunner: new FixedCustomModelTensorRunner([0.1, Number.POSITIVE_INFINITY])
      });

      const result = await service.run('file://selected/custom_model.ms', 'file://selected/input.png');

      expect(result.ok).assertFalse();
      expect(result.output.length).assertEqual(0);
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
      const inputBuffer: ArrayBuffer =
        new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT);
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
        preprocessor: new FixedCustomModelPreprocessor(
          new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT)
        ),
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

    it('customModelResultRowsShowAndroidStyleOutputValues', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(
          new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT)
        ),
        tensorRunner: new FixedCustomModelTensorRunner([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1])
      });

      const result = await new DefaultAiService({ customModelService: customModelService }).run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: 'file://selected/custom_model.ms'
      });

      const rows: Array<AiRunResultRow> = aiRunResultRows(result);
      const outputRows = rows.filter((row: AiRunResultRow) => row.labelKey === 'feature_runtime_result_output');

      expect(outputRows.length).assertEqual(1);
      expect(outputRows[0].value.indexOf('Output data (first 10 values):') >= 0).assertTrue();
      expect(outputRows[0].value.indexOf('Value[0]: 0.100000') >= 0).assertTrue();
      expect(outputRows[0].value.indexOf('... (showing first 10 values)') >= 0).assertTrue();
    });

    it('aiServiceRequiresCustomModelFileBeforeRunningAndroidCustomModel', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const tensorRunner: FixedCustomModelTensorRunner =
        new FixedCustomModelTensorRunner([0.1, 0.2, 0.3]);
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(new ArrayBuffer(12)),
        tensorRunner: tensorRunner
      });

      const result = await new DefaultAiService({ customModelService: customModelService }).run(workflow!, {
        imageUri: 'file://selected/input.png',
        modelUri: ''
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('MISSING_INPUT');
      expect(result.messageKey).assertEqual('feature_runtime_custom_model_model_required');
      expect(tensorRunner.seenModelUris.length).assertEqual(0);
    });

    it('customModelDefaultOrSelectedRunnerRequiresExplicitDefaultModelUri', 0, async () => {
      const defaultRunner: FixedCustomModelTensorRunner = new FixedCustomModelTensorRunner([0.1]);
      const selectedRunner: FixedCustomModelTensorRunner = new FixedCustomModelTensorRunner([0.9]);
      const runner = new CustomModelDefaultOrSelectedRunner({
        defaultModelRunner: defaultRunner,
        selectedModelRunner: selectedRunner
      });

      const defaultOutput = await runner.predictOutput(customModelDefaultModelUri, new ArrayBuffer(4));
      const selectedOutput = await runner.predictOutput('file://selected/custom.ms', new ArrayBuffer(8));
      const emptyOutput = await runner.predictOutput('', new ArrayBuffer(12));

      expect(defaultOutput[0]).assertEqual(0.1);
      expect(selectedOutput[0]).assertEqual(0.9);
      expect(emptyOutput[0]).assertEqual(0.9);
      expect(defaultRunner.seenModelUris[0]).assertEqual(customModelDefaultModelUri);
      expect(selectedRunner.seenModelUris[0]).assertEqual('file://selected/custom.ms');
      expect(selectedRunner.seenModelUris[1]).assertEqual('');
    });

    it('reloadsSelectedCustomModelBytesAfterSameUriReplacement', 0, async () => {
      const backend = new MutableFileUriContentBackend(new Uint8Array([1]));
      const runtime = new RecordingCustomModelBufferRuntime();
      const runner = new CustomModelSelectedFileRunner({
        modelContentReader: new FileUriContentReader(backend),
        runtime: runtime
      });
      const inputBuffer = new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT);

      const first = await runner.predictOutput('/cache/custom_model.ms', inputBuffer);
      backend.setContent(new Uint8Array([2]));
      const second = await runner.predictOutput('/cache/custom_model.ms', inputBuffer);

      expect(first[0]).assertEqual(1);
      expect(second[0]).assertEqual(2);
      expect(runtime.seenModelFirstBytes.join(',')).assertEqual('1,2');
    });

    it('serializesSelectedCustomModelLoadsAndPredictionsAcrossOverlappingRuns', 0, async () => {
      const runtime = new DelayedCustomModelBufferRuntime();
      const runner = new CustomModelSelectedFileRunner({
        modelContentReader: new FileUriContentReader(
          new FixedFileUriContentBackend(new Uint8Array([1]))
        ),
        runtime: runtime
      });
      const inputBuffer = new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT);

      await Promise.all([
        runner.predictOutput('/cache/custom_model.ms', inputBuffer),
        runner.predictOutput('/cache/custom_model.ms', inputBuffer)
      ]);

      expect(runtime.maxActive).assertEqual(1);
    });

    it('aiServiceReportsCustomModelRunnerFailureWithI18nKey', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const customModelService = new CustomModelService({
        preprocessor: new FixedCustomModelPreprocessor(
          new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT)
        ),
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
        preprocessor: new FixedCustomModelPreprocessor(
          new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT)
        ),
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
        stylePredictModelUri: 'file://selected/custom_predict.mnn',
        styleTransferModelUri: 'file://selected/custom_transfer.mnn'
      });

      expect(runner.seenPredictModelUris[0]).assertEqual('file://selected/custom_predict.mnn');
      expect(runner.seenTransferModelUris[0]).assertEqual('file://selected/custom_transfer.mnn');
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
      expect(stylePredictModelRawfilePath).assertEqual('model/style_predict_fp16.mnn');
      expect(styleTransferModelRawfilePath).assertEqual('model/style_transform_fp16.mnn');
      expect(stylePredictModelDownloadUrl).assertEqual(
        'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/prediction/1?lite-format=tflite'
      );
      expect(styleTransferModelDownloadUrl).assertEqual(
        'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/transfer/1?lite-format=tflite'
      );
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
      expect(styleTransferMaxOutputImageSize).assertEqual(1024);
    });

    it('restoresStyleTransferOutputToAndroidPreviewSizedContentImage', 0, () => {
      const small: StyleTransferImageSize = styleTransferOutputImageSizeForContent(800, 600);
      const large: StyleTransferImageSize = styleTransferOutputImageSizeForContent(4032, 3024);
      const invalidWidth: StyleTransferImageSize = styleTransferOutputImageSizeForContent(0, 600);
      const invalidHeight: StyleTransferImageSize = styleTransferOutputImageSizeForContent(800, undefined);

      expect(small.width).assertEqual(800);
      expect(small.height).assertEqual(600);
      expect(large.width).assertEqual(1024);
      expect(large.height).assertEqual(768);
      expect(invalidWidth.width).assertEqual(styleTransferContentImageSize);
      expect(invalidWidth.height).assertEqual(styleTransferContentImageSize);
      expect(invalidHeight.width).assertEqual(styleTransferContentImageSize);
      expect(invalidHeight.height).assertEqual(styleTransferContentImageSize);
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

    it('centerCropsTheShorterSideBeforeStyleTransferResize', 0, () => {
      const landscape = styleTransferCenterCropRegion(800, 600);
      expect(landscape.x).assertEqual(100);
      expect(landscape.y).assertEqual(0);
      expect(landscape.size.width).assertEqual(600);
      expect(landscape.size.height).assertEqual(600);
      const portrait = styleTransferCenterCropRegion(600, 800);
      expect(portrait.x).assertEqual(0);
      expect(portrait.y).assertEqual(100);
      expect(portrait.size.width).assertEqual(600);
      expect(portrait.size.height).assertEqual(600);
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

    it('styleTransferMindSporeRunnerRestoresAndroidContentImageSize', 0, async () => {
      const input: StyleTransferInput = new FixedSizedStyleTransferInput(800, 600);
      const preprocessor: FixedStyleTransferPreprocessor = new FixedStyleTransferPreprocessor(input);
      const tensorRunner: FixedStyleTransferTensorRunner = new FixedStyleTransferTensorRunner({
        output: new Float32Array(styleTransferOutputFloatCount),
        predictMs: 1,
        transferMs: 2
      });
      const resizer = new RecordingStyleTransferOutputImageResizer();
      const runner = new StyleTransferMindSporeRunner({
        preprocessor: preprocessor,
        tensorRunner: tensorRunner,
        outputImageResizer: resizer
      });

      const result = await runner.run('file://selected/content.jpg', 'file://selected/style.jpg');

      expect(result.outputImageWidth).assertEqual(800);
      expect(result.outputImageHeight).assertEqual(600);
      expect(result.outputImageRgba?.byteLength).assertEqual(800 * 600 * 4);
      expect(resizer.seenSourceWidths[0]).assertEqual(styleTransferContentImageSize);
      expect(resizer.seenSourceHeights[0]).assertEqual(styleTransferContentImageSize);
      expect(resizer.seenTargetWidths[0]).assertEqual(800);
      expect(resizer.seenTargetHeights[0]).assertEqual(600);
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
        predictModelUri: 'file://selected/custom_predict.mnn',
        transferModelUri: 'file://selected/custom_transfer.mnn'
      });

      expect(tensorRunner.seenPredictModelUris[0]).assertEqual('file://selected/custom_predict.mnn');
      expect(tensorRunner.seenTransferModelUris[0]).assertEqual('file://selected/custom_transfer.mnn');
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
      expect(imageClassificationModelDownloadUrl).assertEqual('https://download.mindspore.cn/model_zoo/official/lite/quick_start/mobilenetv2.ms');
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

    it('usesNanoDetObjectDetectionAssetContract', 0, () => {
      expect(objectCategoryLabelRawfilePath).assertEqual('labels/object_category.txt');
      expect(objectDetectionModelRawfilePath).assertEqual('model/nanodet_plus_m_320.mnn');
      expect(objectDetectionModelDownloadUrl).assertEqual('https://github.com/RangiLyu/nanodet/releases/download/v1.0.0-alpha-1/nanodet-plus-m_320.onnx');
    });

    it('enablesStyleTransferSaveOnlyForACurrentReadyResult', 0, () => {
      expect(styleTransferSaveReady(false, false, false)).assertFalse();
      expect(styleTransferSaveReady(false, true, false)).assertTrue();
      expect(styleTransferSaveReady(true, true, false)).assertFalse();
      expect(styleTransferSaveReady(false, true, true)).assertFalse();
    });

    it('runsTheTwoNamedMnnStagesOffTheArktsPathAndReusesTheLoadedPair', 0, async () => {
      const runtime = new RecordingStyleTransferMnnRuntime({
        output: new Float32Array(styleTransferOutputFloatCount),
        predictMs: 3,
        transferMs: 5
      });
      const resourceReader = new FixedRawfileContentReader(new Uint8Array([1, 2, 3, 4]));
      const runner = new LocalMnnStyleTransferTensorRunner({
        resourceManager: resourceReader,
        predictModelRawfilePath: stylePredictModelRawfilePath,
        transferModelRawfilePath: styleTransferModelRawfilePath,
        runtime: runtime
      });
      const input: StyleTransferInput = {
        styleInputBuffer: new ArrayBuffer(styleTransferStyleImageSize * styleTransferStyleImageSize * 3 * 4),
        contentInputBuffer: new ArrayBuffer(styleTransferContentImageSize * styleTransferContentImageSize * 3 * 4)
      };

      const first = await runner.runStyleTransfer(input);
      const second = await runner.runStyleTransfer(input);

      expect(first.output.length).assertEqual(styleTransferOutputFloatCount);
      expect(first.predictMs).assertEqual(3);
      expect(first.transferMs).assertEqual(5);
      expect(second.output.length).assertEqual(styleTransferOutputFloatCount);
      expect(runtime.loadedPredictByteLengths.length).assertEqual(1);
      expect(runtime.loadedTransferByteLengths.length).assertEqual(1);
      expect(runtime.seenStyleFloatCounts.join(',')).assertEqual('196608,196608');
      expect(runtime.seenContentFloatCounts.join(',')).assertEqual('442368,442368');
      expect(resourceReader.seenPaths.join(',')).assertEqual(
        `${stylePredictModelRawfilePath},${styleTransferModelRawfilePath}`
      );
    });

    it('definesNanoDetObjectDetectionPreprocessContract', 0, () => {
      expect(objectDetectionInputSize).assertEqual(320);
      expect(objectDetectionInputFloatCount).assertEqual(320 * 320 * 3);
    });

    it('normalizesObjectDetectionRgbaToBgrNchwInputAtTheLegacyContractLocation', 0, () => {
      const rgba: Uint8Array = new Uint8Array(objectDetectionInputSize * objectDetectionInputSize * 4);
      rgba[0] = 255;
      rgba[1] = 0;
      rgba[2] = 0;
      rgba[3] = 77;

      const input = new Float32Array(normalizedObjectDetectionRgbInputFromRgba(rgba));

      expect(input.length).assertEqual(objectDetectionInputFloatCount);
      const planeSize = objectDetectionInputSize * objectDetectionInputSize;
      expect(input[0].toFixed(6)).assertEqual('-1.804444');
      expect(input[planeSize].toFixed(6)).assertEqual('-2.035714');
      expect(input[planeSize * 2].toFixed(6)).assertEqual('2.248908');
    });

    it('requestsObjectDetectionDecodeAsNanoDet320Rgba', 0, () => {
      const options: image.DecodingOptions = objectDetectionDecodeOptions();
      expect(options.desiredSize!.width).assertEqual(320);
      expect(options.desiredSize!.height).assertEqual(320);
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

      const result: ObjectDetectionRunResult = await service.detectObjects('file://selected/street.jpg', 'file://selected/model.mnn');

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('DETECTION_DONE');
      expect(result.detections.length).assertEqual(1);
      expect(result.detections[0].label).assertEqual('person');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/street.jpg');
      expect(runner.seenModelUris[0]).assertEqual('file://selected/model.mnn');
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

    it('keepsLiveObjectDetectionLabelsInsideEveryCanvasEdge', 0, () => {
      const topEdge: ObjectDetectionLiveLabelPlacement = objectDetectionLiveLabelPlacement(
        { left: 8, top: 2, width: 80, height: 60 },
        360,
        640,
        12
      );
      expect(topEdge.left >= 0).assertTrue();
      expect(topEdge.top >= 0).assertTrue();
      expect(topEdge.left + topEdge.maxWidth <= 360).assertTrue();
      expect(topEdge.top + topEdge.estimatedHeight <= 640).assertTrue();
      expect(topEdge.top >= 66).assertTrue();

      const bottomRight: ObjectDetectionLiveLabelPlacement = objectDetectionLiveLabelPlacement(
        { left: 342, top: 612, width: 40, height: 40 },
        360,
        640,
        36
      );
      expect(bottomRight.left >= 0).assertTrue();
      expect(bottomRight.top >= 0).assertTrue();
      expect(bottomRight.left + bottomRight.maxWidth <= 360).assertTrue();
      expect(bottomRight.top + bottomRight.estimatedHeight <= 640).assertTrue();
    });

    it('allocatesNaturalHeightForLongLiveObjectLabels', 0, () => {
      const box: ObjectDetectionLiveOverlayBox = { left: 100, top: 280, width: 80, height: 120 };
      const shortLabel = objectDetectionLiveLabelPlacement(box, 360, 640, 8);
      const longLabel = objectDetectionLiveLabelPlacement(box, 360, 640, 48);

      expect(longLabel.estimatedHeight > shortLabel.estimatedHeight).assertTrue();
      expect(longLabel.left + longLabel.maxWidth <= 360).assertTrue();
      expect(longLabel.top + longLabel.estimatedHeight <= 640).assertTrue();
      expect(objectDetectionLiveLabelPlacement(box, 0, 640, 8).maxWidth).assertEqual(0);
    });

    it('usesAndroidObjectDetectionOverlayPaletteByResultOrder', 0, () => {
      expect(objectDetectionOverlayColor(0)).assertEqual('#FFFFFF');
      expect(objectDetectionOverlayColor(1)).assertEqual('#6DA7FF');
      expect(objectDetectionOverlayColor(2)).assertEqual('#F8E71C');
      expect(objectDetectionOverlayColor(3)).assertEqual('#FF844D');
      expect(objectDetectionOverlayColor(4)).assertEqual('#66B50A');
      expect(objectDetectionOverlayColor(5)).assertEqual('#FFFFFF');
      expect(objectDetectionOverlayTextColor(0)).assertEqual('#333333');
      expect(objectDetectionOverlayTextColor(1)).assertEqual('#333333');
      expect(objectDetectionOverlayTextColor(2)).assertEqual('#333333');
      expect(objectDetectionOverlayTextColor(3)).assertEqual('#333333');
      expect(objectDetectionOverlayTextColor(4)).assertEqual('#333333');
    });

    it('formatsObjectDetectionOverlayLabelsLikeAndroidRectView', 0, () => {
      const detection: ObjectDetection = {
        imageId: 741,
        labelId: 1,
        label: 'person',
        score: 0.75,
        left: 1,
        top: 2,
        right: 101,
        bottom: 202
      };
      const unlabeledDetection: ObjectDetection = {
        imageId: 1900,
        labelId: 7,
        label: '',
        score: 0.1234,
        left: 1,
        top: 2,
        right: 101,
        bottom: 202
      };

      expect(objectDetectionOverlayLabel(detection, 0)).assertEqual('1-person-75.00%');
      expect(objectDetectionOverlayLabel(unlabeledDetection, 4)).assertEqual('5-7-12.34%');
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

    it('objectDetectionServiceTreatsEmptyRunnerResultAsSuccessfulNoTargetDetection', 0, async () => {
      const service = new ObjectDetectionService({
        labels: ['background'],
        runner: new FixedObjectDetectionRunner([])
      });

      const result: ObjectDetectionRunResult = await service.detectObjects('file://selected/street.jpg');

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('DETECTION_DONE');
      expect(result.detections.length).assertEqual(0);
    });

    it('aiServiceReportsSuccessfulEmptyResultWhenNoObjectsAreDetected', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const service = new ObjectDetectionService({
        labels: ['background'],
        runner: new FixedObjectDetectionRunner([])
      });

      const result: AiRunResult = await new DefaultAiService({ objectDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/street.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('OBJECT_DETECTION_DONE');
      expect(result.messageKey).assertEqual('feature_runtime_object_detection_done');
      expect(result.data !== undefined).assertTrue();
      if (result.data !== undefined && result.data.kind === 'objectDetections') {
        expect(result.data.detections.length).assertEqual(0);
      }
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
        modelUri: 'file://selected/model.mnn'
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

    it('aiServiceObjectDetectionRowsListAllDetections', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const person: ObjectDetection = {
        imageId: 4,
        labelId: 1,
        label: 'person',
        score: 0.75,
        left: 1,
        top: 2,
        right: 101,
        bottom: 202
      };
      const bicycle: ObjectDetection = {
        imageId: 4,
        labelId: 2,
        label: 'bicycle',
        score: 0.60,
        left: 12,
        top: 22,
        right: 112,
        bottom: 222
      };
      const service = new ObjectDetectionService({
        labels: ['background', 'person', 'bicycle'],
        runner: new FixedObjectDetectionRunner([person, bicycle])
      });

      const result: AiRunResult = await new DefaultAiService({ objectDetectionService: service }).run(workflow!, {
        imageUri: 'file://selected/street.jpg'
      });
      const rows: Array<AiRunResultRow> = aiRunResultRows(result);
      const detectionsRow = rows.filter((row: AiRunResultRow) => row.labelKey === 'feature_runtime_result_detections')[0];

      expect(result.ok).assertTrue();
      expect(detectionsRow.value.indexOf('1. person 75.00%') >= 0).assertTrue();
      expect(detectionsRow.value.indexOf('2. bicycle 60.00%') >= 0).assertTrue();
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

    it('runtimeFactoryInjectsObjectDetectionServiceWithLocalizedChineseLabels', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        232, 131, 140, 230, 153, 175, 10,
        228, 186, 186
      ]);
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
        labelLocale: 'zh-CN',
        objectDetectionRunner: new FixedObjectDetectionRunner([detection])
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/street.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/zh_CN/object_category.txt');
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('OBJECT_DETECTION_DONE');
      expect(aiRunResultRows(result)[1].value.indexOf('人') >= 0).assertTrue();
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

    it('continuesSelectedModelReadsUntilTheDeclaredFileSizeIsComplete', 0, async () => {
      const backend = new ChunkedFileUriContentBackend(new Uint8Array([1, 2, 3, 4, 5]), 2);

      const content = await new FileUriContentReader(backend).readFileContent('file://selected/large.ms');

      expect(content.length).assertEqual(5);
      expect(content.join(',')).assertEqual('1,2,3,4,5');
      expect(backend.events.join('|')).assertEqual(
        'open:file://selected/large.ms|size:44|read:44:0|read:44:0|read:44:0|close:44'
      );
    });

    it('readsMoreThanOneMiBExactlyAcrossSequentialShortReads', 0, async () => {
      const byteCount = 1024 * 1024 + 37;
      const expected = new Uint8Array(byteCount);
      for (let index = 0; index < expected.length; index++) {
        expected[index] = (index * 31 + 7) % 256;
      }
      const backend = new ChunkedFileUriContentBackend(expected, 65537);

      const actual = await new FileUriContentReader(backend).readFileContent('file://selected/large-exact.ms');

      let mismatches = 0;
      for (let index = 0; index < expected.length; index++) {
        if (actual[index] !== expected[index]) {
          mismatches++;
        }
      }
      expect(actual.length).assertEqual(expected.length);
      expect(mismatches).assertEqual(0);
      expect(backend.events.filter((event: string): boolean => event === 'read:44:0').length > 2).assertTrue();
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

    it('mapsExifOrientationToAndroidRotationDegrees', 0, () => {
      expect(imageRotationDegreesFromOrientationProperty('Right-top')).assertEqual(90);
      expect(imageRotationDegreesFromOrientationProperty('6')).assertEqual(90);
      expect(imageRotationDegreesFromOrientationProperty('Bottom-right')).assertEqual(180);
      expect(imageRotationDegreesFromOrientationProperty('3')).assertEqual(180);
      expect(imageRotationDegreesFromOrientationProperty('Left-bottom')).assertEqual(270);
      expect(imageRotationDegreesFromOrientationProperty('8')).assertEqual(270);
      expect(imageRotationDegreesFromOrientationProperty('Top-left')).assertEqual(0);
      expect(imageRotationDegreesFromOrientationProperty('Unknown Value 9')).assertEqual(0);
    });

    it('addsExifRotationToHarmonyDecodeOptions', 0, () => {
      const options: image.DecodingOptions = decodingOptionsWithImageRotation({
        desiredSize: {
          width: 300,
          height: 300
        },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      }, 90);

      expect(options.rotate).assertEqual(90);
      expect(options.desiredSize!.width).assertEqual(300);
      expect(options.desiredPixelFormat).assertEqual(image.PixelMapFormat.RGBA_8888);
    });

    it('swapsImageSizeForQuarterTurnExifRotation', 0, () => {
      const rotated = rotatedImageSize(640, 480, 90);
      const normal = rotatedImageSize(640, 480, 180);

      expect(rotated.width).assertEqual(480);
      expect(rotated.height).assertEqual(640);
      expect(normal.width).assertEqual(640);
      expect(normal.height).assertEqual(480);
    });

    it('decodesRawfileAsciiContentForAndroidLabels', 0, () => {
      const content: Uint8Array = new Uint8Array([116, 101, 110, 99, 104, 13, 10, 103, 111, 108, 100, 102, 105, 115, 104]);
      expect(rawfileAsciiContentToText(content)).assertEqual('tench\r\ngoldfish');
    });

    it('decodesRawfileUtf8ContentForLocalizedAndroidLabels', 0, () => {
      const content: Uint8Array = new Uint8Array([233, 135, 145, 233, 177, 188]);
      expect(rawfileUtf8ContentToText(content)).assertEqual('金鱼');
    });

    it('selectsAndroidLocalizedLabelRawfilesForChineseLocales', 0, () => {
      expect(imageCategoryLabelRawfilePathForLocale('zh-CN')).assertEqual('labels/zh_CN/image_category_old.txt');
      expect(imageCategoryLabelRawfilePathForLocale('zh-Hans-CN')).assertEqual('labels/zh_CN/image_category_old.txt');
      expect(imageCategoryLabelRawfilePathForLocale('en-US')).assertEqual('labels/image_category_old.txt');
      expect(imageCategoryLabelRawfilePathForLocale('')).assertEqual('labels/image_category_old.txt');
      expect(objectCategoryLabelRawfilePathForLocale('zh_CN')).assertEqual('labels/zh_CN/object_category.txt');
      expect(objectCategoryLabelRawfilePathForLocale('en')).assertEqual('labels/object_category.txt');
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
      expect(result.messageKey).assertEqual('feature_runtime_classification_runner_unavailable');
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

    it('createsHarmonyDefaultAiServiceWithLocalizedChineseImageLabels', 0, async () => {
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        231, 187, 191, 233, 179, 141, 233, 177, 188, 10,
        233, 135, 145, 233, 177, 188
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await createHarmonyDefaultAiService({
        resourceManager: resourceManager,
        labelLocale: 'zh-CN',
        inputPreprocessor: new FixedInputPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedTensorRunner([0.1, 0.9])
      });

      const result = await service.run(workflow!, {
        imageUri: 'file://selected/fish.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/zh_CN/image_category_old.txt');
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('CLASSIFICATION_DONE');
      expect(aiRunResultRows(result)[0].value).assertEqual('金鱼');
    });

    it('cachedRuntimeFactoryReloadsDefaultClassificationServiceWhenLabelLocaleChanges', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      try {
        const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
        expect(workflow !== undefined).assertTrue();

        setHarmonyRuntimeLabelLocaleForTests('en-US');
        const englishLabels: Uint8Array = new Uint8Array([
          116, 101, 110, 99, 104, 10,
          103, 111, 108, 100, 102, 105, 115, 104
        ]);
        const englishResourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(englishLabels);
        const firstService = await cachedRuntimeAiServiceForWorkflow(workflow!, englishResourceManager);

        setHarmonyRuntimeLabelLocaleForTests('zh-CN');
        const chineseLabels: Uint8Array = new Uint8Array([
          231, 187, 191, 233, 179, 141, 233, 177, 188, 10,
          233, 135, 145, 233, 177, 188
        ]);
        const chineseResourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(chineseLabels);
        const secondService = await cachedRuntimeAiServiceForWorkflow(workflow!, chineseResourceManager);

        expect(firstService === secondService).assertFalse();
        expect(englishResourceManager.seenPaths.length).assertEqual(1);
        expect(englishResourceManager.seenPaths[0]).assertEqual('labels/image_category_old.txt');
        expect(chineseResourceManager.seenPaths.length).assertEqual(1);
        expect(chineseResourceManager.seenPaths[0]).assertEqual('labels/zh_CN/image_category_old.txt');
      } finally {
        resetHarmonyRuntimeAiServiceCachesForTests();
      }
    });

    it('cachedRuntimeFactoryRetriesDefaultClassificationServiceAfterLoadFailure', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      const workflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      let rejected = false;
      try {
        await cachedRuntimeAiServiceForWorkflow(workflow, new ThrowingRawfileContentReader());
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();

      const labels: Uint8Array = new Uint8Array([
        116, 101, 110, 99, 104, 10,
        103, 111, 108, 100, 102, 105, 115, 104
      ]);
      const reader = new FixedRawfileContentReader(labels);
      const service = await cachedRuntimeAiServiceForWorkflow(workflow, reader);

      expect(service !== undefined).assertTrue();
      expect(reader.seenPaths.length).assertEqual(1);
      resetHarmonyRuntimeAiServiceCachesForTests();
    });

    it('runtimeAiServiceSessionReusesServiceForSameRoute', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      let creates = 0;

      const first = await session.getOrCreate(workflow, async () => {
        creates++;
        return new DefaultAiService();
      });
      const second = await session.getOrCreate(workflow, async () => {
        creates++;
        return new DefaultAiService();
      });

      expect(first === second).assertTrue();
      expect(creates).assertEqual(1);
    });

    it('runtimeAiServiceSessionReusesOverlappingInFlightCreation', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      let creates = 0;
      let resolveCreation: ((service: DefaultAiService) => void) | undefined = undefined;
      const pending = new Promise<DefaultAiService>((resolve: (service: DefaultAiService) => void) => {
        resolveCreation = resolve;
      });
      const creator = (): Promise<DefaultAiService> => {
        creates++;
        return pending;
      };

      const firstPromise = session.getOrCreate(workflow, creator);
      const secondPromise = session.getOrCreate(workflow, creator);

      expect(creates).assertEqual(1);
      const service = new DefaultAiService();
      resolveCreation!(service);
      const first = await firstPromise;
      const second = await secondPromise;
      expect(first === service).assertTrue();
      expect(second === service).assertTrue();
    });

    it('runtimeAiServiceSessionCreatesAgainAfterInvalidation', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      let creates = 0;
      const creator = async (): Promise<DefaultAiService> => {
        creates++;
        return new DefaultAiService();
      };

      const first = await session.getOrCreate(workflow, creator);
      session.invalidate();
      const second = await session.getOrCreate(workflow, creator);

      expect(first === second).assertFalse();
      expect(creates).assertEqual(2);
    });

    it('runtimeAiServiceSessionInvalidationStopsCachedGestureServiceExactlyOnce', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const runner = new StoppingGestureRunner();
      const service = new DefaultAiService({
        gestureService: new GestureService({ runner: runner })
      });
      await session.getOrCreate(workflow, async (): Promise<DefaultAiService> => service);

      session.invalidate();
      session.invalidate();
      await Promise.resolve();

      expect(runner.stopCount).assertEqual(1);
    });

    it('runtimeAiServiceSessionInvalidationStopsPendingGestureServiceAndDoesNotReturnIt', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const runner = new StoppingGestureRunner();
      const service = new DefaultAiService({
        gestureService: new GestureService({ runner: runner })
      });
      let resolveCreation: ((service: DefaultAiService) => void) | undefined = undefined;
      const creation = new Promise<DefaultAiService>((resolve: (value: DefaultAiService) => void) => {
        resolveCreation = resolve;
      });
      const requested = session.getOrCreate(workflow, (): Promise<DefaultAiService> => creation);

      session.invalidate();
      resolveCreation!(service);
      let rejected = false;
      try {
        await requested;
      } catch (_) {
        rejected = true;
      }
      await Promise.resolve();

      expect(rejected).assertTrue();
      expect(runner.stopCount).assertEqual(1);
    });

    it('runtimeAiServiceSessionInvalidationRejectsEveryPendingSameRouteWaiter', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const staleRunner = new StoppingGestureRunner();
      const staleService = new DefaultAiService({
        gestureService: new GestureService({ runner: staleRunner })
      });
      let resolveCreation: ((service: DefaultAiService) => void) | undefined = undefined;
      const creation = new Promise<DefaultAiService>((resolve: (value: DefaultAiService) => void) => {
        resolveCreation = resolve;
      });
      let creates = 0;
      const creator = (): Promise<DefaultAiService> => {
        creates++;
        return creation;
      };

      const first = session.getOrCreate(workflow, creator).then(
        (_service: DefaultAiService): boolean => false,
        (_error: Error): boolean => true
      );
      const second = session.getOrCreate(workflow, creator).then(
        (_service: DefaultAiService): boolean => false,
        (_error: Error): boolean => true
      );
      expect(creates).assertEqual(1);
      session.invalidate();
      resolveCreation!(staleService);

      expect(await first).assertTrue();
      expect(await second).assertTrue();
      await Promise.resolve();
      expect(staleRunner.stopCount).assertEqual(1);

      const freshService = new DefaultAiService();
      const fresh = await session.getOrCreate(workflow, async (): Promise<DefaultAiService> => {
        creates++;
        return freshService;
      });
      expect(fresh === freshService).assertTrue();
      expect(creates).assertEqual(2);
    });

    it('runtimeAiServiceSessionCreatesAgainForDifferentRoute', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const firstWorkflow: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      const secondWorkflow: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;
      let creates = 0;
      const creator = async (): Promise<DefaultAiService> => {
        creates++;
        return new DefaultAiService();
      };

      const first = await session.getOrCreate(firstWorkflow, creator);
      const second = await session.getOrCreate(secondWorkflow, creator);

      expect(first === second).assertFalse();
      expect(creates).assertEqual(2);
    });

    it('runtimeAiServiceSessionRetriesRejectedCreation', 0, async () => {
      const session = new RuntimeAiServiceSession();
      const workflow: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      let creates = 0;
      let failed = false;

      try {
        await session.getOrCreate(workflow, async () => {
          creates++;
          throw new Error('create failed');
        });
      } catch (_) {
        failed = true;
      }
      const service = await session.getOrCreate(workflow, async () => {
        creates++;
        return new DefaultAiService();
      });

      expect(failed).assertTrue();
      expect(service !== undefined).assertTrue();
      expect(creates).assertEqual(2);
    });

    it('runtimeRequestGenerationInvalidatesOlderAndDisappearedPageRequests', 0, () => {
      const generation = new RuntimeRequestGeneration();
      const first = generation.begin();
      expect(generation.isCurrent(first)).assertTrue();

      const second = generation.begin();
      expect(generation.isCurrent(first)).assertFalse();
      expect(generation.isCurrent(second)).assertTrue();

      generation.invalidate();
      expect(generation.isCurrent(second)).assertFalse();
    });

    it('runtimePixelMapOwnerReleasesReplacedAndClearedValuesOnce', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const first = new FakeReleasablePixelMap();
      const second = new FakeReleasablePixelMap();

      owner.accept(owner.beginReplacement(), first);
      owner.accept(owner.beginReplacement(), second);
      owner.clear();
      owner.clear();

      expect(first.releaseCount).assertEqual(1);
      expect(second.releaseCount).assertEqual(1);
      expect(owner.current()).assertUndefined();
    });

    it('runtimePixelMapOwnerRejectsAndReleasesStaleValues', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const staleRequestId = owner.beginReplacement();
      const stale = new FakeReleasablePixelMap();
      owner.beginReplacement();

      const accepted = owner.accept(staleRequestId, stale);
      owner.clear();

      expect(accepted).assertFalse();
      expect(stale.releaseCount).assertEqual(1);
      expect(owner.current()).assertUndefined();
    });

    it('runtimePixelMapOwnerInvalidatesPendingReplacementWithoutReleasingCurrentValue', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const current = new FakeReleasablePixelMap();
      owner.accept(owner.beginReplacement(), current);
      const pendingRequestId = owner.beginReplacement();
      const stale = new FakeReleasablePixelMap();

      owner.invalidatePendingReplacement();
      const accepted = owner.accept(pendingRequestId, stale);

      expect(accepted).assertFalse();
      expect(stale.releaseCount).assertEqual(1);
      expect(owner.current() === current).assertTrue();
      expect(current.releaseCount).assertEqual(0);
    });

    it('runtimePixelMapOwnerDoesNotReleaseStaleAliasOfCurrentValue', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const value = new FakeReleasablePixelMap();
      owner.accept(owner.beginReplacement(), value);
      const staleRequestId = owner.beginReplacement();
      owner.beginReplacement();

      const accepted = owner.accept(staleRequestId, value);

      expect(accepted).assertFalse();
      expect(value.releaseCount).assertEqual(0);
      owner.clear();
      expect(value.releaseCount).assertEqual(1);
    });

    it('runtimePixelMapOwnerDoesNotReleaseSameCurrentValueTwice', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const value = new FakeReleasablePixelMap();
      const requestId = owner.beginReplacement();

      owner.accept(requestId, value);
      owner.accept(requestId, value);
      owner.clear();

      expect(value.releaseCount).assertEqual(1);
    });

    it('runtimePixelMapOwnerSwallowsReleaseRejections', 0, async () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const rejecting = new FakeReleasablePixelMap(true);
      owner.accept(owner.beginReplacement(), rejecting);

      owner.clear();
      await Promise.resolve();

      expect(rejecting.releaseCount).assertEqual(1);
      expect(owner.current()).assertUndefined();
    });

    it('clearRuntimePixelMapStateReleasesOwnerAndReturnsUndefined', 0, () => {
      const owner = new RuntimePixelMapOwner<FakeReleasablePixelMap>();
      const value = new FakeReleasablePixelMap();
      owner.accept(owner.beginReplacement(), value);

      const state = clearRuntimePixelMapState(owner);

      expect(state).assertUndefined();
      expect(owner.current()).assertUndefined();
      expect(value.releaseCount).assertEqual(1);
    });

    it('mapsImageClassificationLabelsToLocalGestureCategories', 0, () => {
      expect(gestureCategoryForImageClassificationLabel('mitten')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('boxing_glove')).assertEqual(10);
      expect(gestureCategoryForImageClassificationLabel('thumb_up')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('Closed_Fist')).assertEqual(10);
      expect(gestureCategoryForImageClassificationLabel('Thumb_Up')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('Thumb_Down')).assertEqual(9);
      expect(gestureCategoryForImageClassificationLabel('Open_Palm')).assertEqual(4);
      expect(gestureCategoryForImageClassificationLabel('palm')).assertEqual(4);
      expect(gestureCategoryForImageClassificationLabel('high_five')).assertEqual(4);
      expect(gestureCategoryForImageClassificationLabel('Pointing_Up')).assertEqual(0);
      expect(gestureCategoryForImageClassificationLabel('Victory')).assertEqual(1);
      expect(gestureCategoryForImageClassificationLabel('peace_sign')).assertEqual(1);
      expect(gestureCategoryForImageClassificationLabel('OK sign')).assertEqual(13);
      expect(gestureCategoryForImageClassificationLabel('finger heart gesture')).assertEqual(12);
      expect(gestureCategoryForImageClassificationLabel('DISS')).assertEqual(9);
      expect(gestureCategoryForImageClassificationLabel('thumb_down_gesture')).assertEqual(9);
      expect(gestureCategoryForImageClassificationLabel('like_gesture')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('thumbs_up_gesture')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('hand_thumb_up')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('thumb_up_hand')).assertEqual(11);
      expect(gestureCategoryForImageClassificationLabel('hand_open_palm')).assertEqual(4);
      expect(gestureCategoryForImageClassificationLabel('victory_hand')).assertEqual(1);
      expect(gestureCategoryForImageClassificationLabel('closed_fist_hand')).assertEqual(10);
      expect(gestureCategoryForImageClassificationLabel('ok_sign_hand')).assertEqual(13);
      expect(gestureCategoryForImageClassificationLabel('heart_gesture')).assertEqual(12);
      expect(gestureCategoryForImageClassificationLabel('finger_heart_hand')).assertEqual(12);
      expect(gestureCategoryForImageClassificationLabel('gesture_one')).assertEqual(0);
      expect(gestureCategoryForImageClassificationLabel('one_gesture')).assertEqual(0);
      expect(gestureCategoryForImageClassificationLabel('hand_five_gesture')).assertEqual(4);
      expect(gestureCategoryForImageClassificationLabel('gesture_ok_sign')).assertEqual(13);
      expect(gestureCategoryForImageClassificationLabel('like')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('nail')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('hand-held_computer')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('three-toed_sloth')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('bicycle-built-for-two')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('four-poster')).assertEqual(-1);
      expect(gestureCategoryForImageClassificationLabel('goldfish')).assertEqual(-1);
    });

    it('estimatesGestureForegroundRegionFromRgbaPixels', 0, () => {
      const rgba = new Uint8Array(4 * 4 * 4);
      for (let index = 0; index < rgba.length; index += 4) {
        rgba[index] = 255;
        rgba[index + 1] = 255;
        rgba[index + 2] = 255;
        rgba[index + 3] = 255;
      }
      for (let y = 1; y <= 2; y++) {
        for (let x = 1; x <= 2; x++) {
          const offset = (y * 4 + x) * 4;
          rgba[offset] = 96;
          rgba[offset + 1] = 72;
          rgba[offset + 2] = 64;
        }
      }

      const rect = gestureRectangleFromRgbaForeground(rgba, 4, 4);

      expect(rect !== undefined).assertTrue();
      if (rect === undefined) {
        return;
      }
      expect(rect.left).assertEqual(1);
      expect(rect.top).assertEqual(1);
      expect(rect.width).assertEqual(2);
      expect(rect.height).assertEqual(2);
    });

    it('rejectsOverbroadGestureForegroundRegionForNaturalBackgrounds', 0, () => {
      const rgba = new Uint8Array(4 * 4 * 4);
      for (let y = 0; y < 4; y++) {
        for (let x = 0; x < 4; x++) {
          const offset = (y * 4 + x) * 4;
          rgba[offset] = x === 0 ? 40 : 220;
          rgba[offset + 1] = y === 0 ? 60 : 210;
          rgba[offset + 2] = 120;
          rgba[offset + 3] = 255;
        }
      }

      const rect = gestureRectangleFromRgbaForeground(rgba, 4, 4);

      expect(rect === undefined).assertTrue();
    });

    it('imageClassificationGestureRunnerRejectsBundledImageNetMittenLabel', 0, async () => {
      const runner = new ImageClassificationGestureRunner({
        labels: ['goldfish', 'mitten', 'nail'],
        scoreRunner: new FixedScoreRunner([0.1, 0.82, 0.35])
      });

      const result = await runner.detectGesture('file://selected/hand.jpg');

      expect(result.ok).assertFalse();
      expect(result.gestures.length).assertEqual(0);
      expect(result.imageWidth === undefined).assertTrue();
      expect(result.imageHeight === undefined).assertTrue();
    });

    it('imageClassificationGestureRunnerRejectsAliasesWithoutTrustedGestureModelLabels', 0, async () => {
      const runner = new ImageClassificationGestureRunner({
        labels: ['goldfish', 'boxing_glove'],
        scoreRunner: new FixedScoreRunner([0.1, 0.91])
      });

      const result = await runner.detectGesture('file://selected/glove.jpg');

      expect(result.ok).assertFalse();
      expect(result.gestures.length).assertEqual(0);
    });

    it('imageClassificationGestureRunnerAcceptsCommonLocalModelGestureLabels', 0, async () => {
      const runner = new ImageClassificationGestureRunner({
        labels: ['none', 'Victory', 'Thumb_Up'],
        scoreRunner: new FixedScoreRunner([0.95, 0.82, 0.81]),
        trustedGestureModelLabels: true,
        maxGestures: 2
      });

      const result = await runner.detectGesture('file://selected/gesture-model.jpg');

      expect(result.ok).assertTrue();
      expect(result.gestures.length).assertEqual(2);
      expect(result.gestures[0].category).assertEqual(1);
      expect(result.gestures[0].label).assertEqual('Two');
      expect(result.gestures[1].category).assertEqual(11);
      expect(result.gestures[1].label).assertEqual('Thumb up');
    });

    it('imageClassificationGestureRunnerKeepsMultipleAndroidGestureResultsByDefault', 0, async () => {
      const runner = new ImageClassificationGestureRunner({
        labels: ['thumb_up', 'boxing_glove', 'heart_gesture', 'ok_sign'],
        scoreRunner: new FixedScoreRunner([0.86, 0.92, 0.79, 0.95]),
        trustedGestureModelLabels: true
      });

      const result = await runner.detectGesture('file://selected/multiple-hands.jpg');

      expect(localGestureDetectionMaxGestureCount).assertEqual(3);
      expect(result.gestures.length).assertEqual(3);
      expect(result.gestures[0].category).assertEqual(13);
      expect(result.gestures[0].score.toFixed(2)).assertEqual('0.95');
      expect(result.gestures[1].category).assertEqual(10);
      expect(result.gestures[2].category).assertEqual(11);
    });

    it('imageClassificationGestureRunnerUsesEstimatedForegroundRegion', 0, async () => {
      const estimatedRect: GestureRectangle = {
        left: 6,
        top: 7,
        width: 8,
        height: 9
      };
      const estimator = new FixedGestureRegionEstimator(estimatedRect, 30, 40);
      const runner = new ImageClassificationGestureRunner({
        labels: ['goldfish', 'Thumb_Up'],
        scoreRunner: new FixedScoreRunner([0.1, 0.82]),
        trustedGestureModelLabels: true,
        regionEstimator: estimator
      });

      const result = await runner.detectGesture('file://selected/hand-left.jpg');

      expect(result.ok).assertTrue();
      expect(estimator.seenImageUris[0]).assertEqual('file://selected/hand-left.jpg');
      expect(result.gestures[0].rect?.left).assertEqual(6);
      expect(result.gestures[0].rect?.top).assertEqual(7);
      expect(result.gestures[0].rect?.width).assertEqual(8);
      expect(result.gestures[0].rect?.height).assertEqual(9);
      expect(result.imageWidth).assertEqual(30);
      expect(result.imageHeight).assertEqual(40);
    });

    it('imageClassificationGestureRunnerFallsBackWhenRegionEstimatorFails', 0, async () => {
      const runner = new ImageClassificationGestureRunner({
        labels: ['goldfish', 'Thumb_Up'],
        scoreRunner: new FixedScoreRunner([0.1, 0.82]),
        trustedGestureModelLabels: true,
        regionEstimator: new RejectingGestureRegionEstimator()
      });

      const result = await runner.detectGesture('file://selected/hand.jpg');

      expect(result.ok).assertTrue();
      expect(result.gestures[0].rect?.left).assertEqual(25);
      expect(result.gestures[0].rect?.top).assertEqual(10);
      expect(result.gestures[0].rect?.width).assertEqual(50);
      expect(result.gestures[0].rect?.height).assertEqual(70);
      expect(result.imageWidth).assertEqual(100);
      expect(result.imageHeight).assertEqual(100);
    });

    it('imageClassificationGestureRunnerFailsWhenNoHandAdjacentLabelMatches', 0, async () => {
      const estimator = new FixedGestureRegionEstimator();
      const runner = new ImageClassificationGestureRunner({
        labels: ['goldfish', 'hand-held_computer'],
        scoreRunner: new FixedScoreRunner([0.95, 0.93]),
        trustedGestureModelLabels: true,
        regionEstimator: estimator
      });

      const result = await runner.detectGesture('file://selected/fish.jpg');

      expect(result.ok).assertFalse();
      expect(result.gestures.length).assertEqual(0);
      expect(estimator.seenImageUris.length).assertEqual(0);
    });

    it('cachedRuntimeFactoryUsesProductionGestureRouteWithoutLoadingImageNetLabels', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      const workflow = workflowForRoute(AppRoute.GESTURE_LIVE.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        103, 111, 108, 100, 102, 105, 115, 104, 10,
        109, 105, 116, 116, 101, 110
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await cachedRuntimeAiServiceForWorkflow(workflow!, resourceManager);
      const result = await service.run(workflow!, {
        imageUri: 'file://selected/hand.jpg'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('GESTURE_DETECTION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_gesture_failed');
      expect(resourceManager.seenPaths.length).assertEqual(1);
      expect(resourceManager.seenPaths[0]).assertEqual('models/gesture/GestureDetector.ms');
    });

    it('runtimeFactoryInjectsLocalSceneDetectionServiceByDefault', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        97, 105, 114, 102, 105, 101, 108, 100, 10,
        97, 105, 114, 112, 108, 97, 110, 101, 95, 99, 97, 98, 105, 110, 10,
        98, 101, 97, 99, 104
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: resourceManager,
        inputPreprocessor: new FixedInputPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedTensorRunner([0.1, 0.92, 0.81])
      });

      const result = await service.run(workflow!, {
        imageUri: 'file://selected/scene.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('SCENE_DETECTION_DONE');
      expect(result.detailText.indexOf('aircraft 42.80%') >= 0).assertTrue();
    });

    it('cachedRuntimeFactoryReusesLocalSceneDetectionServiceForLiveLoops', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      const workflow = workflowForRoute(AppRoute.SCENE_LIVE.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        97, 105, 114, 102, 105, 101, 108, 100, 10,
        97, 105, 114, 112, 108, 97, 110, 101, 95, 99, 97, 98, 105, 110
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);

      const firstService = await cachedRuntimeAiServiceForWorkflow(workflow!, resourceManager);
      const secondService = await cachedRuntimeAiServiceForWorkflow(workflow!, new ThrowingRawfileContentReader());

      expect(firstService === secondService).assertTrue();
      expect(resourceManager.seenPaths.length).assertEqual(1);
      expect(resourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
    });

    it('cachedRuntimeFactoryReloadsLocalSceneDetectionServiceWhenLabelLocaleChanges', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      try {
        const workflow = workflowForRoute(AppRoute.SCENE_LIVE.name);
        expect(workflow !== undefined).assertTrue();
        const labelContent: Uint8Array = new Uint8Array([
          97, 105, 114, 102, 105, 101, 108, 100, 10,
          98, 101, 97, 99, 104
        ]);

        setHarmonyRuntimeLabelLocaleForTests('en-US');
        const englishResourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
        const firstService = await cachedRuntimeAiServiceForWorkflow(workflow!, englishResourceManager);

        setHarmonyRuntimeLabelLocaleForTests('zh-CN');
        const chineseResourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
        const secondService = await cachedRuntimeAiServiceForWorkflow(workflow!, chineseResourceManager);

        expect(firstService === secondService).assertFalse();
        expect(englishResourceManager.seenPaths.length).assertEqual(1);
        expect(chineseResourceManager.seenPaths.length).assertEqual(1);
        expect(englishResourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
        expect(chineseResourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
      } finally {
        resetHarmonyRuntimeAiServiceCachesForTests();
      }
    });

    it('cachedRuntimeFactoryRetriesLocalSceneDetectionServiceAfterLoadFailure', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      const workflow = workflowForRoute(AppRoute.SCENE_LIVE.name);
      expect(workflow !== undefined).assertTrue();
      let rejected = false;
      try {
        await cachedRuntimeAiServiceForWorkflow(workflow!, new ThrowingRawfileContentReader());
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();

      const labelContent: Uint8Array = new Uint8Array([
        97, 105, 114, 102, 105, 101, 108, 100, 10,
        97, 105, 114, 112, 108, 97, 110, 101, 95, 99, 97, 98, 105, 110
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await cachedRuntimeAiServiceForWorkflow(workflow!, resourceManager);

      expect(service !== undefined).assertTrue();
      expect(resourceManager.seenPaths.length).assertEqual(1);
      expect(resourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
    });

    it('runtimeFactoryInjectsCustomModelServiceForCustomModelWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        customModelPreprocessor: new FixedCustomModelPreprocessor(
          new ArrayBuffer(customModelInputFloatCount * Float32Array.BYTES_PER_ELEMENT)
        ),
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
      expect(inputLabelKey('styleImage')).assertEqual('feature_input_style_image');
    });

    it('addsAndroidStyleTransferCustomStylePickerItem', 0, () => {
      expect(styleTransferStylePickerItemCount).assertEqual(builtInStyleTransferStyleCount + 1);
      expect(styleTransferCustomStylePickerIndex).assertEqual(19);
      expect(isCustomStyleTransferUri('file://selected/custom-style.jpg')).assertTrue();
      expect(isCustomStyleTransferUri(builtInStyleTransferUri(builtInStyleTransferStyles[0]))).assertFalse();
      expect(hasAppStringKey('feature_runtime_style_custom')).assertTrue();
    });

    it('mapsAndroidBuiltInStyleTransferStylesToDistinctMediaNames', 0, () => {
      expect(builtInStyleTransferMediaName(builtInStyleTransferStyles[0])).assertEqual('style0');
      expect(builtInStyleTransferMediaName(builtInStyleTransferStyles[18])).assertEqual('style18');
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

    it('runtimeFactorySharesInjectedLocalModelRunnerForDirectTextAndOcr', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'second arbitrary OCR line\nkeeps newline\n',
        lineCount: 2,
        blockCount: 1,
        executionMs: 7
      });
      const translationRunner: FixedTextTranslationRunner =
        new FixedTextTranslationRunner('translated line one\ntranslated line two\n', 'localModel');
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        textRecognitionRunner: recognitionRunner,
        textTranslationRunner: translationRunner
      });

      const directResult: AiRunResult = await service.run(workflow!, {
        text: 'first arbitrary unmapped sentence'
      });
      const ocrResult: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/translation.jpg'
      });

      expect(directResult.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(ocrResult.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/translation.jpg');
      expect(translationRunner.seenTexts[0]).assertEqual('first arbitrary unmapped sentence');
      expect(translationRunner.seenTexts[1]).assertEqual('second arbitrary OCR line\nkeeps newline\n');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(ocrResult)))
        .assertEqual('translated line one\ntranslated line two\n');
      if (directResult.data?.kind === 'textTranslation') {
        expect(directResult.data.result.runtimeSource).assertEqual('localModel');
      } else {
        expect(false).assertTrue();
      }
      if (ocrResult.data?.kind === 'textTranslation') {
        expect(ocrResult.data.result.runtimeSource).assertEqual('localModel');
      } else {
        expect(false).assertTrue();
      }
    });

    it('translationRepeatedClicksShareRunnerWhileGenerationSuppressesStaleAndPageExit', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const runner = new FixedTextTranslationRunner('translated', 'localModel');
      const service = await createRuntimeAiServiceForWorkflow(workflow, {
        resourceManager: new ThrowingRawfileContentReader(),
        textTranslationRunner: runner
      });
      const generation = new RuntimeRequestGeneration();
      const firstGeneration = generation.begin();
      const results = await Promise.all([
        service.run(workflow, { text: 'first click' }),
        service.run(workflow, { text: 'second click' })
      ]);
      const secondGeneration = generation.begin();

      expect(results[0].code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(results[1].code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(runner.seenTexts.join(',')).assertEqual('first click,second click');
      expect(generation.isCurrent(firstGeneration)).assertFalse();
      expect(generation.isCurrent(secondGeneration)).assertTrue();
      generation.invalidate();
      expect(generation.isCurrent(secondGeneration)).assertFalse();
    });

    it('runtimeFactoryFailsOcrTranslationHonestlyWhenModelAssetIsMissing', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: '\u4F60\u597D\n',
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
      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
      expect(result.detailText.indexOf('source=\u4F60\u597D') >= 0).assertTrue();
      expect(result.detailText.indexOf('translated=') >= 0).assertTrue();
      expect(recognitionRunner.seenImageUris[0]).assertEqual('file://selected/translation.jpg');
    });

    it('runtimeFactoryFailsTypedTranslationHonestlyWhenModelAssetIsMissing', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result: AiRunResult = await service.run(workflow!, {
        text: 'MindSpore'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
      expect(result.detailText.indexOf('source=MindSpore') >= 0).assertTrue();
      expect(result.detailText.indexOf('translated=') >= 0).assertTrue();
    });

    it('runtimeFactoryConstructsModelRunnerWithInjectedHostBundleFactory', 0, async () => {
      resetHarmonyRuntimeAiServiceCachesForTests();
      configureTranslationTokenizerForTests(TOKENIZER_RUNTIME_FIXTURE);
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      let bundleFactoryCalls = 0;
      const service = await createRuntimeAiServiceForWorkflow(workflow, {
        resourceManager: new ThrowingRawfileContentReader(),
        translationModelBundleFactory: async () => {
          bundleFactoryCalls++;
          throw new Error('host bundle unavailable');
        }
      });

      const result = await service.run(workflow, { text: 'arbitrary host sentence' });

      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
      expect(bundleFactoryCalls).assertEqual(1);
    });

    it('runtimeFactoryLoadsAndroidLanguagePairsForLocalTextTranslation', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const languagePairContent = new Uint8Array([
        69, 110, 103, 108, 105, 115, 104, 32, 101, 110, 10,
        67, 104, 105, 110, 101, 115, 101, 32, 122, 104, 10
      ]);
      const reader: FixedRawfileContentReader = new FixedRawfileContentReader(languagePairContent);
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: reader,
        textTranslationRunner: new FixedTextTranslationRunner('\u6607\u601D', 'localModel')
      });

      const result: AiRunResult = await service.run(workflow!, {
        text: 'MindSpore'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('TEXT_TRANSLATION_DONE');
      expect(result.detailText.indexOf('translated=\u6607\u601D') >= 0).assertTrue();
      expect(reader.seenPaths.indexOf(translationLanguagePairsRawfilePath) >= 0).assertTrue();
    });

    it('localTextTranslationCoversAndroidHmsFeatureHelpSentences', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const imageClassification = await runner.translate(
        '\u56FE\u50CF\u5206\u7C7B\u53EF\u4EE5\u63A8\u6D4B\u56FE\u7247\u4E2D\u51FA\u73B0\u7269\u4F53\u7684\u6240\u5C5E\u7C7B\u522B',
        'en'
      );
      expect(imageClassification.ok).assertTrue();
      expect(imageClassification.translatedText)
        .assertEqual('Image classification can infer the category of the object in the picture');

      const sceneDetection = await runner.translate(
        'Scene detection can estimate the category of the target scene.',
        'zh'
      );
      expect(sceneDetection.ok).assertTrue();
      expect(sceneDetection.translatedText)
        .assertEqual('\u573A\u666F\u68C0\u6D4B\u53EF\u4EE5\u5224\u65AD\u76EE\u6807\u573A\u666F\u7684\u7C7B\u578B');

      const photoDetection = await runner.translate(
        'Photo detection can identify the category of the object and mark its position in the image.',
        'zh'
      );
      expect(photoDetection.ok).assertTrue();
      expect(photoDetection.translatedText)
        .assertEqual('\u7167\u7247\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u56FE\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002');

      const cameraDetection = await runner.translate(
        '\u89C6\u9891\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u6444\u50CF\u5934\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002',
        'en'
      );
      expect(cameraDetection.ok).assertTrue();
      expect(cameraDetection.translatedText)
        .assertEqual('Camera detection can identify the category of the object and mark its position in the camera');

      const posenet = await runner.translate(
        '\u9AA8\u9ABC\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u6444\u50CF\u5934\u4E2D\uFF0C\u4E0D\u540C\u59FF\u52BF\u4E0B\u4EBA\u4F53\u7684\u9762\u90E8\u4E94\u5B98\u4E0E\u80A2\u4F53\u59FF\u52BF\u3002',
        'en'
      );
      expect(posenet.ok).assertTrue();
      expect(posenet.translatedText)
        .assertEqual('Posenet can identify the facial features and body postures of human in different positions in the camera');

      const styleTransfer = await runner.translate(
        '\u98CE\u683C\u8FC1\u79FB\u53EF\u4EE5\u6839\u636EAPP\u5185\u7F6E\u7684\u6807\u51C6\u56FE\u7247\u6539\u53D8\u7528\u6237\u76EE\u6807\u56FE\u7247\u7684\u827A\u672F\u98CE\u683C\u3002',
        'en'
      );
      expect(styleTransfer.ok).assertTrue();
      expect(styleTransfer.translatedText)
        .assertEqual('Style transfer can change the art style of users target images based on the standard image in the APP');

      const imageSegmentation = await runner.translate(
        'Image segmentation is used to detect the position of the target or the category of the object in the picture.',
        'zh'
      );
      expect(imageSegmentation.ok).assertTrue();
      expect(imageSegmentation.translatedText)
        .assertEqual('\u56FE\u50CF\u5206\u5272\u7528\u4E8E\u68C0\u6D4B\u76EE\u6807\u5728\u56FE\u7247\u4E2D\u7684\u4F4D\u7F6E\u6216\u8005\u56FE\u7247\u4E2D\u51FA\u73B0\u7684\u7269\u4F53\u662F\u5C5E\u4E8E\u4F55\u79CD\u7C7B\u522B\u7684\u3002');

      const garbageClassification = await runner.translate(
        '\u5783\u573E\u5206\u7C7B\u53EF\u8BC6\u522B\u51FA\u955C\u5934\u4E2D\u7269\u4F53\u6240\u5C5E\u7684\u5783\u573E\u7C7B\u522B\u3002',
        'en'
      );
      expect(garbageClassification.ok).assertTrue();
      expect(garbageClassification.translatedText)
        .assertEqual('Garbage classification identifies the garbage category of the object detected by the camera lens');
    });

    it('localTextTranslationCoversAndroidHmsPromptAndFailureCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishPrompt = await runner.translate(
        'Please click on the picture below, camera, and real-time recognition',
        'zh'
      );
      expect(englishPrompt.ok).assertTrue();
      expect(englishPrompt.translatedText)
        .assertEqual('\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u3001\u5B9E\u65F6\u8FDB\u884C\u8BC6\u522B');

      const chinesePrompt =
        await runner.translate('\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u8FDB\u884C\u63D0\u53D6', 'en');
      expect(chinesePrompt.ok).assertTrue();
      expect(chinesePrompt.translatedText).assertEqual('Please click on the picture below and the camera to extract');

      const gestureFailure = await runner.translate('No gesture detected, try another image', 'zh');
      expect(gestureFailure.ok).assertTrue();
      expect(gestureFailure.translatedText)
        .assertEqual('\u672A\u68C0\u6D4B\u5230\u624B\u52BF\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5');

      const segmentationFailure =
        await runner.translate('\u56FE\u50CF\u5206\u5272\u5931\u8D25\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5', 'en');
      expect(segmentationFailure.ok).assertTrue();
      expect(segmentationFailure.translatedText).assertEqual('Image segmentation failed, try another image');
    });

    it('localTextTranslationCoversAndroidHmsShortActionCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const detect = await runner.translate('\u68C0\u6D4B', 'en');
      expect(detect.ok).assertTrue();
      expect(detect.translatedText).assertEqual('detect');

      const video = await runner.translate('video', 'zh');
      expect(video.ok).assertTrue();
      expect(video.translatedText).assertEqual('\u89C6\u9891');

      const copy = await runner.translate('\u590D\u5236', 'en');
      expect(copy.ok).assertTrue();
      expect(copy.translatedText).assertEqual('copy');

      const save = await runner.translate('SAVE', 'zh');
      expect(save.ok).assertTrue();
      expect(save.translatedText).assertEqual('\u4FDD\u5B58');

      const copied = await runner.translate('Copied successfully', 'zh');
      expect(copied.ok).assertTrue();
      expect(copied.translatedText).assertEqual('\u590D\u5236\u6210\u529F');

      const saved = await runner.translate('\u4FDD\u5B58\u6210\u529F', 'en');
      expect(saved.ok).assertTrue();
      expect(saved.translatedText).assertEqual('Save success');
    });

    it('localTextTranslationCoversAndroidTextTranslationPageCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const inputHint = await runner.translate('\u8BF7\u8F93\u5165\u9700\u8981\u7FFB\u8BD1\u7684\u5185\u5BB9', 'en');
      expect(inputHint.ok).assertTrue();
      expect(inputHint.translatedText).assertEqual('Please enter the content to be translated');

      const englishInputHint = await runner.translate('Please enter the content to be translated...', 'zh');
      expect(englishInputHint.ok).assertTrue();
      expect(englishInputHint.translatedText).assertEqual('\u8BF7\u8F93\u5165\u9700\u8981\u7FFB\u8BD1\u7684\u5185\u5BB9');

      const emptyText = await runner.translate('\u5F53\u524D\u5185\u5BB9\u4E3A\u7A7A', 'en');
      expect(emptyText.ok).assertTrue();
      expect(emptyText.translatedText).assertEqual('The current content is empty');

      const textActions = await runner.translate('Offline Translation\nDetection language', 'zh');
      expect(textActions.ok).assertTrue();
      expect(textActions.translatedText).assertEqual('\u79BB\u7EBF\u7FFB\u8BD1\n\u68C0\u6D4B\u8BED\u8A00');

      const saveFailures = await runner.translate('Null Image needed to save\nSave Failure', 'zh');
      expect(saveFailures.ok).assertTrue();
      expect(saveFailures.translatedText).assertEqual('\u6CA1\u6709\u9700\u8981\u4FDD\u5B58\u7684\u56FE\u7247\n\u4FDD\u5B58\u5931\u8D25');
    });

    it('localTextTranslationCoversAndroidCustomModelPageCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishCopy = await runner.translate(
        'Select Model\nSelect Photo\nTake Photo\nExecute\nSelect Image\nOutput Result\n' +
          'Model output will appear here...\nHelp\nMore\n' +
          'This is a custom model module where you can implement your own AI model functionality.',
        'zh'
      );
      expect(englishCopy.ok).assertTrue();
      expect(englishCopy.translatedText)
        .assertEqual('\u9009\u62E9\u6A21\u578B\n\u9009\u62E9\u56FE\u7247\n\u62CD\u7167\n\u6267\u884C\n' +
          '\u9009\u62E9\u56FE\u7247\n\u8F93\u51FA\u7ED3\u679C\n\u6A21\u578B\u8F93\u51FA\u5C06\u663E\u793A\u5728\u8FD9\u91CC...\n' +
          '\u5E2E\u52A9\n\u66F4\u591A\n' +
          '\u8FD9\u662F\u4E00\u4E2A\u81EA\u5B9A\u4E49\u6A21\u578B\u6A21\u5757\uFF0C' +
          '\u60A8\u53EF\u4EE5\u5728\u8FD9\u91CC\u5B9E\u73B0\u81EA\u5DF1\u7684AI\u6A21\u578B\u529F\u80FD\u3002');

      const chineseCopy = await runner.translate(
        '\u9009\u62E9\u6A21\u578B\n\u9009\u62E9\u56FE\u7247\n\u62CD\u7167\n\u6267\u884C\n' +
          '\u8F93\u51FA\u7ED3\u679C\n\u6A21\u578B\u8F93\u51FA\u5C06\u663E\u793A\u5728\u8FD9\u91CC...\n' +
          '\u5E2E\u52A9\n\u66F4\u591A\n' +
          '\u8FD9\u662F\u4E00\u4E2A\u81EA\u5B9A\u4E49\u6A21\u578B\u6A21\u5757\uFF0C' +
          '\u60A8\u53EF\u4EE5\u5728\u8FD9\u91CC\u5B9E\u73B0\u81EA\u5DF1\u7684AI\u6A21\u578B\u529F\u80FD\u3002',
        'en'
      );
      expect(chineseCopy.ok).assertTrue();
      expect(chineseCopy.translatedText)
        .assertEqual('Select Model\nSelect Photo\nTake Photo\nExecute\nOutput Result\n' +
          'Model output will appear here...\nHelp\nMore\n' +
          'This is a custom model module where you can implement your own AI model functionality.');
    });

    it('localTextTranslationCoversAndroidStyleTransferPageCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishCopy = await runner.translate(
        'Please select an original picture first\nPrevious Model still running\n' +
          'Please click a picture below or choose a photo from your album\nPHOTO\nCAMERA\nRECOVERY\nSAVE\n' +
          'Choose a Style\nModelExecute failed',
        'zh'
      );
      expect(englishCopy.ok).assertTrue();
      expect(englishCopy.translatedText)
        .assertEqual('\u8BF7\u5148\u9009\u62E9\u539F\u59CB\u56FE\u7247\n\u5148\u524D\u7684\u6A21\u578B\u4ECD\u5728\u8FD0\u884C\n' +
          '\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u6216\u76F8\u673A\u9009\u62E9\u7167\u7247\n' +
          '\u56FE\u7247\n\u76F8\u673A\n\u6062\u590D\n\u4FDD\u5B58\n\u9009\u62E9\u98CE\u683C\n\u89E3\u6790\u5931\u8D25');

      const chineseCopy = await runner.translate(
        '\u8BF7\u5148\u9009\u62E9\u539F\u59CB\u56FE\u7247\n\u5148\u524D\u7684\u6A21\u578B\u4ECD\u5728\u8FD0\u884C\n' +
          '\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u6216\u76F8\u673A\u9009\u62E9\u7167\u7247\n' +
          '\u6062\u590D\n\u9009\u62E9\u98CE\u683C\n\u89E3\u6790\u5931\u8D25',
        'en'
      );
      expect(chineseCopy.ok).assertTrue();
      expect(chineseCopy.translatedText)
        .assertEqual('Please select an original picture first\nPrevious Model still running\n' +
          'Please click a picture below or choose a photo from your album\nRECOVERY\nChoose a Style\nModelExecute failed');
    });

    it('localTextTranslationCoversAndroidSceneAndObjectResultCopy', 0, async () => {
      const runner = new LocalTextTranslationRunner();

      const englishCopy = await runner.translate(
        'Scene Count\nScene\nScore\nInference Time:\nContinue to identify\n' +
          'The image path you selected is not valid. Please choose again\n' +
          'Sorry, there is no object identified in this picture. Try another picture\n' +
          'human\nautomobile\ntraffic signal',
        'zh'
      );
      expect(englishCopy.ok).assertTrue();
      expect(englishCopy.translatedText)
        .assertEqual('\u573A\u666F\u8BA1\u6570\n\u573A\u666F\n\u5F97\u5206\n\u63A8\u7406\u65F6\u95F4\uFF1A\n' +
          '\u6B63\u5728\u8BC6\u522B\n\u60A8\u9009\u62E9\u7684\u56FE\u50CF\u8DEF\u5F84\u65E0\u6548\u3002\u8BF7\u518D\u6B21\u9009\u62E9\n' +
          '\u5BF9\u4E0D\u8D77\uFF0C\u6B64\u56FE\u7247\u4E2D\u6CA1\u6709\u4EFB\u4F55\u7269\u4F53\u3002' +
          '\u8BF7\u5C1D\u8BD5\u53E6\u4E00\u5F20\u56FE\u7247\n\u4EBA\n\u6C7D\u8F66\n\u4EA4\u901A\u706F');

      const chineseCopy = await runner.translate(
        '\u573A\u666F\u8BA1\u6570\n\u573A\u666F\n\u5F97\u5206\n\u63A8\u7406\u65F6\u95F4\uFF1A\n' +
          '\u6B63\u5728\u8BC6\u522B\n\u60A8\u9009\u62E9\u7684\u56FE\u50CF\u8DEF\u5F84\u65E0\u6548\u3002\u8BF7\u518D\u6B21\u9009\u62E9\n' +
          '\u5BF9\u4E0D\u8D77\uFF0C\u6B64\u56FE\u7247\u4E2D\u6CA1\u6709\u4EFB\u4F55\u7269\u4F53\u3002' +
          '\u8BF7\u5C1D\u8BD5\u53E6\u4E00\u5F20\u56FE\u7247\n\u4EBA\n\u6C7D\u8F66\n\u4EA4\u901A\u706F',
        'en'
      );
      expect(chineseCopy.ok).assertTrue();
      expect(chineseCopy.translatedText)
        .assertEqual('Scene Count\nScene\nScore\nInference Time:\nContinue to identify\n' +
          'The image path you selected is not valid. Please choose again\n' +
          'Sorry, there is no object identified in this picture. Try another picture\n' +
          'human\nautomobile\ntraffic signal');
    });

    it('runtimeFactoryDoesNotFallBackToDictionaryForArbitraryText', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader()
      });

      const result: AiRunResult = await service.run(workflow!, {
        text: 'unmapped phrase'
      });

      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
      expect(result.detailText.indexOf('source=unmapped phrase') >= 0).assertTrue();
      expect(result.detailText.indexOf('translated=') >= 0).assertTrue();
      expect(aiRunResultRows(result)[1].value).assertEqual('unmapped phrase');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('unmapped phrase');
    });

    it('runtimeFactoryModelFailurePreservesOcrSourceWithoutFallback', 0, async () => {
      const workflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name);
      expect(workflow !== undefined).assertTrue();
      const recognitionRunner: FixedTextRecognitionRunner = new FixedTextRecognitionRunner({
        ok: true,
        text: 'unmapped phrase\n',
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
      expect(result.code).assertEqual('TEXT_TRANSLATION_FAILED');
      expect(result.messageKey).assertEqual('feature_runtime_text_translation_failed');
      expect(aiRunResultRows(result)[1].value).assertEqual('unmapped phrase\n');
      expect(copyableTextForAiResult('translateText', aiRunResultRows(result))).assertEqual('unmapped phrase\n');
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

    it('runtimeFactoryUsesInjectedAndroidGestureDetectorWithoutImageNetLabels', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const resourceManager = new FixedRawfileContentReader(new Uint8Array([102, 105, 115, 116]));
      const detector = new FixedAndroidGestureModelDetector({
        gestures: [{ category: 10, score: 0.91 }],
        imageWidth: 320,
        imageHeight: 240,
        executionMs: 6
      });
      const options: HarmonyImageClassificationRuntimeOptions = {
        resourceManager: resourceManager,
        androidGestureModelDetector: detector
      };

      const service = await createRuntimeAiServiceForWorkflow(workflow, options);
      const result = await service.run(workflow, {
        imageUri: 'file://selected/gesture.jpg'
      });

      expect(result.code).assertEqual('GESTURE_DETECTION_DONE');
      expect(detector.seenImageUris.length).assertEqual(1);
      expect(resourceManager.seenPaths.length).assertEqual(0);
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

    it('runtimeFactoryLocalizesInjectedSceneDetectionLabelsForChineseLocale', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const scene: SceneDetection = { label: 'stage', score: 0.82 };
      const sceneResult: SceneDetectionResult = {
        ok: true,
        scenes: [scene],
        executionMs: 7
      };
      const runner: FixedSceneDetectionRunner = new FixedSceneDetectionRunner(sceneResult);
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        labelLocale: 'zh-CN',
        sceneDetectionRunner: runner
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/stage.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.detailText.indexOf('舞台 82.00%') >= 0).assertTrue();
      const rows = aiRunResultRows(result);
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value.indexOf('1. 舞台 82.00%') >= 0).assertTrue();
    });

    it('runtimeFactoryLocalizesDefaultLocalSceneDetectionLabelsForChineseLocale', 0, async () => {
      const workflow = workflowForRoute(AppRoute.SCENE_STILL.name);
      expect(workflow !== undefined).assertTrue();
      const labelContent: Uint8Array = new Uint8Array([
        115, 116, 97, 103, 101, 10,
        98, 101, 97, 99, 104
      ]);
      const resourceManager: FixedRawfileContentReader = new FixedRawfileContentReader(labelContent);
      const service = await createRuntimeAiServiceForWorkflow(workflow!, {
        resourceManager: resourceManager,
        labelLocale: 'zh-CN',
        inputPreprocessor: new FixedInputPreprocessor(new ArrayBuffer(12)),
        tensorRunner: new FixedTensorRunner([0.82, 0.1])
      });

      const result: AiRunResult = await service.run(workflow!, {
        imageUri: 'file://selected/stage.jpg'
      });

      expect(resourceManager.seenPaths[0]).assertEqual('labels/places365.txt');
      expect(result.ok).assertTrue();
      expect(result.detailText.indexOf('舞台 67.26%') >= 0).assertTrue();
      const rows = aiRunResultRows(result);
      expect(rows[1].labelKey).assertEqual('feature_runtime_result_scenes');
      expect(rows[1].value.indexOf('1. 舞台 67.26%') >= 0).assertTrue();
    });

    it('runtimeFactoryInjectsSegmentationServiceForSegmentationWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      expect(workflow !== undefined).assertTrue();
      const runner: FixedSegmentationRunner = new FixedSegmentationRunner({
        ok: true,
        subjectCount: 1,
        detailCount: 0,
        foregroundAvailable: true,
        foregroundImageRgba: new Uint8Array([0, 0, 0, 255]).buffer as ArrayBuffer,
        foregroundImageWidth: 1,
        foregroundImageHeight: 1,
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

    it('runtimeFactoryMapsAndroidSegmentationSceneModes', 0, () => {
      const stillWorkflow: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const liveWorkflow: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!;
      const portraitWorkflow: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;

      expect(segmentationAndroidSceneForWorkflow(stillWorkflow)).assertEqual('all');
      expect(segmentationAndroidSceneForWorkflow(liveWorkflow)).assertEqual('foregroundOnly');
      expect(segmentationAndroidSceneForWorkflow(portraitWorkflow)).assertEqual('foregroundOnly');

      const allConfig = segmentationConfigForAndroidScene('all');
      expect(allConfig.maxCount).assertEqual(6);
      expect(allConfig.enableSubjectDetails).assertTrue();
      expect(allConfig.enableSubjectForegroundImage).assertTrue();

      const foregroundOnlyConfig = segmentationConfigForAndroidScene('foregroundOnly');
      expect(foregroundOnlyConfig.maxCount).assertEqual(6);
      expect(foregroundOnlyConfig.enableSubjectDetails).assertFalse();
      expect(foregroundOnlyConfig.enableSubjectForegroundImage).assertTrue();
    });

    it('runtimeFactoryInjectsPoseServiceForPoseWorkflow', 0, async () => {
      const workflow = workflowForRoute(AppRoute.POSENET.name);
      expect(workflow !== undefined).assertTrue();
      const point: PosePoint = { type: 0, score: 0.95, x: 10, y: 20 };
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: 1,
        points: [point],
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
      expect(runner.seenModes[0]).assertEqual('normal');
    });

    it('runtimeFactoryPassesAndroidYogaModeForLiveSkeletonWorkflow', 0, async () => {
      const stillWorkflow = workflowForRoute(AppRoute.POSENET.name);
      const liveWorkflow = workflowForRoute(AppRoute.LIVE_SKELETON.name);
      expect(stillWorkflow !== undefined).assertTrue();
      expect(liveWorkflow !== undefined).assertTrue();
      expect(poseModeForWorkflow(stillWorkflow!)).assertEqual('normal');
      expect(poseModeForWorkflow(liveWorkflow!)).assertEqual('yoga');
      const point: PosePoint = { type: 0, score: 0.95, x: 10, y: 20 };
      const runner: FixedPoseRunner = new FixedPoseRunner({
        ok: true,
        skeletonCount: 1,
        pointCount: 1,
        points: [point],
        executionMs: 6
      });
      const service = await createRuntimeAiServiceForWorkflow(liveWorkflow!, {
        resourceManager: new ThrowingRawfileContentReader(),
        poseRunner: runner
      });

      const result: AiRunResult = await service.run(liveWorkflow!, {
        imageUri: 'file://selected/live-pose.jpg'
      });

      expect(result.ok).assertTrue();
      expect(result.code).assertEqual('POSE_DETECTION_DONE');
      expect(runner.seenImageUris[0]).assertEqual('file://selected/live-pose.jpg');
      expect(runner.seenModes[0]).assertEqual('yoga');
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

    it('recoversRuntimePermissionDenialWithAndroidLikeRetryActions', 0, () => {
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const imageCamera: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      const liveCameraRouteNames: Array<string> = [
        AppRoute.IMAGE_CAMERA.name,
        AppRoute.OBJECT_CAMERA.name,
        AppRoute.GESTURE_LIVE.name,
        AppRoute.SCENE_LIVE.name,
        AppRoute.SEGMENTATION_LIVE.name,
        AppRoute.PORTRAIT_SEGMENTATION.name,
        AppRoute.LIVE_SKELETON.name
      ];

      expect(runtimePermissionRecoveryActionForWorkflow(
        textTranslation,
        'feature_runtime_permission_denied'
      )).assertEqual('retryRun');
      expect(runtimePermissionRecoveryActionForWorkflow(
        imageCamera,
        'feature_runtime_permission_denied'
      )).assertEqual('retryCameraInput');
      expect(runtimePermissionRecoveryActionForWorkflow(
        imageCamera,
        'feature_runtime_live_camera_failed'
      )).assertEqual('none');
      expect(runtimePermissionRecoveryActionForWorkflow(
        undefined,
        'feature_runtime_permission_denied'
      )).assertEqual('none');

      expect(runtimePermissionRunActionForWorkflow(
        imageCamera,
        'feature_runtime_permission_denied'
      )).assertEqual('retryCameraInput');
      expect(runtimePermissionRunActionForWorkflow(
        textTranslation,
        'feature_runtime_permission_denied'
      )).assertEqual('runWorkflow');
      expect(runtimePermissionRunActionForWorkflow(
        imageCamera,
        'feature_runtime_live_camera_failed'
      )).assertEqual('runWorkflow');
      const deniedSummary = permissionRequestSummary(
        ['ohos.permission.CAMERA', 'ohos.permission.READ_IMAGEVIDEO'],
        [0, -1]
      );
      expect(deniedSummary.ok).assertFalse();
      expect(JSON.stringify(deniedSummary.denied))
        .assertEqual('["ohos.permission.READ_IMAGEVIDEO"]');
      const runtimeSettingsAction = runtimeOpenPermissionSettingsAction(deniedSummary.denied);
      expect(runtimeSettingsAction.openSettings).assertTrue();
      expect(JSON.stringify(runtimeSettingsAction.permissions))
        .assertEqual('["ohos.permission.READ_IMAGEVIDEO"]');
      expect(runtimeOpenPermissionSettingsAction([]).openSettings).assertFalse();
      const fallbackWant = harmonySettingsFallbackWant('com.example.mindspore');
      expect(fallbackWant.bundleName).assertEqual('com.huawei.hmos.settings');
      expect(fallbackWant.moduleName).assertEqual('phone_settings');
      expect(fallbackWant.abilityName).assertEqual('com.huawei.hmos.settings.MainAbility');
      expect(JSON.stringify(fallbackWant.parameters))
        .assertEqual('{"settingsParamBundleName":"com.example.mindspore"}');
      liveCameraRouteNames.forEach((routeName: string) => {
        const workflow: FeatureWorkflow = workflowForRoute(routeName)!;
        expect(runtimePermissionRecoveryActionForWorkflow(
          workflow,
          'feature_runtime_permission_denied'
        )).assertEqual('retryCameraInput');
        expect(runtimePermissionRunActionForWorkflow(
          workflow,
          'feature_runtime_permission_denied'
        )).assertEqual('retryCameraInput');
      });
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
      expect(runtimeInputActionsForWorkflow(portraitSegmentation).indexOf('startLiveCamera') >= 0).assertTrue();
      expect(runtimeInputActionsForWorkflow(portraitSegmentation).indexOf('captureImage')).assertEqual(-1);
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

    it('definesTheNanoDetApi24TensorContract', 0, () => {
      expect(objectDetectionInputSize).assertEqual(320);
      expect(objectDetectionInputFloatCount).assertEqual(1 * 3 * 320 * 320);
      expect(objectDetectionOutputChannelCount).assertEqual(112);
      expect(objectDetectionOutputFloatCount).assertEqual(1 * 2125 * 112);
    });

    it('normalizesObjectDetectionRgbaToBgrNchwInput', 0, () => {
      const rgba: Uint8Array = new Uint8Array(objectDetectionInputSize * objectDetectionInputSize * 4);
      rgba[0] = 255;
      rgba[1] = 0;
      rgba[2] = 0;
      rgba[3] = 77;

      const input = new Float32Array(normalizedObjectDetectionRgbInputFromRgba(rgba));
      const planeSize = objectDetectionInputSize * objectDetectionInputSize;

      expect(input.length).assertEqual(objectDetectionInputFloatCount);
      expect(input[0].toFixed(6)).assertEqual('-1.804444');
      expect(input[planeSize].toFixed(6)).assertEqual('-2.035714');
      expect(input[planeSize * 2].toFixed(6)).assertEqual('2.248908');
    });

    it('decodesTheDocumentedNanoDetOutputAndMapsCocoIdsAfterBackground', 0, () => {
      const output = new Float32Array(objectDetectionOutputFloatCount);
      output[16] = 0.9;
      for (let side = 0; side < 4; side++) {
        const offset = 80 + side * 8;
        for (let bin = 0; bin < 8; bin++) {
          output[offset + bin] = bin === 1 ? 20 : -20;
        }
      }

      const detections = decodeNanoDetObjectDetections(output, 640, 320);

      expect(detections.length).assertEqual(1);
      expect(detections[0].imageId).assertEqual(0);
      expect(detections[0].labelId).assertEqual(17);
      expect(detections[0].score.toFixed(1)).assertEqual('0.9');
      expect(detections[0].left.toFixed(0)).assertEqual('0');
      expect(detections[0].top.toFixed(0)).assertEqual('0');
      expect(detections[0].right.toFixed(0)).assertEqual('16');
      expect(detections[0].bottom.toFixed(0)).assertEqual('8');
    });

    it('rejectsMalformedOrNonFiniteNanoDetOutput', 0, () => {
      expect(decodeNanoDetObjectDetections(new Float32Array(objectDetectionOutputFloatCount - 1), 320, 320).length)
        .assertEqual(0);
      const nonFinite = new Float32Array(objectDetectionOutputFloatCount);
      nonFinite[0] = Number.NaN;
      expect(decodeNanoDetObjectDetections(nonFinite, 320, 320).length).assertEqual(0);
      expect(decodeNanoDetObjectDetections(new Float32Array(objectDetectionOutputFloatCount), 320, 320).length)
        .assertEqual(0);
    });

    it('serializesLoadAndPredictAcrossObjectDetectionRunnerInstances', 0, async () => {
      const runtime = new RecordingObjectDetectionMnnRuntime(true);
      const input: ObjectDetectionInput = {
        inputBuffer: new ArrayBuffer(objectDetectionInputFloatCount * 4),
        imageWidth: 320,
        imageHeight: 320
      };
      const runnerA = new LocalMnnObjectDetectionRunner({
        resourceManager: new FixedRawfileContentReader(new Uint8Array([9])),
        modelRawfilePath: 'model/a.mnn',
        preprocessor: new FixedObjectDetectionPreprocessor(input),
        modelContentReader: new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1]))),
        runtime: runtime
      });
      const runnerB = new LocalMnnObjectDetectionRunner({
        resourceManager: new FixedRawfileContentReader(new Uint8Array([9])),
        modelRawfilePath: 'model/b.mnn',
        preprocessor: new FixedObjectDetectionPreprocessor(input),
        modelContentReader: new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([2]))),
        runtime: runtime
      });

      const first = runnerA.detectObjects('file://image-a.jpg', 'file://model-a.mnn');
      await runtime.waitForFirstPredict();
      const second = runnerB.detectObjects('file://image-b.jpg', 'file://model-b.mnn');
      for (let tick = 0; tick < 20; tick++) {
        await Promise.resolve();
      }
      const eventsBeforeRelease = runtime.events.join(',');
      runtime.releaseFirstPredict();
      await first;
      await second;
      await runnerA.detectObjects('file://image-a-again.jpg', 'file://model-a.mnn');

      expect(eventsBeforeRelease).assertEqual('load:1,predict-start:1');
      expect(runtime.events.join(','))
        .assertEqual('load:1,predict-start:1,predict-end:1,load:2,predict-start:2,predict-end:2,' +
          'load:1,predict-start:1,predict-end:1');
    });

    it('reloadsCustomObjectDetectionModelWhenSameCacheUriContentChanges', 0, async () => {
      const runtime = new RecordingObjectDetectionMnnRuntime();
      const backend = new MutableFileUriContentBackend(new Uint8Array([3]));
      const input: ObjectDetectionInput = {
        inputBuffer: new ArrayBuffer(objectDetectionInputFloatCount * 4),
        imageWidth: 320,
        imageHeight: 320
      };
      const runner = new LocalMnnObjectDetectionRunner({
        resourceManager: new FixedRawfileContentReader(new Uint8Array([9])),
        modelRawfilePath: 'model/builtin.mnn',
        preprocessor: new FixedObjectDetectionPreprocessor(input),
        modelContentReader: new FileUriContentReader(backend),
        runtime: runtime
      });

      await runner.detectObjects('file://first.jpg', 'file://cache/object_detection_model.mnn');
      backend.setContent(new Uint8Array([4]));
      await runner.detectObjects('file://second.jpg', 'file://cache/object_detection_model.mnn');

      expect(runtime.events.join(','))
        .assertEqual('load:3,predict-start:3,predict-end:3,load:4,predict-start:4,predict-end:4');
    });

    it('rejectsMalformedMnnOutputInsteadOfReportingSuccessfulNoTargetDetection', 0, async () => {
      const input: ObjectDetectionInput = {
        inputBuffer: new ArrayBuffer(objectDetectionInputFloatCount * 4),
        imageWidth: 320,
        imageHeight: 320
      };
      const wrongSizedRunner = new LocalMnnObjectDetectionRunner({
        resourceManager: new FixedRawfileContentReader(new Uint8Array([9])),
        modelRawfilePath: 'model/builtin.mnn',
        preprocessor: new FixedObjectDetectionPreprocessor(input),
        runtime: new FixedOutputObjectDetectionMnnRuntime(
          new Float32Array(objectDetectionOutputFloatCount - 1))
      });
      const nonFiniteOutput = new Float32Array(objectDetectionOutputFloatCount);
      nonFiniteOutput[0] = Number.NaN;
      const nonFiniteRunner = new LocalMnnObjectDetectionRunner({
        resourceManager: new FixedRawfileContentReader(new Uint8Array([9])),
        modelRawfilePath: 'model/builtin.mnn',
        preprocessor: new FixedObjectDetectionPreprocessor(input),
        runtime: new FixedOutputObjectDetectionMnnRuntime(nonFiniteOutput)
      });

      const wrongSizedResult = await new ObjectDetectionService({
        labels: ['background'],
        runner: wrongSizedRunner
      }).detectObjects('file://wrong-sized.jpg');
      const nonFiniteResult = await new ObjectDetectionService({
        labels: ['background'],
        runner: nonFiniteRunner
      }).detectObjects('file://non-finite.jpg');

      expect(wrongSizedResult.ok).assertFalse();
      expect(wrongSizedResult.code).assertEqual('DETECTION_INVALID_OUTPUT');
      expect(nonFiniteResult.ok).assertFalse();
      expect(nonFiniteResult.code).assertEqual('DETECTION_INVALID_OUTPUT');
    });

    it('keepsNativeCameraPickerForPhysicalDevicesAndGuardsApi24Emulator', 0, () => {
      expect(isApi24EmulatorCameraPickerUnsupported('PHEMU-FD00')).assertTrue();
      expect(isApi24EmulatorCameraPickerUnsupported('phemu-x86_64')).assertTrue();
      expect(isApi24EmulatorCameraPickerUnsupported('emulator')).assertTrue();
      expect(isApi24EmulatorCameraPickerUnsupported('LNA-AL00')).assertFalse();
      expect(isApi24EmulatorCameraPickerUnsupported('')).assertFalse();
    });

    it('stillSceneUsesInlineCameraWhenNativeCaptureIsUnavailable', 0, () => {
      const stillScene = workflowForRoute(AppRoute.SCENE_STILL.name);
      const liveScene = workflowForRoute(AppRoute.SCENE_LIVE.name);
      const unavailable: PickResult = { ok: false, uri: '', failure: 'cameraUnavailable' };
      const cancelled: PickResult = { ok: false, uri: '' };

      expect(shouldUseInlineCameraFallback(stillScene, 'camera', unavailable)).assertTrue();
      expect(shouldUseInlineCameraFallback(stillScene, 'photo', unavailable)).assertFalse();
      expect(shouldUseInlineCameraFallback(stillScene, 'camera', cancelled)).assertFalse();
      expect(shouldUseInlineCameraFallback(liveScene, 'camera', unavailable)).assertFalse();
      expect(shouldUseInlineCameraFallback(undefined, 'camera', unavailable)).assertFalse();
    });

    it('autoRunsTextImageInputsAfterAndroidImageInputReadyOnly', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const gestureStill: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const sceneStill: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_STILL.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'text')).assertFalse();

      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'text')).assertFalse();

      expect(shouldAutoRunWorkflowAfterInputReady(objectPhoto, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(objectPhoto, 'modelFile')).assertFalse();

      expect(shouldAutoRunWorkflowAfterInputReady(segmentationStill, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(segmentationStill, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(gestureStill, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(gestureStill, 'camera')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(sceneStill, 'photo')).assertTrue();
      expect(shouldAutoRunWorkflowAfterInputReady(sceneStill, 'camera')).assertTrue();

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

    it('autoRunsStyleTransferAfterAndroidStyleInputReadyWhenContentExists', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;

      expect(shouldAutoRunStyleTransferAfterStyleReady(styleTransfer, 'styleImage', true)).assertTrue();
      expect(shouldAutoRunStyleTransferAfterStyleReady(styleTransfer, 'styleImage', false)).assertFalse();
      expect(shouldAutoRunStyleTransferAfterStyleReady(styleTransfer, 'contentImage', true)).assertFalse();
      expect(shouldAutoRunStyleTransferAfterStyleReady(styleTransfer, 'camera', true)).assertFalse();
      expect(shouldAutoRunStyleTransferAfterStyleReady(textRecognition, 'styleImage', true)).assertFalse();
    });

    it('usesAndroidStyleTransferOriginalImagePromptWhenStyleIsSelectedFirst', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;

      expect(styleTransferStyleReadyStatusKey(styleTransfer, 'styleImage', false, 'feature_runtime_image_ready'))
        .assertEqual('feature_runtime_style_original_required');
      expect(styleTransferStyleReadyStatusKey(styleTransfer, 'styleImage', true, 'feature_runtime_image_ready'))
        .assertEqual('feature_runtime_image_ready');
      expect(styleTransferStyleReadyStatusKey(styleTransfer, 'contentImage', false, 'feature_runtime_image_ready'))
        .assertEqual('feature_runtime_image_ready');
      expect(styleTransferStyleReadyStatusKey(textRecognition, 'styleImage', false, 'feature_runtime_image_ready'))
        .assertEqual('feature_runtime_image_ready');
      expect(hasAppStringKey('feature_runtime_style_original_required')).assertTrue();
    });

    it('blocksRepeatedAsyncWorkflowRunsWhileKeepingLiveLoopRunnable', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;
      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;

      expect(shouldStartWorkflowRun(styleTransfer, false, false)).assertTrue();
      expect(shouldStartWorkflowRun(styleTransfer, true, false)).assertFalse();
      expect(shouldStartWorkflowRun(customModel, true, false)).assertFalse();
      expect(shouldStartWorkflowRun(objectCamera, true, false)).assertFalse();
      expect(shouldStartWorkflowRun(objectCamera, true, true)).assertTrue();
    });

    it('blocksStyleTransferInputChangesWhileAsyncRunIsInProgress', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;

      expect(shouldAllowRuntimeInputChange(styleTransfer, 'styleImage', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'contentImage', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'camera', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'stylePredictModelFile', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'styleTransferModelFile', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'styleImage', false)).assertTrue();
      expect(shouldAllowRuntimeInputChange(textRecognition, 'photo', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(undefined, 'photo', true)).assertTrue();
      expect(hasAppStringKey('feature_runtime_status_running')).assertTrue();
    });

    it('clearsTypedTranslationTextWhenAndroidImageTranslationInputIsReady', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

      expect(shouldClearTextInputAfterInputReady(textTranslation, 'photo')).assertTrue();
      expect(shouldClearTextInputAfterInputReady(textTranslation, 'camera')).assertTrue();
      expect(shouldClearTextInputAfterInputReady(textTranslation, 'text')).assertFalse();
      expect(shouldClearTextInputAfterInputReady(textRecognition, 'photo')).assertFalse();
    });

    it('hidesTextTranslationEditorWhenPreparingAndroidImageInput', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

      expect(shouldHideTextInputWhenPreparingInput(textTranslation, 'photo')).assertTrue();
      expect(shouldHideTextInputWhenPreparingInput(textTranslation, 'camera')).assertTrue();
      expect(shouldHideTextInputWhenPreparingInput(textTranslation, 'text')).assertFalse();
      expect(shouldHideTextInputWhenPreparingInput(textRecognition, 'photo')).assertFalse();
      expect(shouldHideTextInputWhenPreparingInput(styleTransfer, 'photo')).assertFalse();
    });

    it('restoresTextTranslationEditorVisibilityAfterCancelledImagePick', 0, () => {
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;

      expect(textInputVisibleAfterCancelledPick(textTranslation, 'photo', false, true)).assertTrue();
      expect(textInputVisibleAfterCancelledPick(textTranslation, 'camera', false, true)).assertTrue();
      expect(textInputVisibleAfterCancelledPick(textTranslation, 'photo', false, false)).assertFalse();
      expect(textInputVisibleAfterCancelledPick(textTranslation, 'text', false, true)).assertFalse();
      expect(textInputVisibleAfterCancelledPick(textRecognition, 'photo', false, true)).assertFalse();
    });

    it('computesTextImageInputReadyPageActionBeforeAutoRun', 0, () => {
      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      const segmentationStill: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

      const imageTranslationAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textTranslation, 'photo', 'typed first');
      expect(imageTranslationAction.userText).assertEqual('');
      expect(imageTranslationAction.shouldRunWorkflow).assertTrue();
      expect(imageTranslationAction.textInputVisible).assertFalse();

      const cameraTranslationAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textTranslation, 'camera', 'typed first');
      expect(cameraTranslationAction.userText).assertEqual('');
      expect(cameraTranslationAction.shouldRunWorkflow).assertTrue();
      expect(cameraTranslationAction.textInputVisible).assertFalse();

      const typedTranslationAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textTranslation, 'text', 'typed first');
      expect(typedTranslationAction.userText).assertEqual('typed first');
      expect(typedTranslationAction.shouldRunWorkflow).assertFalse();
      expect(typedTranslationAction.textInputVisible).assertTrue();

      const imageOcrAction: WorkflowInputReadyAction =
        workflowInputReadyAction(textRecognition, 'camera', 'typed first');
      expect(imageOcrAction.userText).assertEqual('typed first');
      expect(imageOcrAction.shouldRunWorkflow).assertTrue();
      expect(imageOcrAction.textInputVisible).assertTrue();

      const objectPhotoAction: WorkflowInputReadyAction =
        workflowInputReadyAction(objectPhoto, 'photo', 'typed first');
      expect(objectPhotoAction.userText).assertEqual('typed first');
      expect(objectPhotoAction.shouldRunWorkflow).assertTrue();
      expect(objectPhotoAction.textInputVisible).assertTrue();

      const segmentationStillAction: WorkflowInputReadyAction =
        workflowInputReadyAction(segmentationStill, 'camera', 'typed first');
      expect(segmentationStillAction.userText).assertEqual('typed first');
      expect(segmentationStillAction.shouldRunWorkflow).assertTrue();
      expect(segmentationStillAction.textInputVisible).assertTrue();

      const styleTransferAction: WorkflowInputReadyAction =
        workflowInputReadyAction(styleTransfer, 'photo', 'typed first');
      expect(styleTransferAction.userText).assertEqual('typed first');
      expect(styleTransferAction.shouldRunWorkflow).assertFalse();
      expect(styleTransferAction.textInputVisible).assertTrue();

      const customModelAction: WorkflowInputReadyAction =
        workflowInputReadyAction(customModel, 'camera', 'typed first');
      expect(customModelAction.userText).assertEqual('typed first');
      expect(customModelAction.shouldRunWorkflow).assertFalse();
      expect(customModelAction.textInputVisible).assertTrue();
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

    it('showsGestureBoxesOnOnlyTheAndroidStyleLiveGesturePreview', 0, () => {
      expect(shouldShowLiveGestureCameraOverlay(workflowForRoute(AppRoute.GESTURE_LIVE.name)))
        .assertTrue();
      expect(shouldShowLiveGestureCameraOverlay(workflowForRoute(AppRoute.GESTURE_STILL.name)))
        .assertFalse();
      expect(shouldShowLiveGestureCameraOverlay(workflowForRoute(AppRoute.SCENE_LIVE.name)))
        .assertFalse();
      expect(shouldShowLiveGestureCameraOverlay(undefined))
        .assertFalse();
    });

    it('keepsLiveGestureOverlayCameraAndRetryStatePerRoute', 0, () => {
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;
      const sceneLive: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_LIVE.name)!;

      expect(usesAndroidLiveGestureLayout(gestureLive)).assertTrue();
      expect(usesAndroidLiveGestureLayout(sceneLive)).assertFalse();
      expect(liveGestureRetryActionForStatus(gestureLive, 'feature_runtime_live_camera_failed'))
        .assertEqual('restartCamera');
      expect(liveGestureRetryActionForStatus(gestureLive, 'feature_runtime_run_failed'))
        .assertEqual('restartInference');
      expect(liveGestureRetryActionForStatus(gestureLive, 'feature_runtime_gesture_failed'))
        .assertEqual('restartInference');
      expect(liveGestureRetryActionForStatus(gestureLive, 'feature_runtime_status_idle')).assertEqual('none');
      expect(liveGestureRetryActionForStatus(sceneLive, 'feature_runtime_run_failed')).assertEqual('none');
      expect(shouldPublishLiveGesturePreparingStatus(gestureLive, false)).assertTrue();
      expect(shouldPublishLiveGesturePreparingStatus(gestureLive, true)).assertFalse();
      expect(shouldPublishLiveGesturePreparingStatus(sceneLive, true)).assertTrue();
      expect(shouldClearRuntimeResultAtWorkflowStart(gestureLive)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(gestureLive, false)).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(gestureLive, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(gestureLive, true, 'gesture')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(gestureLive, true, 'classification')).assertFalse();
      expect(shouldPreserveLiveCameraInputOnFailure(gestureLive)).assertTrue();
      expect(shouldPreserveLiveCameraInputOnFailure(sceneLive)).assertTrue();
    });

    it('keepsLiveSceneLabelsCameraAndRetryStatePerRoute', 0, () => {
      const sceneLive: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_LIVE.name)!;
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;

      expect(usesAndroidLiveSceneLayout(sceneLive)).assertTrue();
      expect(usesAndroidLiveSceneLayout(gestureLive)).assertFalse();
      expect(liveSceneRetryActionForStatus(sceneLive, 'feature_runtime_live_camera_failed'))
        .assertEqual('restartCamera');
      expect(liveSceneRetryActionForStatus(sceneLive, 'feature_runtime_run_failed'))
        .assertEqual('restartInference');
      expect(liveSceneRetryActionForStatus(sceneLive, 'feature_runtime_scene_runner_unavailable'))
        .assertEqual('restartInference');
      expect(liveSceneRetryActionForStatus(sceneLive, 'feature_runtime_scene_failed'))
        .assertEqual('restartInference');
      expect(liveSceneRetryActionForStatus(sceneLive, 'feature_runtime_status_idle')).assertEqual('none');
      expect(liveSceneRetryActionForStatus(gestureLive, 'feature_runtime_run_failed')).assertEqual('none');
      expect(shouldPublishLiveScenePreparingStatus(sceneLive, false)).assertTrue();
      expect(shouldPublishLiveScenePreparingStatus(sceneLive, true)).assertFalse();
      expect(shouldPublishLiveScenePreparingStatus(gestureLive, true)).assertTrue();
      expect(shouldClearRuntimeResultAtWorkflowStart(sceneLive)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(sceneLive, false)).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(sceneLive, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(sceneLive, true, 'scenes')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(sceneLive, true, 'gesture')).assertFalse();
      expect(shouldPreserveLiveCameraInputOnFailure(sceneLive)).assertTrue();
    });

    it('showsObjectBoxesOnOnlyTheAndroidStyleLiveObjectPreview', 0, () => {
      expect(shouldShowLiveObjectDetectionCameraOverlay(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertTrue();
      expect(shouldShowLiveObjectDetectionCameraOverlay(workflowForRoute(AppRoute.OBJECT_PHOTO.name)))
        .assertFalse();
      expect(shouldShowLiveObjectDetectionCameraOverlay(workflowForRoute(AppRoute.GESTURE_LIVE.name)))
        .assertFalse();
      expect(shouldShowLiveObjectDetectionCameraOverlay(undefined))
        .assertFalse();
    });

    it('showsPoseSkeletonOnOnlyTheAndroidStyleLiveSkeletonPreview', 0, () => {
      expect(shouldShowLivePoseCameraOverlay(workflowForRoute(AppRoute.LIVE_SKELETON.name)))
        .assertTrue();
      expect(shouldShowLivePoseCameraOverlay(workflowForRoute(AppRoute.POSENET.name)))
        .assertFalse();
      expect(shouldShowLivePoseCameraOverlay(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldShowLivePoseCameraOverlay(undefined))
        .assertFalse();
    });

    it('showsPoseTemplateOnOnlyTheAndroidStyleLiveSkeletonPreview', 0, () => {
      expect(shouldShowLivePoseTemplateOverlay(workflowForRoute(AppRoute.LIVE_SKELETON.name)))
        .assertTrue();
      expect(shouldShowLivePoseTemplateOverlay(workflowForRoute(AppRoute.POSENET.name)))
        .assertFalse();
      expect(shouldShowLivePoseTemplateOverlay(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldShowLivePoseTemplateOverlay(undefined))
        .assertFalse();
    });

    it('showsSegmentationForegroundOnOnlyTheAndroidStyleLiveSegmentationPreview', 0, () => {
      expect(shouldShowLiveSegmentationCameraOverlay(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)))
        .assertTrue();
      expect(shouldShowLiveSegmentationCameraOverlay(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)))
        .assertTrue();
      expect(shouldShowLiveSegmentationCameraOverlay(workflowForRoute(AppRoute.SEGMENTATION_STILL.name)))
        .assertFalse();
      expect(shouldShowLiveSegmentationCameraOverlay(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldShowLiveSegmentationCameraOverlay(undefined))
        .assertFalse();
    });

    it('showsClassificationLabelOnOnlyTheAndroidStyleLiveImagePreview', 0, () => {
      expect(shouldShowLiveClassificationCameraOverlay(workflowForRoute(AppRoute.IMAGE_CAMERA.name)))
        .assertTrue();
      expect(shouldShowLiveClassificationCameraOverlay(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldShowLiveClassificationCameraOverlay(workflowForRoute(AppRoute.CUSTOM_MODEL.name)))
        .assertFalse();
      expect(shouldShowLiveClassificationCameraOverlay(undefined))
        .assertFalse();
    });

    it('usesAndroidKeepMovingPromptForEmptyLiveClassificationResults', 0, () => {
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);

      expect(liveClassificationEmptyPromptKey(imageCamera))
        .assertEqual('feature_runtime_live_classification_keep');
      expect(hasAppStringKey('feature_runtime_live_classification_keep')).assertTrue();
      expect(liveClassificationEmptyPromptKey(objectCamera))
        .assertUndefined();
      expect(liveClassificationEmptyPromptKey(undefined))
        .assertUndefined();
    });

    it('keepsPreviousLiveClassificationLabelUntilNextResultLikeAndroid', 0, () => {
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);

      expect(shouldClearRuntimeResultAtWorkflowStart(imageCamera))
        .assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(imageCamera, false))
        .assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(imageCamera, true))
        .assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)))
        .assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(workflowForRoute(AppRoute.TEXT_RECOGNITION.name)))
        .assertTrue();
      expect(shouldClearRuntimeResultAtWorkflowStart(undefined))
        .assertTrue();
    });

    it('offersExplicitLiveClassificationRetryOnlyForCameraAndInferenceFailures', 0, () => {
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);

      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_live_camera_failed'))
        .assertEqual('restartCamera');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_live_camera_surface_missing'))
        .assertEqual('restartCamera');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_permission_denied'))
        .assertEqual('restartCamera');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_live_frame_failed'))
        .assertEqual('restartInference');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_run_failed'))
        .assertEqual('restartInference');
      expect(liveClassificationRetryActionForStatus(
        imageCamera,
        'feature_runtime_classification_runner_unavailable'
      )).assertEqual('restartInference');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_classification_failed'))
        .assertEqual('restartInference');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_status_preparing'))
        .assertEqual('none');
      expect(liveClassificationRetryActionForStatus(imageCamera, 'feature_runtime_classification_done'))
        .assertEqual('none');
      expect(liveClassificationRetryActionForStatus(objectCamera, 'feature_runtime_run_failed'))
        .assertEqual('none');
      expect(liveClassificationRetryActionForStatus(undefined, 'feature_runtime_live_camera_failed'))
        .assertEqual('none');
    });

    it('keepsLiveClassificationSuccessVisibleBetweenAutomaticFrames', 0, () => {
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);

      expect(shouldPublishLiveClassificationPreparingStatus(imageCamera, false)).assertTrue();
      expect(shouldPublishLiveClassificationPreparingStatus(imageCamera, true)).assertFalse();
      expect(shouldPublishLiveClassificationPreparingStatus(objectCamera, true)).assertTrue();
      expect(shouldPublishLiveClassificationPreparingStatus(undefined, true)).assertTrue();
    });

    it('keepsLiveObjectOverlayOnFailureAndAtomicallyReplacesItOnCurrentSuccess', 0, () => {
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);

      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectCamera, false, ''))
        .assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectCamera, true, 'objectDetections'))
        .assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectCamera, true, 'classification'))
        .assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnLiveFrameFailure(objectCamera)).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnLiveFrameFailure(
        workflowForRoute(AppRoute.TEXT_RECOGNITION.name)
      )).assertFalse();
    });

    it('offersExplicitLiveObjectRetryOnlyForCameraAndInferenceFailures', 0, () => {
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);

      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_live_camera_failed'))
        .assertEqual('restartCamera');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_live_camera_surface_missing'))
        .assertEqual('restartCamera');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_permission_denied'))
        .assertEqual('restartCamera');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_live_frame_failed'))
        .assertEqual('restartInference');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_run_failed'))
        .assertEqual('restartInference');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_pending_adapter'))
        .assertEqual('restartInference');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_object_detection_failed'))
        .assertEqual('restartInference');
      expect(liveObjectDetectionRetryActionForStatus(objectCamera, 'feature_runtime_object_detection_done'))
        .assertEqual('none');
      expect(liveObjectDetectionRetryActionForStatus(imageCamera, 'feature_runtime_run_failed'))
        .assertEqual('none');
      expect(liveObjectDetectionRetryActionForStatus(undefined, 'feature_runtime_live_camera_failed'))
        .assertEqual('none');
    });

    it('keepsLiveObjectStatusVisibleBetweenAutomaticFrames', 0, () => {
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);
      const imageCamera = workflowForRoute(AppRoute.IMAGE_CAMERA.name);

      expect(shouldPublishLiveObjectDetectionPreparingStatus(objectCamera, false)).assertTrue();
      expect(shouldPublishLiveObjectDetectionPreparingStatus(objectCamera, true)).assertFalse();
      expect(shouldPublishLiveObjectDetectionPreparingStatus(imageCamera, true)).assertTrue();
      expect(shouldPublishLiveObjectDetectionPreparingStatus(undefined, true)).assertTrue();
    });

    it('samplesLiveObjectFrameLogsWithoutGrowingAtFrameRateForever', 0, () => {
      expect(shouldLogObjectDetectionLiveFrame(1)).assertTrue();
      expect(shouldLogObjectDetectionLiveFrame(8)).assertTrue();
      expect(shouldLogObjectDetectionLiveFrame(9)).assertFalse();
      expect(shouldLogObjectDetectionLiveFrame(9, false)).assertTrue();
      expect(shouldLogObjectDetectionLiveFrame(10)).assertTrue();
      expect(shouldLogObjectDetectionLiveFrame(11)).assertFalse();
    });

    it('autoStartsOnlyCameraOnlyLiveWorkflowsLikeAndroidLiveActivities', 0, () => {
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.IMAGE_CAMERA.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.OBJECT_CAMERA.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.GESTURE_LIVE.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.SCENE_LIVE.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.LIVE_SKELETON.name)!)).assertEqual('camera');
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.POSENET.name)!)).assertUndefined();
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.GESTURE_STILL.name)!)).assertUndefined();
      expect(autoStartInputKindForWorkflow(workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!)).assertUndefined();

    });

    it('keepsGenericLiveLayoutUnusedAfterSkeletonGetsItsOwnRuntime', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesSimpleAndroidLiveLayout(workflow)).assertFalse();
      });
      expect(usesSimpleAndroidLiveLayout(undefined)).assertFalse();
    });

    it('usesAndroidLiveSkeletonLayoutOnlyForLiveSkeleton', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidLiveSkeletonLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.LIVE_SKELETON.name);
      });
      expect(usesAndroidLiveSkeletonLayout(undefined)).assertFalse();
    });

    it('usesAndroidPortraitSegmentationLayoutOnlyForPortrait', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidPortraitSegmentationLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.PORTRAIT_SEGMENTATION.name);
      });
      expect(usesAndroidPortraitSegmentationLayout(undefined)).assertFalse();
    });

    it('usesAndroidTextRecognitionLayout', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidTextRecognitionLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.TEXT_RECOGNITION.name);
      });
      expect(usesAndroidTextRecognitionLayout(undefined)).assertFalse();
    });

    it('usesAndroidTextTranslationLayout', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidTextTranslationLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.TEXT_TRANSLATION.name);
      });
      expect(usesAndroidTextTranslationLayout(undefined)).assertFalse();
    });

    it('usesAndroidPoseNetStillLayoutOnlyForPoseNetStill', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidPoseNetStillLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.POSENET.name);
      });
      expect(usesAndroidPoseNetStillLayout(undefined)).assertFalse();
    });

    it('mapsAndroidPoseNetStillToastOnlyForPoseNetStill', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        const isPoseNetStill = workflow.routeName === AppRoute.POSENET.name;
        expect(poseNetStillToastKey(workflow, true)).assertEqual(
          isPoseNetStill ? 'feature_runtime_pose_detect_success_android' : undefined
        );
        expect(poseNetStillToastKey(workflow, false)).assertEqual(
          isPoseNetStill ? 'feature_runtime_pose_detect_failed_android' : undefined
        );
      });
      expect(poseNetStillToastKey(undefined, true)).assertUndefined();
      expect(poseNetStillToastKey(undefined, false)).assertUndefined();
      expect(hasAppStringKey('feature_runtime_pose_detect_android')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_detect_success_android')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_detect_failed_android')).assertTrue();
    });

    it('usesAndroidObjectPhotoLayoutOnlyForObjectPhoto', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidObjectPhotoLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.OBJECT_PHOTO.name);
      });
      expect(usesAndroidObjectPhotoLayout(undefined)).assertFalse();
    });

    it('mapsObjectPhotoFailureToastOnlyForFailedObjectPhoto', 0, () => {
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(objectPhotoResultToastKey(objectPhoto, false))
        .assertEqual('feature_runtime_object_detection_failed');
      expect(objectPhotoResultToastKey(objectPhoto, true)).assertUndefined();
      expect(objectPhotoResultToastKey(objectCamera, false)).assertUndefined();
      expect(objectPhotoResultToastKey(styleTransfer, false)).assertUndefined();
      expect(objectPhotoResultToastKey(undefined, false)).assertUndefined();
    });

    it('usesAndroidStyleTransferLayoutOnlyForStyleTransfer', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(usesAndroidStyleTransferLayout(styleTransfer)).assertTrue();
      expect(usesAndroidStyleTransferLayout(objectPhoto)).assertFalse();
      expect(usesAndroidStyleTransferLayout(undefined)).assertFalse();
    });

    it('mapsStyleTransferFailureToastOnlyForFailedStyleTransfer', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(styleTransferResultToastKey(styleTransfer, false))
        .assertEqual('feature_runtime_style_transfer_failed');
      expect(styleTransferResultToastKey(styleTransfer, true)).assertUndefined();
      expect(styleTransferResultToastKey(objectPhoto, false)).assertUndefined();
      expect(styleTransferResultToastKey(undefined, false)).assertUndefined();
    });

    it('usesAndroidStillSceneLayoutOnlyForStillScene', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidStillSceneLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.SCENE_STILL.name);
      });
      expect(usesAndroidStillSceneLayout(undefined)).assertFalse();
    });

    it('mapsOnlyStillSceneEmptyResultCodeToFailureToast', 0, () => {
      const stillScene = workflowForRoute(AppRoute.SCENE_STILL.name);
      const liveScene = workflowForRoute(AppRoute.SCENE_LIVE.name);
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(stillSceneResultToastKey(stillScene, 'SCENE_DETECTION_FAILED'))
        .assertEqual('feature_runtime_scene_failed');
      expect(stillSceneResultToastKey(stillScene, 'SCENE_DETECTION_RUNTIME_FAILED')).assertUndefined();
      expect(stillSceneResultToastKey(stillScene, 'SCENE_DETECTION_DONE')).assertUndefined();
      expect(stillSceneResultToastKey(liveScene, 'SCENE_DETECTION_FAILED')).assertUndefined();
      expect(stillSceneResultToastKey(stillSegmentation, 'SCENE_DETECTION_FAILED')).assertUndefined();
      expect(stillSceneResultToastKey(styleTransfer, 'SCENE_DETECTION_FAILED')).assertUndefined();
      expect(stillSceneResultToastKey(objectPhoto, 'SCENE_DETECTION_FAILED')).assertUndefined();
      expect(stillSceneResultToastKey(undefined, 'SCENE_DETECTION_FAILED')).assertUndefined();
    });

    it('preservesRowsForFailedStillSceneAndObjectPhotoResults', 0, () => {
      const stillScene = workflowForRoute(AppRoute.SCENE_STILL.name);
      const liveScene = workflowForRoute(AppRoute.SCENE_LIVE.name);
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(shouldPreserveRuntimeTextResultOnAiResult(stillScene, false)).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(stillScene, true)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(liveScene, false)).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(stillSegmentation, false)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(styleTransfer, false)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(objectPhoto, false)).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(objectPhoto, true)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(undefined, false)).assertFalse();
    });

    it('preservesStillSceneRowsAndRejectsOnlyRunningPrimaryInputChanges', 0, () => {
      const stillScene = workflowForRoute(AppRoute.SCENE_STILL.name);
      const liveScene = workflowForRoute(AppRoute.SCENE_LIVE.name);
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(shouldPreserveRuntimeResultAfterInputReady(stillScene, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillScene, 'camera')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillScene, 'backgroundImage')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(liveScene, 'photo')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'contentImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(objectPhoto, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(objectPhoto, 'modelFile')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(objectPhoto, 'camera')).assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(stillScene)).assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(objectPhoto)).assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(liveScene)).assertFalse();

      expect(shouldAllowRuntimeInputChange(stillScene, 'photo', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(stillScene, 'camera', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(stillScene, 'backgroundImage', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(stillScene, 'photo', false)).assertTrue();
      expect(shouldAllowRuntimeInputChange(liveScene, 'photo', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(stillSegmentation, 'photo', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'contentImage', true)).assertFalse();
    });

    it('usesAndroidStillSegmentationLayoutOnlyForStillSegmentation', 0, () => {
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const liveSegmentation = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name);
      const portraitSegmentation = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(usesAndroidStillSegmentationLayout(stillSegmentation)).assertTrue();
      expect(usesAndroidStillSegmentationLayout(liveSegmentation)).assertFalse();
      expect(usesAndroidStillSegmentationLayout(portraitSegmentation)).assertFalse();
      expect(usesAndroidStillSegmentationLayout(styleTransfer)).assertFalse();
      expect(usesAndroidStillSegmentationLayout(undefined)).assertFalse();
    });

    it('mapsStillSegmentationFailureToastOnlyForFailedStillSegmentation', 0, () => {
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const liveSegmentation = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name);
      const portraitSegmentation = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(stillSegmentationResultToastKey(stillSegmentation, false))
        .assertEqual('feature_runtime_segmentation_failed');
      expect(stillSegmentationResultToastKey(stillSegmentation, true)).assertUndefined();
      expect(stillSegmentationResultToastKey(liveSegmentation, false)).assertUndefined();
      expect(stillSegmentationResultToastKey(portraitSegmentation, false)).assertUndefined();
      expect(stillSegmentationResultToastKey(styleTransfer, false)).assertUndefined();
      expect(stillSegmentationResultToastKey(undefined, false)).assertUndefined();
    });

    it('preservesStillAndLiveSegmentationForegroundUntilAtomicReplacement', 0, () => {
      const stillSegmentation = workflowForRoute(AppRoute.SEGMENTATION_STILL.name);
      const liveSegmentation = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name);
      const portraitSegmentation = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'camera')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'backgroundImage')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(stillSegmentation, 'styleImage')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(liveSegmentation, 'photo')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'camera')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'backgroundImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'contentImage')).assertTrue();

      expect(shouldClearRuntimeResultAtWorkflowStart(stillSegmentation)).assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(liveSegmentation)).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(stillSegmentation, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(stillSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(stillSegmentation, true, 'classification')).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(liveSegmentation, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(liveSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(portraitSegmentation, true, 'segmentation')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(styleTransfer, true, 'styleTransfer')).assertTrue();
    });

    it('mapsStyleSelectionOriginalRequiredToastOnlyForStyleTransferWithoutContent', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(styleTransferStyleSelectionToastKey(styleTransfer, 'styleImage', false))
        .assertEqual('feature_runtime_style_original_required');
      expect(styleTransferStyleSelectionToastKey(styleTransfer, 'styleImage', true)).assertUndefined();
      expect(styleTransferStyleSelectionToastKey(objectPhoto, 'styleImage', false)).assertUndefined();
      expect(styleTransferStyleSelectionToastKey(styleTransfer, 'contentImage', false)).assertUndefined();
      expect(styleTransferStyleSelectionToastKey(styleTransfer, 'camera', false)).assertUndefined();
      expect(styleTransferStyleSelectionToastKey(undefined, 'styleImage', false)).assertUndefined();
    });

    it('mapsStyleTransferModelCacheToastOnlyForExactModelSlots', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      const successKey = 'feature_runtime_model_ready';
      const failureKey = 'feature_runtime_model_cache_failed';

      expect(styleTransferModelCacheToastKey(styleTransfer, 'stylePredictModelFile', successKey))
        .assertEqual(successKey);
      expect(styleTransferModelCacheToastKey(styleTransfer, 'styleTransferModelFile', failureKey))
        .assertEqual(failureKey);
      expect(styleTransferModelCacheToastKey(styleTransfer, 'photo', successKey)).assertUndefined();
      expect(styleTransferModelCacheToastKey(styleTransfer, 'styleImage', successKey)).assertUndefined();
      expect(styleTransferModelCacheToastKey(styleTransfer, 'modelFile', successKey)).assertUndefined();
      expect(styleTransferModelCacheToastKey(objectPhoto, 'stylePredictModelFile', successKey)).assertUndefined();
      expect(styleTransferModelCacheToastKey(undefined, 'styleTransferModelFile', successKey)).assertUndefined();
    });

    it('resetsStyleTransferPageOnlyAfterSuccessfulModelSlotCache', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        styleTransfer, 'stylePredictModelFile', true)).assertTrue();
      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        styleTransfer, 'styleTransferModelFile', true)).assertTrue();
      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        styleTransfer, 'stylePredictModelFile', false)).assertFalse();
      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        styleTransfer, 'styleImage', true)).assertFalse();
      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        objectPhoto, 'stylePredictModelFile', true)).assertFalse();
      expect(shouldResetStyleTransferPageAfterModelCacheResult(
        undefined, 'styleTransferModelFile', true)).assertFalse();
    });

    it('preservesStyleTransferResultUntilExplicitAtomicReplacementOrReset', 0, () => {
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);

      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'contentImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'camera')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'styleImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'stylePredictModelFile')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'styleTransferModelFile')).assertTrue();
      expect(shouldShowStyleOriginalAfterInputReady(styleTransfer, 'contentImage')).assertTrue();
      expect(shouldShowStyleOriginalAfterInputReady(styleTransfer, 'camera')).assertTrue();
      expect(shouldShowStyleOriginalAfterInputReady(styleTransfer, 'styleImage')).assertFalse();
      expect(shouldShowStyleOriginalAfterInputReady(styleTransfer, 'stylePredictModelFile')).assertFalse();
      expect(shouldShowStyleOriginalAfterInputReady(styleTransfer, 'styleTransferModelFile')).assertFalse();
      expect(shouldShowStyleOriginalAfterInputReady(objectPhoto, 'contentImage')).assertFalse();
      expect(shouldShowStyleOriginalAfterInputReady(undefined, 'camera')).assertFalse();

      expect(shouldClearRuntimeResultAtWorkflowStart(styleTransfer)).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(styleTransfer, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(styleTransfer, false, 'styleTransfer')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(styleTransfer, true, 'styleTransfer')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(styleTransfer, true, 'classification')).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectPhoto, false, '')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectPhoto, false, 'styleTransfer')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectPhoto, true, 'objectDetections')).assertTrue();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(objectPhoto, true, 'styleTransfer')).assertFalse();
      expect(shouldPreserveRuntimeVisualResultOnAiResult(undefined, false, '')).assertFalse();
    });

    it('repicksPhotoOnlyAfterObjectPhotoModelCacheSuccess', 0, () => {
      const objectPhoto = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      const objectCamera = workflowForRoute(AppRoute.OBJECT_CAMERA.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(objectPhoto, 'modelFile')).assertEqual('photo');
      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(objectPhoto, 'photo')).assertUndefined();
      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(objectPhoto, 'camera')).assertUndefined();
      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(objectCamera, 'modelFile')).assertUndefined();
      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(styleTransfer, 'modelFile')).assertUndefined();
      expect(objectPhotoFollowupInputKindAfterModelCacheSuccess(undefined, 'modelFile')).assertUndefined();
    });

    it('usesAndroidCustomModelLayoutOnlyForCustomModel', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidCustomModelLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.CUSTOM_MODEL.name);
      });
      expect(usesAndroidCustomModelLayout(undefined)).assertFalse();
    });

    it('removesOnlyCustomModelExecutePermissions', 0, () => {
      expect(workflowForRoute(AppRoute.CUSTOM_MODEL.name)!.requiredPermissions.length).assertEqual(0);
      expect(JSON.stringify(workflowForRoute(AppRoute.POSENET.name)!.requiredPermissions))
        .assertEqual(JSON.stringify(['camera', 'media']));
      expect(JSON.stringify(workflowForRoute(AppRoute.OBJECT_PHOTO.name)!.requiredPermissions))
        .assertEqual(JSON.stringify(['media']));
      expect(JSON.stringify(workflowForRoute(AppRoute.OBJECT_CAMERA.name)!.requiredPermissions))
        .assertEqual(JSON.stringify(['camera']));
      expect(JSON.stringify(workflowForRoute(AppRoute.STYLE_TRANSFER.name)!.requiredPermissions))
        .assertEqual(JSON.stringify(['camera', 'media']));
    });

    it('ordersCustomModelExecutePreflightLikeAndroid', 0, () => {
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(customModelExecutePreflightToastKey(customModel, false, false, false))
        .assertEqual('feature_runtime_custom_model_image_required');
      expect(customModelExecutePreflightToastKey(customModel, false, false, true))
        .assertEqual('feature_runtime_custom_model_image_required');
      expect(customModelExecutePreflightToastKey(customModel, true, false, true))
        .assertEqual('feature_runtime_custom_model_model_required');
      expect(customModelExecutePreflightToastKey(customModel, true, true, true))
        .assertEqual('feature_runtime_custom_model_already_running');
      expect(customModelExecutePreflightToastKey(customModel, true, true, false)).assertUndefined();
      expect(customModelExecutePreflightToastKey(styleTransfer, false, false, true)).assertUndefined();
      expect(customModelExecutePreflightToastKey(undefined, false, false, true)).assertUndefined();
    });

    it('resolvesCustomModelOutputFallbackInVisiblePriorityOrder', 0, () => {
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(customModelOutputFallbackKey(customModel, true, true, 'terminal output'))
        .assertEqual('feature_runtime_custom_model_running_output');
      expect(customModelOutputFallbackKey(customModel, false, true, 'terminal output'))
        .assertEqual('feature_runtime_permission_denied');
      expect(customModelOutputFallbackKey(customModel, false, false, 'terminal output')).assertUndefined();
      expect(customModelOutputFallbackKey(customModel, false, false, ''))
        .assertEqual('feature_runtime_custom_model_output_placeholder');
      expect(customModelOutputFallbackKey(styleTransfer, true, true, '')).assertUndefined();
      expect(customModelOutputFallbackKey(undefined, true, true, '')).assertUndefined();
    });

    it('preservesCustomModelTerminalOutputAcrossInputReadyChanges', 0, () => {
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const portraitSegmentation = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(shouldPreserveRuntimeResultAfterInputReady(customModel, 'modelFile')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(customModel, 'photo')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(customModel, 'camera')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(customModel, 'text')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'backgroundImage')).assertTrue();
      expect(shouldPreserveRuntimeResultAfterInputReady(portraitSegmentation, 'camera')).assertFalse();
      expect(shouldPreserveRuntimeResultAfterInputReady(styleTransfer, 'styleImage')).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(customModel, false)).assertTrue();
      expect(shouldPreserveRuntimeTextResultOnAiResult(customModel, false, false)).assertFalse();
      expect(shouldPreserveRuntimeTextResultOnAiResult(customModel, true)).assertFalse();
      expect(shouldClearRuntimeResultAtWorkflowStart(customModel)).assertFalse();
    });

    it('blocksOnlyRunningCustomModelAndStyleTransferInputChanges', 0, () => {
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);
      const textRecognition = workflowForRoute(AppRoute.TEXT_RECOGNITION.name);

      expect(shouldAllowRuntimeInputChange(customModel, 'modelFile', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(customModel, 'photo', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(customModel, 'camera', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(customModel, 'text', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(customModel, 'photo', false)).assertTrue();
      expect(shouldAllowRuntimeInputChange(styleTransfer, 'styleImage', true)).assertFalse();
      expect(shouldAllowRuntimeInputChange(textRecognition, 'photo', true)).assertTrue();
      expect(shouldAllowRuntimeInputChange(undefined, 'photo', true)).assertTrue();
    });

    it('skipsOnlyCustomModelCachedModelRestore', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(shouldRestoreCachedModelFileInputs(workflow))
          .assertEqual(workflow.routeName !== AppRoute.CUSTOM_MODEL.name);
      });
      expect(shouldRestoreCachedModelFileInputs(undefined)).assertFalse();
    });

    it('mapsCustomModelCacheToastsAndDeclaresAndroidOutputStrings', 0, () => {
      const customModel = workflowForRoute(AppRoute.CUSTOM_MODEL.name);
      const styleTransfer = workflowForRoute(AppRoute.STYLE_TRANSFER.name);

      expect(customModelModelCacheToastKey(customModel, 'feature_runtime_model_ready'))
        .assertEqual('feature_runtime_model_ready');
      expect(customModelModelCacheToastKey(customModel, 'feature_runtime_model_cache_failed'))
        .assertEqual('feature_runtime_model_cache_failed');
      expect(customModelModelCacheToastKey(customModel, 'feature_runtime_model_incompatible'))
        .assertEqual('feature_runtime_model_incompatible');
      expect(customModelModelCacheToastKey(styleTransfer, 'feature_runtime_model_ready')).assertUndefined();
      expect(customModelModelCacheToastKey(undefined, 'feature_runtime_model_ready')).assertUndefined();
      expect(hasAppStringKey('feature_runtime_custom_model_execute')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_running_output')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_already_running')).assertTrue();
      expect(hasAppStringKey('feature_runtime_custom_model_failure_output')).assertTrue();
    });

    it('usesAndroidGestureStillLayoutOnlyForStaticGesture', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidGestureStillLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.GESTURE_STILL.name);
      });
      expect(usesAndroidGestureStillLayout(undefined)).assertFalse();
    });

    it('showsAndroidGestureFailureToastOnlyForFailedStaticGesture', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(shouldShowGestureStillFailureToast(workflow, false))
          .assertEqual(workflow.routeName === AppRoute.GESTURE_STILL.name);
        expect(shouldShowGestureStillFailureToast(workflow, true)).assertFalse();
      });
      expect(shouldShowGestureStillFailureToast(undefined, false)).assertFalse();
      expect(shouldShowGestureStillFailureToast(undefined, true)).assertFalse();
    });

    it('selectsSpecializedAndroidLiveLayoutForEveryRouteSpecificCameraWorkflow', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        let expectedLayout: string | undefined = undefined;
        if (workflow.routeName === AppRoute.IMAGE_CAMERA.name) {
          expectedLayout = 'imageClassification';
        } else if (workflow.routeName === AppRoute.OBJECT_CAMERA.name) {
          expectedLayout = 'objectDetection';
        } else if (workflow.routeName === AppRoute.SEGMENTATION_LIVE.name) {
          expectedLayout = 'segmentation';
        } else if (workflow.routeName === AppRoute.GESTURE_LIVE.name) {
          expectedLayout = 'gesture';
        } else if (workflow.routeName === AppRoute.SCENE_LIVE.name) {
          expectedLayout = 'scene';
        } else if (workflow.routeName === AppRoute.LIVE_SKELETON.name) {
          expectedLayout = 'skeleton';
        }
        expect(specializedAndroidLiveLayoutForWorkflow(workflow)).assertEqual(expectedLayout);
      });
      expect(specializedAndroidLiveLayoutForWorkflow(undefined)).assertUndefined();
    });

    it('coversEveryRegisteredWorkflowWithExactlyOneAndroidLayoutFamily', 0, () => {
      const layoutMatchCount = (workflow: FeatureWorkflow | undefined): number => [
        usesAndroidTextTranslationLayout(workflow),
        usesAndroidTextRecognitionLayout(workflow),
        usesAndroidPoseNetStillLayout(workflow),
        usesAndroidGestureStillLayout(workflow),
        usesAndroidObjectPhotoLayout(workflow),
        usesAndroidStyleTransferLayout(workflow),
        usesAndroidCustomModelLayout(workflow),
        usesAndroidStillSegmentationLayout(workflow),
        usesAndroidStillSceneLayout(workflow),
        usesAndroidPortraitSegmentationLayout(workflow),
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'imageClassification',
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'objectDetection',
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'segmentation',
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'gesture',
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'scene',
        specializedAndroidLiveLayoutForWorkflow(workflow) === 'skeleton',
        usesSimpleAndroidLiveLayout(workflow)
      ].filter((matches: boolean) => matches).length;

      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(layoutMatchCount(workflow)).assertEqual(1);
      });
      expect(layoutMatchCount(undefined)).assertEqual(0);
    });

    it('hidesAutoStartCameraFromLiveInputChipsLikeAndroidLiveActivities', 0, () => {
      const liveRouteNames: Array<string> = [
        AppRoute.LIVE_SKELETON.name,
        AppRoute.SEGMENTATION_LIVE.name,
        AppRoute.PORTRAIT_SEGMENTATION.name,
        AppRoute.IMAGE_CAMERA.name,
        AppRoute.GESTURE_LIVE.name,
        AppRoute.SCENE_LIVE.name,
        AppRoute.OBJECT_CAMERA.name
      ];
      expect(liveRouteNames.length).assertEqual(7);
      expect(new Set<string>(liveRouteNames).size).assertEqual(7);

      let emptyVisibleInputCount = 0;
      liveRouteNames.forEach((routeName: string) => {
        const workflow: FeatureWorkflow = workflowForRoute(routeName)!;
        expect(runtimeInputKindsForWorkflow(workflow).includes('camera')).assertTrue();
        expect(autoStartInputKindForWorkflow(workflow)).assertEqual('camera');
        const visibleInputs: Array<FeatureInputKind> = visibleInputKindsForWorkflow(workflow);
        if (routeName === AppRoute.OBJECT_CAMERA.name) {
          expect(JSON.stringify(visibleInputs)).assertEqual(JSON.stringify(['modelFile']));
        } else {
          expect(visibleInputs.length).assertEqual(0);
          emptyVisibleInputCount += 1;
        }
      });
      expect(emptyVisibleInputCount).assertEqual(6);

      const stillRouteNames: Array<string> = [
        AppRoute.POSENET.name,
        AppRoute.SEGMENTATION_STILL.name,
        AppRoute.GESTURE_STILL.name,
        AppRoute.SCENE_STILL.name
      ];
      stillRouteNames.forEach((routeName: string) => {
        const workflow: FeatureWorkflow = workflowForRoute(routeName)!;
        expect(JSON.stringify(visibleInputKindsForWorkflow(workflow)))
          .assertEqual(JSON.stringify(['photo', 'camera']));
      });
    });

    it('replacesOnlyStillPrimaryInputPreviewsAfterTheirOverlayIsReady', 0, () => {
      const overlayRouteNames: Array<string> = [
        AppRoute.OBJECT_PHOTO.name,
        AppRoute.POSENET.name,
        AppRoute.GESTURE_STILL.name
      ];

      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(shouldShowPrimaryImageInputPreview(workflow, false)).assertTrue();
        expect(shouldShowPrimaryImageInputPreview(workflow, true))
          .assertEqual(overlayRouteNames.indexOf(workflow.routeName) < 0);
      });
      expect(shouldShowPrimaryImageInputPreview(undefined, false)).assertTrue();
      expect(shouldShowPrimaryImageInputPreview(undefined, true)).assertTrue();
    });

    it('showsPrimaryRunActionOnlyForAndroidManualWorkflows', 0, () => {
      const expectedRouteNames: Array<string> = [
        AppRoute.POSENET.name,
        AppRoute.LIVE_SKELETON.name,
        AppRoute.SEGMENTATION_STILL.name,
        AppRoute.SEGMENTATION_LIVE.name,
        AppRoute.PORTRAIT_SEGMENTATION.name,
        AppRoute.IMAGE_CAMERA.name,
        AppRoute.GESTURE_STILL.name,
        AppRoute.GESTURE_LIVE.name,
        AppRoute.SCENE_STILL.name,
        AppRoute.SCENE_LIVE.name,
        AppRoute.TEXT_RECOGNITION.name,
        AppRoute.TEXT_TRANSLATION.name,
        AppRoute.OBJECT_PHOTO.name,
        AppRoute.OBJECT_CAMERA.name,
        AppRoute.STYLE_TRANSFER.name,
        AppRoute.CUSTOM_MODEL.name
      ];
      const manualRouteNames: Array<string> = [
        AppRoute.POSENET.name,
        AppRoute.TEXT_TRANSLATION.name,
        AppRoute.CUSTOM_MODEL.name
      ];

      expect(featureWorkflows.length).assertEqual(expectedRouteNames.length);
      expectedRouteNames.forEach((routeName: string) => {
        expect(featureWorkflows.filter((workflow: FeatureWorkflow) => workflow.routeName === routeName).length)
          .assertEqual(1);
      });
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(expectedRouteNames.indexOf(workflow.routeName) >= 0).assertTrue();
        expect(shouldShowPrimaryRunAction(workflow))
          .assertEqual(manualRouteNames.indexOf(workflow.routeName) >= 0);
      });
      expect(shouldShowPrimaryRunAction(undefined)).assertFalse();
    });

    it('usesAndroidFrontCameraDefaultsForSelfieLiveWorkflows', 0, () => {
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!))
        .assertEqual('front');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!))
        .assertEqual('front');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.SCENE_LIVE.name)!))
        .assertEqual('front');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.IMAGE_CAMERA.name)!)).assertEqual('back');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.OBJECT_CAMERA.name)!)).assertEqual('back');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.GESTURE_LIVE.name)!)).assertEqual('back');
      expect(initialLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.LIVE_SKELETON.name)!)).assertEqual('back');
      expect(initialLiveCameraPositionForWorkflow(undefined)).assertEqual('back');
    });

    it('fixesAndroidImageObjectLiveCameraWorkflowsToBackCamera', 0, () => {
      expect(fixedLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.IMAGE_CAMERA.name)!)).assertEqual('back');
      expect(fixedLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.OBJECT_CAMERA.name)!)).assertEqual('back');
      expect(fixedLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!)).assertUndefined();
      expect(fixedLiveCameraPositionForWorkflow(workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!)).assertUndefined();
      expect(fixedLiveCameraPositionForWorkflow(undefined)).assertUndefined();
    });

    it('remembersLiveCameraPositionPerRouteAfterSwitches', 0, () => {
      resetRememberedLiveCameraPositionsForTests();
      const segmentationLive: FeatureWorkflow = workflowForRoute(AppRoute.SEGMENTATION_LIVE.name)!;
      const sceneLive: FeatureWorkflow = workflowForRoute(AppRoute.SCENE_LIVE.name)!;
      const gestureLive: FeatureWorkflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;

      expect(rememberedLiveCameraPositionForWorkflow(segmentationLive)).assertEqual('front');
      expect(rememberedLiveCameraPositionForWorkflow(sceneLive)).assertEqual('front');
      expect(rememberedLiveCameraPositionForWorkflow(gestureLive)).assertEqual('back');

      rememberLiveCameraPositionForRoute(segmentationLive.routeName, 'back');
      rememberLiveCameraPositionForRoute(gestureLive.routeName, 'front');

      expect(rememberedLiveCameraPositionForWorkflow(segmentationLive)).assertEqual('back');
      expect(rememberedLiveCameraPositionForWorkflow(sceneLive)).assertEqual('front');
      expect(rememberedLiveCameraPositionForWorkflow(gestureLive)).assertEqual('front');
      expect(rememberedLiveCameraPositionForWorkflow(undefined)).assertEqual('back');
      resetRememberedLiveCameraPositionsForTests();
    });

    it('doesNotRememberManualSwitchesForAndroidFixedCameraWorkflows', 0, () => {
      resetRememberedLiveCameraPositionsForTests();
      const imageCamera: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;

      rememberLiveCameraPositionForRoute(imageCamera.routeName, 'front');
      rememberLiveCameraPositionForRoute(objectCamera.routeName, 'front');

      expect(rememberedLiveCameraPositionForWorkflow(imageCamera)).assertEqual('back');
      expect(rememberedLiveCameraPositionForWorkflow(objectCamera)).assertEqual('back');
      resetRememberedLiveCameraPositionsForTests();
    });

    it('autoPreparesObjectPhotoAlbumInputLikeAndroidPhotoActivity', 0, () => {
      expect(initialInputKindForWorkflow(workflowForRoute(AppRoute.OBJECT_PHOTO.name)!)).assertEqual('photo');
      expect(initialInputKindForWorkflow(workflowForRoute(AppRoute.OBJECT_CAMERA.name)!)).assertUndefined();
      expect(initialInputKindForWorkflow(workflowForRoute(AppRoute.POSENET.name)!)).assertUndefined();
      expect(initialInputKindForWorkflow(workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!)).assertUndefined();
    });

    it('hidesAutoPreparedObjectPhotoAlbumInputLikeAndroidPhotoActivity', 0, () => {
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;

      expect(JSON.stringify(runtimeInputKindsForWorkflow(objectPhoto)))
        .assertEqual(JSON.stringify(['photo', 'modelFile']));
      expect(initialInputKindForWorkflow(objectPhoto)).assertEqual('photo');
      expect(autoStartInputKindForWorkflow(objectPhoto)).assertUndefined();
      expect(JSON.stringify(visibleInputKindsForWorkflow(objectPhoto)))
        .assertEqual(JSON.stringify(['modelFile']));
    });

    it('keepsObjectPhotoScreenOnLikeAndroidLayout', 0, () => {
      expect(shouldKeepScreenOnForWorkflow(workflowForRoute(AppRoute.OBJECT_PHOTO.name)))
        .assertTrue();
      expect(shouldKeepScreenOnForWorkflow(workflowForRoute(AppRoute.OBJECT_CAMERA.name)))
        .assertFalse();
      expect(shouldKeepScreenOnForWorkflow(workflowForRoute(AppRoute.IMAGE_CAMERA.name)))
        .assertFalse();
      expect(shouldKeepScreenOnForWorkflow(undefined))
        .assertFalse();
    });

    it('leavesRuntimeOnlyWhenObjectPhotoInitialPickIsCancelledLikeAndroid', 0, () => {
      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(shouldLeaveRuntimeAfterCancelledInitialPick(objectPhoto, 'photo', true)).assertTrue();
      expect(shouldLeaveRuntimeAfterCancelledInitialPick(objectPhoto, 'photo', false)).assertFalse();
      expect(shouldLeaveRuntimeAfterCancelledInitialPick(objectPhoto, 'modelFile', true)).assertFalse();
      expect(shouldLeaveRuntimeAfterCancelledInitialPick(objectPhoto, 'modelFile', false)).assertFalse();
      expect(cancelledPickStatusKeyForWorkflow(objectPhoto, 'photo', true)).assertEqual('feature_runtime_image_invalid');
      expect(cancelledPickToastStatusKeyForWorkflow(objectPhoto, 'photo', true))
        .assertEqual('feature_runtime_image_invalid');
      expect(cancelledPickStatusKeyForWorkflow(objectPhoto, 'photo', false))
        .assertEqual('feature_runtime_pick_cancelled');
      expect(cancelledPickToastStatusKeyForWorkflow(objectPhoto, 'photo', false)).assertUndefined();

      const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
      expect(shouldLeaveRuntimeAfterCancelledInitialPick(textRecognition, 'photo', true)).assertFalse();
      expect(cancelledPickStatusKeyForWorkflow(textRecognition, 'photo', true))
        .assertEqual('feature_runtime_pick_cancelled');
      expect(cancelledPickToastStatusKeyForWorkflow(textRecognition, 'photo', true)).assertUndefined();
    });

    it('previewsAndroidPoseNetSampleOnEntryWithoutAutoDetecting', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      const initialPreview = initialPreviewActionForWorkflow(posenet)!;

      expect(initialPreview.inputKind).assertEqual('sampleImage');
      expect(initialPreview.uri).assertEqual('rawfile://posenet/skeleton_image.JPG');
      expect(initialPreview.readyKey).assertEqual('feature_runtime_image_ready');
      expect(initialPreview.shouldRunWorkflow).assertFalse();
      expect(initialPreviewActionForWorkflow(workflowForRoute(AppRoute.OBJECT_PHOTO.name)!)).assertUndefined();
    });

    it('liveCameraPreviewServiceRequiresSurfaceIdBeforeStarting', 0, async () => {
      const driver = new RecordingLiveCameraPreviewDriver(false);
      const result = await new LiveCameraPreviewService(driver).start('');

      expect(result.ok).assertFalse();
      expect(result.messageKey).assertEqual('feature_runtime_live_camera_surface_missing');
      expect(driver.startedSurfaceIds.length).assertEqual(0);
    });

    it('liveCameraPreviewServiceReportsReadyAndFailure', 0, async () => {
      const readyDriver = new RecordingLiveCameraPreviewDriver(false, 90, 3 / 4);
      const readyResult = await new LiveCameraPreviewService(readyDriver).start('surface-1');
      const failedResult = await new LiveCameraPreviewService(new RecordingLiveCameraPreviewDriver(true)).start('surface-2');

      expect(liveCameraXComponentId.length > 0).assertTrue();
      expect(readyResult.ok).assertTrue();
      expect(readyResult.surfaceId).assertEqual('surface-1');
      expect(readyResult.messageKey).assertEqual('feature_runtime_live_camera_ready');
      expect(readyResult.previewRotationDegrees).assertEqual(90);
      expect(readyResult.previewAspectRatio).assertEqual(3 / 4);
      expect(readyDriver.startedSurfaceIds[0]).assertEqual('surface-1');
      expect(readyDriver.startedPositions[0]).assertEqual('back');
      expect(failedResult.ok).assertFalse();
      expect(failedResult.messageKey).assertEqual('feature_runtime_live_camera_failed');
    });

    it('liveCameraPreviewServiceReadsTheCurrentRotationForEachFrame', 0, async () => {
      const driver = new RecordingLiveCameraPreviewDriver(false, 90);
      const service = new LiveCameraPreviewService(driver);
      await service.start('surface-rotation');

      expect(service.previewRotationDegrees()).assertEqual(90);
      driver.setRotationDegrees(180);
      expect(service.previewRotationDegrees()).assertEqual(180);
    });

    it('mapsBackCameraSensorContentIntoTheCurrentDisplayRotation', 0, () => {
      expect(livePreviewContentRotationDegrees(90, 0, 'back', 0)).assertEqual(90);
      expect(livePreviewContentRotationDegrees(90, 1, 'back', 0)).assertEqual(0);
      expect(livePreviewContentRotationDegrees(270, 0, 'back', 0)).assertEqual(270);
      expect(livePreviewContentRotationDegrees(90, 1, 'front', 0)).assertEqual(180);
      expect(livePreviewContentRotationDegrees(270, 1, 'front', 0)).assertEqual(0);
      expect(livePreviewContentRotationDegrees(-1, 0, 'back', 90)).assertEqual(90);
    });

    it('swapsTheCameraAspectRatioForQuarterTurnPreviewRotation', 0, () => {
      expect(livePreviewAspectRatioForRotation(270)).assertEqual(3 / 4);
      expect(livePreviewAspectRatioForRotation(90)).assertEqual(3 / 4);
      expect(livePreviewAspectRatioForRotation(0)).assertEqual(4 / 3);
      expect(livePreviewAspectRatioForRotation(45)).assertEqual(4 / 3);
    });

    it('usesCompactWidthOnlyForVerticalCameraPreviews', 0, () => {
      expect(livePreviewWidthForAspectRatio(3 / 4)).assertEqual('78%');
      expect(livePreviewWidthForAspectRatio(4 / 3)).assertEqual('100%');
      expect(livePreviewWidthForAspectRatio(Number.NaN)).assertEqual('100%');
    });

    it('refreshesNativeFallbackWhenDisplayRotatesWithInvalidSensorOrientation', 0, () => {
      const displayProvider = new MutableLiveDisplayRotationProvider(0);
      const output = new RecordingLivePreviewRotationOutput([90, 0, 45]);
      const tracker = new LivePreviewRotationTracker(-1, 'back', output, displayProvider);

      expect(tracker.currentRotationDegrees()).assertEqual(90);
      displayProvider.rotation = 1;
      expect(tracker.currentRotationDegrees()).assertEqual(0);
      expect(output.displayRotations.length).assertEqual(2);
      expect(output.displayRotations[0]).assertEqual(0);
      expect(output.displayRotations[1]).assertEqual(1);

      displayProvider.rotation = 2;
      expect(tracker.currentRotationDegrees()).assertEqual(0);
      expect(output.displayRotations[2]).assertEqual(2);

      output.fail = true;
      displayProvider.rotation = 3;
      expect(tracker.currentRotationDegrees()).assertEqual(0);
      expect(output.displayRotations[3]).assertEqual(3);
    });

    it('doesNotCallNativeFallbackWhenSensorOrientationIsValid', 0, () => {
      const displayProvider = new MutableLiveDisplayRotationProvider(0);
      const output = new RecordingLivePreviewRotationOutput([180]);
      const tracker = new LivePreviewRotationTracker(90, 'back', output, displayProvider);

      expect(tracker.currentRotationDegrees()).assertEqual(90);
      displayProvider.rotation = 1;
      expect(tracker.currentRotationDegrees()).assertEqual(0);
      expect(output.displayRotations.length).assertEqual(0);
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

    it('showsLiveCameraSwitchOnlyWhenFrontAndBackCamerasAreAvailable', 0, () => {
      expect(liveCameraSwitchAvailableForPositions(['back', 'front'])).assertTrue();
      expect(liveCameraSwitchAvailableForPositions(['front', 'back', 'front'])).assertTrue();
      expect(liveCameraSwitchAvailableForPositions(['back'])).assertFalse();
      expect(liveCameraSwitchAvailableForPositions(['front'])).assertFalse();
      expect(liveCameraSwitchAvailableForPositions([])).assertFalse();
    });

    it('usesAvailableLiveCameraPositionWhenPreferredCameraIsMissing', 0, () => {
      expect(liveCameraPreferredPositionForAvailablePositions('back', ['back', 'front'])).assertEqual('back');
      expect(liveCameraPreferredPositionForAvailablePositions('front', ['back', 'front'])).assertEqual('front');
      expect(liveCameraPreferredPositionForAvailablePositions('back', ['front'])).assertEqual('front');
      expect(liveCameraPreferredPositionForAvailablePositions('front', ['back'])).assertEqual('back');
      expect(liveCameraPreferredPositionForAvailablePositions('back', [])).assertEqual('back');
    });

    it('liveCameraSwitchCapabilityFallsBackToPreviousManualSwitchBehavior', 0, () => {
      const frontOnly = new LiveCameraSwitchCapabilityService(
        new FixedLiveCameraDevicePositionProvider(['front'])
      ).capability('back');
      const unknown = new LiveCameraSwitchCapabilityService(
        new ThrowingLiveCameraDevicePositionProvider()
      ).capability('front');

      expect(frontOnly.canSwitch).assertFalse();
      expect(frontOnly.preferredPosition).assertEqual('front');
      expect(unknown.canSwitch).assertTrue();
      expect(unknown.preferredPosition).assertEqual('front');
    });

    it('liveFrameImageServiceCapturesSurfaceToCacheImageUri', 0, async () => {
      const encoder = new FixedLiveFrameImageEncoder(new Uint8Array([1, 2, 3]).buffer as ArrayBuffer);
      const store = new RecordingLiveFrameImageStore('/cache/live-frame.jpg');
      const result = await new LiveFrameImageService(encoder, store)
        .captureToCacheImage('surface-1', '/cache', 270);

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('/cache/live-frame.jpg');
      expect(result.messageKey).assertEqual('feature_runtime_image_ready');
      expect(encoder.seenSurfaceIds[0]).assertEqual('surface-1');
      expect(encoder.seenRotationDegrees[0]).assertEqual(270);
      expect(store.seenCacheDirs[0]).assertEqual('/cache');
      expect(store.seenBytes[0][2]).assertEqual(3);
    });

    it('liveFrameImageEncoderUsesAndroidLikeJpegPacking', 0, () => {
      expect(liveFrameImagePackingOption.format).assertEqual('image/jpeg');
      expect(liveFrameImagePackingOption.quality).assertEqual(90);
    });

    it('normalizesLiveFrameCachePathForStableJpegSlot', 0, () => {
      expect(liveFrameImageCachePath('/cache')).assertEqual('/cache/mindspore_live_frame.jpg');
      expect(liveFrameImageCachePath('/cache/')).assertEqual('/cache/mindspore_live_frame.jpg');
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

    it('capturesLiveFrameWheneverLiveCameraIsSelectedEvenBeforePreviewActivation', 0, () => {
      expect(shouldCaptureLiveFrameImage(false, '', false)).assertFalse();
      expect(shouldCaptureLiveFrameImage(false, '/cache/selected.jpg', true)).assertFalse();
      expect(shouldCaptureLiveFrameImage(true, '', false)).assertTrue();
      expect(shouldCaptureLiveFrameImage(true, '/cache/selected.jpg', false)).assertTrue();
      expect(shouldCaptureLiveFrameImage(true, '/cache/previous.jpg', true)).assertTrue();
    });

    it('startsLiveLoopOnlyForActiveImageClassificationCameraWorkflow', 0, () => {
      expect(shouldRunLiveImageClassificationLoop('classifyImage', true, true)).assertTrue();
      expect(shouldRunLiveImageClassificationLoop('classifyImage', true, false)).assertFalse();
      expect(shouldRunLiveImageClassificationLoop('detectObjects', true, true)).assertFalse();
      expect(shouldRunLiveImageClassificationLoop('classifyImage', false, true)).assertFalse();
      expect(liveImageClassificationIntervalMs).assertEqual(1000);
      expect(liveRuntimeIntervalMs).assertEqual(1000);
      expect(liveRuntimeIntervalForAiMethod('classifyImage')).assertEqual(1000);
      expect(liveRuntimeIntervalForAiMethod('detectGesture')).assertEqual(500);
      expect(liveRuntimeIntervalForAiMethod('detectScene')).assertEqual(500);
      expect(liveRuntimeIntervalForAiMethod('detectObjects')).assertEqual(1000);
      expect(liveRuntimeIntervalForAiMethod('segmentPerson')).assertEqual(1000);
      expect(liveRuntimeIntervalForAiMethod('detectPose')).assertEqual(1000);
    });

    it('runsLiveLoopForImplementedLiveCameraAiMethodsOnly', 0, () => {
      expect(shouldRunLiveRuntimeLoop('classifyImage', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectObjects', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('segmentPerson', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectPose', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectGesture', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('detectScene', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('translateText', true, true, true)).assertTrue();
      expect(shouldRunLiveRuntimeLoop('runStyleTransfer', true, true, true)).assertFalse();
      expect(shouldRunLiveRuntimeLoop('translateText', false, true, true)).assertFalse();
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
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectGesture', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectScene', true, true)).assertTrue();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectGesture', false, true)).assertFalse();
      expect(shouldAutoRunLiveRuntimeAfterPreview('runStyleTransfer', false, true)).assertFalse();
      expect(shouldAutoRunLiveRuntimeAfterPreview('detectObjects', true, false)).assertFalse();
    });

    it('rejectsStaleLiveRuntimeFramesWithoutBlockingManualRuns', 0, () => {
      expect(isLiveRuntimeGenerationCurrent(undefined, 4)).assertTrue();
      expect(isLiveRuntimeGenerationCurrent(4, 4)).assertTrue();
      expect(isLiveRuntimeGenerationCurrent(3, 4)).assertFalse();
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

    it('liveGesturePublishesLicensedFourThenClearsOverlayAndScoreForGrayFrame', 0, async () => {
      const scheduler = new ManualLiveRuntimeLoopScheduler();
      const gestureRunner = new SequenceGestureRunner([
        {
          ok: true,
          gestures: [{
            category: 3,
            label: 'Four',
            score: 0.9031183391820973,
            rect: { left: 242.214, top: 182.637, width: 41.648, height: 59.506 }
          }],
          imageWidth: 384,
          imageHeight: 512,
          executionMs: 1
        },
        { ok: false, gestures: [], imageWidth: 384, imageHeight: 512, executionMs: 1 }
      ]);
      const service = new DefaultAiService({
        gestureService: new GestureService({ runner: gestureRunner })
      });
      const workflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;
      const loop = new LiveRuntimeLoopService(scheduler);
      const frameRunner = new LiveGestureAiFrameRunner(
        service,
        workflow,
        ['fixtures/gesture/four.jpg', 'fixtures/gesture/solid_gray.png'],
        12
      );

      loop.start(liveRuntimeIntervalForAiMethod('detectGesture'), frameRunner);
      await frameRunner.waitForFrameCount(1);
      const positive = frameRunner.current();
      expect(positive.generation).assertEqual(12);
      expect(positive.imageUri).assertEqual('fixtures/gesture/four.jpg');
      expect(positive.detections.length).assertEqual(1);
      expect(positive.detections[0].category).assertEqual(3);
      expect(positive.detections[0].score > 0).assertTrue();

      await Promise.resolve();
      scheduler.tick();
      await frameRunner.waitForFrameCount(2);
      const empty = frameRunner.current();
      expect(empty.generation).assertEqual(12);
      expect(empty.imageUri).assertEqual('');
      expect(empty.detections.length).assertEqual(0);
      expect(empty.imageWidth).assertEqual(0);
      expect(empty.imageHeight).assertEqual(0);
      expect(gestureRunner.seenImageUris.join(',')).assertEqual(
        'fixtures/gesture/four.jpg,fixtures/gesture/solid_gray.png'
      );
      loop.stop();
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

    it('liveRuntimeLoopRecoversOnTheNextBoundedTickAfterAFrameFailure', 0, async () => {
      const scheduler = new ManualLiveRuntimeLoopScheduler();
      const runner = new RejectingOnceLiveRuntimeFrameRunner();
      const service = new LiveRuntimeLoopService(scheduler);

      service.start(liveRuntimeIntervalMs, runner);
      await Promise.resolve();
      await Promise.resolve();
      scheduler.tick();
      await Promise.resolve();
      await Promise.resolve();

      expect(runner.runCount).assertEqual(2);
      expect(runner.successCount).assertEqual(1);
      service.stop();
    });

    it('mapsClockwiseRotatedDetectionIntoTheContainedLivePreview', 0, () => {
      const detection: ObjectDetection = {
        imageId: 1,
        labelId: 0,
        label: 'object',
        score: 0.9,
        left: 100,
        top: 20,
        right: 300,
        bottom: 120
      };

      const exactPortrait = objectDetectionLiveOverlayBox(detection, 400, 200, 200, 400, 90);
      expect(exactPortrait.left).assertEqual(80);
      expect(exactPortrait.top).assertEqual(100);
      expect(exactPortrait.width).assertEqual(100);
      expect(exactPortrait.height).assertEqual(200);

      const letterboxedPortrait = objectDetectionLiveOverlayBox(detection, 400, 200, 300, 500, 90);
      expect(letterboxedPortrait.left).assertEqual(125);
      expect(letterboxedPortrait.top).assertEqual(125);
      expect(letterboxedPortrait.width).assertEqual(125);
      expect(letterboxedPortrait.height).assertEqual(250);

      const unrotated = objectDetectionLiveOverlayBox(detection, 400, 200, 400, 200, 0);
      expect(unrotated.left).assertEqual(100);
      expect(unrotated.top).assertEqual(20);
      expect(unrotated.width).assertEqual(200);
      expect(unrotated.height).assertEqual(100);

      const upsideDown = objectDetectionLiveOverlayBox(detection, 400, 200, 400, 200, 180);
      expect(upsideDown.left).assertEqual(100);
      expect(upsideDown.top).assertEqual(80);
      expect(upsideDown.width).assertEqual(200);
      expect(upsideDown.height).assertEqual(100);

      const counterClockwise = objectDetectionLiveOverlayBox(detection, 400, 200, 200, 400, 270);
      expect(counterClockwise.left).assertEqual(20);
      expect(counterClockwise.top).assertEqual(100);
      expect(counterClockwise.width).assertEqual(100);
      expect(counterClockwise.height).assertEqual(200);
    });

    it('usesMindSporeModelFileSuffixForModelPicker', 0, () => {
      expect(modelFileSuffixFilters.length).assertEqual(1);
      expect(modelFileSuffixFilters[0]).assertEqual('.ms');
    });

    it('usesAndroidModelCacheFileNamesForPickedModelInputs', 0, () => {
      expect(cachedModelFileNameForInputKind(AppRoute.CUSTOM_MODEL.name, 'modelFile')).assertEqual('custom_model.ms');
      expect(cachedModelFileNameForInputKind(AppRoute.STYLE_TRANSFER.name, 'stylePredictModelFile')).assertEqual('custom_predict.mnn');
      expect(cachedModelFileNameForInputKind(AppRoute.STYLE_TRANSFER.name, 'styleTransferModelFile')).assertEqual('custom_transfer.mnn');
    });

    it('restoresCachedStyleTransferModelOverridesAcrossRuntimeRecreation', 0, async () => {
      const checker = new FixedCachedModelFileExistenceChecker([
        '/cache/custom_predict.mnn',
        '/cache/custom_transfer.mnn'
      ]);

      const state = await cachedModelFileInputStateForRoute(AppRoute.STYLE_TRANSFER.name, '/cache', checker);

      expect(state.modelInputUri).assertEqual('');
      expect(state.stylePredictModelInputUri).assertEqual('/cache/custom_predict.mnn');
      expect(state.styleTransferModelInputUri).assertEqual('/cache/custom_transfer.mnn');
    });

    it('cachesObjectDetectionPickedModelsInDedicatedCacheSlot', 0, () => {
      expect(shouldCachePickedModelFileForRoute(AppRoute.OBJECT_PHOTO.name, 'modelFile')).assertTrue();
      expect(shouldCachePickedModelFileForRoute(AppRoute.OBJECT_CAMERA.name, 'modelFile')).assertTrue();
      expect(cachedModelFileNameForInputKind(AppRoute.OBJECT_PHOTO.name, 'modelFile')).assertEqual('object_detection_model.mnn');
      expect(cachedModelFileNameForInputKind(AppRoute.OBJECT_CAMERA.name, 'modelFile')).assertEqual('object_detection_model.mnn');
      expect(cachedModelFileNameForInputKind(AppRoute.CUSTOM_MODEL.name, 'modelFile')).assertEqual('custom_model.ms');
    });

    it('cachesPickedModelFileContentBeforeRuntimeUse', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4])));
      const writer = new RecordingModelFileCacheWriter('/cache/custom_model.ms');
      const service = new RuntimeModelFileCacheService(
        reader,
        writer,
        new RecordingModelFileCompatibilityChecker(true)
      );

      const result = await service.cachePickedModelFile('file://selected/custom.ms', '/cache', AppRoute.CUSTOM_MODEL.name, 'modelFile');

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('/cache/custom_model.ms');
      expect(result.messageKey).assertEqual('feature_runtime_model_ready');
      expect(writer.seenCacheDirs[0]).assertEqual('/cache');
      expect(writer.seenFileNames[0]).assertEqual('custom_model.ms');
      expect(writer.writtenBytes[0]).assertEqual(4);
    });

    it('cachesPickedObjectDetectionModelFileContentBeforeRuntimeUse', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8])));
      const writer = new RecordingModelFileCacheWriter('/cache/object_detection_model.mnn');
      const service = new RuntimeModelFileCacheService(
        reader,
        writer,
        new RecordingModelFileCompatibilityChecker(true)
      );

      const result = await service.cachePickedModelFile('file://selected/ssd.ms', '/cache', AppRoute.OBJECT_PHOTO.name, 'modelFile');

      expect(result.ok).assertTrue();
      expect(result.uri).assertEqual('/cache/object_detection_model.mnn');
      expect(result.messageKey).assertEqual('feature_runtime_model_ready');
      expect(writer.seenCacheDirs[0]).assertEqual('/cache');
      expect(writer.seenFileNames[0]).assertEqual('object_detection_model.mnn');
      expect(writer.writtenBytes[0]).assertEqual(4);
    });

    it('reportsAndroidStyleModelSlotLoadStatusForStyleTransferModelPicks', 0, async () => {
      expect(hasAppStringKey('feature_runtime_style_predict_model_loaded')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_predict_model_load_failed')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_transfer_model_loaded')).assertTrue();
      expect(hasAppStringKey('feature_runtime_style_transfer_model_load_failed')).assertTrue();

      const predictReader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4])));
      const predictWriter = new RecordingModelFileCacheWriter('/cache/custom_predict.mnn');
      const predictService = new RuntimeModelFileCacheService(
        predictReader,
        predictWriter,
        new RecordingModelFileCompatibilityChecker(true),
        new RecordingStyleTransferModelPairCompatibilityChecker(true)
      );

      const predictResult = await predictService.cachePickedModelFile(
        'file://selected/predict.ms',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'stylePredictModelFile'
      );

      expect(predictResult.ok).assertTrue();
      expect(predictResult.messageKey).assertEqual('feature_runtime_style_predict_model_loaded');
      expect(predictWriter.seenFileNames[0]).assertEqual('custom_predict.mnn');

      const failedPredictService = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4]))),
        new RecordingModelFileCacheWriter('/cache/custom_predict.mnn'),
        new RecordingModelFileCompatibilityChecker(false)
      );

      const failedPredictResult = await failedPredictService.cachePickedModelFile(
        'file://selected/bad-predict.ms',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'stylePredictModelFile'
      );

      expect(failedPredictResult.ok).assertFalse();
      expect(failedPredictResult.messageKey).assertEqual('feature_runtime_style_predict_model_load_failed');

      const loadedTransferWriter = new RecordingModelFileCacheWriter('/cache/custom_transfer.mnn');
      const loadedTransferService = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8]))),
        loadedTransferWriter,
        new RecordingModelFileCompatibilityChecker(true),
        new RecordingStyleTransferModelPairCompatibilityChecker(true)
      );

      const loadedTransferResult = await loadedTransferService.cachePickedModelFile(
        'file://selected/transfer.ms',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'styleTransferModelFile'
      );

      expect(loadedTransferResult.ok).assertTrue();
      expect(loadedTransferResult.messageKey).assertEqual('feature_runtime_style_transfer_model_loaded');
      expect(loadedTransferWriter.seenFileNames[0]).assertEqual('custom_transfer.mnn');

      const transferReader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8])));
      const transferWriter = new RecordingModelFileCacheWriter('/cache/custom_transfer.mnn');
      const transferService = new RuntimeModelFileCacheService(
        transferReader,
        transferWriter,
        new RecordingModelFileCompatibilityChecker(false)
      );

      const transferResult = await transferService.cachePickedModelFile(
        'file://selected/transfer.ms',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'styleTransferModelFile'
      );

      expect(transferResult.ok).assertFalse();
      expect(transferResult.messageKey).assertEqual('feature_runtime_style_transfer_model_load_failed');
      expect(transferWriter.writtenBytes.length).assertEqual(0);
    });

    it('preflightsCachedPickedModelFileCompatibilityBeforeMarkingReady', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8])));
      const writer = new RecordingModelFileCacheWriter('/cache/object_detection_model.ms');
      const checker = new RecordingModelFileCompatibilityChecker(true);
      const service = new RuntimeModelFileCacheService(reader, writer, checker);

      const result = await service.cachePickedModelFile('file://selected/ssd.ms', '/cache', AppRoute.OBJECT_CAMERA.name, 'modelFile');

      expect(result.ok).assertTrue();
      expect(result.messageKey).assertEqual('feature_runtime_model_ready');
      expect(checker.seenRouteNames[0]).assertEqual(AppRoute.OBJECT_CAMERA.name);
      expect(checker.seenInputKinds[0]).assertEqual('modelFile');
      expect(checker.seenUris[0]).assertEqual('/cache/object_detection_model.mnn');
      expect(checker.seenByteLengths[0]).assertEqual(4);
    });

    it('rejectsIncompatiblePickedModelFilesBeforeRuntimeUse', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8])));
      const writer = new RecordingModelFileCacheWriter('/cache/custom_transfer.mnn');
      const checker = new RecordingModelFileCompatibilityChecker(false);
      const service = new RuntimeModelFileCacheService(reader, writer, checker);

      const result = await service.cachePickedModelFile(
        'file://selected/other.ms',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'styleTransferModelFile'
      );

      expect(result.ok).assertFalse();
      expect(result.uri).assertEqual('');
      expect(result.messageKey).assertEqual('feature_runtime_style_transfer_model_load_failed');
      expect(writer.writtenBytes.length).assertEqual(0);
    });

    it('treatsCompatibilityCheckerExceptionsAsModelIncompatibility', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([5, 6, 7, 8])));
      const writer = new RecordingModelFileCacheWriter('/cache/custom_model.ms');
      const checker = new ThrowingModelFileCompatibilityChecker();
      const service = new RuntimeModelFileCacheService(reader, writer, checker);

      const result = await service.cachePickedModelFile('file://selected/bad.ms', '/cache', AppRoute.CUSTOM_MODEL.name, 'modelFile');

      expect(result.ok).assertFalse();
      expect(result.uri).assertEqual('');
      expect(result.messageKey).assertEqual('feature_runtime_model_incompatible');
      expect(writer.writtenBytes.length).assertEqual(0);
    });

    it('defaultModelCompatibilityCheckerRoutesObjectModelsToTheNativeValidator', 0, async () => {
      const loader = new RecordingModelFileCompatibilityLoader(true);
      const validator = new RecordingObjectDetectionModelContentValidator(false);
      const checker = new BasicModelFileCompatibilityChecker(loader, validator);

      const compatible = await checker.isCompatible(
        AppRoute.OBJECT_PHOTO.name,
        'modelFile',
        '/cache/object_detection_model.mnn',
        new Uint8Array([1, 2, 3, 4])
      );

      expect(compatible).assertFalse();
      expect(validator.seenByteLengths[0]).assertEqual(4);
      expect(loader.seenByteLengths.length).assertEqual(0);
    });

    it('preflightsObjectDetectionTensorAndFirstOutputBeforeAtomicPublication', 0, async () => {
      const loader = new RecordingModelFileCompatibilityLoader(true);
      const validator = new RecordingObjectDetectionModelContentValidator(true);
      const checker = new BasicModelFileCompatibilityChecker(loader, validator);

      const compatible = await checker.isCompatible(
        AppRoute.OBJECT_PHOTO.name,
        'modelFile',
        '/cache/object_detection_model.mnn',
        new Uint8Array([9, 8, 7, 6])
      );

      expect(compatible).assertTrue();
      expect(validator.seenByteLengths.length).assertEqual(1);
      expect(validator.seenByteLengths[0]).assertEqual(4);
      expect(loader.seenByteLengths.length).assertEqual(0);
    });

    it('rejectsBadObjectDetectionOverrideWithoutReplacingTheLastValidCache', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([9, 8, 7, 6])));
      const writer = new RecordingModelFileCacheWriter('/cache/object_detection_model.mnn');
      const checker = new BasicModelFileCompatibilityChecker(
        new RecordingModelFileCompatibilityLoader(true),
        new RecordingObjectDetectionModelContentValidator(false)
      );
      const service = new RuntimeModelFileCacheService(reader, writer, checker);

      const result = await service.cachePickedModelFile(
        'file://selected/bad.ms',
        '/cache',
        AppRoute.OBJECT_PHOTO.name,
        'modelFile'
      );

      expect(result.ok).assertFalse();
      expect(result.messageKey).assertEqual('feature_runtime_model_incompatible');
      expect(writer.writtenBytes.length).assertEqual(0);
    });

    it('acceptsOnlyTheFixedCustomModelInputTensorContract', 0, () => {
      const compatibleInput: ModelFileTensorMetadata = {
        shape: [1, 224, 224, 3],
        dtype: mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
        format: mindSporeLite.Format.NHWC,
        elementNum: 150528,
        dataSize: 602112
      };
      expect(customModelInputContractCompatible([compatibleInput])).assertTrue();

      const incompatibleInputs: Array<Array<ModelFileTensorMetadata>> = [
        [],
        [compatibleInput, compatibleInput],
        [{
          shape: [1, 224, 224, 3],
          dtype: mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          format: mindSporeLite.Format.NCHW,
          elementNum: 150528,
          dataSize: 602112
        }],
        [{
          shape: [1, 3, 224, 224],
          dtype: mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          format: mindSporeLite.Format.NHWC,
          elementNum: 150528,
          dataSize: 602112
        }],
        [{
          shape: [1, 224, 224, 3],
          dtype: mindSporeLite.DataType.NUMBER_TYPE_INT8,
          format: mindSporeLite.Format.NHWC,
          elementNum: 150528,
          dataSize: 602112
        }],
        [{
          shape: [1, 224, 224, 3],
          dtype: mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          format: mindSporeLite.Format.NHWC,
          elementNum: 150527,
          dataSize: 602112
        }],
        [{
          shape: [1, 224, 224, 3],
          dtype: mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
          format: mindSporeLite.Format.NHWC,
          elementNum: 150528,
          dataSize: 602108
        }]
      ];

      for (let index = 0; index < incompatibleInputs.length; index++) {
        expect(customModelInputContractCompatible(incompatibleInputs[index])).assertFalse();
      }
    });

    it('preflightsCustomModelFirstOutputThroughTheCandidateRuntimeBeforePublication', 0, async () => {
      const loader = new RecordingModelFileCompatibilityLoader(true);
      const customValidator = new RecordingCustomModelContentValidator(true);
      const checker = new BasicModelFileCompatibilityChecker(
        loader,
        new RecordingObjectDetectionModelContentValidator(true),
        new RecordingStyleTransferModelContentValidator(true),
        customValidator
      );

      const compatible = await checker.isCompatible(
        AppRoute.CUSTOM_MODEL.name,
        'modelFile',
        '/cache/custom_model.ms',
        new Uint8Array([3, 2, 1])
      );

      expect(compatible).assertTrue();
      expect(customValidator.seenByteLengths.join(',')).assertEqual('3');
      expect(loader.seenByteLengths.length).assertEqual(0);
    });

    it('rejectsInvalidCustomOutputProbeWithoutReplacingTheLastGoodCache', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      const checker = new BasicModelFileCompatibilityChecker(
        new RecordingModelFileCompatibilityLoader(true),
        new RecordingObjectDetectionModelContentValidator(true),
        new RecordingStyleTransferModelContentValidator(true),
        new RecordingCustomModelContentValidator(false)
      );
      const service = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3]))),
        new HarmonyModelFileCacheWriter(backend),
        checker
      );

      const result = await service.cachePickedModelFile(
        'file://selected/invalid-output.ms',
        '/cache',
        AppRoute.CUSTOM_MODEL.name,
        'modelFile'
      );

      expect(result.ok).assertFalse();
      expect(result.messageKey).assertEqual('feature_runtime_model_incompatible');
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.replacedStablePaths.length).assertEqual(0);
    });

    it('preflightsEachStyleTransferSlotSchemaAndFirstOutputBeforePublication', 0, async () => {
      const loader = new RecordingModelFileCompatibilityLoader(true);
      const objectValidator = new RecordingObjectDetectionModelContentValidator(true);
      const styleValidator = new RecordingStyleTransferModelContentValidator(true);
      const checker = new BasicModelFileCompatibilityChecker(loader, objectValidator, styleValidator);

      expect(await checker.isCompatible(
        AppRoute.STYLE_TRANSFER.name,
        'stylePredictModelFile',
        '/cache/custom_predict.mnn',
        new Uint8Array([1, 2])
      )).assertTrue();
      expect(await checker.isCompatible(
        AppRoute.STYLE_TRANSFER.name,
        'styleTransferModelFile',
        '/cache/custom_transfer.mnn',
        new Uint8Array([3, 4, 5])
      )).assertTrue();
      expect(styleValidator.predictByteLengths.join(',')).assertEqual('2');
      expect(styleValidator.transferByteLengths.join(',')).assertEqual('3');
      expect(objectValidator.seenByteLengths.length).assertEqual(0);
      expect(loader.seenByteLengths.length).assertEqual(0);
    });

    it('pairPreflightUsesTheStableCustomOtherStageWhenAvailable', 0, async () => {
      const rawfiles = new FixedRawfileContentReader(new Uint8Array([8, 8, 8, 8]));
      const validator = new RecordingStyleTransferModelContentValidator(true);
      const checker = new NativeStyleTransferModelPairCompatibilityChecker(
        rawfiles,
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2]))),
        new FixedCachedModelFileExistenceChecker(['/cache/custom_predict.mnn']),
        validator
      );

      expect(await checker.isCompatible(
        'styleTransferModelFile',
        '/cache',
        new Uint8Array([3, 4, 5])
      )).assertTrue();
      expect(validator.pairByteLengths.join(',')).assertEqual('2:3');
      expect(rawfiles.seenPaths.length).assertEqual(0);
    });

    it('pairPreflightFallsBackToTheBuiltinOtherStage', 0, async () => {
      const rawfiles = new FixedRawfileContentReader(new Uint8Array([8, 8, 8, 8]));
      const validator = new RecordingStyleTransferModelContentValidator(true);
      const checker = new NativeStyleTransferModelPairCompatibilityChecker(
        rawfiles,
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2]))),
        new FixedCachedModelFileExistenceChecker([]),
        validator
      );

      expect(await checker.isCompatible(
        'stylePredictModelFile',
        '/cache',
        new Uint8Array([3])
      )).assertTrue();
      expect(validator.pairByteLengths.join(',')).assertEqual('1:4');
      expect(rawfiles.seenPaths.join(',')).assertEqual(styleTransferModelRawfilePath);
    });

    it('rejectsBadStyleTransferOverrideWithoutReplacingTheLastValidCache', 0, async () => {
      const writer = new RecordingModelFileCacheWriter('/cache/custom_predict.mnn');
      const checker = new BasicModelFileCompatibilityChecker(
        new RecordingModelFileCompatibilityLoader(true),
        new RecordingObjectDetectionModelContentValidator(true),
        new RecordingStyleTransferModelContentValidator(false)
      );
      const service = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([9, 8, 7]))),
        writer,
        checker
      );

      const result = await service.cachePickedModelFile(
        'file://selected/bad.mnn',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'stylePredictModelFile'
      );

      expect(result.ok).assertFalse();
      expect(writer.writtenBytes.length).assertEqual(0);
    });

    it('rejectsStageValidPairInvalidStyleOverrideWithoutPollutingStableCache', 0, async () => {
      const stablePath = '/cache/custom_predict.mnn';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9, 9]));
      const pairChecker = new RecordingStyleTransferModelPairCompatibilityChecker(false);
      const service = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3]))),
        new HarmonyModelFileCacheWriter(backend),
        new RecordingModelFileCompatibilityChecker(true),
        pairChecker
      );

      const result = await service.cachePickedModelFile(
        'file://selected/pair-invalid.mnn',
        '/cache',
        AppRoute.STYLE_TRANSFER.name,
        'stylePredictModelFile'
      );

      expect(result.ok).assertFalse();
      expect(pairChecker.candidateByteLengths.join(',')).assertEqual('3');
      expect(backend.openedPaths.length).assertEqual(0);
      expect(backend.replacedStablePaths.length).assertEqual(0);
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.bytes(stablePath)[1]).assertEqual(9);
    });

    it('reportsPickedModelFileCacheFailureWithI18nKey', 0, async () => {
      const reader = new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3, 4])));
      const writer = new RejectingModelFileCacheWriter();
      const checker = new RecordingModelFileCompatibilityChecker(true);
      const service = new RuntimeModelFileCacheService(reader, writer, checker);

      const result = await service.cachePickedModelFile('file://selected/custom.ms', '/cache', AppRoute.CUSTOM_MODEL.name, 'modelFile');

      expect(result.ok).assertFalse();
      expect(result.uri).assertEqual('');
      expect(result.messageKey).assertEqual('feature_runtime_model_cache_failed');
      expect(checker.seenRouteNames[0]).assertEqual(AppRoute.CUSTOM_MODEL.name);
    });

    it('atomicallyPublishesCurrentPickedModelOverStableCache', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));

      const result = await new HarmonyModelFileCacheWriter(backend).writeModelFile(
        '/cache',
        'custom_model.ms',
        new Uint8Array([1, 2, 3]),
        41,
        (): boolean => true
      );

      expect(result).assertEqual(stablePath);
      expect(backend.bytes(stablePath).length).assertEqual(3);
      expect(backend.bytes(stablePath)[0]).assertEqual(1);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
      expect(backend.openedPaths[0] === stablePath).assertFalse();
    });

    it('dropsStalePickedModelWithoutReplacingLastValidCache', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      const service = new RuntimeModelFileCacheService(
        new FileUriContentReader(new FixedFileUriContentBackend(new Uint8Array([1, 2, 3]))),
        new HarmonyModelFileCacheWriter(backend),
        new RecordingModelFileCompatibilityChecker(true)
      );

      const result = await service.cachePickedModelFile(
        'file://selected/custom.ms',
        '/cache',
        AppRoute.CUSTOM_MODEL.name,
        'modelFile',
        42,
        (): boolean => false
      );

      expect(result === undefined).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
      expect(backend.replacedStablePaths.length).assertEqual(0);
    });

    it('preservesLastValidCacheWhenTempWriteIsPartial', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      backend.failStage = 'partial';
      let failed = false;
      try {
        await new HarmonyModelFileCacheWriter(backend).writeModelFile(
          '/cache', 'custom_model.ms', new Uint8Array([1, 2]), 43, (): boolean => true
        );
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
    });

    it('preservesLastValidCacheWhenTempWriteThrows', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      backend.failStage = 'write';
      let failed = false;
      try {
        await new HarmonyModelFileCacheWriter(backend).writeModelFile(
          '/cache', 'custom_model.ms', new Uint8Array([1]), 44, (): boolean => true
        );
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
    });

    it('preservesLastValidCacheWhenTempCloseThrows', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      backend.failStage = 'close';
      let failed = false;
      try {
        await new HarmonyModelFileCacheWriter(backend).writeModelFile(
          '/cache', 'custom_model.ms', new Uint8Array([1]), 45, (): boolean => true
        );
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
    });

    it('preservesLastValidCacheWhenAtomicReplaceThrows', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      backend.failStage = 'replace';
      let failed = false;
      try {
        await new HarmonyModelFileCacheWriter(backend).writeModelFile(
          '/cache', 'custom_model.ms', new Uint8Array([1]), 46, (): boolean => true
        );
      } catch (_) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(9);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
    });

    it('preventsDelayedStaleAFromReplacingPublishedB', 0, async () => {
      const stablePath = '/cache/custom_model.ms';
      const backend = new MemoryModelFileCacheFileBackend();
      backend.seed(stablePath, new Uint8Array([9]));
      backend.delayedFirstByte = 1;
      const writer = new HarmonyModelFileCacheWriter(backend);
      let currentRequest = 1;
      const staleA = writer.writeModelFile(
        '/cache', 'custom_model.ms', new Uint8Array([1]), 1, (): boolean => currentRequest === 1
      );
      await Promise.resolve();
      await Promise.resolve();

      currentRequest = 2;
      const currentB = await writer.writeModelFile(
        '/cache', 'custom_model.ms', new Uint8Array([2]), 2, (): boolean => currentRequest === 2
      );
      backend.releaseDelayedWrite();
      const staleResult = await staleA;

      expect(currentB).assertEqual(stablePath);
      expect(staleResult === undefined).assertTrue();
      expect(backend.bytes(stablePath)[0]).assertEqual(2);
      expect(backend.has(backend.openedPaths[0])).assertFalse();
      expect(backend.has(backend.openedPaths[1])).assertFalse();
    });

    it('usesUniqueSameDirectoryTempTokensAndKeepsSiblingStableNames', 0, async () => {
      const backend = new MemoryModelFileCacheFileBackend();
      const writer = new HarmonyModelFileCacheWriter(backend);

      await writer.writeModelFile('/cache', 'custom_predict.mnn', new Uint8Array([1]), 7, (): boolean => true);
      await writer.writeModelFile('/cache', 'custom_predict.mnn', new Uint8Array([2]), 7, (): boolean => true);

      expect(backend.openedPaths.length).assertEqual(2);
      expect(backend.openedPaths[0] === backend.openedPaths[1]).assertFalse();
      expect(backend.openedPaths[0].startsWith('/cache/custom_predict.mnn.tmp-')).assertTrue();
      expect(backend.openedPaths[1].startsWith('/cache/custom_predict.mnn.tmp-')).assertTrue();
      expect(backend.replacedStablePaths[0]).assertEqual('/cache/custom_predict.mnn');
      expect(backend.replacedStablePaths[1]).assertEqual('/cache/custom_predict.mnn');
      expect(cachedModelFileNameForInputKind(AppRoute.OBJECT_PHOTO.name, 'modelFile'))
        .assertEqual('object_detection_model.mnn');
      expect(cachedModelFileNameForInputKind(AppRoute.STYLE_TRANSFER.name, 'styleTransferModelFile'))
        .assertEqual('custom_transfer.mnn');
    });

    it('rejectsShortModelFileCacheWrites', 0, () => {
      expect(modelFileCacheWriteSucceeded(4, new Uint8Array([1, 2, 3, 4]))).assertTrue();
      expect(modelFileCacheWriteSucceeded(3, new Uint8Array([1, 2, 3, 4]))).assertFalse();
    });
  });
}
