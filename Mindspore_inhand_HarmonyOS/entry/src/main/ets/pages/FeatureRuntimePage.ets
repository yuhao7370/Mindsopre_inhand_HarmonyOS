import router from '@ohos.router';
import {
  FeatureInputKind,
  FeaturePermissionKind,
  FeatureWorkflow,
  inputLabelKey,
  permissionLabelKey,
  workflowForRoute
} from '../features/runtime/FeatureWorkflowCatalog';
import {
  AiRunInputs,
  AiRunResult,
  AiRunResultRow,
  DefaultAiService,
  aiRunResultRows,
  copyableTextForAiResult
} from '../services/ai/AiService';
import { cachedRuntimeAiServiceForHarmonyResourceManager } from '../services/ai/ImageClassificationRuntimeFactory';
import { PermissionRequestSummary, PermissionService } from '../services/permissions/PermissionService';
import { ClipboardService, CopyTextResult } from '../services/clipboard/ClipboardService';
import { PickerService, PickResult, runtimeInputActionForWorkflowInput } from '../services/picker/PickerService';
import {
  HarmonyLiveCameraPreviewDriver,
  HarmonyLiveFrameImageEncoder,
  HarmonyLiveFrameImageStore,
  LiveCameraPreviewResult,
  LiveCameraPreviewService,
  LiveFrameImageResult,
  LiveFrameImageService,
  LiveRuntimeFrameRunner,
  LiveRuntimeLoopService,
  liveImageClassificationIntervalMs,
  liveCameraXComponentId,
  shouldRunLiveImageClassificationLoop,
  shouldCaptureLiveFrameImage
} from '../services/camera/LiveCameraService';
import {
  ObjectDetection,
  ObjectDetectionBoxPercent,
  objectDetectionBoxPercent
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
  BuiltInStyleTransferStyle,
  builtInStyleTransferStyles,
  builtInStyleTransferUri,
  styleTransferPixelMapFromRgbaOutput
} from '../services/ai/StyleTransferService';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { webPagePath } from '../common/data/WebDestination';

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

@Entry
@Component
struct FeatureRuntimePage {
  @State titleKey: AppStringKey = 'feature_stub_title';
  @State summaryKey: AppStringKey = 'feature_runtime_status_idle';
  @State statusKey: AppStringKey = 'feature_runtime_status_idle';
  @State routeName: string = '';
  @State aiMethod: string = '';
  @State resultText: string = '';
  @State resultRows: Array<AiRunResultRow> = [];
  @State selectedInputSummary: string = '';
  @State imageInputUri: string = '';
  @State contentImageUri: string = '';
  @State styleImageUri: string = '';
  @State stylePredictModelInputUri: string = '';
  @State styleTransferModelInputUri: string = '';
  @State modelInputUri: string = '';
  @State userText: string = '';
  @State styledImagePixelMap: image.PixelMap | undefined = undefined;
  @State objectDetectionImageUri: string = '';
  @State objectDetections: Array<ObjectDetection> = [];
  @State objectDetectionImageWidth: number = 0;
  @State objectDetectionImageHeight: number = 0;
  @State segmentationImageUri: string = '';
  @State segmentationForegroundPixelMap: image.PixelMap | undefined = undefined;
  @State segmentationRectangles: Array<SegmentationRectangle> = [];
  @State segmentationImageWidth: number = 0;
  @State segmentationImageHeight: number = 0;
  @State poseImageUri: string = '';
  @State posePoints: Array<PosePoint> = [];
  @State poseImageWidth: number = 0;
  @State poseImageHeight: number = 0;
  @State helpUrl: string = '';
  @State inputKinds: Array<FeatureInputKind> = [];
  @State permissionKinds: Array<FeaturePermissionKind> = [];
  @State liveCameraSurfaceId: string = '';
  @State liveCameraActive: boolean = false;
  private liveCameraController: XComponentController = new XComponentController();
  private liveCameraService: LiveCameraPreviewService | undefined = undefined;
  private liveCameraInputSelected: boolean = false;
  private liveRuntimeLoopService: LiveRuntimeLoopService = new LiveRuntimeLoopService();

