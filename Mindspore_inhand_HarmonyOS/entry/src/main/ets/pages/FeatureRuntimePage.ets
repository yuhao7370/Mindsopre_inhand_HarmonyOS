import router from '@ohos.router';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import { AppRoute, findRouteByName } from '../app/AppRoutes';
import {
  FeatureInputKind,
  FeaturePermissionKind,
  FeatureWorkflow,
  autoStartInputKindForWorkflow,
  fixedLiveCameraPositionForWorkflow,
  inputKindReplacesPrimaryInput,
  isInputPreparationRequestCurrent,
  initialInputKindForWorkflow,
  initialPreviewActionForWorkflow,
  liveRuntimeModeForWorkflow,
  rememberedLiveCameraPositionForWorkflow,
  rememberLiveCameraPositionForRoute,
  permissionLabelKey,
  runtimeInputKindsForWorkflow,
  specializedAndroidLiveLayoutForWorkflow,
  usesAndroidPortraitSegmentationLayout,
  usesAndroidTextRecognitionLayout,
  usesSimpleAndroidLiveLayout,
  visibleInputKindsForWorkflow,
  shouldShowPrimaryImageInputPreview,
  sampleImageUriForWorkflow,
  shouldAutoRunStyleTransferAfterStyleReady,
  shouldDeferRuntimeResultClearUntilPickResult,
  shouldLeaveRuntimeAfterCancelledInitialPick,
  cancelledPickStatusKeyForWorkflow,
  cancelledPickToastStatusKeyForWorkflow,
  shouldPreserveRuntimeResultAfterInputReady,
  shouldPreserveRuntimeVisualResultOnAiResult,
  runtimeSegmentationBackgroundImageUri,
  shouldStartWorkflowRun,
  shouldAllowRuntimeInputChange,
  shouldHideTextInputWhenPreparingInput,
  textInputVisibleAfterCancelledPick,
  shouldClearRuntimeResultAtWorkflowStart,
  shouldKeepScreenOnForWorkflow,
  shouldMirrorSegmentationForeground,
  shouldMirrorLiveGestureCameraOverlay,
  shouldShowCopyTextAction,
  shouldShowCompositeSegmentationSaveAction,
  shouldShowLiveClassificationCameraOverlay,
  liveClassificationEmptyPromptKey,
  shouldShowLiveGestureCameraOverlay,
  shouldShowLiveObjectDetectionCameraOverlay,
  shouldShowLivePoseCameraOverlay,
  shouldShowLivePoseTemplateOverlay,
  shouldShowPrimaryRunAction,
  shouldShowLiveSegmentationCameraOverlay,
  shouldRenderLiveCameraPreview,
  shouldShowResultSaveAction,
  shouldShowStandaloneSegmentationForegroundPreview,
  shouldShowStandaloneSegmentationOverlayPreview,
  shouldShowStyleRecoveryControl,
  shouldShowStyleTransferStyledPreview,
  shouldUseLongTextInput,
  shouldUseLongTextResultRow,
  styleTransferRecoveryStatusKey,
  styleTransferStyleReadyStatusKey,
  textInputPlaceholderKeyForWorkflow,
  workflowInitialStatusKey,
  workflowInputLabelKey,
  workflowGoLiveLabelKey,
  workflowResultTitleKey,
  workflowRunActionKey,
  workflowInputReadyAction,
  workflowRuntimeTitleKey,
  workflowForRoute
} from '../features/runtime/FeatureWorkflowCatalog';
import {
  FeatureRuntimePickedInputState,
  runtimePickedInputStateAfterModelCacheFailure,
  runtimePickedInputStateAfterCancelledPick
} from '../features/runtime/FeatureRuntimeInputState';
import {
  RuntimePixelMapOwner,
  clearRuntimePixelMapState
} from '../features/runtime/RuntimePixelMapOwner';
import { RuntimeRequestGeneration } from '../features/runtime/RuntimeRequestGeneration';
import {
  AiRunInputs,
  AiRunResult,
  AiRunResultRow,
  DefaultAiService,
  SceneDetectionOverlayRow,
  SegmentationBackgroundMetadata,
  aiRunResultRows,
  copyableTextForAiResult,
  segmentationMetadataWithBackground,
  sceneDetectionOverlayRows
} from '../services/ai/AiService';
import { cachedRuntimeAiServiceForHarmonyResourceManager } from '../services/ai/ImageClassificationRuntimeFactory';
import { RuntimeAiServiceSession } from '../services/ai/RuntimeAiServiceSession';
import {
  PermissionRequestSummary,
  PermissionService,
  RuntimePermissionRecoveryAction,
  RuntimePermissionRunAction,
  runtimeOpenAppSettingsAction,
  runtimePermissionRecoveryActionForWorkflow,
  runtimePermissionRunActionForWorkflow
} from '../services/permissions/PermissionService';
import { ClipboardService, CopyTextResult } from '../services/clipboard/ClipboardService';
import { PickerService, PickResult, runtimeInputActionForWorkflowInput } from '../services/picker/PickerService';
import {
  CachedModelFileInputState,
  ModelFileCacheResult,
  RuntimeModelFileCacheService,
  cachedModelFileInputStateForRoute,
  shouldCachePickedModelFileForRoute
} from '../services/picker/ModelFileCacheService';
import {
  HarmonyLiveCameraPreviewDriver,
  HarmonyLiveCameraDevicePositionProvider,
  HarmonyLiveFrameImageEncoder,
  HarmonyLiveFrameImageStore,
  LiveCameraPosition,
  LiveCameraPreviewResult,
  LiveCameraPreviewService,
  LiveCameraSwitchCapabilityService,
  LiveFrameImageResult,
  LiveFrameImageService,
  LiveRuntimeFrameRunner,
  LiveRuntimeLoopService,
  isLiveRuntimeGenerationCurrent,
  liveRuntimeIntervalForAiMethod,
  liveCameraXComponentId,
  shouldRunLiveRuntimeLoop,
  shouldAutoRunLiveRuntimeAfterPreview,
  nextLiveCameraPosition,
  shouldCaptureLiveFrameImage
} from '../services/camera/LiveCameraService';
import {
  HarmonyResultImageAssetWriter,
  HarmonyResultImagePixelMapEncoder,
  ResultImageSaveResult,
  ResultImageSaveService,
  withCallerOwnedPixelMap
} from '../services/media/ResultImageSaveService';
import {
  ObjectDetection,
  ObjectDetectionBoxPercent,
  ObjectDetectionLiveLabelOffset,
  objectDetectionBoxPercent,
  objectDetectionLiveLabelOffset,
  objectDetectionOverlayColor,
  objectDetectionOverlayLabel,
  objectDetectionOverlayTextColor
} from '../services/ai/ObjectDetectionService';
import {
  SegmentationRectangle,
  SegmentationResult,
  SegmentationRectanglePercent,
  segmentationRectanglePercent
} from '../services/ai/SegmentationService';
import {
  PoseLine,
  PoseLinePercent,
  PosePoint,
  PosePointPercent,
  isPosePointVisible,
  poseLinePercent,
  posePointPercent,
  poseSkeletonLines
} from '../services/ai/PoseService';
import {
  GestureDetection,
  GestureRectanglePercent,
  gestureDetectionLabel,
  gestureDetectionLabelKey,
  gestureRectanglePercent
} from '../services/ai/GestureService';
import {
  BuiltInStyleTransferStyle,
  builtInStyleTransferMediaName,
  builtInStyleTransferStyles,
  builtInStyleTransferUri,
  isCustomStyleTransferUri,
  styleTransferPixelMapFromRgbaOutput
} from '../services/ai/StyleTransferService';
import {
  initialPortraitSegmentationBackgroundState,
  PortraitSegmentationBackgroundPreset,
  PortraitSegmentationBackgroundState,
  portraitSegmentationBackgroundPresets,
  portraitSegmentationBackgroundUri,
  portraitSegmentationCustomBackgroundId
} from '../features/runtime/PortraitSegmentationBackgroundCatalog';
import { featureRuntimeOverlayPreviewImageOrientationForUri } from '../features/runtime/FeatureRuntimeOverlayPreview';
import {
  segmentationBackgroundReplacementComponentId
} from '../features/runtime/FeatureRuntimeViewIds';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonyKeepScreenOnWindowProvider,
  KeepScreenOnService
} from '../services/window/KeepScreenOnService';
import { common, OpenLinkOptions } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import {
  ExternalHelpLinkContext,
  ExternalHelpLinkOpenOptions,
  ExternalHelpNavigator,
  RuntimeHelpRouteOptions,
  openRuntimeHelpSource
} from '../services/web/RuntimeHelpLinkService';

interface FeatureRuntimeParams {
  titleKey?: AppStringKey;
  routeName?: string;
}

class PageLiveRuntimeFrameRunner implements LiveRuntimeFrameRunner {
  private readonly runFrame: () => Promise<void>;

  constructor(runFrame: () => Promise<void>) {
    this.runFrame = runFrame;
  }

  async runOnce(): Promise<void> {
    await this.runFrame();
  }
}

class PageExternalHelpNavigator implements ExternalHelpNavigator {
  private readonly pushRoute: (options: RuntimeHelpRouteOptions) => void;

  constructor(pushRoute: (options: RuntimeHelpRouteOptions) => void) {
    this.pushRoute = pushRoute;
  }

  pushUrl(options: RuntimeHelpRouteOptions): void {
    this.pushRoute(options);
  }
}

class PageExternalHelpLinkContext implements ExternalHelpLinkContext {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async openLink(link: string, options?: ExternalHelpLinkOpenOptions): Promise<void> {
    const openOptions: OpenLinkOptions = {
      hideFailureTipDialog: options?.hideFailureTipDialog === true
    };
    await this.context.openLink(link, openOptions);
  }
}

@Entry
@Component
struct FeatureRuntimePage {
  @State titleKey: AppStringKey = 'EntryAbility_label';
  @State summaryKey: AppStringKey = 'feature_runtime_status_idle';
  @State statusKey: AppStringKey = 'feature_runtime_status_idle';
  @State runActionKey: AppStringKey = 'feature_runtime_run';
  @State workflowRunning: boolean = false;
  @State longTextInput: boolean = false;
  @State routeName: string = '';
  @State aiMethod: string = '';
  @State resultText: string = '';
  @State resultRows: Array<AiRunResultRow> = [];
  @State selectedInputSummary: string = '';
  @State imageInputUri: string = '';
  @State contentImageUri: string = '';
  @State styleImageUri: string = '';
  @State backgroundImageUri: string = '';
  @State selectedPortraitBackgroundPresetId: string = '';
  @State stylePredictModelInputUri: string = '';
  @State styleTransferModelInputUri: string = '';
  @State modelInputUri: string = '';
  @State userText: string = '';
  @State textInputVisible: boolean = true;
  @State styledImagePixelMap: image.PixelMap | undefined = undefined;
  @State styleOriginalPreviewRecovered: boolean = false;
  @State objectDetectionImageUri: string = '';
  @State objectDetectionImageOrientation: ImageRotateOrientation = ImageRotateOrientation.UP;
  @State objectDetections: Array<ObjectDetection> = [];
  @State objectDetectionImageWidth: number = 0;
  @State objectDetectionImageHeight: number = 0;
  @State liveObjectDetectionOverlayHeightVp: number = 0;
  @State segmentationImageUri: string = '';
  @State segmentationImageOrientation: ImageRotateOrientation = ImageRotateOrientation.UP;
  @State segmentationBackgroundImageUri: string = '';
  @State segmentationBackgroundImageOrientation: ImageRotateOrientation = ImageRotateOrientation.UP;
  @State segmentationForegroundPixelMap: image.PixelMap | undefined = undefined;
  @State segmentationRectangles: Array<SegmentationRectangle> = [];
  @State segmentationImageWidth: number = 0;
  @State segmentationImageHeight: number = 0;
  @State poseImageUri: string = '';
  @State poseImageOrientation: ImageRotateOrientation = ImageRotateOrientation.UP;
  @State posePoints: Array<PosePoint> = [];
  @State poseImageWidth: number = 0;
  @State poseImageHeight: number = 0;
  @State gestureImageUri: string = '';
  @State gestureImageOrientation: ImageRotateOrientation = ImageRotateOrientation.UP;
  @State gestureDetections: Array<GestureDetection> = [];
  @State gestureImageWidth: number = 0;
  @State gestureImageHeight: number = 0;
  @State sceneOverlayRows: Array<SceneDetectionOverlayRow> = [];
  @State helpUrl: string = '';
  @State helpContentKey: AppStringKey | undefined = undefined;
  @State inputKinds: Array<FeatureInputKind> = [];
  @State permissionKinds: Array<FeaturePermissionKind> = [];
  @State liveCameraSurfaceId: string = '';
  @State liveCameraActive: boolean = false;
  @State liveCameraPosition: LiveCameraPosition = 'back';
  @State liveCameraSwitchAvailable: boolean = true;
  private liveCameraController: XComponentController = new XComponentController();
  private liveCameraService: LiveCameraPreviewService | undefined = undefined;
  private liveCameraStopTask: Promise<void> | undefined = undefined;
  private liveCameraInputSelected: boolean = false;
  private liveCameraPreviewRequestId: number = 0;
  private liveRuntimeGeneration: number = 0;
  private runtimeRequestGeneration: RuntimeRequestGeneration = new RuntimeRequestGeneration();
  private inputPreparationRequestId: number = 0;
  private liveRuntimeLoopService: LiveRuntimeLoopService = new LiveRuntimeLoopService();
  private runtimeAiServiceSession: RuntimeAiServiceSession = new RuntimeAiServiceSession();
  private styledImagePixelMapOwner: RuntimePixelMapOwner<image.PixelMap> = new RuntimePixelMapOwner();
  private segmentationForegroundPixelMapOwner: RuntimePixelMapOwner<image.PixelMap> = new RuntimePixelMapOwner();
  private initialInputPrepared: boolean = false;
  private pendingPickTextInputVisible: boolean | undefined = undefined;

