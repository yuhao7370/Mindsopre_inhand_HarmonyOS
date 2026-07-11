import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import {
  collegeItems,
  collegeAdapterViewTitleKey,
  collegeQuickActionVisual,
  collegeTimelineVisualForItem,
  CollegeItem,
  CollegeMediaName,
  CollegeQuickAction,
  CollegeQuickActionVisual,
  CollegeTimelineVisual,
  isCollegeItemUrlNavigable
} from '../common/data/CollegeCatalog';
import {
  androidCollegeSummaryDialogSpec,
  CollegeSummaryDialogSpec
} from '../common/data/CollegeSummaryDialog';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { webPagePath } from '../common/data/WebDestination';
import {
  CollegeProgressService,
  HarmonyCollegeProgressStore
} from '../services/storage/CollegeProgressService';

function collegeMediaResource(mediaName: CollegeMediaName): Resource {
  switch (mediaName) {
    case 'college_summary_uncheck':
      return $r('app.media.college_summary_uncheck');
    case 'college_summary_checked':
      return $r('app.media.college_summary_checked');
    case 'college_cloud_uncheck':
      return $r('app.media.college_cloud_uncheck');
    case 'college_cloud_checked':
      return $r('app.media.college_cloud_checked');
    case 'college_quick_uncheck':
      return $r('app.media.college_quick_uncheck');
    case 'college_quick_checked':
      return $r('app.media.college_quick_checked');
    case 'college_faq_uncheck':
      return $r('app.media.college_faq_uncheck');
    case 'college_faq_checked':
      return $r('app.media.college_faq_checked');
    case 'college_ask_uncheck':
      return $r('app.media.college_ask_uncheck');
    case 'college_ask_checked':
      return $r('app.media.college_ask_checked');
    case 'college_train_uncheck':
      return $r('app.media.college_train_uncheck');
    case 'college_train_checked':
      return $r('app.media.college_train_checked');
    case 'college_execute_uncheck':
      return $r('app.media.college_execute_uncheck');
    case 'college_execute_checked':
      return $r('app.media.college_execute_checked');
    case 'college_app_uncheck':
      return $r('app.media.college_app_uncheck');
    case 'college_app_checked':
      return $r('app.media.college_app_checked');
    case 'college_video_uncheck':
      return $r('app.media.college_video_uncheck');
    case 'college_video_checked':
      return $r('app.media.college_video_checked');
  }
}

@CustomDialog
struct CollegeSummaryNoticeDialog {
  controller?: CustomDialogController;
  private spec: CollegeSummaryDialogSpec = androidCollegeSummaryDialogSpec();

  build() {
    Column() {
      Text(appString(this.spec.titleKey))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 17 })
      Text(appString(this.spec.contentKey))
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .textAlign(TextAlign.Start)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 22, left: 22, right: 22 })
      if (this.spec.showBottomLogo) {
        Image($r('app.media.logo_with_title'))
          .width(95)
          .height(80)
          .objectFit(ImageFit.Contain)
          .margin({ top: 18 })
      }
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .margin({ top: this.spec.showBottomLogo ? 22 : 50, left: 22, right: 22 })
      Button(appString(this.spec.confirmKey))
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor(AppColor.textPrimary)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('86%')
    .backgroundColor(Color.White)
    .borderRadius(AppRadius.card)
    .clip(true)
  }
}

@Component
export struct CollegePage {
  private progressService: CollegeProgressService | undefined = undefined;
  private summaryDialogController: CustomDialogController = new CustomDialogController({
    builder: CollegeSummaryNoticeDialog(),
    autoCancel: false,
    customStyle: true
  });
  @State checkedCollegeItemIds: Array<string> = [];
  @State checkedQuickActionIds: Array<string> = [];