  aboutToAppear() {
    const params = router.getParams() as FeatureRuntimeParams;
    this.routeName = params?.routeName ?? '';
    const workflow = workflowForRoute(this.routeName);
    this.titleKey = params?.titleKey ?? workflow?.titleKey ?? this.titleKey;
    this.summaryKey = workflow?.summaryKey ?? this.summaryKey;
    this.aiMethod = workflow?.aiMethod ?? '';
    this.helpUrl = workflow?.helpUrl ?? '';
    this.inputKinds = workflow?.inputKinds ?? [];
    this.permissionKinds = workflow?.requiredPermissions ?? [];
  }

  aboutToDisappear() {
    this.stopLiveCameraPreview();
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private prepareInput(inputKind: FeatureInputKind): void {
    this.statusKey = 'feature_runtime_status_preparing';
    this.resultRows = [];
    this.resultText = '';
    this.clearVisualResults();
    const liveCameraInput = this.isLiveCameraInput(inputKind);
    this.liveCameraInputSelected = liveCameraInput;
    if (!liveCameraInput) {
      this.stopLiveRuntimeLoop();
    }
    if (inputKind === 'text') {
      this.statusKey = this.userText.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
      this.selectedInputSummary = this.userText;
      return;
    }
    if (liveCameraInput) {
      this.startLiveCameraPreview();
      return;
    }
    const context = this.uiAbilityContext();
    if (!context) {
      this.statusKey = 'feature_runtime_pick_cancelled';
      return;
    }
    const pickerService = new PickerService(context);
    if (inputKind === 'modelFile' ||
      inputKind === 'stylePredictModelFile' ||
      inputKind === 'styleTransferModelFile') {
      pickerService.pickModelFile().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_model_ready', inputKind));
      return;
    }
    if (inputKind === 'camera') {
      pickerService.captureImage().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_image_ready', inputKind));
      return;
    }
    pickerService.pickImage().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_image_ready', inputKind));
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
    return workflow.inputKinds.some((inputKind: FeatureInputKind) =>
      runtimeInputActionForWorkflowInput(workflow, inputKind) === 'startLiveCamera');
  }

  private startLiveCameraPreview(): void {
    this.startLiveCameraPreviewAsync();
  }

  private async startLiveCameraPreviewAsync(): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    const context = this.uiAbilityContext();
    if (!workflow || !context) {
      this.applyLiveCameraPreviewResult({
        ok: false,
        surfaceId: '',
        messageKey: 'feature_runtime_permission_denied'
      });
      return;
    }

    this.statusKey = 'feature_runtime_status_preparing';
    this.resultRows = [];
    this.resultText = '';
    this.clearVisualResults();
    try {
      const permission = await new PermissionService().requestForWorkflow(context, workflow);
      if (!permission.ok) {
        this.applyLiveCameraPreviewResult({
          ok: false,
          surfaceId: '',
          messageKey: 'feature_runtime_permission_denied'
        });
        this.resultText = permission.requested.join(', ');
        return;
      }

      const surfaceId = this.liveCameraSurfaceId.length > 0 ?
        this.liveCameraSurfaceId :
        this.liveCameraController.getXComponentSurfaceId();
      this.liveCameraService = new LiveCameraPreviewService(new HarmonyLiveCameraPreviewDriver(context));
      const result = await this.liveCameraService.start(surfaceId);
      this.applyLiveCameraPreviewResult(result);
    } catch (_) {
      this.applyLiveCameraPreviewResult({
        ok: false,
        surfaceId: '',
        messageKey: 'feature_runtime_live_camera_failed'
      });
    }
  }

  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {
    this.statusKey = result.messageKey;
    this.liveCameraActive = result.ok;
    this.liveCameraSurfaceId = result.surfaceId;
    this.selectedInputSummary = result.surfaceId;
    if (!result.ok) {
      this.liveCameraInputSelected = false;
      this.stopLiveRuntimeLoop();
    }
  }

  private stopLiveCameraPreview(): void {
    this.stopLiveRuntimeLoop();
    this.liveCameraInputSelected = false;
    this.liveCameraActive = false;
    const service = this.liveCameraService;
    this.liveCameraService = undefined;
    if (service !== undefined) {
      service.stop();
    }
  }