  aboutToAppear() {
    const params = router.getParams() as FeatureRuntimeParams;
    this.routeName = params?.routeName ?? '';
    const workflow = workflowForRoute(this.routeName);
    this.titleKey = workflowRuntimeTitleKey(workflow, params?.titleKey ?? this.titleKey);
    this.summaryKey = workflow?.summaryKey ?? this.summaryKey;
    this.aiMethod = workflow?.aiMethod ?? '';
    this.statusKey = workflowInitialStatusKey(workflow);
    this.runActionKey = workflowRunActionKey(workflow);
    this.longTextInput = shouldUseLongTextInput(workflow);
    this.helpUrl = workflow?.helpUrl ?? '';
    this.helpContentKey = workflow?.helpContentKey;
    this.inputKinds = workflow ? runtimeInputKindsForWorkflow(workflow) : [];
    this.permissionKinds = workflow?.requiredPermissions ?? [];
    this.liveCameraPosition = rememberedLiveCameraPositionForWorkflow(workflow);
    this.setRuntimeKeepScreenOn(true);
    this.refreshLiveCameraSwitchAvailability();
    this.applyDefaultPortraitBackgroundIfNeeded();
    this.restoreCachedModelFileInputsIfNeeded();
    setTimeout(() => this.prepareInitialInputIfNeeded(), 0);
  }

  aboutToDisappear() {
    this.inputPreparationRequestId++;
    this.runtimeRequestGeneration.invalidate();
    this.runtimeAiServiceSession.invalidate();
    this.styledImagePixelMap = clearRuntimePixelMapState(this.styledImagePixelMapOwner);
    this.segmentationForegroundPixelMap = clearRuntimePixelMapState(this.segmentationForegroundPixelMapOwner);
    this.setRuntimeKeepScreenOn(false);
    this.stopLiveCameraPreview();
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private setRuntimeKeepScreenOn(isKeepScreenOn: boolean): void {
    if (!shouldKeepScreenOnForWorkflow(workflowForRoute(this.routeName))) {
      return;
    }
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    new KeepScreenOnService(
      new HarmonyKeepScreenOnWindowProvider(context)
    ).setKeepScreenOn(isKeepScreenOn);
  }

  private prepareInput(inputKind: FeatureInputKind, initialPick: boolean = false): void {
    const requestId = ++this.inputPreparationRequestId;
    this.prepareInputAsync(inputKind, initialPick, requestId);
  }

  private async prepareInputAsync(
    inputKind: FeatureInputKind,
    initialPick: boolean,
    requestId: number
  ): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {
      this.statusKey = 'feature_runtime_status_running';
      return;
    }
    this.statusKey = 'feature_runtime_status_preparing';
    this.pendingPickTextInputVisible = undefined;
    if (!workflow || !shouldDeferRuntimeResultClearUntilPickResult(workflow, inputKind)) {
      this.clearRuntimeResultState();
    }
    const liveCameraInput = this.isLiveCameraInput(inputKind);
    if (liveCameraInput) {
      this.liveCameraInputSelected = true;
    } else if (inputKindReplacesPrimaryInput(inputKind)) {
      if (this.liveCameraInputSelected || this.liveCameraActive || this.liveCameraService !== undefined ||
        this.liveCameraStopTask !== undefined) {
        await this.stopLiveCameraPreviewAsync();
        if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {
          return;
        }
      } else {
        this.stopLiveRuntimeLoop();
      }
    }
    if (inputKind === 'text') {
      this.textInputVisible = true;
      this.statusKey = this.userText.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
      this.selectedInputSummary = this.userText;
      return;
    }
    if (liveCameraInput) {
      if (workflow && shouldHideTextInputWhenPreparingInput(workflow, inputKind)) {
        this.pendingPickTextInputVisible = this.textInputVisible;
        this.textInputVisible = false;
      }
      if (this.liveCameraSurfaceId.length > 0) {
        this.startLiveCameraPreview();
      }
      return;
    }
    if (inputKind === 'sampleImage') {
      const uri = workflow ? sampleImageUriForWorkflow(workflow) : '';
      this.applyPickResult({
        ok: uri.length > 0,
        uri: uri
      }, 'feature_runtime_image_ready', inputKind);
      return;
    }
    if (workflow && shouldHideTextInputWhenPreparingInput(workflow, inputKind)) {
      this.pendingPickTextInputVisible = this.textInputVisible;
      this.textInputVisible = false;
    }
    const context = this.uiAbilityContext();
    if (!context) {
      this.statusKey = 'feature_runtime_pick_cancelled';
      this.textInputVisible = textInputVisibleAfterCancelledPick(
        workflow,
        inputKind,
        this.textInputVisible,
        this.pendingPickTextInputVisible
      );
      this.pendingPickTextInputVisible = undefined;
      return;
    }
    const pickerService = new PickerService(context);
    if (inputKind === 'modelFile' ||
      inputKind === 'stylePredictModelFile' ||
      inputKind === 'styleTransferModelFile') {
      const result = await pickerService.pickModelFile();
      if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {
        return;
      }
      await this.cacheAndApplyPickedModelFile(
        result,
        context.cacheDir,
        inputKind,
        initialPick,
        requestId
      );
      return;
    }
    if (inputKind === 'camera') {
      const result = await pickerService.captureImage();
      if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {
        return;
      }
      this.applyPickResult(result, 'feature_runtime_image_ready', inputKind, true, initialPick);
      return;
    }
    const result = await pickerService.pickImage();
    if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {
      return;
    }
    this.applyPickResult(result, 'feature_runtime_image_ready', inputKind, true, initialPick);
  }

  private async cacheAndApplyPickedModelFile(
    result: PickResult,
    cacheDir: string,
    inputKind: FeatureInputKind,
    initialPick: boolean,
    requestId: number
  ): Promise<void> {
    if (!result.ok) {
      this.applyPickResult(result, 'feature_runtime_model_ready', inputKind, true, initialPick);
      return;
    }
    if (!shouldCachePickedModelFileForRoute(this.routeName, inputKind)) {
      this.applyPickResult(result, 'feature_runtime_model_ready', inputKind, true, initialPick);
      return;
    }
    const cacheResult = await new RuntimeModelFileCacheService()
      .cachePickedModelFile(result.uri, cacheDir, this.routeName, inputKind);
    if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {
      return;
    }
    this.applyModelFileCacheResult(cacheResult, inputKind);
  }

  private applyModelFileCacheResult(result: ModelFileCacheResult, inputKind: FeatureInputKind): void {
    if (!result.ok) {
      this.clearRuntimeResultState();
      this.statusKey = result.messageKey;
      this.applyPickedInputState(runtimePickedInputStateAfterModelCacheFailure(inputKind, this.pickedInputState()));
      return;
    }
    this.runtimeAiServiceSession.invalidate();
    this.applyPickResult({
      ok: true,
      uri: result.uri
    }, result.messageKey, inputKind);
  }

