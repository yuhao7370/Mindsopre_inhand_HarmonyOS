import router from '@ohos.router';
import {
  FeatureInputKind,
  FeaturePermissionKind,
  FeatureWorkflow,
  inputLabelKey,
  permissionLabelKey,
  workflowForRoute
} from '../features/runtime/FeatureWorkflowCatalog';
import { AiRunResult, DefaultAiService } from '../services/ai/AiService';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';

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
  @State inputKinds: Array<FeatureInputKind> = [];
  @State permissionKinds: Array<FeaturePermissionKind> = [];

  aboutToAppear() {
    const params = router.getParams() as FeatureRuntimeParams;
    this.routeName = params?.routeName ?? '';
    const workflow = workflowForRoute(this.routeName);
    this.titleKey = params?.titleKey ?? workflow?.titleKey ?? this.titleKey;
    this.summaryKey = workflow?.summaryKey ?? this.summaryKey;
    this.aiMethod = workflow?.aiMethod ?? '';
    this.inputKinds = workflow?.inputKinds ?? [];
    this.permissionKinds = workflow?.requiredPermissions ?? [];
  }

  private runWorkflow(): void {
    const workflow = workflowForRoute(this.routeName);
    if (!workflow) {
      this.statusKey = 'feature_runtime_unknown_route';
      return;
    }
    new DefaultAiService().run(workflow).then((result: AiRunResult) => {
      this.statusKey = result.messageKey;
      this.resultText = `${result.aiMethod}: ${result.code}`;
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