  private applyPickResult(result: PickResult, readyKey: AppStringKey, inputKind: FeatureInputKind): void {
    if (!result.ok) {
      this.statusKey = 'feature_runtime_pick_cancelled';
      this.selectedInputSummary = '';
      if (inputKind === 'modelFile') {
        this.modelInputUri = '';
      } else if (inputKind === 'stylePredictModelFile') {
        this.stylePredictModelInputUri = '';
      } else if (inputKind === 'styleTransferModelFile') {
        this.styleTransferModelInputUri = '';
      } else if (inputKind === 'contentImage') {
        this.contentImageUri = '';
      } else if (inputKind === 'styleImage') {
        this.styleImageUri = '';
      } else {
        this.imageInputUri = '';
      }
      return;
    }
    this.statusKey = readyKey;
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
    } else {
      this.imageInputUri = result.uri;
    }
  }

  private aiRunInputs(): AiRunInputs {
    const contentImageUri = this.contentImageUri.length > 0 ? this.contentImageUri : this.imageInputUri;
    return {
      imageUri: this.imageInputUri,
      contentImageUri: contentImageUri,
      styleImageUri: this.styleImageUri,
      stylePredictModelUri: this.stylePredictModelInputUri,
      styleTransferModelUri: this.styleTransferModelInputUri,
      modelUri: this.modelInputUri,
      text: this.userText
    };
  }

  private runWorkflow(): void {
    if (shouldRunLiveImageClassificationLoop(this.aiMethod, this.liveCameraInputSelected, this.liveCameraActive)) {
      this.startLiveRuntimeLoop();
      return;
    }
    this.stopLiveRuntimeLoop();
    this.runWorkflowAsync();
  }

  private startLiveRuntimeLoop(): void {
    const runner = new PageLiveRuntimeFrameRunner(async (): Promise<void> => {
      await this.runWorkflowAsync();
    });
    this.liveRuntimeLoopService.start(liveImageClassificationIntervalMs, runner);
  }

  private stopLiveRuntimeLoop(): void {
    this.liveRuntimeLoopService.stop();
  }

  private async runWorkflowAsync(): Promise<void> {
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
    this.resultText = '';
    this.resultRows = [];
    this.clearVisualResults();
    try {
      const permission: PermissionRequestSummary = await new PermissionService().requestForWorkflow(context, workflow);
      if (!permission.ok) {
        this.statusKey = 'feature_runtime_permission_denied';
        this.resultText = permission.requested.join(', ');
        this.resultRows = [];
        this.clearVisualResults();
        return;
      }
      const frameInputReady = await this.prepareLiveFrameImageInput(context);
      if (!frameInputReady) {
        return;
      }
      const aiService: DefaultAiService =
        await cachedRuntimeAiServiceForHarmonyResourceManager(workflow, context.resourceManager);
      const result: AiRunResult = await aiService.run(workflow, this.aiRunInputs());
      this.applyAiResult(result);
    } catch (_) {
      this.applyRuntimeFailure();
    }
  }

  private applyRuntimeFailure(): void {
    this.statusKey = 'feature_runtime_run_failed';
    this.resultText = this.aiMethod;
    this.resultRows = [];
    this.clearVisualResults();
  }

  private async prepareLiveFrameImageInput(context: common.UIAbilityContext): Promise<boolean> {
    if (!shouldCaptureLiveFrameImage(this.liveCameraInputSelected, this.imageInputUri, this.liveCameraActive)) {
      return true;
    }

    if (!this.liveCameraActive) {
      await this.startLiveCameraPreviewAsync();
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

  private applyAiResult(result: AiRunResult): void {
    this.statusKey = result.messageKey;
    this.resultText = result.detailText.length > 0 ? result.detailText : `${result.aiMethod}: ${result.code}`;
    this.resultRows = aiRunResultRows(result);
    this.clearVisualResults();
    this.updateObjectDetectionPreview(result);
    this.updateSegmentationPreview(result);
    this.updatePosePreview(result);
    this.updateStyledImagePreview(result);
  }

  private clearVisualResults(): void {
    this.styledImagePixelMap = undefined;
    this.objectDetectionImageUri = '';
    this.objectDetections = [];
    this.objectDetectionImageWidth = 0;
    this.objectDetectionImageHeight = 0;
    this.segmentationImageUri = '';
    this.segmentationForegroundPixelMap = undefined;
    this.segmentationRectangles = [];
    this.segmentationImageWidth = 0;
    this.segmentationImageHeight = 0;
    this.poseImageUri = '';
    this.posePoints = [];
    this.poseImageWidth = 0;
    this.poseImageHeight = 0;
  }

  private updateObjectDetectionPreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'objectDetections' || data.detections.length === 0) {
      return;
    }

    this.objectDetectionImageUri = data.imageUri;
    this.objectDetections = data.detections;
    this.objectDetectionImageWidth = this.objectDetectionSourceWidth(data.detections);
    this.objectDetectionImageHeight = this.objectDetectionSourceHeight(data.detections);
  }

  private updateSegmentationPreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'segmentation' || data.result.rectangles.length === 0) {
      return;
    }

    this.segmentationImageUri = data.imageUri;
    this.segmentationRectangles = data.result.rectangles;
    this.segmentationImageWidth = data.result.imageWidth ?? this.segmentationSourceWidth(data.result.rectangles);
    this.segmentationImageHeight = data.result.imageHeight ?? this.segmentationSourceHeight(data.result.rectangles);
    this.updateSegmentationForegroundPreview(data.result);
  }

  private updateSegmentationForegroundPreview(result: SegmentationResult): void {
    const rgba = result.foregroundImageRgba;
    const width = result.foregroundImageWidth ?? 0;
    const height = result.foregroundImageHeight ?? 0;
    if (rgba === undefined || rgba.byteLength === 0 || width <= 0 || height <= 0) {
      return;
    }

    styleTransferPixelMapFromRgbaOutput(rgba, width, height).then((pixelMap: image.PixelMap) => {
      this.segmentationForegroundPixelMap = pixelMap;
    }).catch(() => {
      this.segmentationForegroundPixelMap = undefined;
    });
  }

  private updatePosePreview(result: AiRunResult): void {
    const data = result.data;
    if (data === undefined || data.kind !== 'pose' || data.result.points.length === 0) {
      return;
    }

    this.poseImageUri = data.imageUri;
    this.posePoints = data.result.points;
    this.poseImageWidth = data.result.imageWidth ?? this.poseSourceWidth(data.result.points);
    this.poseImageHeight = data.result.imageHeight ?? this.poseSourceHeight(data.result.points);
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

  private updateStyledImagePreview(result: AiRunResult): void {
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

    styleTransferPixelMapFromRgbaOutput(rgba, width, height).then((pixelMap: image.PixelMap) => {
      this.styledImagePixelMap = pixelMap;
    }).catch(() => {
      this.styledImagePixelMap = undefined;
    });
  }

  private openHelpPage(): void {
    if (this.helpUrl.length === 0) {
      return;
    }
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: this.titleKey,
        url: this.helpUrl
      }
    });
  }

  private hasInputPreview(): boolean {
    return this.imageInputUri.length > 0 ||
      this.contentImageUri.length > 0 ||
      this.styleImageUri.length > 0 ||
      this.stylePredictModelInputUri.length > 0 ||
      this.styleTransferModelInputUri.length > 0 ||
      this.modelInputUri.length > 0;
  }

  private isStyleTransferWorkflow(): boolean {
    return this.aiMethod === 'runStyleTransfer';
  }

  private selectBuiltInStyle(style: BuiltInStyleTransferStyle): void {
    this.styleImageUri = builtInStyleTransferUri(style);
    this.selectedInputSummary = style.rawfilePath;
    this.statusKey = 'feature_runtime_image_ready';
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

  @Builder
  inputChip(inputKind: FeatureInputKind) {
    Text(appString(inputLabelKey(inputKind)))
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
      this.styleTransferStyleImage(style.id)
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
  styleTransferStyleImage(styleId: number) {
    if (styleId === 0) {
      this.styleTransferStyleImageSource($r('app.media.style0'))
    } else if (styleId === 1) {
      this.styleTransferStyleImageSource($r('app.media.style1'))
    } else if (styleId === 2) {
      this.styleTransferStyleImageSource($r('app.media.style2'))
    } else if (styleId === 3) {
      this.styleTransferStyleImageSource($r('app.media.style3'))
    } else if (styleId === 4) {
      this.styleTransferStyleImageSource($r('app.media.style4'))
    } else if (styleId === 5) {
      this.styleTransferStyleImageSource($r('app.media.style5'))
    } else if (styleId === 6) {
      this.styleTransferStyleImageSource($r('app.media.style6'))
    } else if (styleId === 7) {
      this.styleTransferStyleImageSource($r('app.media.style7'))
    } else if (styleId === 8) {
      this.styleTransferStyleImageSource($r('app.media.style8'))
    } else if (styleId === 9) {
      this.styleTransferStyleImageSource($r('app.media.style9'))
    } else if (styleId === 10) {
      this.styleTransferStyleImageSource($r('app.media.style10'))
    } else if (styleId === 11) {
      this.styleTransferStyleImageSource($r('app.media.style11'))
    } else if (styleId === 12) {
      this.styleTransferStyleImageSource($r('app.media.style12'))
    } else if (styleId === 13) {
      this.styleTransferStyleImageSource($r('app.media.style13'))
    } else if (styleId === 14) {
      this.styleTransferStyleImageSource($r('app.media.style14'))
    } else if (styleId === 15) {
      this.styleTransferStyleImageSource($r('app.media.style15'))
    } else if (styleId === 16) {
      this.styleTransferStyleImageSource($r('app.media.style16'))
    } else if (styleId === 17) {
      this.styleTransferStyleImageSource($r('app.media.style17'))
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
  liveCameraPreview() {
    Column() {
      Text(appString('feature_runtime_preview_image'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      XComponent({
        id: liveCameraXComponentId,
        type: XComponentType.SURFACE,
        controller: this.liveCameraController
      })
        .width('100%')
        .height(260)
        .backgroundColor('#111827')
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .clip(true)
        .margin({ top: AppSpacing.xs })
        .onLoad(() => {
          this.liveCameraSurfaceId = this.liveCameraController.getXComponentSurfaceId();
        })
        .onDestroy(() => this.stopLiveCameraPreview())
    }
    .width('100%')
    .margin({ top: AppSpacing.md })
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

  private objectDetectionLabel(detection: ObjectDetection): string {
    const label = detection.label.length > 0 ? detection.label : `${detection.labelId}`;
    return `${label} ${(detection.score * 100).toFixed(1)}%`;
  }

  private objectDetectionBoxStyle(detection: ObjectDetection): ObjectDetectionBoxPercent {
    return objectDetectionBoxPercent(
      detection,
      this.objectDetectionImageWidth,
      this.objectDetectionImageHeight
    );
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

  private poseLineStyle(line: PoseLine): PoseLinePercent {
    return poseLinePercent(
      line,
      this.poseImageWidth,
      this.poseImageHeight
    );
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

  @Builder
  posePreview(labelKey: AppStringKey, uri: string) {
    Column() {
      Text(appString(labelKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack({ alignContent: Alignment.TopStart }) {
        Image(uri)
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
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
        ForEach(this.objectDetections, (detection: ObjectDetection) => {
          this.objectDetectionBox(detection)
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
  objectDetectionBox(detection: ObjectDetection) {
    Column() {
      Text(this.objectDetectionLabel(detection))
        .fontSize(10)
        .fontColor('#FFFFFF')
        .backgroundColor(AppColor.accent)
        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
        .maxLines(1)
    }
    .width(this.percentLength(this.objectDetectionBoxStyle(detection).width))
    .height(this.percentLength(this.objectDetectionBoxStyle(detection).height))
    .border({ width: 2, color: AppColor.accent, radius: 2 })
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
      Text(row.value)
        .fontSize(13)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(4)
    }
    .width('100%')
    .margin({ top: AppSpacing.xs })
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('<')
            .fontSize(18)
            .fontColor(AppColor.textSecondary)
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick(() => router.back())
          Text(appString(this.titleKey))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .layoutWeight(1)
            .maxLines(1)
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)

        Column() {
          Text(appString(this.summaryKey))
            .fontSize(15)
            .fontColor(AppColor.textPrimary)
            .lineHeight(22)
          Text(this.aiMethod)
            .fontSize(12)
            .fontColor(AppColor.textMuted)
            .margin({ top: AppSpacing.sm })
          if (this.helpUrl.length > 0) {
            Button(appString('title_source'))
              .height(32)
              .margin({ top: AppSpacing.md })
              .onClick(() => this.openHelpPage())
          }
        }
        .width('100%')
        .padding(AppSpacing.md)
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })

        Column() {
          Text(appString('feature_runtime_inputs_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.inputKinds, (inputKind: FeatureInputKind) => {
              this.inputChip(inputKind)
            }, (inputKind: FeatureInputKind) => inputKind)
          }
          .width('100%')
          .margin({ top: AppSpacing.md })
          if (this.isStyleTransferWorkflow()) {
            this.styleTransferStyleGrid()
          }
          if (this.hasLiveCameraInput()) {
            this.liveCameraPreview()
          }
          if (this.inputKinds.indexOf('text') >= 0) {
            TextInput({ text: this.userText, placeholder: appString('feature_runtime_text_placeholder') })
              .width('100%')
              .height(44)
              .fontSize(14)
              .margin({ top: AppSpacing.sm })
              .onChange((value: string) => {
                this.userText = value;
                this.selectedInputSummary = value;
                this.statusKey = value.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
              })
          }
          if (this.hasInputPreview()) {
            Column() {
              Text(appString('feature_runtime_preview_title'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.textPrimary)
                .width('100%')
              if (this.imageInputUri.length > 0) {
                this.imagePreview('feature_runtime_preview_image', this.imageInputUri)
              }
              if (this.contentImageUri.length > 0) {
                this.imagePreview('feature_runtime_preview_content', this.contentImageUri)
              }
              if (this.styleImageUri.length > 0) {
                this.imagePreview('feature_runtime_preview_style', this.styleImageUri)
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

        Button(appString('feature_runtime_run'))
          .width('100%')
          .height(44)
          .margin({ top: AppSpacing.lg })
          .onClick(() => this.runWorkflow())

        Column() {
          Text(appString('feature_runtime_result_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .width('100%')
          Text(appString(this.statusKey))
            .fontSize(14)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.sm })
            .width('100%')
          if (this.resultRows.length > 0) {
            ForEach(this.resultRows, (row: AiRunResultRow) => {
              this.resultRow(row)
            }, (row: AiRunResultRow) => row.labelKey)
          }
          if (this.styledImagePixelMap !== undefined) {
            this.pixelMapPreview('feature_runtime_result_styled_image', this.styledImagePixelMap)
          }
          if (this.objectDetectionImageUri.length > 0 && this.objectDetections.length > 0) {
            this.objectDetectionPreview('feature_runtime_result_detection_overlay', this.objectDetectionImageUri)
          }
          if (this.segmentationForegroundPixelMap !== undefined) {
            this.pixelMapPreview('feature_runtime_result_foreground', this.segmentationForegroundPixelMap)
          }
          if (this.segmentationImageUri.length > 0 && this.segmentationRectangles.length > 0) {
            this.segmentationPreview('feature_runtime_result_segmentation_overlay', this.segmentationImageUri)
          }
          if (this.poseImageUri.length > 0 && this.posePoints.length > 0) {
            this.posePreview('feature_runtime_result_pose_overlay', this.poseImageUri)
          }
          if (this.recognizedTextForCopy().length > 0) {
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
          if (this.selectedInputSummary.length > 0) {
            Text(this.selectedInputSummary)
              .fontSize(12)
              .fontColor(AppColor.textMuted)
              .margin({ top: AppSpacing.sm })
              .width('100%')
              .maxLines(2)
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
