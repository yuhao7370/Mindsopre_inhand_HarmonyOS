import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
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
  liveCameraXComponentId,
  nextLiveCameraPosition
} from '../services/camera/LiveCameraService';
import {
  DanceSamplingPageState,
  danceSamplingCompletionStatusKey,
  danceSamplingPageState,
  danceResultMessageKey,
  danceScoreText,
  danceTemplateDemoScore
} from '../services/dance/DancePageService';
import {
  DanceSamplingCancellationToken,
  HarmonyDanceSamplingClock,
  HarmonyDanceSamplingDelay,
  DanceLiveFrameImageCapturer,
  DanceLivePoseFrameSource,
  DancePoseServiceDetector,
  DanceTimedSamplingService
} from '../services/dance/DanceSamplingService';
import { PermissionRequestSummary, PermissionService } from '../services/permissions/PermissionService';

@Entry
@Component
struct DancePage {
  @State scoreText: string = '--';
  @State resultMessageKey: AppStringKey = 'empty';
  @State hasResult: boolean = false;
  @State statusKey: AppStringKey = 'empty';
  @State samplingSummaryText: string = '';
  @State sampling: boolean = false;
  @State liveCameraSurfaceId: string = '';
  @State liveCameraActive: boolean = false;
  @State liveCameraPosition: LiveCameraPosition = 'front';
  private liveCameraController: XComponentController = new XComponentController();
  private liveCameraService: LiveCameraPreviewService | undefined = undefined;
  private samplingSessionId: number = 0;
  private samplingCancellation: DanceSamplingCancellationToken | undefined = undefined;

  aboutToDisappear() {
    this.cancelLiveSampling();
    this.stopLiveCameraPreview();
  }

  private runTemplateDemo(): void {
    this.cancelLiveSampling();
    const score = danceTemplateDemoScore();
    this.scoreText = danceScoreText(score);
    this.resultMessageKey = danceResultMessageKey(score);
    this.hasResult = true;
    this.statusKey = 'empty';
    this.samplingSummaryText = '';
  }

  private reset(): void {
    this.cancelLiveSampling();
    this.scoreText = '--';
    this.resultMessageKey = 'empty';
    this.hasResult = false;
    this.statusKey = 'empty';
    this.samplingSummaryText = '';
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private liveSamplingButtonKey(): AppStringKey {
    return this.sampling ? 'dance_sampling' : 'dance_start_live';
  }

  private cancelLiveSampling(): void {
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
    const permission: PermissionRequestSummary = await new PermissionService().requestStartup(context);
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

  private switchLiveCamera(): void {
    this.liveCameraPosition = nextLiveCameraPosition(this.liveCameraPosition);
    if (this.liveCameraActive) {
      this.liveCameraActive = false;
      this.startLiveCameraPreviewAsync();
    }
  }

  private runLiveSampling(): void {
    this.runLiveSamplingAsync();
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
        return;
      }
      this.applyDanceSamplingPageState(
        danceSamplingPageState(result)
      );
      this.statusKey = completionStatusKey;
    } catch (_) {
      if (this.isLiveSamplingSessionCurrent(sessionId, cancellation)) {
        this.statusKey = 'dance_sampling_failed';
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
    this.scoreText = state.scoreText;
    this.resultMessageKey = state.resultMessageKey;
    this.hasResult = state.hasResult;
    this.samplingSummaryText = state.summaryText;
  }

  @Builder
  header() {
    Row() {
      Text('<')
        .fontSize(24)
        .fontColor(AppColor.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
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
  preparePanel() {
    Column() {
      Image($r('app.media.skeleton_template'))
        .width(132)
        .aspectRatio(135 / 169)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: AppSpacing.lg })

      Text(appString('dance_prepare_summary'))
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(22)

      Button(appString('dance_start_demo'))
        .width('100%')
        .height(44)
        .margin({ top: AppSpacing.lg })
        .onClick(() => this.runTemplateDemo())

      this.liveCameraPreview()

      Button(appString(this.liveSamplingButtonKey()))
        .width('100%')
        .height(44)
        .margin({ top: AppSpacing.md })
        .enabled(!this.sampling)
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
      Button(appString('feature_runtime_switch_camera'))
        .height(32)
        .margin({ top: AppSpacing.sm })
        .enabled(!this.sampling)
        .onClick(() => this.switchLiveCamera())
    }
    .width('100%')
    .margin({ top: AppSpacing.lg })
  }

  @Builder
  resultPanel() {
    Column() {
      Text(appString('dance_result_title'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
      Text(this.scoreText)
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accent)
        .margin({ top: AppSpacing.sm })
      Text(appString(this.resultMessageKey))
        .fontSize(16)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .margin({ top: AppSpacing.sm })
      if (this.samplingSummaryText.length > 0) {
        Row() {
          Text(appString('dance_sampling_frames'))
            .fontSize(13)
            .fontColor(AppColor.textSecondary)
          Text(this.samplingSummaryText)
            .fontSize(13)
            .fontColor(AppColor.textPrimary)
            .fontWeight(FontWeight.Medium)
            .margin({ left: AppSpacing.sm })
        }
        .margin({ top: AppSpacing.sm })
      }
      Button(appString(this.liveSamplingButtonKey()))
        .width('100%')
        .height(40)
        .margin({ top: AppSpacing.lg })
        .enabled(!this.sampling)
        .onClick(() => this.runLiveSampling())
      Button(appString('dance_start_demo'))
        .width('100%')
        .height(40)
        .margin({ top: AppSpacing.sm })
        .onClick(() => this.runTemplateDemo())
      Button(appString('dance_reset'))
        .width('100%')
        .height(40)
        .margin({ top: AppSpacing.sm })
        .backgroundColor(AppColor.cardBackground)
        .fontColor(AppColor.accent)
        .border({ width: 1, color: AppColor.accent, radius: AppRadius.button })
        .onClick(() => this.reset())
    }
    .width('100%')
    .padding(AppSpacing.xl)
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .margin({ top: AppSpacing.lg })
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
