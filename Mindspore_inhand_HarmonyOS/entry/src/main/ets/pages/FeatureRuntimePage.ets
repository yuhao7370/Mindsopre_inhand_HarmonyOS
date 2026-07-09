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
import { PickerService, PickResult } from '../services/picker/PickerService';
import { styleTransferPixelMapFromRgbaOutput } from '../services/ai/StyleTransferService';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { webPagePath } from '../common/data/WebDestination';

interface FeatureRuntimeParams {
  titleKey?: AppStringKey;
  routeName?: string;
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
  @State modelInputUri: string = '';
  @State userText: string = '';
  @State styledImagePixelMap: image.PixelMap | undefined = undefined;
  @State helpUrl: string = '';
  @State inputKinds: Array<FeatureInputKind> = [];
  @State permissionKinds: Array<FeaturePermissionKind> = [];

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
    this.styledImagePixelMap = undefined;
    if (inputKind === 'text') {
      this.statusKey = this.userText.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
      this.selectedInputSummary = this.userText;
      return;
    }
    const context = this.uiAbilityContext();
    if (!context) {
      this.statusKey = 'feature_runtime_pick_cancelled';
      return;
    }
    const pickerService = new PickerService(context);
    if (inputKind === 'modelFile') {
      pickerService.pickModelFile().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_model_ready', inputKind));
      return;
    }
    if (inputKind === 'camera') {
      pickerService.captureImage().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_image_ready', inputKind));
      return;
    }
    pickerService.pickImage().then((result: PickResult) => this.applyPickResult(result, 'feature_runtime_image_ready', inputKind));
  }

  private applyPickResult(result: PickResult, readyKey: AppStringKey, inputKind: FeatureInputKind): void {
    if (!result.ok) {
      this.statusKey = 'feature_runtime_pick_cancelled';
      this.selectedInputSummary = '';
      if (inputKind === 'modelFile') {
        this.modelInputUri = '';
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
    } else if (inputKind === 'contentImage') {
      this.contentImageUri = result.uri;
    } else if (inputKind === 'styleImage') {
      this.styleImageUri = result.uri;
    } else {
      this.imageInputUri = result.uri;
    }
  }

  private aiRunInputs(): AiRunInputs {
    return {
      imageUri: this.imageInputUri,
      contentImageUri: this.contentImageUri,
      styleImageUri: this.styleImageUri,
      modelUri: this.modelInputUri,
      text: this.userText
    };
  }

  private runWorkflow(): void {
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
    new PermissionService().requestForWorkflow(context, workflow).then((permission: PermissionRequestSummary) => {
      if (!permission.ok) {
        this.statusKey = 'feature_runtime_permission_denied';
        this.resultText = permission.requested.join(', ');
        this.resultRows = [];
        this.styledImagePixelMap = undefined;
        return;
      }
      cachedRuntimeAiServiceForHarmonyResourceManager(workflow, context.resourceManager).then((aiService: DefaultAiService) => {
        aiService.run(workflow, this.aiRunInputs()).then((result: AiRunResult) => {
          this.applyAiResult(result);
        });
      });
    });
  }

  private applyAiResult(result: AiRunResult): void {
    this.statusKey = result.messageKey;
    this.resultText = result.detailText.length > 0 ? result.detailText : `${result.aiMethod}: ${result.code}`;
    this.resultRows = aiRunResultRows(result);
    this.styledImagePixelMap = undefined;
    this.updateStyledImagePreview(result);
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
      this.modelInputUri.length > 0;
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