  private isLiveCameraInput(inputKind: FeatureInputKind): boolean {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      return false;
    }
    return runtimeInputActionForWorkflowInput(workflow, inputKind) === 'startLiveCamera';
  }

  private hasLiveCameraInput(): boolean {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      return false;
    }
    return runtimeInputKindsForWorkflow(workflow).some((inputKind: FeatureInputKind) =>
      runtimeInputActionForWorkflowInput(workflow, inputKind) === 'startLiveCamera');
  }

  private refreshLiveCameraSwitchAvailability(): void {
    if (!this.hasLiveCameraInput()) {
      this.liveCameraSwitchAvailable = false;
      return;
    }
    const fixedPosition = fixedLiveCameraPositionForWorkflow(workflowForRoute(this.routeName));
    if (fixedPosition !== undefined) {
      this.liveCameraPosition = fixedPosition;
      this.liveCameraSwitchAvailable = false;
      return;
    }
    const context = this.uiAbilityContext();
    if (!context) {
      this.liveCameraSwitchAvailable = true;
      return;
    }
    const capability = new LiveCameraSwitchCapabilityService(
      new HarmonyLiveCameraDevicePositionProvider(context)
    ).capability(this.liveCameraPosition);
    this.liveCameraSwitchAvailable = capability.canSwitch;
    this.liveCameraPosition = capability.preferredPosition;
    rememberLiveCameraPositionForRoute(this.routeName, this.liveCameraPosition);
  }

  private autoStartLiveCameraIfNeeded(): void {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow || this.liveCameraInputSelected || this.liveCameraActive) {
      return;
    }
    const inputKind = autoStartInputKindForWorkflow(workflow);
    if (inputKind !== undefined) {
      this.prepareInput(inputKind);
    }
  }

  private prepareInitialInputIfNeeded(): void {
    if (this.initialInputPrepared) {
      return;
    }
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      return;
    }
    const initialPreviewAction = initialPreviewActionForWorkflow(workflow);
    if (initialPreviewAction !== undefined) {
      this.initialInputPrepared = true;
      this.applyPickResult({
        ok: true,
        uri: initialPreviewAction.uri
      }, initialPreviewAction.readyKey, initialPreviewAction.inputKind, initialPreviewAction.shouldRunWorkflow);
      return;
    }
    const inputKind = initialInputKindForWorkflow(workflow);
    if (inputKind !== undefined) {
      this.initialInputPrepared = true;
      this.prepareInput(inputKind, true);
    }
  }

  private startLiveCameraPreview(): void {
    this.startLiveCameraPreviewAsync();
  }

  private async startLiveCameraPreviewAsync(): Promise<void> {
    const requestId = ++this.liveCameraPreviewRequestId;
    const workflow = workflowForRoute(this.routeName);
    const context = this.uiAbilityContext();
    if (!workflow || !context) {
      if (requestId === this.liveCameraPreviewRequestId) {
        this.applyLiveCameraPreviewResult({
          ok: false,
          surfaceId: '',
          messageKey: 'feature_runtime_permission_denied'
        });
      }
      return;
    }

    this.statusKey = 'feature_runtime_status_preparing';
    this.resultRows = [];
    this.resultText = '';
    this.clearVisualResults();
    try {
      const permission = await new PermissionService().requestForWorkflow(context, workflow);
      if (requestId !== this.liveCameraPreviewRequestId) {
        return;
      }
      if (!permission.ok) {
        this.applyLiveCameraPreviewResult({
          ok: false,
          surfaceId: '',
          messageKey: 'feature_runtime_permission_denied'
        });
        this.resultText = permission.requested.join(', ');
        return;
      }

      const pendingStopTask = this.liveCameraStopTask;
      if (pendingStopTask !== undefined) {
        await pendingStopTask;
        if (requestId !== this.liveCameraPreviewRequestId) {
          return;
        }
      }

      const surfaceId = this.liveCameraSurfaceId.length > 0 ?
        this.liveCameraSurfaceId :
        this.liveCameraController.getXComponentSurfaceId();
      const previousService = this.liveCameraService;
      if (previousService !== undefined) {
        await previousService.stop();
        if (requestId !== this.liveCameraPreviewRequestId) {
          return;
        }
      }
      const service = new LiveCameraPreviewService(new HarmonyLiveCameraPreviewDriver(context));
      this.liveCameraService = service;
      const result = await service.start(surfaceId, this.liveCameraPosition);
      if (requestId !== this.liveCameraPreviewRequestId || this.liveCameraService !== service) {
        await service.stop();
        return;
      }
      this.applyLiveCameraPreviewResult(result);
    } catch (_) {
      if (requestId === this.liveCameraPreviewRequestId) {
        this.applyLiveCameraPreviewResult({
          ok: false,
          surfaceId: '',
          messageKey: 'feature_runtime_live_camera_failed'
        });
      }
    }
  }

  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {
    this.statusKey = result.messageKey;
    this.liveCameraActive = result.ok;
    this.liveCameraSurfaceId = result.surfaceId;
    this.selectedInputSummary = result.surfaceId;
    const workflow = workflowForRoute(this.routeName);
    if (!result.ok) {
      this.pendingPickTextInputVisible = undefined;
      this.liveCameraInputSelected = false;
      this.stopLiveRuntimeLoop();
      return;
    }
    this.pendingPickTextInputVisible = undefined;
    if (workflow && shouldAutoRunLiveRuntimeAfterPreview(
      this.aiMethod,
      liveRuntimeModeForWorkflow(workflow),
      result.ok
    )) {
      this.startLiveRuntimeLoop(workflow);
    }
  }

  private stopLiveCameraPreview(): void {
    this.stopLiveCameraPreviewAsync();
  }

  private async stopLiveCameraPreviewAsync(): Promise<void> {
    this.liveCameraPreviewRequestId++;
    this.stopLiveRuntimeLoop();
    this.liveCameraInputSelected = false;
    this.liveCameraActive = false;
    this.liveCameraSurfaceId = '';
    const service = this.liveCameraService;
    this.liveCameraService = undefined;
    if (service !== undefined) {
      const stopTask = service.stop();
      this.liveCameraStopTask = stopTask;
      await stopTask;
      if (this.liveCameraStopTask === stopTask) {
        this.liveCameraStopTask = undefined;
      }
      return;
    }
    const stopTask = this.liveCameraStopTask;
    if (stopTask !== undefined) {
      await stopTask;
    }
  }

  private switchLiveCamera(): void {
    if (fixedLiveCameraPositionForWorkflow(workflowForRoute(this.routeName)) !== undefined) {
      return;
    }
    this.liveCameraPosition = nextLiveCameraPosition(this.liveCameraPosition);
    rememberLiveCameraPositionForRoute(this.routeName, this.liveCameraPosition);
    if (this.liveCameraInputSelected || this.liveCameraActive) {
      this.stopLiveRuntimeLoop();
      this.liveCameraActive = false;
      this.startLiveCameraPreview();
    }
  }

  private applyPickResult(
    result: PickResult,
    readyKey: AppStringKey,
    inputKind: FeatureInputKind,
    shouldRunReadyWorkflow: boolean = true,
    initialPick: boolean = false
  ): void {
    const workflow = workflowForRoute(this.routeName);
    if (result.ok && !shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {
      this.pendingPickTextInputVisible = undefined;
      this.statusKey = 'feature_runtime_status_running';
      return;
    }
    if (!result.ok) {
      const previousTextInputVisible = this.pendingPickTextInputVisible;
      this.pendingPickTextInputVisible = undefined;
      this.statusKey = cancelledPickStatusKeyForWorkflow(workflow, inputKind, initialPick);
      this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(
        this.routeName,
        inputKind,
        this.pickedInputState()
      ));
      this.textInputVisible = textInputVisibleAfterCancelledPick(
        workflow,
        inputKind,
        this.textInputVisible,
        previousTextInputVisible
      );
      if (workflow && shouldLeaveRuntimeAfterCancelledInitialPick(workflow, inputKind, initialPick)) {
        this.showRuntimeToast(cancelledPickToastStatusKeyForWorkflow(workflow, inputKind, initialPick));
        router.back();
      }
      return;
    }
    this.pendingPickTextInputVisible = undefined;
    if (!shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {
      this.clearRuntimeResultState();
    }
    this.statusKey = workflow ?
      styleTransferStyleReadyStatusKey(workflow, inputKind, this.styleTransferContentInputReady(), readyKey) :
      readyKey;
    this.selectedInputSummary = result.uri;
    if (inputKind === 'modelFile') {
      this.modelInputUri = result.uri;
    } else if (inputKind === 'stylePredictModelFile') {
      this.stylePredictModelInputUri = result.uri;
    } else if (inputKind === 'styleTransferModelFile') {
      this.styleTransferModelInputUri = result.uri;
    } else if (inputKind === 'contentImage') {
      this.contentImageUri = result.uri;
    } else if (inputKind === 'styleImage') {
      this.styleImageUri = result.uri;
    } else if (inputKind === 'backgroundImage') {
      this.applyPortraitBackgroundUri(result.uri, portraitSegmentationCustomBackgroundId);
    } else {
      this.imageInputUri = result.uri;
    }
    if (workflow && shouldRunReadyWorkflow) {
      const inputReadyAction = workflowInputReadyAction(workflow, inputKind, this.userText);
      this.userText = inputReadyAction.userText;
      this.textInputVisible = inputReadyAction.textInputVisible;
      if (inputReadyAction.shouldRunWorkflow || this.shouldRunStyleTransferAfterStyleReady(workflow, inputKind)) {
        this.runWorkflow();
      }
    }
  }

  private aiRunInputs(): AiRunInputs {
    const contentImageUri = this.contentImageUri.length > 0 ? this.contentImageUri : this.imageInputUri;
    return {
      imageUri: this.imageInputUri,
      contentImageUri: contentImageUri,
      styleImageUri: this.styleImageUri,
      backgroundImageUri: this.backgroundImageUri,
      stylePredictModelUri: this.stylePredictModelInputUri,
      styleTransferModelUri: this.styleTransferModelInputUri,
      modelUri: this.modelInputUri,
      text: this.userText
    };
  }

  private pickedInputState(): FeatureRuntimePickedInputState {
    return {
      selectedInputSummary: this.selectedInputSummary,
      imageInputUri: this.imageInputUri,
      contentImageUri: this.contentImageUri,
      styleImageUri: this.styleImageUri,
      backgroundImageUri: this.backgroundImageUri,
      selectedPortraitBackgroundPresetId: this.selectedPortraitBackgroundPresetId,
      modelInputUri: this.modelInputUri,
      stylePredictModelInputUri: this.stylePredictModelInputUri,
      styleTransferModelInputUri: this.styleTransferModelInputUri
    };
  }

  private applyPickedInputState(state: FeatureRuntimePickedInputState): void {
    this.selectedInputSummary = state.selectedInputSummary;
    this.imageInputUri = state.imageInputUri;
    this.contentImageUri = state.contentImageUri;
    this.styleImageUri = state.styleImageUri;
    this.backgroundImageUri = state.backgroundImageUri;
    this.selectedPortraitBackgroundPresetId = state.selectedPortraitBackgroundPresetId;
    this.modelInputUri = state.modelInputUri;
    this.stylePredictModelInputUri = state.stylePredictModelInputUri;
    this.styleTransferModelInputUri = state.styleTransferModelInputUri;
  }

  private restoreCachedModelFileInputsIfNeeded(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    const routeName = this.routeName;
    cachedModelFileInputStateForRoute(routeName, context.cacheDir)
      .then((state: CachedModelFileInputState) => {
        if (this.routeName !== routeName) {
          return;
        }
        this.applyCachedModelFileInputState(state);
      });
  }

  private applyCachedModelFileInputState(state: CachedModelFileInputState): void {
    if (this.modelInputUri.length === 0) {
      this.modelInputUri = state.modelInputUri;
    }
    if (this.stylePredictModelInputUri.length === 0) {
      this.stylePredictModelInputUri = state.stylePredictModelInputUri;
    }
    if (this.styleTransferModelInputUri.length === 0) {
      this.styleTransferModelInputUri = state.styleTransferModelInputUri;
    }
  }

  private runWorkflow(): void {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      this.statusKey = 'feature_runtime_unknown_route';
      return;
    }
    const liveRuntimeLoopReady = shouldRunLiveRuntimeLoop(
      workflow.aiMethod,
      liveRuntimeModeForWorkflow(workflow),
      this.liveCameraInputSelected, this.liveCameraActive);
    if (liveRuntimeLoopReady) {
      this.startLiveRuntimeLoop(workflow);
      return;
    }
    if (!shouldStartWorkflowRun(workflow, this.workflowRunning, liveRuntimeLoopReady)) {
      return;
    }
    this.stopLiveRuntimeLoop();
    this.workflowRunning = true;
    const runtimeRequestId = this.beginRuntimeRequest();
    this.runWorkflowAsync(runtimeRequestId)
      .then(() => {
        this.workflowRunning = false;
      })
      .catch(() => {
        this.workflowRunning = false;
      });
  }

  private startLiveRuntimeLoop(workflow: FeatureWorkflow): void {
    if (this.liveRuntimeLoopService.isRunning()) {
      return;
    }
    const liveGeneration = ++this.liveRuntimeGeneration;
    const runner = new PageLiveRuntimeFrameRunner(async (): Promise<void> => {
      await this.runWorkflowAsync(this.beginRuntimeRequest(), liveGeneration);
    });
    this.liveRuntimeLoopService.start(liveRuntimeIntervalForAiMethod(workflow.aiMethod), runner);
  }

  private stopLiveRuntimeLoop(): void {
    this.liveRuntimeGeneration++;
    this.runtimeRequestGeneration.invalidate();
    this.styledImagePixelMapOwner.invalidatePendingReplacement();
    this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();
    this.liveRuntimeLoopService.stop();
  }

  private beginRuntimeRequest(): number {
    this.styledImagePixelMapOwner.invalidatePendingReplacement();
    this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();
    return this.runtimeRequestGeneration.begin();
  }

  private isRuntimeRequestCurrent(runtimeRequestId: number, liveGeneration?: number): boolean {
    return this.runtimeRequestGeneration.isCurrent(runtimeRequestId) &&
      isLiveRuntimeGenerationCurrent(liveGeneration, this.liveRuntimeGeneration);
  }

  private async runWorkflowAsync(runtimeRequestId: number, liveGeneration?: number): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      this.statusKey = 'feature_runtime_unknown_route';
      return;
    }
    const context = this.uiAbilityContext();
    if (!context) {
      this.statusKey = 'feature_runtime_permission_denied';
      return;
    }
    this.statusKey = 'feature_runtime_status_preparing';
    if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {
      this.resultText = '';
      this.resultRows = [];
      this.clearVisualResults();
    }
    try {
      const permission: PermissionRequestSummary = await new PermissionService().requestForWorkflow(context, workflow);
      if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        return;
      }
      if (!permission.ok) {
        this.statusKey = 'feature_runtime_permission_denied';
        this.resultText = permission.requested.join(', ');
        this.resultRows = [];
        this.clearVisualResults();
        return;
      }
      const frameInputReady = await this.prepareLiveFrameImageInput(context, runtimeRequestId, liveGeneration);
      if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        return;
      }
      if (!frameInputReady) {
        return;
      }
      const aiService: DefaultAiService =
        await this.runtimeAiServiceSession.getOrCreate(workflow, () =>
          cachedRuntimeAiServiceForHarmonyResourceManager(workflow, context.resourceManager));
      if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        return;
      }
      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());
      if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        return;
      }
      this.applyAiResult(result, runtimeRequestId);
    } catch (_) {
      if (this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        this.applyRuntimeFailure();
      }
    }
  }

  private applyRuntimeFailure(): void {
    this.statusKey = 'feature_runtime_run_failed';
    this.resultText = '';
    this.resultRows = [];
    this.clearVisualResults();
  }

  private async prepareLiveFrameImageInput(
    context: common.UIAbilityContext,
    runtimeRequestId: number,
    liveGeneration?: number
  ): Promise<boolean> {
    if (!shouldCaptureLiveFrameImage(this.liveCameraInputSelected, this.imageInputUri, this.liveCameraActive)) {
      return true;
    }

    if (!this.liveCameraActive) {
      await this.startLiveCameraPreviewAsync();
      if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
        return false;
      }
      if (!this.liveCameraActive) {
        return false;
      }
    }

    const surfaceId = this.liveCameraSurfaceId.length > 0 ?
      this.liveCameraSurfaceId :
      this.liveCameraController.getXComponentSurfaceId();
    const result: LiveFrameImageResult = await new LiveFrameImageService(
      new HarmonyLiveFrameImageEncoder(),
      new HarmonyLiveFrameImageStore()
    ).captureToCacheImage(surfaceId, context.cacheDir);
    if (!this.isRuntimeRequestCurrent(runtimeRequestId, liveGeneration)) {
      return false;
    }
    if (!result.ok) {
      this.statusKey = result.messageKey;
      this.resultText = '';
      this.resultRows = [];
      this.clearVisualResults();
      return false;
    }

    this.imageInputUri = result.uri;
    this.selectedInputSummary = result.uri;
    return true;
  }

  private applyAiResult(result: AiRunResult, runtimeRequestId: number): void {
    this.statusKey = result.messageKey;
    this.resultText = result.detailText;
    this.resultRows = aiRunResultRows(result);
    if (!this.shouldPreserveVisualResultsOnAiResult(result)) {
      this.clearVisualResults();
    }
    this.updateObjectDetectionPreview(result);
    this.updateSegmentationPreview(result, runtimeRequestId);
    this.updatePosePreview(result);
    this.updateGesturePreview(result);
    this.updateSceneOverlay(result);
    this.updateStyledImagePreview(result, runtimeRequestId);
  }

  private clearRuntimeResultState(): void {
    this.resultRows = [];
    this.resultText = '';
    this.clearVisualResults();
  }

  private shouldPreserveVisualResultsOnAiResult(result: AiRunResult): boolean {
    const dataKind = result.data?.kind ?? '';
    return shouldPreserveRuntimeVisualResultOnAiResult(workflowForRoute(this.routeName), result.ok, dataKind);
  }

  private clearVisualResults(): void {
    this.styledImagePixelMapOwner.clear();
    this.styledImagePixelMap = undefined;
    this.styleOriginalPreviewRecovered = false;
    this.objectDetectionImageUri = '';
    this.objectDetectionImageOrientation = ImageRotateOrientation.UP;
    this.objectDetections = [];
    this.objectDetectionImageWidth = 0;
    this.objectDetectionImageHeight = 0;
    this.segmentationImageUri = '';
    this.segmentationImageOrientation = ImageRotateOrientation.UP;
    this.segmentationBackgroundImageUri = '';
    this.segmentationBackgroundImageOrientation = ImageRotateOrientation.UP;
    this.segmentationForegroundPixelMapOwner.clear();
    this.segmentationForegroundPixelMap = undefined;
    this.segmentationRectangles = [];
    this.segmentationImageWidth = 0;
    this.segmentationImageHeight = 0;
    this.poseImageUri = '';
    this.poseImageOrientation = ImageRotateOrientation.UP;
    this.posePoints = [];
    this.poseImageWidth = 0;
    this.poseImageHeight = 0;
    this.gestureImageUri = '';
    this.gestureImageOrientation = ImageRotateOrientation.UP;
    this.gestureDetections = [];
    this.gestureImageWidth = 0;
    this.gestureImageHeight = 0;
    this.sceneOverlayRows = [];
  }

  private updateObjectDetectionPreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'objectDetections' || data.detections.length === 0) {
      return;
    }

    this.objectDetectionImageUri = data.imageUri;
    this.updateObjectDetectionImageOrientation(data.imageUri);
    this.objectDetections = data.detections;
    this.objectDetectionImageWidth = this.objectDetectionSourceWidth(data.detections);
    this.objectDetectionImageHeight = this.objectDetectionSourceHeight(data.detections);
  }

  private updateSegmentationPreview(result: AiRunResult, runtimeRequestId: number): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'segmentation' || data.result.rectangles.length === 0) {
      return;
    }

    this.segmentationImageUri = data.imageUri;
    this.updateSegmentationImageOrientation(data.imageUri);
    const backgroundImageUri = runtimeSegmentationBackgroundImageUri(
      workflowForRoute(this.routeName),
      this.backgroundImageUri,
      data.backgroundImageUri
    );
    this.segmentationBackgroundImageUri = backgroundImageUri;
    this.updateSegmentationBackgroundImageOrientation(backgroundImageUri);
    const metadata: SegmentationBackgroundMetadata =
      segmentationMetadataWithBackground(this.resultRows, this.resultText, backgroundImageUri);
    this.resultRows = metadata.rows;
    this.resultText = metadata.detailText;
    this.segmentationRectangles = data.result.rectangles;
    this.segmentationImageWidth = data.result.imageWidth ?? this.segmentationSourceWidth(data.result.rectangles);
    this.segmentationImageHeight = data.result.imageHeight ?? this.segmentationSourceHeight(data.result.rectangles);
    this.updateSegmentationForegroundPreview(data.result, runtimeRequestId);
  }

  private updateSegmentationForegroundPreview(result: SegmentationResult, runtimeRequestId: number): void {
    const rgba = result.foregroundImageRgba;
    const width = result.foregroundImageWidth ?? 0;
    const height = result.foregroundImageHeight ?? 0;
    if (rgba === undefined || rgba.byteLength === 0 || width <= 0 || height <= 0) {
      return;
    }

    const requestId = this.segmentationForegroundPixelMapOwner.beginReplacement();
    styleTransferPixelMapFromRgbaOutput(rgba, width, height).then((pixelMap: image.PixelMap) => {
      if (!this.runtimeRequestGeneration.isCurrent(runtimeRequestId)) {
        this.segmentationForegroundPixelMapOwner.accept(requestId, pixelMap);
        return;
      }
      if (this.segmentationForegroundPixelMapOwner.accept(requestId, pixelMap)) {
        this.segmentationForegroundPixelMap = pixelMap;
      }
    }).catch(() => {
      if (this.runtimeRequestGeneration.isCurrent(runtimeRequestId) &&
        this.segmentationForegroundPixelMapOwner.isCurrent(requestId)) {
        this.segmentationForegroundPixelMapOwner.clear();
        this.segmentationForegroundPixelMap = undefined;
      }
    });
  }

  private updatePosePreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'pose' || data.result.points.length === 0) {
      return;
    }

    this.poseImageUri = data.imageUri;
    this.updatePoseImageOrientation(data.imageUri);
    this.posePoints = data.result.points;
    this.poseImageWidth = data.result.imageWidth ?? this.poseSourceWidth(data.result.points);
    this.poseImageHeight = data.result.imageHeight ?? this.poseSourceHeight(data.result.points);
  }

  private updateGesturePreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'gesture' || data.result.gestures.length === 0) {
      return;
    }

    this.gestureImageUri = data.imageUri;
    this.updateGestureImageOrientation(data.imageUri);
    this.gestureDetections = data.result.gestures;
    this.gestureImageWidth = data.result.imageWidth ?? this.gestureSourceWidth(data.result.gestures);
    this.gestureImageHeight = data.result.imageHeight ?? this.gestureSourceHeight(data.result.gestures);
  }

  private updateSceneOverlay(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'scenes' || !this.shouldShowLiveSceneOverlay()) {
      return;
    }
    this.sceneOverlayRows = sceneDetectionOverlayRows(data.result);
  }

  private shouldShowLiveSceneOverlay(): boolean {
    const workflow = workflowForRoute(this.routeName);
    return workflow?.aiMethod === 'detectScene' && workflow.liveMode;
  }

  private gestureSourceWidth(gestures: Array<GestureDetection>): number {
    let width = 0;
    gestures.forEach((gesture: GestureDetection) => {
      if (gesture.rect !== undefined) {
        width = Math.max(width, gesture.rect.left + gesture.rect.width);
      }
    });
    return width;
  }

  private gestureSourceHeight(gestures: Array<GestureDetection>): number {
    let height = 0;
    gestures.forEach((gesture: GestureDetection) => {
      if (gesture.rect !== undefined) {
        height = Math.max(height, gesture.rect.top + gesture.rect.height);
      }
    });
    return height;
  }

  private poseSourceWidth(points: Array<PosePoint>): number {
    let width = 0;
    points.forEach((point: PosePoint) => {
      width = Math.max(width, point.x);
    });
    return width;
  }

  private poseSourceHeight(points: Array<PosePoint>): number {
    let height = 0;
    points.forEach((point: PosePoint) => {
      height = Math.max(height, point.y);
    });
    return height;
  }

  private segmentationSourceWidth(rectangles: Array<SegmentationRectangle>): number {
    let width = 0;
    rectangles.forEach((rectangle: SegmentationRectangle) => {
      width = Math.max(width, rectangle.left + rectangle.width);
    });
    return width;
  }

  private segmentationSourceHeight(rectangles: Array<SegmentationRectangle>): number {
    let height = 0;
    rectangles.forEach((rectangle: SegmentationRectangle) => {
      height = Math.max(height, rectangle.top + rectangle.height);
    });
    return height;
  }

  private objectDetectionSourceWidth(detections: Array<ObjectDetection>): number {
    let width = 0;
    detections.forEach((detection: ObjectDetection) => {
      width = Math.max(width, detection.imageWidth ?? 0, detection.right);
    });
    return width;
  }

  private objectDetectionSourceHeight(detections: Array<ObjectDetection>): number {
    let height = 0;
    detections.forEach((detection: ObjectDetection) => {
      height = Math.max(height, detection.imageHeight ?? 0, detection.bottom);
    });
    return height;
  }

  private updateStyledImagePreview(result: AiRunResult, runtimeRequestId: number): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'styleTransfer') {
      return;
    }

    const rgba = data.result.outputImageRgba;
    const width = data.result.outputImageWidth ?? 0;
    const height = data.result.outputImageHeight ?? 0;
    if (rgba === undefined || rgba.byteLength === 0 || width <= 0 || height <= 0) {
      return;
    }

    const requestId = this.styledImagePixelMapOwner.beginReplacement();
    styleTransferPixelMapFromRgbaOutput(rgba, width, height).then((pixelMap: image.PixelMap) => {
      if (!this.runtimeRequestGeneration.isCurrent(runtimeRequestId)) {
        this.styledImagePixelMapOwner.accept(requestId, pixelMap);
        return;
      }
      if (this.styledImagePixelMapOwner.accept(requestId, pixelMap)) {
        this.styledImagePixelMap = pixelMap;
        this.styleOriginalPreviewRecovered = false;
      }
    }).catch(() => {
      if (this.runtimeRequestGeneration.isCurrent(runtimeRequestId) &&
        this.styledImagePixelMapOwner.isCurrent(requestId)) {
        this.styledImagePixelMapOwner.clear();
        this.styledImagePixelMap = undefined;
        this.styleOriginalPreviewRecovered = false;
      }
    });
  }

  private openHelpPage(): void {
    if (this.helpUrl.length === 0) {
      return;
    }
    openRuntimeHelpSource(
      this.externalHelpLinkContext(),
      this.helpUrl,
      this.titleKey,
      new PageExternalHelpNavigator((options: RuntimeHelpRouteOptions) => this.openRuntimeHelpFallback(options))
    );
  }

  private externalHelpLinkContext(): ExternalHelpLinkContext | undefined {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return undefined;
    }
    return new PageExternalHelpLinkContext(context);
  }

  private openRuntimeHelpFallback(options: RuntimeHelpRouteOptions): void {
    try {
      this.getUIContext().getRouter().pushUrl(options).catch(() => {
      });
    } catch (_) {
    }
  }

  private showLocalHelpDialog(): void {
    if (this.helpContentKey === undefined) {
      return;
    }
    AlertDialog.show({
      title: appString('feature_runtime_help'),
      message: appString(this.helpContentKey),
      primaryButton: {
        value: appString('confirm'),
        action: () => {}
      }
    });
  }

  private showRuntimeToast(statusKey: AppStringKey | undefined): void {
    if (statusKey === undefined) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({
        message: appString(statusKey),
        duration: 2000
      });
    } catch (_) {
    }
  }

  private hasLinkedLiveRoute(): boolean {
    const workflow = workflowForRoute(this.routeName);
    return (workflow?.linkedLiveRouteName ?? '').length > 0;
  }

  private openLinkedLiveRoute(): void {
    const workflow = workflowForRoute(this.routeName);
    const linkedRouteName = workflow?.linkedLiveRouteName ?? '';
    const route = findRouteByName(linkedRouteName);
    if (!route) {
      return;
    }
    const linkedWorkflow = workflowForRoute(linkedRouteName);
    router.pushUrl({
      url: route.page,
      params: {
        routeName: linkedRouteName,
        titleKey: linkedWorkflow?.titleKey ?? this.titleKey
      }
    });
  }

  private hasInputPreview(): boolean {
    return (this.imageInputUri.length > 0 && shouldShowPrimaryImageInputPreview(
      workflowForRoute(this.routeName),
      this.primaryOverlayReady()
    )) ||
      this.contentImageUri.length > 0 ||
      this.styleImageUri.length > 0 ||
      this.backgroundImageUri.length > 0 ||
      this.stylePredictModelInputUri.length > 0 ||
      this.styleTransferModelInputUri.length > 0 ||
      this.modelInputUri.length > 0;
  }

  private primaryOverlayReady(): boolean {
    if (this.routeName === AppRoute.OBJECT_PHOTO.name) {
      return this.objectDetectionImageUri.length > 0 && this.objectDetections.length > 0;
    }
    if (this.routeName === AppRoute.POSENET.name) {
      return this.poseImageUri.length > 0 && this.posePoints.length > 0;
    }
    if (this.routeName === AppRoute.GESTURE_STILL.name) {
      return this.gestureImageUri.length > 0 && this.visibleGestureDetections().length > 0;
    }
    return false;
  }

  private isStyleTransferWorkflow(): boolean {
    return this.aiMethod === 'runStyleTransfer';
  }

  private isPortraitSegmentationWorkflow(): boolean {
    return this.routeName === AppRoute.PORTRAIT_SEGMENTATION.name;
  }

  private applyDefaultPortraitBackgroundIfNeeded(): void {
    const backgroundState: PortraitSegmentationBackgroundState = initialPortraitSegmentationBackgroundState(
      this.routeName,
      this.backgroundImageUri,
      this.selectedPortraitBackgroundPresetId
    );
    this.backgroundImageUri = backgroundState.backgroundImageUri;
    this.selectedPortraitBackgroundPresetId = backgroundState.selectedPresetId;
  }

  private visibleInputKinds(): Array<FeatureInputKind> {
    const workflow = workflowForRoute(this.routeName);
    if (workflow !== undefined) {
      return visibleInputKindsForWorkflow(workflow);
    }
    return this.inputKinds;
  }

  private shouldShowSegmentationBackgroundPreview(): boolean {
    return this.isPortraitSegmentationWorkflow() &&
      this.segmentationBackgroundImageUri.length > 0 &&
      this.segmentationForegroundPixelMap !== undefined;
  }

  private textInputPlaceholderKey(): AppStringKey {
    return textInputPlaceholderKeyForWorkflow(workflowForRoute(this.routeName));
  }

  private runActionEnabled(): boolean {
    const workflow = workflowForRoute(this.routeName);
    if (workflow === undefined) {
      return true;
    }
    const liveRuntimeLoopReady = shouldRunLiveRuntimeLoop(
      workflow.aiMethod,
      liveRuntimeModeForWorkflow(workflow),
      this.liveCameraInputSelected, this.liveCameraActive);
    return shouldStartWorkflowRun(workflow, this.workflowRunning, liveRuntimeLoopReady);
  }

  private runtimePermissionRecoveryAction(): RuntimePermissionRecoveryAction {
    return runtimePermissionRecoveryActionForWorkflow(workflowForRoute(this.routeName), this.statusKey);
  }

  private runtimePermissionRunAction(): RuntimePermissionRunAction {
    return runtimePermissionRunActionForWorkflow(workflowForRoute(this.routeName), this.statusKey);
  }

  private shouldShowRuntimePermissionRetry(): boolean {
    return this.runtimePermissionRecoveryAction() !== 'none';
  }

  private runPrimaryAction(): void {
    if (this.runtimePermissionRunAction() === 'retryCameraInput') {
      this.prepareInput('camera');
      return;
    }
    this.runWorkflow();
  }

  private retryRuntimePermission(): void {
    const action = this.runtimePermissionRecoveryAction();
    if (action === 'retryCameraInput') {
      this.prepareInput('camera');
      return;
    }
    if (action === 'retryRun') {
      this.runWorkflow();
    }
  }

  private openRuntimePermissionSettings(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    try {
      const action = runtimeOpenAppSettingsAction(context.applicationInfo.name);
      context.startAbility(action.want).catch(() => {
      });
    } catch (_) {
    }
  }

  private selectBuiltInStyle(style: BuiltInStyleTransferStyle): void {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldAllowRuntimeInputChange(workflow, 'styleImage', this.workflowRunning)) {
      this.statusKey = 'feature_runtime_status_running';
      return;
    }
    this.styleImageUri = builtInStyleTransferUri(style);
    this.selectedInputSummary = style.rawfilePath;
    this.statusKey = workflow ?
      styleTransferStyleReadyStatusKey(workflow, 'styleImage', this.styleTransferContentInputReady(),
        'feature_runtime_image_ready') :
      'feature_runtime_image_ready';
    if (workflow && this.shouldRunStyleTransferAfterStyleReady(workflow, 'styleImage')) {
      this.runWorkflow();
    }
  }

  private shouldRunStyleTransferAfterStyleReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
    return shouldAutoRunStyleTransferAfterStyleReady(workflow, inputKind, this.styleTransferContentInputReady());
  }

  private styleTransferContentInputReady(): boolean {
    return this.contentImageUri.length > 0 || this.imageInputUri.length > 0;
  }

  private recoverStyleOriginalPreview(): void {
    if (!this.styleTransferContentInputReady()) {
      this.statusKey = styleTransferRecoveryStatusKey(false);
      return;
    }
    this.styleOriginalPreviewRecovered = true;
    this.statusKey = styleTransferRecoveryStatusKey(true);
  }

  private selectPortraitBackgroundPreset(preset: PortraitSegmentationBackgroundPreset): void {
    this.applyPortraitBackgroundUri(portraitSegmentationBackgroundUri(preset), preset.id);
    this.selectedInputSummary = preset.rawfilePath;
    this.statusKey = 'feature_runtime_image_ready';
  }

  private applyPortraitBackgroundUri(uri: string, presetId: string): void {
    this.backgroundImageUri = uri;
    this.selectedPortraitBackgroundPresetId = presetId;
    this.segmentationBackgroundImageUri = uri;
    this.updateSegmentationBackgroundImageOrientation(uri);
    const metadata: SegmentationBackgroundMetadata =
      segmentationMetadataWithBackground(this.resultRows, this.resultText, uri);
    this.resultRows = metadata.rows;
    this.resultText = metadata.detailText;
  }

  private lastPathSegment(uri: string): string {
    const normalized = uri.split('\\').join('/');
    const parts = normalized.split('/');
    if (parts.length === 0) {
      return uri;
    }
    return parts[parts.length - 1];
  }

  private recognizedTextForCopy(): string {
    return copyableTextForAiResult(this.aiMethod, this.resultRows);
  }

  private copyRecognizedText(): void {
    new ClipboardService().copyText(this.recognizedTextForCopy()).then((result: CopyTextResult) => {
      this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';
    });
  }

  private updateUserText(value: string): void {
    this.userText = value;
    this.selectedInputSummary = value;
    this.statusKey = value.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
  }

  private saveResultImage(pixelMap: image.PixelMap | undefined): void {
    this.saveResultPixelMap(pixelMap);
  }

  private saveResultComponentImage(componentId: string): void {
    this.saveResultComponentImageAsync(componentId).catch(() => {
      this.statusKey = 'feature_runtime_save_image_failed';
    });
  }

  private saveResultPixelMap(pixelMap: image.PixelMap | undefined): void {
    this.saveResultPixelMapAsync(pixelMap).catch(() => {
      this.statusKey = 'feature_runtime_save_image_failed';
    });
  }

  private async saveResultComponentImageAsync(componentId: string): Promise<void> {
    const pixelMap = await componentSnapshot.get(componentId, { waitUntilRenderFinished: true });
    await withCallerOwnedPixelMap(pixelMap, async (snapshot: image.PixelMap | undefined): Promise<void> => {
      await this.saveResultPixelMapAsync(snapshot);
    });
  }

  private async saveResultPixelMapAsync(pixelMap: image.PixelMap | undefined): Promise<void> {
    const context = this.uiAbilityContext();
    if (!context) {
      this.statusKey = 'feature_runtime_save_image_failed';
      return;
    }
    const result: ResultImageSaveResult = await new ResultImageSaveService(
      new HarmonyResultImagePixelMapEncoder(),
      new HarmonyResultImageAssetWriter(context)
    ).save(pixelMap);
    this.statusKey = result.messageKey;
    if (result.ok) {
      this.selectedInputSummary = result.uri;
    }
  }

  @Builder
  inputChip(inputKind: FeatureInputKind) {
    Text(appString(workflowInputLabelKey(workflowForRoute(this.routeName), inputKind)))
      .fontSize(12)
      .fontColor(AppColor.accent)
      .padding({ left: AppSpacing.sm, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
      .backgroundColor('#F0F3FF')
      .borderRadius(AppRadius.button)
      .margin({ right: AppSpacing.sm, bottom: AppSpacing.sm })
      .onClick(() => this.prepareInput(inputKind))
  }

  @Builder
  permissionChip(permissionKind: FeaturePermissionKind) {
    Text(appString(permissionLabelKey(permissionKind)))
      .fontSize(12)
      .fontColor(AppColor.textSecondary)
      .padding({ left: AppSpacing.sm, right: AppSpacing.sm, top: AppSpacing.xs, bottom: AppSpacing.xs })
      .backgroundColor('#F7F8FA')
      .borderRadius(AppRadius.button)
      .margin({ right: AppSpacing.sm, bottom: AppSpacing.sm })
  }

  @Builder
  styleTransferStyleGrid() {
    Column() {
      Text(appString('feature_runtime_style_presets_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textPrimary)
        .width('100%')
      Grid() {
        ForEach(builtInStyleTransferStyles, (style: BuiltInStyleTransferStyle) => {
          GridItem() {
            this.styleTransferStyleItem(style)
          }
        }, (style: BuiltInStyleTransferStyle) => `${style.id}`)
        GridItem() {
          this.styleTransferCustomStyleItem()
        }
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(AppSpacing.sm)
      .rowsGap(AppSpacing.sm)
      .width('100%')
      .margin({ top: AppSpacing.sm })
    }
    .width('100%')
    .margin({ top: AppSpacing.md })
  }

  @Builder
  styleTransferStyleItem(style: BuiltInStyleTransferStyle) {
    Column() {
      this.styleTransferStyleImage(style)
    }
    .width('100%')
    .aspectRatio(1)
    .padding(2)
    .border({
      width: this.styleImageUri === builtInStyleTransferUri(style) ? 2 : 1,
      color: this.styleImageUri === builtInStyleTransferUri(style) ? AppColor.accent : AppColor.divider,
      radius: AppRadius.card
    })
    .clip(true)
    .onClick(() => this.selectBuiltInStyle(style))
  }

  @Builder
  styleTransferCustomStyleItem() {
    Column() {
      if (isCustomStyleTransferUri(this.styleImageUri)) {
        Image(this.styleImageUri)
          .width('100%')
          .height('72%')
          .objectFit(ImageFit.Cover)
      } else {
        Image($r('app.media.icon_default'))
          .width('100%')
          .height('72%')
          .objectFit(ImageFit.Contain)
      }
      Text(appString('feature_runtime_style_custom'))
        .fontSize(9)
        .fontColor(AppColor.textSecondary)
        .maxLines(1)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .aspectRatio(1)
    .padding(2)
    .justifyContent(FlexAlign.Center)
    .border({
      width: isCustomStyleTransferUri(this.styleImageUri) ? 2 : 1,
      color: isCustomStyleTransferUri(this.styleImageUri) ? AppColor.accent : AppColor.divider,
      radius: AppRadius.card
    })
    .backgroundColor('#F7F8FA')
    .clip(true)
    .onClick(() => this.prepareInput('styleImage'))
  }

  @Builder
  styleTransferStyleImage(style: BuiltInStyleTransferStyle) {
    if (builtInStyleTransferMediaName(style) === 'style0') {
      this.styleTransferStyleImageSource($r('app.media.style0'))
    } else if (builtInStyleTransferMediaName(style) === 'style1') {
      this.styleTransferStyleImageSource($r('app.media.style1'))
    } else if (builtInStyleTransferMediaName(style) === 'style2') {
      this.styleTransferStyleImageSource($r('app.media.style2'))
    } else if (builtInStyleTransferMediaName(style) === 'style3') {
      this.styleTransferStyleImageSource($r('app.media.style3'))
    } else if (builtInStyleTransferMediaName(style) === 'style4') {
      this.styleTransferStyleImageSource($r('app.media.style4'))
    } else if (builtInStyleTransferMediaName(style) === 'style5') {
      this.styleTransferStyleImageSource($r('app.media.style5'))
    } else if (builtInStyleTransferMediaName(style) === 'style6') {
      this.styleTransferStyleImageSource($r('app.media.style6'))
    } else if (builtInStyleTransferMediaName(style) === 'style7') {
      this.styleTransferStyleImageSource($r('app.media.style7'))
    } else if (builtInStyleTransferMediaName(style) === 'style8') {
      this.styleTransferStyleImageSource($r('app.media.style8'))
    } else if (builtInStyleTransferMediaName(style) === 'style9') {
      this.styleTransferStyleImageSource($r('app.media.style9'))
    } else if (builtInStyleTransferMediaName(style) === 'style10') {
      this.styleTransferStyleImageSource($r('app.media.style10'))
    } else if (builtInStyleTransferMediaName(style) === 'style11') {
      this.styleTransferStyleImageSource($r('app.media.style11'))
    } else if (builtInStyleTransferMediaName(style) === 'style12') {
      this.styleTransferStyleImageSource($r('app.media.style12'))
    } else if (builtInStyleTransferMediaName(style) === 'style13') {
      this.styleTransferStyleImageSource($r('app.media.style13'))
    } else if (builtInStyleTransferMediaName(style) === 'style14') {
      this.styleTransferStyleImageSource($r('app.media.style14'))
    } else if (builtInStyleTransferMediaName(style) === 'style15') {
      this.styleTransferStyleImageSource($r('app.media.style15'))
    } else if (builtInStyleTransferMediaName(style) === 'style16') {
      this.styleTransferStyleImageSource($r('app.media.style16'))
    } else if (builtInStyleTransferMediaName(style) === 'style17') {
      this.styleTransferStyleImageSource($r('app.media.style17'))
    } else if (builtInStyleTransferMediaName(style) === 'style18') {
      this.styleTransferStyleImageSource($r('app.media.style18'))
    } else {
      this.styleTransferStyleImageSource($r('app.media.style18'))
    }
  }

  @Builder
  styleTransferStyleImageSource(source: Resource) {
    Image(source)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
  }

  @Builder
  portraitSegmentationBackgroundGrid() {
    Column() {
      Text(appString('feature_runtime_portrait_background_presets'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textPrimary)
        .width('100%')
      Grid() {
        ForEach(portraitSegmentationBackgroundPresets, (preset: PortraitSegmentationBackgroundPreset) => {
          GridItem() {
            this.portraitSegmentationBackgroundItem(preset)
          }
        }, (preset: PortraitSegmentationBackgroundPreset) => preset.id)
        GridItem() {
          this.portraitSegmentationCustomBackgroundItem()
        }
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(AppSpacing.sm)
      .rowsGap(AppSpacing.sm)
      .width('100%')
      .margin({ top: AppSpacing.sm })
    }
    .width('100%')
    .margin({ top: AppSpacing.md })
  }

  @Builder
  portraitSegmentationBackgroundItem(preset: PortraitSegmentationBackgroundPreset) {
    Column() {
      Image(portraitSegmentationBackgroundUri(preset))
        .width('100%')
        .height(70)
        .objectFit(ImageFit.Cover)
      Text(appString(preset.titleKey))
        .fontSize(10)
        .fontColor(AppColor.textSecondary)
        .maxLines(1)
        .margin({ top: 4 })
    }
    .width('100%')
    .height(100)
    .padding(2)
    .border({
      width: this.selectedPortraitBackgroundPresetId === preset.id ? 2 : 1,
      color: this.selectedPortraitBackgroundPresetId === preset.id ? AppColor.accent : AppColor.divider,
      radius: AppRadius.card
    })
    .clip(true)
    .onClick(() => this.selectPortraitBackgroundPreset(preset))
  }

  @Builder
  portraitSegmentationCustomBackgroundItem() {
    Column() {
      Image($r('app.media.icon_default'))
        .width('100%')
        .height(64)
        .objectFit(ImageFit.Contain)
      Text(appString('feature_runtime_portrait_background_custom'))
        .fontSize(10)
        .fontColor(AppColor.textSecondary)
        .maxLines(1)
    }
    .width('100%')
    .height(100)
    .padding(2)
    .justifyContent(FlexAlign.Center)
    .border({
      width: this.selectedPortraitBackgroundPresetId === portraitSegmentationCustomBackgroundId ? 2 : 1,
      color: this.selectedPortraitBackgroundPresetId === portraitSegmentationCustomBackgroundId ?
        AppColor.accent :
        AppColor.divider,
      radius: AppRadius.card
    })
    .backgroundColor('#F7F8FA')
    .clip(true)
    .onClick(() => this.prepareInput('backgroundImage'))
  }

  @Builder
  liveCameraSurfaceContent() {
    XComponent({
      id: liveCameraXComponentId,
      type: XComponentType.SURFACE,
      controller: this.liveCameraController
    })
      .width('100%')
      .height('100%')
      .onLoad(() => {
        this.liveCameraSurfaceId = this.liveCameraController.getXComponentSurfaceId();
        if (this.liveCameraInputSelected) {
          this.startLiveCameraPreview();
        } else {
          this.autoStartLiveCameraIfNeeded();
        }
      })
      .onDestroy(() => this.stopLiveCameraPreview())
    if (this.sceneOverlayRows.length > 0 && this.shouldShowLiveSceneOverlay()) {
      this.liveSceneOverlay()
    }
    if (this.segmentationForegroundPixelMap !== undefined &&
      shouldShowLiveSegmentationCameraOverlay(workflowForRoute(this.routeName)) &&
      !usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {
      Image(this.segmentationForegroundPixelMap)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .scale({ x: this.segmentationForegroundMirrorScaleX(), y: 1 })
    }
    if (this.objectDetections.length > 0 &&
      shouldShowLiveObjectDetectionCameraOverlay(workflowForRoute(this.routeName))) {
      ForEach(this.objectDetections, (detection: ObjectDetection, index: number) => {
        this.liveObjectDetectionBox(detection, index)
      }, (detection: ObjectDetection) => `${detection.imageId}-${detection.labelId}-${detection.score}`)
    }
    if (this.posePoints.length > 0 && shouldShowLivePoseCameraOverlay(workflowForRoute(this.routeName))) {
      ForEach(this.poseLines(), (line: PoseLine) => {
        this.poseLine(line)
      }, (line: PoseLine) => `${line.start.type}-${line.end.type}-${line.start.x}-${line.start.y}`)
      ForEach(this.visiblePosePoints(), (point: PosePoint) => {
        this.posePoint(point)
      }, (point: PosePoint) => `${point.type}-${point.x}-${point.y}-${point.score}`)
    }
    if (this.visibleGestureDetections().length > 0 &&
      shouldShowLiveGestureCameraOverlay(workflowForRoute(this.routeName))) {
      ForEach(this.visibleGestureDetections(), (gesture: GestureDetection) => {
        this.gestureBox(gesture)
      }, (gesture: GestureDetection) =>
        `${gesture.category}-${gesture.score}-${gesture.rect?.left}-${gesture.rect?.top}`)
    }
    if (shouldShowLivePoseTemplateOverlay(workflowForRoute(this.routeName))) {
      Column() {
        this.livePoseTemplateOverlay()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.End)
    }
    if (shouldShowLiveClassificationCameraOverlay(workflowForRoute(this.routeName)) &&
      specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) !== 'imageClassification') {
      this.liveClassificationOverlay()
    }
  }

  @Builder
  liveCameraPreview() {
    Column() {
      Text(appString('feature_runtime_preview_image'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        this.liveCameraSurfaceContent()
      }
        .width('100%')
        .height(260)
        .backgroundColor('#111827')
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .clip(true)
        .margin({ top: AppSpacing.xs })
      if (this.liveCameraSwitchAvailable) {
        Image($r('app.media.front_back_switch'))
          .width(35)
          .height(35)
          .objectFit(ImageFit.Contain)
          .margin({ top: AppSpacing.sm })
          .onClick(() => this.switchLiveCamera())
      }
    }
    .width('100%')
    .margin({ top: AppSpacing.md })
  }

  @Builder
  liveSceneOverlay() {
    Column() {
      ForEach(this.sceneOverlayRows, (row: SceneDetectionOverlayRow) => {
        Row() {
          Text(appString(row.labelKey))
            .fontSize(13)
            .fontColor('#FCA5A5')
            .fontWeight(FontWeight.Medium)
          Text(`: ${row.value}`)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
      }, (row: SceneDetectionOverlayRow) => row.id)
    }
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#66000000')
    .border({ radius: 6 })
    .margin({ left: 10, top: 10 })
    .width(190)
  }

  @Builder
  liveClassificationOverlay() {
    Column() {
      Row() {
        Text(this.liveClassificationOverlayValue())
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(44)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .backgroundColor('#66000000')
      .borderRadius(6)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: 10, bottom: 10 })
    .justifyContent(FlexAlign.End)
  }

  @Builder
  livePoseTemplateOverlay() {
    Column() {
      Text(`similarity:${this.livePoseSimilarityPercent()}`)
        .fontSize(13)
        .fontColor(Color.White)
        .height(18)
      Image($r('app.media.skeleton_template'))
        .width(135)
        .height(169)
        .objectFit(ImageFit.Contain)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  imagePreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Image(uri)
        .width('100%')
        .height(156)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F7F8FA')
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  private segmentationAspectRatio(): number {
    if (this.segmentationImageWidth <= 0 || this.segmentationImageHeight <= 0) {
      return 1;
    }
    return this.segmentationImageWidth / this.segmentationImageHeight;
  }

  private poseAspectRatio(): number {
    if (this.poseImageWidth <= 0 || this.poseImageHeight <= 0) {
      return 1;
    }
    return this.poseImageWidth / this.poseImageHeight;
  }

  private objectDetectionAspectRatio(): number {
    if (this.objectDetectionImageWidth <= 0 || this.objectDetectionImageHeight <= 0) {
      return 1;
    }
    return this.objectDetectionImageWidth / this.objectDetectionImageHeight;
  }

  private gestureAspectRatio(): number {
    if (this.gestureImageWidth <= 0 || this.gestureImageHeight <= 0) {
      return 1;
    }
    return this.gestureImageWidth / this.gestureImageHeight;
  }

  private objectDetectionLabel(detection: ObjectDetection, index: number): string {
    return objectDetectionOverlayLabel(detection, index);
  }

  private gestureLabelResource(gesture: GestureDetection): ResourceStr {
    const labelKey = gestureDetectionLabelKey(gesture);
    if (labelKey !== undefined) {
      return appString(labelKey);
    }
    return gestureDetectionLabel(gesture);
  }

  private gestureScoreLabel(gesture: GestureDetection): string {
    return ` ${(gesture.score * 100).toFixed(1)}%`;
  }

  private resultRowValue(row: AiRunResultRow): ResourceStr {
    if (row.valueKey !== undefined) {
      return appString(row.valueKey);
    }
    return row.value;
  }

  private liveClassificationOverlayValue(): ResourceStr {
    const row = this.resultRows[0];
    if (row !== undefined) {
      return this.resultRowValue(row);
    }
    const promptKey = liveClassificationEmptyPromptKey(workflowForRoute(this.routeName));
    if (promptKey !== undefined) {
      return appString(promptKey);
    }
    return '';
  }

  private livePoseSimilarityPercent(): string {
    const similarityRow = this.resultRows.find((row: AiRunResultRow) =>
      row.labelKey === 'feature_runtime_result_similarity');
    return similarityRow?.value ?? '0%';
  }

  private objectDetectionBoxStyle(detection: ObjectDetection): ObjectDetectionBoxPercent {
    return objectDetectionBoxPercent(
      detection,
      this.objectDetectionImageWidth,
      this.objectDetectionImageHeight
    );
  }

  private liveObjectDetectionLabelOffset(detection: ObjectDetection): ObjectDetectionLiveLabelOffset {
    return objectDetectionLiveLabelOffset(
      this.objectDetectionBoxStyle(detection).top,
      this.liveObjectDetectionOverlayHeightVp
    );
  }

  private gestureBoxStyle(gesture: GestureDetection): GestureRectanglePercent {
    if (gesture.rect === undefined) {
      return {
        left: 0,
        top: 0,
        width: 0,
        height: 0
      };
    }
    return gestureRectanglePercent(
      gesture.rect,
      this.gestureImageWidth,
      this.gestureImageHeight,
      shouldMirrorLiveGestureCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)
    );
  }

  private visibleGestureDetections(): Array<GestureDetection> {
    return this.gestureDetections.filter((gesture: GestureDetection) => gesture.rect !== undefined);
  }

  private posePointStyle(point: PosePoint): PosePointPercent {
    return posePointPercent(
      point,
      this.poseImageWidth,
      this.poseImageHeight
    );
  }

  private visiblePosePoints(): Array<PosePoint> {
    return this.posePoints.filter((point: PosePoint) => isPosePointVisible(point));
  }

  private poseLines(): Array<PoseLine> {
    return poseSkeletonLines(this.posePoints);
  }

  private shouldShowPoseTemplate(): boolean {
    return shouldShowLivePoseTemplateOverlay(workflowForRoute(this.routeName));
  }

  private poseLineStyle(line: PoseLine): PoseLinePercent {
    return poseLinePercent(
      line,
      this.poseImageWidth,
      this.poseImageHeight
    );
  }

  private segmentationForegroundMirrorScaleX(): number {
    return shouldMirrorSegmentationForeground(workflowForRoute(this.routeName), this.liveCameraPosition) ? -1 : 1;
  }

  private segmentationBoxStyle(rectangle: SegmentationRectangle): SegmentationRectanglePercent {
    return segmentationRectanglePercent(
      rectangle,
      this.segmentationImageWidth,
      this.segmentationImageHeight
    );
  }

  private percentLength(value: number): string {
    return `${value}%`;
  }

  private updateObjectDetectionImageOrientation(uri: string): void {
    this.updateOverlayPreviewImageOrientation(uri, (orientation: ImageRotateOrientation) => {
      if (this.objectDetectionImageUri === uri) {
        this.objectDetectionImageOrientation = orientation;
      }
    });
  }

  private updateSegmentationImageOrientation(uri: string): void {
    this.updateOverlayPreviewImageOrientation(uri, (orientation: ImageRotateOrientation) => {
      if (this.segmentationImageUri === uri) {
        this.segmentationImageOrientation = orientation;
      }
    });
  }

  private updateSegmentationBackgroundImageOrientation(uri: string): void {
    this.updateOverlayPreviewImageOrientation(uri, (orientation: ImageRotateOrientation) => {
      if (this.segmentationBackgroundImageUri === uri) {
        this.segmentationBackgroundImageOrientation = orientation;
      }
    });
  }

  private updatePoseImageOrientation(uri: string): void {
    this.updateOverlayPreviewImageOrientation(uri, (orientation: ImageRotateOrientation) => {
      if (this.poseImageUri === uri) {
        this.poseImageOrientation = orientation;
      }
    });
  }

  private updateGestureImageOrientation(uri: string): void {
    this.updateOverlayPreviewImageOrientation(uri, (orientation: ImageRotateOrientation) => {
      if (this.gestureImageUri === uri) {
        this.gestureImageOrientation = orientation;
      }
    });
  }

  private updateOverlayPreviewImageOrientation(
    uri: string,
    applyOrientation: (orientation: ImageRotateOrientation) => void
  ): void {
    if (uri.length === 0) {
      applyOrientation(ImageRotateOrientation.UP);
      return;
    }
    featureRuntimeOverlayPreviewImageOrientationForUri(uri)
      .then((orientation: ImageRotateOrientation) => applyOrientation(orientation))
      .catch(() => applyOrientation(ImageRotateOrientation.UP));
  }

  @Builder
  posePreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(uri)
          .orientation(this.poseImageOrientation)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        ForEach(this.poseLines(), (line: PoseLine) => {
          this.poseLine(line)
        }, (line: PoseLine) => `${line.start.type}-${line.end.type}-${line.start.x}-${line.start.y}`)
        ForEach(this.visiblePosePoints(), (point: PosePoint) => {
          this.posePoint(point)
        }, (point: PosePoint) => `${point.type}-${point.x}-${point.y}-${point.score}`)
      }
      .width('100%')
      .aspectRatio(this.poseAspectRatio())
      .backgroundColor('#F7F8FA')
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      .clip(true)
      .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  poseTemplatePreview() {
    Column() {
      Text(appString('feature_runtime_result_pose_template'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
      Image($r('app.media.skeleton_template'))
        .width(120)
        .aspectRatio(135 / 169)
        .objectFit(ImageFit.Contain)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .alignItems(HorizontalAlign.End)
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  poseLine(line: PoseLine) {
    Column() {
    }
    .width(this.percentLength(this.poseLineStyle(line).length))
    .height(3)
    .borderRadius(2)
    .backgroundColor('#1D9A6C')
    .position({
      x: this.percentLength(this.poseLineStyle(line).startX),
      y: this.percentLength(this.poseLineStyle(line).startY)
    })
    .rotate({
      x: 0,
      y: 0,
      z: 1,
      angle: this.poseLineStyle(line).angle,
      centerX: 0,
      centerY: 1.5
    })
  }

  @Builder
  posePoint(point: PosePoint) {
    Column() {
    }
    .width(8)
    .height(8)
    .borderRadius(4)
    .backgroundColor('#FF5A5F')
    .border({ width: 1, color: '#FFFFFF' })
    .position({
      x: this.percentLength(this.posePointStyle(point).x),
      y: this.percentLength(this.posePointStyle(point).y)
    })
  }

  @Builder
  segmentationPreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(uri)
          .orientation(this.segmentationImageOrientation)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        ForEach(this.segmentationRectangles, (rectangle: SegmentationRectangle) => {
          this.segmentationBox(rectangle)
        }, (rectangle: SegmentationRectangle) =>
          `${rectangle.left}-${rectangle.top}-${rectangle.width}-${rectangle.height}`)
      }
      .width('100%')
      .aspectRatio(this.segmentationAspectRatio())
      .backgroundColor('#F7F8FA')
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      .clip(true)
      .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  segmentationBackgroundReplacementPreview(pixelMap: image.PixelMap) {
    Column() {
      Text(appString('feature_runtime_result_background_replacement'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.segmentationBackgroundImageUri)
          .orientation(this.segmentationBackgroundImageOrientation)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        Image(pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
          .scale({ x: this.segmentationForegroundMirrorScaleX(), y: 1 })
      }
      .width('100%')
      .aspectRatio(this.segmentationAspectRatio())
      .backgroundColor('#F7F8FA')
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      .clip(true)
      .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  segmentationBox(rectangle: SegmentationRectangle) {
    Column() {
    }
    .width(this.percentLength(this.segmentationBoxStyle(rectangle).width))
    .height(this.percentLength(this.segmentationBoxStyle(rectangle).height))
    .border({ width: 2, color: '#1D9A6C', radius: 2 })
    .position({
      x: this.percentLength(this.segmentationBoxStyle(rectangle).left),
      y: this.percentLength(this.segmentationBoxStyle(rectangle).top)
    })
  }

  @Builder
  objectDetectionPreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(uri)
          .orientation(this.objectDetectionImageOrientation)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        ForEach(this.objectDetections, (detection: ObjectDetection, index: number) => {
          this.objectDetectionBox(detection, index)
        }, (detection: ObjectDetection) => `${detection.imageId}-${detection.labelId}-${detection.score}`)
      }
      .width('100%')
      .aspectRatio(this.objectDetectionAspectRatio())
      .backgroundColor('#F7F8FA')
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      .clip(true)
      .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  gesturePreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(uri)
          .orientation(this.gestureImageOrientation)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        ForEach(this.visibleGestureDetections(), (gesture: GestureDetection) => {
          this.gestureBox(gesture)
        }, (gesture: GestureDetection) =>
          `${gesture.category}-${gesture.score}-${gesture.rect?.left}-${gesture.rect?.top}`)
      }
      .width('100%')
      .aspectRatio(this.gestureAspectRatio())
      .backgroundColor('#F7F8FA')
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      .clip(true)
      .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  gestureBox(gesture: GestureDetection) {
    Column() {
      Row() {
        Text(this.gestureLabelResource(gesture))
          .fontSize(10)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .maxLines(1)
        Text(this.gestureScoreLabel(gesture))
          .fontSize(10)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .backgroundColor(AppColor.accent)
      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
    }
    .width(this.percentLength(this.gestureBoxStyle(gesture).width))
    .height(this.percentLength(this.gestureBoxStyle(gesture).height))
    .border({ width: 2, color: AppColor.accent, radius: 2 })
    .position({
      x: this.percentLength(this.gestureBoxStyle(gesture).left),
      y: this.percentLength(this.gestureBoxStyle(gesture).top)
    })
  }

  @Builder
  objectDetectionBox(detection: ObjectDetection, index: number) {
    Column() {
      Text(this.objectDetectionLabel(detection, index))
        .fontSize(10)
        .fontColor(objectDetectionOverlayTextColor(index))
        .backgroundColor(objectDetectionOverlayColor(index))
        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
        .maxLines(1)
    }
    .width(this.percentLength(this.objectDetectionBoxStyle(detection).width))
    .height(this.percentLength(this.objectDetectionBoxStyle(detection).height))
    .border({ width: 2, color: objectDetectionOverlayColor(index), radius: 2 })
    .position({
      x: this.percentLength(this.objectDetectionBoxStyle(detection).left),
      y: this.percentLength(this.objectDetectionBoxStyle(detection).top)
    })
  }

  @Builder
  liveObjectDetectionBox(detection: ObjectDetection, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .border({ width: 2, color: objectDetectionOverlayColor(index), radius: 2 })
      Text(this.objectDetectionLabel(detection, index))
        .fontSize(16)
        .fontColor(objectDetectionOverlayColor(index))
        .maxLines(1)
        .position({
          x: this.liveObjectDetectionLabelOffset(detection).x,
          y: this.liveObjectDetectionLabelOffset(detection).y
        })
    }
    .width(this.percentLength(this.objectDetectionBoxStyle(detection).width))
    .height(this.percentLength(this.objectDetectionBoxStyle(detection).height))
    .position({
      x: this.percentLength(this.objectDetectionBoxStyle(detection).left),
      y: this.percentLength(this.objectDetectionBoxStyle(detection).top)
    })
  }

  @Builder
  pixelMapPreview(labelKey: AppStringKey, pixelMap: image.PixelMap) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Image(pixelMap)
        .width('100%')
        .height(220)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F7F8FA')
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .margin({ top: AppSpacing.xs })
    }
    .width('100%')
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  resultImageSaveControl(pixelMap: image.PixelMap | undefined) {
    Row() {
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_IMAGE,
        buttonType: ButtonType.Capsule
      })
        .height(36)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveResultImage(pixelMap);
            return;
          }
          this.statusKey = 'feature_runtime_save_image_failed';
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  styleRecoveryControl() {
    Row() {
      Button(appString('feature_runtime_style_recovery'))
        .height(36)
        .onClick(() => this.recoverStyleOriginalPreview())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  resultComponentImageSaveControl(componentId: string) {
    Row() {
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_IMAGE,
        buttonType: ButtonType.Capsule
      })
        .height(36)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveResultComponentImage(componentId);
            return;
          }
          this.statusKey = 'feature_runtime_save_image_failed';
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: AppSpacing.sm })
  }

  @Builder
  filePreview(labelKey: AppStringKey, uri: string) {
    Row() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width(84)
      Text(this.lastPathSegment(uri))
        .fontSize(12)
        .fontColor(AppColor.textMuted)
        .layoutWeight(1)
        .maxLines(1)
    }
    .width('100%')
    .margin({ top: AppSpacing.xs })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  resultRow(row: AiRunResultRow) {
    Row() {
      Text(appString(row.labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width(108)
      if (shouldUseLongTextResultRow(this.aiMethod, row.labelKey)) {
        Text(this.resultRowValue(row))
          .fontSize(13)
          .fontColor(AppColor.textPrimary)
          .layoutWeight(1)
      } else {
        Text(this.resultRowValue(row))
          .fontSize(13)
          .fontColor(AppColor.textPrimary)
          .layoutWeight(1)
          .maxLines(4)
      }
    }
    .width('100%')
    .margin({ top: AppSpacing.xs })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  runtimeActionToolbar(showActions: boolean) {
    Row() {
      Row() {
        Image($r('app.media.icon_back'))
          .width(11)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())
      Text(appString(this.titleKey))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
      if (showActions && this.helpContentKey !== undefined) {
        Row() {
          Image($r('app.media.icon_help'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ left: AppSpacing.xs })
          .onClick(() => this.showLocalHelpDialog())
      }
      if (showActions && this.helpUrl.length > 0) {
        Row() {
          Image($r('app.media.icon_more'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ left: AppSpacing.xs })
          .onClick(() => this.openHelpPage())
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.page, right: AppSpacing.page })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  @Builder
  runtimePermissionRecoveryOverlay() {
    if (this.shouldShowRuntimePermissionRetry()) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Text(appString(this.statusKey))
            .fontSize(14)
            .fontColor(AppColor.textPrimary)
            .textAlign(TextAlign.Center)
          Button(appString('splash_permission_retry'))
            .height(36)
            .margin({ top: AppSpacing.sm })
            .onClick(() => this.retryRuntimePermission())
          Button(appString('app_permission_by_hand'))
            .height(36)
            .margin({ top: AppSpacing.sm })
            .onClick(() => this.openRuntimePermissionSettings())
        }
        .padding(AppSpacing.md)
        .backgroundColor('#E6FFFFFF')
        .borderRadius(AppRadius.card)
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  portraitSegmentationToolbar() {
    Row() {
      Row() {
        Image($r('app.media.icon_back'))
          .width(11)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())
      Text(appString(this.titleKey))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
      if (this.liveCameraSwitchAvailable) {
        Row() {
          Image($r('app.media.icon_camera'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.switchLiveCamera())
      }
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        buttonType: ButtonType.Normal
      })
        .width(40)
        .height(40)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveResultComponentImage(segmentationBackgroundReplacementComponentId);
            return;
          }
          this.statusKey = 'feature_runtime_save_image_failed';
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.page, right: AppSpacing.page })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  @Builder
  portraitSegmentationComposite() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(this.backgroundImageUri)
        .orientation(this.segmentationBackgroundImageOrientation)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
      if (this.segmentationForegroundPixelMap !== undefined) {
        Image(this.segmentationForegroundPixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
          .scale({ x: this.segmentationForegroundMirrorScaleX(), y: 1 })
      }
    }
    .width('100%')
    .height('100%')
    .id(segmentationBackgroundReplacementComponentId)
  }

  @Builder
  portraitSegmentationBackgroundStrip() {
    Column() {
      Divider()
        .strokeWidth(5)
        .color(AppColor.divider)
        .width('100%')
      List({ space: 0 }) {
        ForEach(portraitSegmentationBackgroundPresets, (preset: PortraitSegmentationBackgroundPreset) => {
          ListItem() {
            Image(portraitSegmentationBackgroundUri(preset))
              .width(95)
              .height(120)
              .objectFit(ImageFit.Fill)
              .onClick(() => this.selectPortraitBackgroundPreset(preset))
          }
        }, (preset: PortraitSegmentationBackgroundPreset) => preset.id)
        ListItem() {
          Image($r('app.media.icon_default'))
            .width(95)
            .height(120)
            .objectFit(ImageFit.Fill)
            .onClick(() => this.prepareInput('backgroundImage'))
        }
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(100)
      .clip(true)
    }
    .width('100%')
    .height(105)
    .backgroundColor(AppColor.divider)
  }

  @Builder
  portraitSegmentationAndroidLayout() {
    Column() {
      this.portraitSegmentationToolbar()
      Stack({ alignContent: Alignment.TopStart }) {
        this.liveCameraSurfaceContent()
        this.portraitSegmentationComposite()
        Column() {
          this.portraitSegmentationBackgroundStrip()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        this.runtimePermissionRecoveryOverlay()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#111827')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  simpleAndroidLiveLayout() {
    Column() {
      this.runtimeActionToolbar(false)
      Stack({ alignContent: Alignment.TopStart }) {
        this.liveCameraSurfaceContent()
        if (this.liveCameraSwitchAvailable) {
          Column() {
            Image($r('app.media.front_back_switch'))
              .width(35)
              .height(35)
              .objectFit(ImageFit.Contain)
              .margin({ bottom: 30 })
              .onClick(() => this.switchLiveCamera())
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }
        this.runtimePermissionRecoveryOverlay()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#111827')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  imageClassificationAndroidLiveLayout() {
    Column() {
      this.runtimeActionToolbar(true)
      Stack({ alignContent: Alignment.TopStart }) {
        this.liveCameraSurfaceContent()
        Column() {
          Column() {
            Text(this.liveClassificationOverlayValue())
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 6 })
            Divider()
              .strokeWidth(0.5)
              .color('#E6E6E6')
              .width('100%')
              .margin({ top: 10 })
          }
          .width('100%')
          .height(100)
          .padding({ left: 15, right: 15 })
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(Color.White)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        this.runtimePermissionRecoveryOverlay()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#111827')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  objectDetectionAndroidLiveLayout() {
    Column() {
      this.runtimeActionToolbar(true)
      Stack({ alignContent: Alignment.TopStart }) {
        this.liveCameraSurfaceContent()
        Column() {
          Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile')))
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#33B5E5')
            .onClick(() => this.prepareInput('modelFile'))
        }
        .width('100%')
        .height('100%')
        .padding({ right: 16, bottom: 16 })
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.End)
        this.runtimePermissionRecoveryOverlay()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#111827')
      .onAreaChange((_previousArea: Area, currentArea: Area) => {
        const height = Number(currentArea.height);
        this.liveObjectDetectionOverlayHeightVp = Number.isFinite(height) && height > 0 ? height : 0;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  textRecognitionAndroidLayout() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.runtimeActionToolbar(false)
        Row() {
        }
        .width('100%')
        .height(1)
        .backgroundColor('#DBDBDB')
        Stack({ alignContent: Alignment.Center }) {
          if (this.imageInputUri.length > 0) {
            Image(this.imageInputUri)
              .width('100%')
              .height('100%')
              .padding(10)
              .objectFit(ImageFit.Contain)
          } else {
            Column() {
              Image($r('app.media.icon_style'))
                .width(69.33)
                .height(56.33)
                .objectFit(ImageFit.Contain)
              Text(appString('workflow_summary_text_recognition_android_prompt'))
                .fontSize(16)
                .fontColor('#666666')
                .textAlign(TextAlign.Center)
                .margin({ top: 10 })
            }
            .alignItems(HorizontalAlign.Center)
          }
          if (this.workflowRunning) {
            LoadingProgress()
              .width(80)
              .height(80)
          }
        }
        .width('100%')
        .layoutWeight(5)
        .backgroundColor('#E6E6E6')
        Row() {
          Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .onClick(() => this.prepareInput('photo'))
          Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .margin({ left: 10 })
            .onClick(() => this.prepareInput('camera'))
        }
        .width('100%')
        .height(50)
        .margin({ left: 10, right: 10, top: 14, bottom: 10 })
        .alignItems(VerticalAlign.Center)
        Scroll() {
          Text(this.recognizedTextForCopy())
            .width('100%')
            .fontSize(14)
            .fontColor('#000000')
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .layoutWeight(3)
        .padding({ left: 24, right: 24 })
        .scrollBar(BarState.Auto)
        .backgroundColor('#E6E6E6')
        Button(appString('feature_runtime_copy_text'), { type: ButtonType.Normal })
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontWeight(FontWeight.Normal)
          .fontColor('#000000')
          .backgroundColor(Color.White)
          .borderRadius(10)
          .onClick(() => this.copyRecognizedText())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
      this.runtimePermissionRecoveryOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  build() {
    if (usesAndroidTextRecognitionLayout(workflowForRoute(this.routeName))) {
      this.textRecognitionAndroidLayout()
    } else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {
      this.portraitSegmentationAndroidLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'imageClassification') {
      this.imageClassificationAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'objectDetection') {
      this.objectDetectionAndroidLiveLayout()
    } else if (usesSimpleAndroidLiveLayout(workflowForRoute(this.routeName))) {
      this.simpleAndroidLiveLayout()
    } else {
      Scroll() {
      Column() {
        Row() {
          Row() {
            Image($r('app.media.icon_back'))
              .width(11)
              .height(22)
              .objectFit(ImageFit.Contain)
          }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .onClick(() => router.back())
          Text(appString(this.titleKey))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .layoutWeight(1)
            .maxLines(1)
          if (this.helpContentKey !== undefined) {
            Row() {
              Image($r('app.media.icon_help'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)
            }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ left: AppSpacing.xs })
              .onClick(() => this.showLocalHelpDialog())
          }
          if (this.helpUrl.length > 0) {
            Row() {
              Image($r('app.media.icon_more'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)
            }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ left: AppSpacing.xs })
              .onClick(() => this.openHelpPage())
          }
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)

        Column() {
          Text(appString(this.summaryKey))
            .fontSize(15)
            .fontColor(AppColor.textPrimary)
            .lineHeight(22)
        }
        .width('100%')
        .padding(AppSpacing.md)
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })

        Column() {
          if (this.visibleInputKinds().length > 0) {
        Column() {
          Text(appString('feature_runtime_inputs_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.visibleInputKinds(), (inputKind: FeatureInputKind) => {
              this.inputChip(inputKind)
            }, (inputKind: FeatureInputKind) => inputKind)
          }
          .width('100%')
          .margin({ top: AppSpacing.md })
        }
        .width('100%')
          }
          if (this.hasLinkedLiveRoute()) {
            Button(appString(workflowGoLiveLabelKey(workflowForRoute(this.routeName))))
              .height(34)
              .margin({ top: AppSpacing.xs })
              .onClick(() => this.openLinkedLiveRoute())
          }
          if (this.isStyleTransferWorkflow()) {
            this.styleTransferStyleGrid()
          }
          if (this.isPortraitSegmentationWorkflow()) {
            this.portraitSegmentationBackgroundGrid()
          }
          if (shouldRenderLiveCameraPreview(
            workflowForRoute(this.routeName),
            this.liveCameraActive
          )) {
            this.liveCameraPreview()
          }
          if (this.inputKinds.indexOf('text') >= 0 && this.textInputVisible) {
            if (this.longTextInput) {
              TextArea({ text: this.userText, placeholder: appString(this.textInputPlaceholderKey()) })
                .width('100%')
                .height(132)
                .fontSize(14)
                .margin({ top: AppSpacing.sm })
                .onChange((value: string) => this.updateUserText(value))
            } else {
              TextInput({ text: this.userText, placeholder: appString(this.textInputPlaceholderKey()) })
                .width('100%')
                .height(44)
                .fontSize(14)
                .margin({ top: AppSpacing.sm })
                .onChange((value: string) => this.updateUserText(value))
            }
          }
          if (this.hasInputPreview()) {
            Column() {
              Text(appString('feature_runtime_preview_title'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.textPrimary)
                .width('100%')
              if (this.imageInputUri.length > 0 && shouldShowPrimaryImageInputPreview(
                workflowForRoute(this.routeName),
                this.primaryOverlayReady()
              )) {
                this.imagePreview('feature_runtime_preview_image', this.imageInputUri)
              }
              if (this.contentImageUri.length > 0) {
                this.imagePreview('feature_runtime_preview_content', this.contentImageUri)
              }
              if (this.styleImageUri.length > 0) {
                this.imagePreview('feature_runtime_preview_style', this.styleImageUri)
              }
              if (this.backgroundImageUri.length > 0) {
                this.imagePreview('feature_runtime_preview_background', this.backgroundImageUri)
              }
              if (this.stylePredictModelInputUri.length > 0) {
                this.filePreview('feature_input_style_predict_model_file', this.stylePredictModelInputUri)
              }
              if (this.styleTransferModelInputUri.length > 0) {
                this.filePreview('feature_input_style_transfer_model_file', this.styleTransferModelInputUri)
              }
              if (this.modelInputUri.length > 0) {
                this.filePreview('feature_runtime_preview_model', this.modelInputUri)
              }
            }
            .width('100%')
            .margin({ top: AppSpacing.md })
          }
        }
        .width('100%')
        .padding(AppSpacing.md)
        .margin({ top: AppSpacing.md })
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })

        Column() {
          Text(appString('feature_runtime_permissions_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.permissionKinds, (permissionKind: FeaturePermissionKind) => {
              this.permissionChip(permissionKind)
            }, (permissionKind: FeaturePermissionKind) => permissionKind)
          }
          .width('100%')
          .margin({ top: AppSpacing.md })
        }
        .width('100%')
        .padding(AppSpacing.md)
        .margin({ top: AppSpacing.md })
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })

        if (shouldShowPrimaryRunAction(workflowForRoute(this.routeName))) {
          Button(appString(this.runActionKey))
            .width('100%')
            .height(44)
            .margin({ top: AppSpacing.lg })
            .enabled(this.runActionEnabled())
            .onClick(() => this.runPrimaryAction())
        }

        Column() {
          Text(appString(workflowResultTitleKey(workflowForRoute(this.routeName))))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .width('100%')
          Text(appString(this.statusKey))
            .fontSize(14)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.sm })
            .width('100%')
          if (this.shouldShowRuntimePermissionRetry()) {
            Button(appString('splash_permission_retry'))
              .height(36)
              .margin({ top: AppSpacing.sm })
              .onClick(() => this.retryRuntimePermission())
            Button(appString('app_permission_by_hand'))
              .height(36)
              .margin({ top: AppSpacing.sm })
              .onClick(() => this.openRuntimePermissionSettings())
          }
          if (this.resultRows.length > 0) {
            ForEach(this.resultRows, (row: AiRunResultRow) => {
              this.resultRow(row)
            }, (row: AiRunResultRow) => row.labelKey)
          }
          if (this.styledImagePixelMap !== undefined && shouldShowStyleTransferStyledPreview(
            true,
            this.styleOriginalPreviewRecovered
          )) {
            this.pixelMapPreview('feature_runtime_result_styled_image', this.styledImagePixelMap)
          }
          if (shouldShowResultSaveAction(workflowForRoute(this.routeName), this.styledImagePixelMap !== undefined) &&
            this.aiMethod === 'runStyleTransfer') {
            this.resultImageSaveControl(this.styledImagePixelMap)
          }
          if (shouldShowStyleRecoveryControl(this.aiMethod, this.styledImagePixelMap !== undefined)) {
            this.styleRecoveryControl()
          }
          if (this.objectDetectionImageUri.length > 0 && this.objectDetections.length > 0) {
            this.objectDetectionPreview('feature_runtime_result_detection_overlay', this.objectDetectionImageUri)
          }
          if (this.gestureImageUri.length > 0 && this.visibleGestureDetections().length > 0) {
            this.gesturePreview('feature_runtime_result_gesture_overlay', this.gestureImageUri)
          }
          if (this.segmentationForegroundPixelMap !== undefined &&
            shouldShowStandaloneSegmentationForegroundPreview(workflowForRoute(this.routeName))) {
            this.pixelMapPreview('feature_runtime_result_foreground', this.segmentationForegroundPixelMap)
          }
          if (shouldShowResultSaveAction(workflowForRoute(this.routeName),
            this.segmentationForegroundPixelMap !== undefined) &&
            this.aiMethod === 'segmentPerson') {
            this.resultImageSaveControl(this.segmentationForegroundPixelMap)
          }
          if (this.shouldShowSegmentationBackgroundPreview() && this.segmentationForegroundPixelMap !== undefined) {
            this.segmentationBackgroundReplacementPreview(this.segmentationForegroundPixelMap)
            if (shouldShowCompositeSegmentationSaveAction(workflowForRoute(this.routeName))) {
              this.resultComponentImageSaveControl(segmentationBackgroundReplacementComponentId)
            }
          }
          if (this.segmentationImageUri.length > 0 && this.segmentationRectangles.length > 0 &&
            shouldShowStandaloneSegmentationOverlayPreview(workflowForRoute(this.routeName))) {
            this.segmentationPreview('feature_runtime_result_segmentation_overlay', this.segmentationImageUri)
          }
          if (this.poseImageUri.length > 0 && this.posePoints.length > 0) {
            this.posePreview('feature_runtime_result_pose_overlay', this.poseImageUri)
            if (this.shouldShowPoseTemplate()) {
              this.poseTemplatePreview()
            }
          }
          if (shouldShowCopyTextAction(this.aiMethod)) {
            Button(appString('feature_runtime_copy_text'))
              .height(36)
              .margin({ top: AppSpacing.md })
              .onClick(() => this.copyRecognizedText())
          }
          if (this.resultText.length > 0) {
            Text(this.resultText)
              .fontSize(12)
              .fontColor(AppColor.textMuted)
              .margin({ top: AppSpacing.sm })
              .width('100%')
          }
        }
        .width('100%')
        .padding(AppSpacing.md)
        .margin({ top: AppSpacing.md })
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      }
      .width('100%')
      .padding(AppSpacing.page)
    }
    .scrollBar(BarState.Off)
      .backgroundColor(AppColor.pageBackground)
    }
  }
}
