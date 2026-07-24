import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonySkeletonDetectionRunner,
  PoseService
} from '../services/ai/PoseService';
import {
  HarmonyLiveCameraPreviewDriver,
  HarmonyLiveFrameImageEncoder,
  HarmonyLiveFrameImageStore,
  LiveCameraPosition,
  LiveCameraPreviewResult,
  LiveCameraPreviewService,
  LiveFrameImageService,
  liveCameraXComponentId
} from '../services/camera/LiveCameraService';
import {
  DanceSamplingPageState,
  danceCountdownSequence,
  danceCountdownStepMs,
  danceReferenceVideoCanStartLive,
  danceReferenceVideoPlayerPreparedAfterCacheResult,
  danceReferenceVideoProgressText,
  danceResultActionButtonHeightPx,
  danceResultActionButtonWidthPx,
  danceResultBackButtonHeightPx,
  danceResultBackButtonWidthPx,
  danceResultComponentId,
  danceResultPlayAgainLabelKey,
  danceResultBackgroundHeightPx,
  danceSamplingCompletionStatusKey,
  danceSamplingPageState,
  danceSaveStatusKey,
  danceSamplingResultStopsLiveCameraPreview
} from '../services/dance/DancePageService';
import {
  DanceReferenceVideoCacheService,
  DanceReferenceVideoProgress,
  danceReferenceVideoProgressPercent,
  DanceReferenceVideoPrepareResult
} from '../services/dance/DanceReferenceVideoService';
import {
  DanceKeepScreenOnService,
  HarmonyDanceKeepScreenOnWindowProvider
} from '../services/dance/DanceKeepScreenOnService';
import {
  DanceSamplingCancellationToken,
  HarmonyDanceSamplingClock,
  HarmonyDanceSamplingDelay,
  DanceLiveFrameImageCapturer,
  DanceLivePoseFrameSource,
  DancePoseServiceDetector,
  DanceTimedSamplingService
} from '../services/dance/DanceSamplingService';
import {
  HarmonyResultImageAssetWriter,
  HarmonyResultImagePixelMapEncoder,
  ResultImageSaveResult,
  ResultImageSaveService,
  withCallerOwnedPixelMap
} from '../services/media/ResultImageSaveService';
import { PermissionRequestSummary, PermissionService } from '../services/permissions/PermissionService';

type DanceFlowStage = 'prepare' | 'countdown' | 'sampling' | 'result';

@Entry
@Component
struct DancePage {
  @State scoreLabelKey: AppStringKey = 'dance_score_prefix';
  @State scoreText: string = '--';
  @State resultMessageKey: AppStringKey = 'empty';
  @State hasResult: boolean = false;
  @State statusKey: AppStringKey = 'empty';
  @State samplingSummaryText: string = '';
  @State sampling: boolean = false;
  @State liveCameraSurfaceId: string = '';
  @State liveCameraActive: boolean = false;
  @State liveCameraPosition: LiveCameraPosition = 'front';
  @State flowStage: DanceFlowStage = 'prepare';
  @State countdownText: string = '';
  @State referenceVideoFailed: boolean = false;
  @State referenceVideoPreparing: boolean = false;
  @State referenceVideoReady: boolean = false;
  @State referenceVideoPlayerPrepared: boolean = false;
  @State referenceVideoSrc: string = '';
  @State referenceVideoProgressPercent: number = 0;
  private referenceVideoController: VideoController = new VideoController();
  private liveCameraController: XComponentController = new XComponentController();
  private liveCameraService: LiveCameraPreviewService | undefined = undefined;
  private samplingSessionId: number = 0;
  private referenceVideoPrepareSessionId: number = 0;
  private samplingCancellation: DanceSamplingCancellationToken | undefined = undefined;
  private countdownTimer: number = -1;

  aboutToAppear() {
    this.setDanceKeepScreenOn(true);
    this.prepareReferenceVideo();
  }

  aboutToDisappear() {
    this.setDanceKeepScreenOn(false);
    this.referenceVideoPrepareSessionId++;
    this.cancelLiveSampling();
    this.stopReferenceVideo();
    this.stopLiveCameraPreview();
  }