  aboutToAppear() {
    this.refreshCollegeProgress();
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private collegeProgressService(): CollegeProgressService | undefined {
    if (this.progressService !== undefined) {
      return this.progressService;
    }
    try {
      const context = this.uiAbilityContext();
      if (context === undefined) {
        return undefined;
      }
      this.progressService = new CollegeProgressService(new HarmonyCollegeProgressStore(context));
      return this.progressService;
    } catch (error) {
      return undefined;
    }
  }

  private refreshCollegeProgress(): void {
    const service = this.collegeProgressService();
    if (service === undefined) {
      return;
    }
    const itemIds: Array<string> = [];
    const quickActionIds: Array<string> = [];
    collegeItems.forEach((item: CollegeItem) => {
      if (item.type !== 'footer') {
        itemIds.push(item.id);
      }
      if (item.quickActions !== undefined) {
        item.quickActions.forEach((action: CollegeQuickAction) => {
          quickActionIds.push(action.id);
        });
      }
    });
    this.checkedCollegeItemIds = service.checkedItemIds(itemIds);
    this.checkedQuickActionIds = service.checkedQuickActionIds(quickActionIds);
  }

  private isCollegeItemChecked(itemId: string): boolean {
    return this.checkedCollegeItemIds.indexOf(itemId) >= 0;
  }

  private isQuickActionChecked(actionId: string): boolean {
    return this.checkedQuickActionIds.indexOf(actionId) >= 0;
  }

  private markCollegeItemChecked(item: CollegeItem): void {
    const service = this.collegeProgressService();
    if (service === undefined || item.type === 'footer') {
      return;
    }
    service.markItemChecked(item.id);
    this.refreshCollegeProgress();
  }

  private markQuickActionChecked(action: CollegeQuickAction): void {
    const service = this.collegeProgressService();
    if (service === undefined) {
      return;
    }
    service.markQuickActionChecked(action.id);
    this.refreshCollegeProgress();
  }

  private openWeb(titleKey: AppStringKey, url: string): void {
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: titleKey,
        url: url
      }
    });
  }

  private showSummary(): void {
    this.summaryDialogController.open();
  }

  private timelineVisualForState(item: CollegeItem): CollegeTimelineVisual {
    return collegeTimelineVisualForItem(item, this.isCollegeItemChecked(item.id));
  }

  private quickActionVisualForState(action: CollegeQuickAction): CollegeQuickActionVisual {
    return collegeQuickActionVisual(action, this.isQuickActionChecked(action.id));
  }

  @Builder
  collegeTimelineMarker(item: CollegeItem) {
    Column() {
      Image(collegeMediaResource(this.timelineVisualForState(item).iconMediaName))
        .width(this.timelineVisualForState(item).iconSizeVp)
        .height(this.timelineVisualForState(item).iconSizeVp)
        .objectFit(ImageFit.Contain)
      if (this.timelineVisualForState(item).showsTrailingLine) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
          }
            .width(1)
            .height(this.timelineVisualForState(item).rowHeightVp - this.timelineVisualForState(item).iconSizeVp)
            .backgroundColor(this.timelineVisualForState(item).lineColor)
          if (this.timelineVisualForState(item).showsProgressDot) {
            Column() {
            }
              .width(10)
              .height(10)
              .border({ width: 4, color: '#335C99F4', radius: 5 })
              .backgroundColor('#5C99F4')
              .borderRadius(5)
          }
        }
        .width(this.timelineVisualForState(item).iconSizeVp)
        .height(this.timelineVisualForState(item).rowHeightVp - this.timelineVisualForState(item).iconSizeVp)
      } else {
        Blank()
          .width(this.timelineVisualForState(item).iconSizeVp)
          .height(this.timelineVisualForState(item).rowHeightVp - this.timelineVisualForState(item).iconSizeVp)
      }
    }
    .width(this.timelineVisualForState(item).iconSizeVp)
    .height(this.timelineVisualForState(item).rowHeightVp)
  }

  @Builder
  quickActionCard(action: CollegeQuickAction) {
    Column() {
      Image(collegeMediaResource(this.quickActionVisualForState(action).iconMediaName))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
        .margin({ top: 13 })
      Text(appString(action.titleKey))
        .fontSize(9)
        .fontColor(this.quickActionVisualForState(action).textColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .width('100%')
        .margin({ top: 9 })
    }
    .width(this.quickActionVisualForState(action).widthVp)
    .height(this.quickActionVisualForState(action).heightVp)
    .backgroundColor(Color.White)
    .border({ width: 1, color: this.quickActionVisualForState(action).borderColor, radius: 10 })
    .onClick(() => {
      this.markQuickActionChecked(action);
      this.openWeb(action.titleKey, action.url);
    })
  }

  @Builder
  collegeRow(item: CollegeItem) {
    Row() {
      this.collegeTimelineMarker(item)
      Column() {
        Row() {
          Text(appString(item.titleKey))
            .fontSize(13)
            .fontColor(AppColor.textPrimary)
            .layoutWeight(1)
            .maxLines(2)
          if (item.type === 'summary' || isCollegeItemUrlNavigable(item)) {
            Text(appString(collegeAdapterViewTitleKey))
              .fontSize(12)
              .fontColor(AppColor.accent)
              .maxLines(1)
              .margin({ right: AppSpacing.sm })
            Text('>')
              .fontSize(14)
              .fontColor(AppColor.textMuted)
          }
        }
        .height(this.timelineVisualForState(item).iconSizeVp)
        .width('100%')
        .alignItems(VerticalAlign.Center)
        if (item.quickActions) {
          Row() {
            ForEach(item.quickActions, (action: CollegeQuickAction) => {
              this.quickActionCard(action)
            }, (action: CollegeQuickAction) => action.id)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: AppSpacing.md })
        }
      }
      .layoutWeight(1)
      .height(this.timelineVisualForState(item).rowHeightVp)
      .margin({ left: 20 })
    }
    .width('100%')
    .height(this.timelineVisualForState(item).rowHeightVp)
    .alignItems(VerticalAlign.Top)
    .padding({ left: 0, right: 0 })
    .onClick(() => {
      if (item.type === 'summary') {
        this.markCollegeItemChecked(item);
        this.showSummary();
        return;
      }
      if (isCollegeItemUrlNavigable(item)) {
        this.markCollegeItemChecked(item);
        this.openWeb(item.titleKey, item.url ?? '');
      }
    })
  }

  build() {
    Scroll() {
      Column() {
        GradientTitleBar({
          titleKey: 'college_head_title',
          subtitleKey: 'college_head_subtitle'
        })
        Column() {
          SectionTitle({ titleKey: 'mindspore_college_title' })
          Column() {
            ForEach(collegeItems, (item: CollegeItem) => {
              if (item.type === 'footer') {
                Text(appString(item.titleKey))
                  .width('100%')
                  .fontSize(13)
                  .fontColor(AppColor.textMuted)
                  .textAlign(TextAlign.Center)
                  .margin({ top: AppSpacing.md })
              } else {
                this.collegeRow(item)
              }
            }, (item: CollegeItem) => item.id)
          }
          .width('100%')
          .margin({ top: AppSpacing.md })
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.pageBackground)
  }
}