  private reset(): void {
    this.cancelLiveSampling();
    this.stopReferenceVideo();
    this.scoreLabelKey = 'dance_score_prefix';
    this.scoreText = '--';
    this.resultMessageKey = 'empty';
    this.hasResult = false;
    this.flowStage = 'prepare';
    this.countdownText = '';
    this.statusKey = 'empty';
    this.samplingSummaryText = '';
    this.prepareReferenceVideo();
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private setDanceKeepScreenOn(isKeepScreenOn: boolean): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    new DanceKeepScreenOnService(
      new HarmonyDanceKeepScreenOnWindowProvider(context)
    ).setKeepScreenOn(isKeepScreenOn);
  }

  private liveSamplingButtonKey(): AppStringKey {
    if (this.flowStage === 'countdown') {
      return 'dance_countdown';
    }
    return this.sampling ? 'dance_sampling' : 'dance_start_live';
  }

  private liveSamplingActionEnabled(): boolean {
    return !this.sampling &&
      this.flowStage !== 'countdown' &&
      danceReferenceVideoCanStartLive({
        cached: this.referenceVideoReady,
        playerPrepared: this.referenceVideoPlayerPrepared,
        preparing: this.referenceVideoPreparing,
        failed: this.referenceVideoFailed
      });
  }

  private clearDanceCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearTimeout(this.countdownTimer);
      this.countdownTimer = -1;
    }
    this.countdownText = '';
  }

  private countdownMediaResource(): Resource {
    if (this.countdownText === '3') {
      return $r('app.media.dance_countdown_three');
    }
    if (this.countdownText === '2') {
      return $r('app.media.dance_countdown_two');
    }
    if (this.countdownText === '1') {
      return $r('app.media.dance_countdown_one');
    }
    return $r('app.media.dance_countdown_three');
  }

  private startReferenceVideoFromBeginning(): boolean {
    if (!danceReferenceVideoCanStartLive({
      cached: this.referenceVideoReady,
      playerPrepared: this.referenceVideoPlayerPrepared,
      preparing: this.referenceVideoPreparing,
      failed: this.referenceVideoFailed
    })) {
      this.statusKey = this.referenceVideoPreparing ?
        'dance_reference_video_downloading' :
        'dance_reference_video_failed';
      return false;
    }
    try {
      this.referenceVideoController.setCurrentTime(0);
      this.referenceVideoController.start();
      this.referenceVideoFailed = false;
      return true;
    } catch (_) {
      this.referenceVideoFailed = true;
      this.statusKey = 'dance_reference_video_failed';
      return false;
    }
  }

  private prepareReferenceVideo(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.referenceVideoReady = false;
      this.referenceVideoFailed = true;
      this.referenceVideoPreparing = false;
      this.referenceVideoPlayerPrepared = false;
      this.referenceVideoSrc = '';
      this.referenceVideoProgressPercent = 0;
      this.statusKey = 'dance_reference_video_failed';
      return;
    }

    const sessionId = ++this.referenceVideoPrepareSessionId;
    const previousReferenceVideoSrc = this.referenceVideoSrc;
    const previousReferenceVideoPlayerPrepared = this.referenceVideoPlayerPrepared;
    this.referenceVideoReady = false;
    this.referenceVideoFailed = false;
    this.referenceVideoPreparing = true;
    this.referenceVideoPlayerPrepared = false;
    this.referenceVideoProgressPercent = 0;
    this.statusKey = 'dance_reference_video_downloading';
    new DanceReferenceVideoCacheService().prepare(
      context.cacheDir,
      context,
      (progress: DanceReferenceVideoProgress) => {
        if (sessionId === this.referenceVideoPrepareSessionId) {
          this.referenceVideoProgressPercent = danceReferenceVideoProgressPercent(progress);
        }
      }
    )
      .then((result: DanceReferenceVideoPrepareResult) => {
        if (sessionId !== this.referenceVideoPrepareSessionId) {
          return;
        }
        this.referenceVideoPreparing = false;
        this.referenceVideoReady = result.ok;
        this.referenceVideoFailed = !result.ok;
        this.referenceVideoPlayerPrepared = danceReferenceVideoPlayerPreparedAfterCacheResult(
          result.ok,
          result.uri,
          previousReferenceVideoSrc,
          previousReferenceVideoPlayerPrepared
        );
        this.referenceVideoSrc = result.uri;
        this.referenceVideoProgressPercent = result.ok ? 100 : 0;
        this.statusKey = result.messageKey;
      })
      .catch(() => {
        if (sessionId !== this.referenceVideoPrepareSessionId) {
          return;
        }
        this.referenceVideoReady = false;
        this.referenceVideoFailed = true;
        this.referenceVideoPreparing = false;
        this.referenceVideoPlayerPrepared = false;
        this.referenceVideoSrc = '';
        this.referenceVideoProgressPercent = 0;
        this.statusKey = 'dance_reference_video_failed';
      });
  }

  private stopReferenceVideo(): void {
    try {
      this.referenceVideoController.stop();
    } catch (_) {
    }
  }

  private startDanceCountdown(index: number): void {
    const sequence = danceCountdownSequence();
    if (index >= sequence.length) {
      this.countdownTimer = -1;
      this.countdownText = '';
      if (this.startReferenceVideoFromBeginning()) {
        this.flowStage = 'sampling';
        this.runLiveSamplingAsync();
      } else {
        this.flowStage = 'prepare';
      }
      return;
    }
    this.countdownText = `${sequence[index]}`;
    this.countdownTimer = setTimeout(() => {
      this.startDanceCountdown(index + 1);
    }, danceCountdownStepMs);
  }

  private cancelLiveSampling(): void {
    this.clearDanceCountdown();
    this.samplingSessionId++;
    const cancellation = this.samplingCancellation;
    this.samplingCancellation = undefined;
    if (cancellation !== undefined) {
      cancellation.cancel();
    }
    this.sampling = false;
  }

  private isLiveSamplingSessionCurrent(sessionId: number, cancellation: DanceSamplingCancellationToken): boolean {
    return this.samplingSessionId === sessionId && !cancellation.isCancelled();
  }

  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {
    this.statusKey = result.messageKey;
    this.liveCameraActive = result.ok;
    this.liveCameraSurfaceId = result.surfaceId;
  }

  private async startLiveCameraPreviewAsync(): Promise<boolean> {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'feature_runtime_permission_denied';
      this.liveCameraActive = false;
      return false;
    }

    const surfaceId = this.liveCameraSurfaceId.length > 0 ?
      this.liveCameraSurfaceId :
      this.liveCameraController.getXComponentSurfaceId();
    const permission: PermissionRequestSummary = await new PermissionService().requestCamera(context);
    if (!permission.ok) {
      this.statusKey = 'feature_runtime_permission_denied';
      this.liveCameraActive = false;
      return false;
    }

    try {
      const previousService = this.liveCameraService;
      if (previousService !== undefined) {
        await previousService.stop();
      }
      this.liveCameraService = new LiveCameraPreviewService(new HarmonyLiveCameraPreviewDriver(context));
      const result = await this.liveCameraService.start(surfaceId, this.liveCameraPosition);
      this.applyLiveCameraPreviewResult(result);
      return result.ok;
    } catch (_) {
      this.applyLiveCameraPreviewResult({
        ok: false,
        surfaceId: '',
        messageKey: 'feature_runtime_live_camera_failed'
      });
      return false;
    }
  }

  private stopLiveCameraPreview(): void {
    this.liveCameraActive = false;
    const service = this.liveCameraService;
    this.liveCameraService = undefined;
    if (service !== undefined) {
      service.stop();
    }
  }

  private runLiveSampling(): void {
    this.runLiveSamplingWithCountdown();
  }

  private async runLiveSamplingWithCountdown(): Promise<void> {
    if (!this.liveSamplingActionEnabled()) {
      if (this.referenceVideoFailed) {
        this.statusKey = 'dance_reference_video_failed';
      }
      return;
    }
    const previewReady = this.liveCameraActive ? true : await this.startLiveCameraPreviewAsync();
    if (!previewReady) {
      return;
    }
    this.stopReferenceVideo();
    this.hasResult = false;
    this.scoreLabelKey = 'dance_score_prefix';
    this.scoreText = '--';
    this.resultMessageKey = 'empty';
    this.samplingSummaryText = '';
    this.flowStage = 'countdown';
    this.statusKey = 'dance_countdown';
    this.startDanceCountdown(0);
  }

  private async runLiveSamplingAsync(): Promise<void> {
    if (this.sampling) {
      return;
    }
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'feature_runtime_permission_denied';
      return;
    }

    const cancellation = new DanceSamplingCancellationToken();
    this.samplingSessionId++;
    const sessionId = this.samplingSessionId;
    this.samplingCancellation = cancellation;
    this.sampling = true;
    this.hasResult = false;
    this.scoreLabelKey = 'dance_score_prefix';
    this.scoreText = '--';
    this.resultMessageKey = 'empty';
    this.samplingSummaryText = '';
    try {
      const previewReady = this.liveCameraActive ? true : await this.startLiveCameraPreviewAsync();
      if (!previewReady) {
        return;
      }
      const surfaceId = this.liveCameraSurfaceId.length > 0 ?
        this.liveCameraSurfaceId :
        this.liveCameraController.getXComponentSurfaceId();
      if (surfaceId.length === 0) {
        this.statusKey = 'feature_runtime_live_camera_surface_missing';
        return;
      }

      this.statusKey = 'dance_sampling';
      const source = new DanceLivePoseFrameSource(
        surfaceId,
        context.cacheDir,
        new DanceLiveFrameImageCapturer(
          new LiveFrameImageService(new HarmonyLiveFrameImageEncoder(), new HarmonyLiveFrameImageStore())
        ),
        new DancePoseServiceDetector(new PoseService({ runner: new HarmonySkeletonDetectionRunner() }))
      );
      const result = await new DanceTimedSamplingService(
        new HarmonyDanceSamplingDelay(),
        new HarmonyDanceSamplingClock(),
        cancellation
      ).sample(source);
      if (!this.isLiveSamplingSessionCurrent(sessionId, cancellation) || result.cancelled) {
        return;
      }
      const completionStatusKey = danceSamplingCompletionStatusKey(result);
      if (completionStatusKey === 'feature_runtime_live_frame_failed') {
        this.statusKey = completionStatusKey;
        this.flowStage = 'prepare';
        this.stopReferenceVideo();
        return;
      }
      this.applyDanceSamplingPageState(danceSamplingPageState(result));
      this.flowStage = 'result';
      this.stopReferenceVideo();
      if (danceSamplingResultStopsLiveCameraPreview(result)) {
        this.stopLiveCameraPreview();
      }
      this.statusKey = completionStatusKey;
    } catch (_) {
      if (this.isLiveSamplingSessionCurrent(sessionId, cancellation)) {
        this.statusKey = 'dance_sampling_failed';
        this.flowStage = 'prepare';
        this.stopReferenceVideo();
      }
    } finally {
      if (this.samplingSessionId === sessionId) {
        this.sampling = false;
        if (this.samplingCancellation === cancellation) {
          this.samplingCancellation = undefined;
        }
      }
    }
  }

  private applyDanceSamplingPageState(state: DanceSamplingPageState): void {
    this.scoreLabelKey = state.scoreLabelKey;
    this.scoreText = state.scoreText;
    this.resultMessageKey = state.resultMessageKey;
    this.hasResult = state.hasResult;
    this.samplingSummaryText = state.summaryText;
  }

  private async danceResultPixelMap(): Promise<image.PixelMap | undefined> {
    if (!this.hasResult) {
      return undefined;
    }
    try {
      return await componentSnapshot.get(danceResultComponentId, { waitUntilRenderFinished: true });
    } catch (_) {
      return undefined;
    }
  }

  private async saveDanceResultImage(): Promise<ResultImageSaveResult> {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_save_image_failed' };
    }
    const resultImage = await this.danceResultPixelMap();
    return withCallerOwnedPixelMap(resultImage, async (snapshot: image.PixelMap | undefined) =>
      new ResultImageSaveService(
        new HarmonyResultImagePixelMapEncoder(),
        new HarmonyResultImageAssetWriter(context)
      ).save(snapshot));
  }

  private saveDanceResult(): void {
    this.saveDanceResultImage()
      .then((result: ResultImageSaveResult) => {
        this.statusKey = danceSaveStatusKey(result.ok);
      })
      .catch(() => {
        this.statusKey = danceSaveStatusKey(false);
      });
  }

  @Builder
  header() {
    Row() {
      Image($r('app.media.dance_back'))
        .width(40)
        .height(40)
        .objectFit(ImageFit.Contain)
        .onClick(() => router.back())
      Text(appString('title_dance'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.md, right: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
  }

  @Builder
  referenceVideoPanel() {
    Column() {
      Text(appString('dance_reference_video'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      Stack() {
        Video({
          src: this.referenceVideoSrc,
          previewUri: $r('app.media.dance_thumbnail'),
          controller: this.referenceVideoController
        })
          .width('100%')
          .height(190)
          .objectFit(ImageFit.Contain)
          .autoPlay(this.flowStage === 'prepare' && this.referenceVideoReady)
          .controls(true)
          .loop(this.flowStage === 'prepare' && this.referenceVideoReady)
          .backgroundColor('#111827')
          .onPrepared(() => {
            this.referenceVideoFailed = false;
            this.referenceVideoPlayerPrepared = true;
          })
          .onError(() => {
            this.referenceVideoFailed = true;
            this.referenceVideoPlayerPrepared = false;
            this.statusKey = 'dance_reference_video_failed';
          })
          .onFinish(() => {
            if (this.flowStage === 'prepare' && !this.referenceVideoFailed) {
              this.referenceVideoController.start();
            }
          })
        if (this.flowStage === 'countdown') {
          Column() {
            Text(appString('dance_countdown'))
              .fontSize(15)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
            Image(this.countdownMediaResource())
              .width('100%')
              .height('82%')
              .objectFit(ImageFit.Contain)
              .margin({ top: AppSpacing.xs })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#111827')
        }
      }
      .width('100%')
      .height(190)
      .clip(true)
      .margin({ top: AppSpacing.xs })
      .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
      if (this.referenceVideoPreparing) {
        Row() {
          Text(appString('dance_reference_video_downloading'))
            .fontSize(12)
            .fontColor(AppColor.textSecondary)
            .lineHeight(18)
          Text(danceReferenceVideoProgressText(this.referenceVideoProgressPercent))
            .fontSize(12)
            .fontColor(AppColor.textSecondary)
            .lineHeight(18)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: AppSpacing.sm })
        Progress({ value: this.referenceVideoProgressPercent, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color(AppColor.accent)
          .backgroundColor(AppColor.divider)
          .margin({ top: AppSpacing.xs })
      }
      if (this.referenceVideoFailed) {
        Text(appString('dance_reference_video_failed'))
          .fontSize(12)
          .fontColor(AppColor.danger)
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .margin({ top: AppSpacing.sm })
      }
    }
    .width('100%')
  }

  @Builder
  preparePanel() {
    Column() {
      this.referenceVideoPanel()

      Text(appString('dance_prepare_summary'))
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
        .margin({ top: AppSpacing.lg })

      this.liveCameraPreview()

      Button(appString(this.liveSamplingButtonKey()))
        .width('100%')
        .height(44)
        .margin({ top: AppSpacing.md })
        .enabled(this.liveSamplingActionEnabled())
        .onClick(() => this.runLiveSampling())

      if (this.statusKey !== 'empty') {
        Text(appString(this.statusKey))
          .fontSize(13)
          .fontColor(AppColor.textSecondary)
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .margin({ top: AppSpacing.sm })
      }
    }
    .width('100%')
    .padding(AppSpacing.xl)
    .backgroundColor(AppColor.cardBackground)
    .backgroundImage($r('app.media.dance_prepare_bk'))
    .backgroundImageSize(ImageSize.Cover)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
  }

  @Builder
  liveCameraPreview() {
    Column() {
      Text(appString('dance_live_preview'))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
      XComponent({
        id: liveCameraXComponentId,
        type: XComponentType.SURFACE,
        controller: this.liveCameraController
      })
        .width('100%')
        .height(220)
        .backgroundColor('#111827')
        .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
        .clip(true)
        .margin({ top: AppSpacing.xs })
        .onLoad(() => {
          this.liveCameraSurfaceId = this.liveCameraController.getXComponentSurfaceId();
        })
        .onDestroy(() => {
          this.cancelLiveSampling();
          this.stopLiveCameraPreview();
        })
    }
    .width('100%')
    .margin({ top: AppSpacing.lg })
    .padding(AppSpacing.sm)
    .backgroundImage($r('app.media.dance_run_bk'))
    .backgroundImageSize(ImageSize.Cover)
  }

  @Builder
  resultPanel() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column() {
          if (this.scoreText.length > 0) {
            Row() {
              Text(appString(this.scoreLabelKey))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF40ADFF')
                .textAlign(TextAlign.End)
                .lineHeight(32)
                .maxLines(2)
                .layoutWeight(1)
              Text(this.scoreText)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF40ADFF')
                .lineHeight(32)
                .flexShrink(0)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          } else {
            Text(appString(this.scoreLabelKey))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF40ADFF')
              .textAlign(TextAlign.Center)
              .lineHeight(32)
              .width('100%')
              .maxLines(2)
          }
          if (this.resultMessageKey !== 'empty') {
            Text(appString(this.resultMessageKey))
              .fontSize(20)
              .fontColor('#FF40ADFF')
              .textAlign(TextAlign.Center)
              .lineHeight(28)
              .margin({ top: AppSpacing.md })
          }
        }
        .width('100%')
        .padding({ left: AppSpacing.xl, right: AppSpacing.xl })
        .margin({ top: 138 })
        Blank()
          .layoutWeight(1)
        this.danceResultSaveButton()
        this.danceResultPlayAgainButton()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: AppSpacing.xl })
      Image($r('app.media.dance_result_back'))
        .width(danceResultBackButtonWidthPx / 2)
        .height(danceResultBackButtonHeightPx / 2)
        .objectFit(ImageFit.Fill)
        .margin({ left: AppSpacing.md, top: AppSpacing.md })
        .onClick(() => router.back())
    }
    .id(danceResultComponentId)
    .width('100%')
    .height(danceResultBackgroundHeightPx / 2)
    .backgroundImage($r('app.media.dance_result_bk'))
    .backgroundImageSize(ImageSize.Cover)
    .clip(true)
    .margin({ top: AppSpacing.lg })
  }

  @Builder
  danceResultSaveButton() {
    SaveButton({
      icon: SaveIconStyle.FULL_FILLED,
      text: SaveDescription.SAVE_IMAGE,
      buttonType: ButtonType.Capsule
    })
      .width(danceResultActionButtonWidthPx / 2)
      .height(danceResultActionButtonHeightPx / 2)
      .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
        if (result === SaveButtonOnClickResult.SUCCESS) {
          this.saveDanceResult();
          return;
        }
        this.statusKey = danceSaveStatusKey(false);
      })
  }

  @Builder
  danceResultPlayAgainButton() {
    Button(appString(danceResultPlayAgainLabelKey), { type: ButtonType.Capsule })
      .width(danceResultActionButtonWidthPx / 2)
      .height(danceResultActionButtonHeightPx / 2)
      .margin({ top: AppSpacing.lg })
      .backgroundColor('#FFF8C04A')
      .fontColor('#FF7A3E00')
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .onClick(() => this.reset())
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column() {
          this.preparePanel()
          if (this.hasResult) {
            this.resultPanel()
          }
          Text(appString('dance_platform_note'))
            .fontSize(12)
            .fontColor(AppColor.textMuted)
            .lineHeight(18)
            .textAlign(TextAlign.Center)
            .margin({ top: AppSpacing.lg })
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
