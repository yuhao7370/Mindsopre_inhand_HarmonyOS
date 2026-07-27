import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import {
  collegeAdapterViewTitleKey,
  collegeItems,
  CollegeItem,
  CollegeQuickAction,
  isCollegeItemUrlNavigable
} from '../common/data/CollegeCatalog';
import {
  collegeCardRadiusVp,
  collegeDialogConfirmMinHeightVp,
  collegeEntryMinHeightVp,
  collegeHeaderMinHeightVp,
  collegePageInsetVp,
  collegeQuickActionMinHeightVp
} from '../common/data/CollegeLayoutSpec';
import {
  androidCollegeSummaryDialogSpec,
  CollegeSummaryDialogSpec
} from '../common/data/CollegeSummaryDialog';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor } from '../common/theme/AppTheme';
import { webPagePath } from '../common/data/WebDestination';
import {
  CollegeProgressService,
  HarmonyCollegeProgressStore
} from '../services/storage/CollegeProgressService';

const collegeCardBorderColor: string = '#E8EDF5';
const collegeCompletedBackgroundColor: string = '#F4F7FF';
const collegeQuickActionBackgroundColor: string = '#F8FAFD';

function collegeItemMediaResource(itemId: string): Resource {
  switch (itemId) {
    case 'summary':
      return $r('app.media.college_summary_v2');
    case 'cloud':
      return $r('app.media.college_cloud_v2');
    case 'quick':
      return $r('app.media.college_quick_v2');
    case 'faq':
      return $r('app.media.college_faq_v2');
    case 'forum':
      return $r('app.media.college_forum_v2');
    default:
      return $r('app.media.college_summary_v2');
  }
}

function collegeQuickActionMediaResource(actionId: string): Resource {
  switch (actionId) {
    case 'train':
      return $r('app.media.college_train_v2');
    case 'inference':
      return $r('app.media.college_inference_v2');
    case 'applications':
      return $r('app.media.college_applications_v2');
    case 'video':
      return $r('app.media.college_video_v2');
    default:
      return $r('app.media.college_quick_v2');
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
        .margin({ top: 20 })
      Scroll() {
        Column() {
          Text(appString(this.spec.contentKey))
            .fontSize(12)
            .fontColor(AppColor.textSecondary)
            .textAlign(TextAlign.Start)
            .lineHeight(20)
            .width('100%')
          if (this.spec.showBottomLogo) {
            Image($r('app.media.logo_with_title'))
              .width(95)
              .height(80)
              .objectFit(ImageFit.Contain)
              .margin({ top: 18 })
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: '72%' })
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .margin({ top: 18 })
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .margin({ top: 16 })
      Button(appString(this.spec.confirmKey))
        .width('100%')
        .constraintSize({ minHeight: collegeDialogConfirmMinHeightVp })
        .fontSize(13)
        .fontColor(AppColor.textPrimary)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('86%')
    .constraintSize({ maxHeight: '72%' })
    .padding({ left: 22, right: 22 })
    .backgroundColor(Color.White)
    .borderRadius(20)
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
    } catch (_) {
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

  private openCollegeItem(item: CollegeItem): void {
    if (item.type === 'summary') {
      this.markCollegeItemChecked(item);
      this.showSummary();
      return;
    }
    if (isCollegeItemUrlNavigable(item)) {
      this.markCollegeItemChecked(item);
      this.openWeb(item.titleKey, item.url ?? '');
    }
  }

  @Builder
  private collegeItemCompletedStatus(itemId: string) {
    Row() {
      Text('✓')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accent)
      Text(appString('college_checked'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.accent)
        .maxLines(2)
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
    .visibility(this.isCollegeItemChecked(itemId) ? Visibility.Visible : Visibility.None)
  }

  @Builder
  private quickActionCompletedStatus(actionId: string) {
    Row() {
      Text('✓')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accent)
      Text(appString('college_checked'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.accent)
        .maxLines(2)
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
    .visibility(this.isQuickActionChecked(actionId) ? Visibility.Visible : Visibility.None)
  }

  @Builder
  private collegeHeader() {
    Column() {
      Text(appString('college_head_title'))
        .width('100%')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
      Text(appString('college_head_subtitle'))
        .width('100%')
        .fontSize(14)
        .fontColor(AppColor.textSecondary)
        .lineHeight(21)
        .margin({ top: 8 })
    }
    .width('100%')
    .constraintSize({ minHeight: collegeHeaderMinHeightVp })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private collegeEntryCard(item: CollegeItem) {
    Column() {
      Row() {
        Image(collegeItemMediaResource(item.id))
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
        Text(appString(item.titleKey))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textPrimary)
          .maxLines(2)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Row() {
        this.collegeItemCompletedStatus(item.id)
        Blank()
        Row() {
          Text(appString(collegeAdapterViewTitleKey))
            .fontSize(12)
            .fontColor(AppColor.accent)
            .maxLines(2)
          Image($r('app.media.me_go'))
            .width(6)
            .height(12)
            .objectFit(ImageFit.Contain)
            .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 6 })
    }
    .width('100%')
    .constraintSize({ minHeight: collegeEntryMinHeightVp })
    .padding({ top: 12, bottom: 12, left: 14, right: 14 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isCollegeItemChecked(item.id) ? collegeCompletedBackgroundColor : Color.White)
    .border({ width: 1, color: collegeCardBorderColor, radius: collegeCardRadiusVp })
    .margin({ top: 10 })
    .onClick(() => {
      this.openCollegeItem(item);
    })
  }

  @Builder
  private quickActionCard(action: CollegeQuickAction) {
    Column() {
      Row() {
        Image(collegeQuickActionMediaResource(action.id))
          .width(30)
          .height(30)
          .objectFit(ImageFit.Contain)
        Text(appString(action.titleKey))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isQuickActionChecked(action.id) ? AppColor.accent : AppColor.textPrimary)
          .maxLines(2)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.quickActionCompletedStatus(action.id)
    }
    .width('100%')
    .constraintSize({ minHeight: collegeQuickActionMinHeightVp })
    .padding({ top: 10, bottom: 10, left: 10, right: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(collegeQuickActionBackgroundColor)
    .border({ width: 1, color: collegeCardBorderColor, radius: 12 })
    .onClick(() => {
      this.markQuickActionChecked(action);
      this.openWeb(action.titleKey, action.url);
    })
  }

  @Builder
  private quickStartCard(item: CollegeItem) {
    Column() {
      Row() {
        Image(collegeItemMediaResource(item.id))
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
        Text(appString(item.titleKey))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .maxLines(2)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.collegeItemCompletedStatus(item.id)
      if (item.quickActions !== undefined) {
        Grid() {
          ForEach(item.quickActions, (action: CollegeQuickAction) => {
            GridItem() {
              this.quickActionCard(action)
            }
          }, (action: CollegeQuickAction) => action.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .constraintSize({ minHeight: collegeQuickActionMinHeightVp * 2 + 8 })
        .width('100%')
        .scrollBar(BarState.Off)
        .enableScrollInteraction(false)
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .border({ width: 1, color: collegeCardBorderColor, radius: collegeCardRadiusVp })
    .margin({ top: 10 })
  }

  @Builder
  private collegeFooter(item: CollegeItem) {
    Text(appString(item.titleKey))
      .width('100%')
      .fontSize(13)
      .fontColor(AppColor.textMuted)
      .textAlign(TextAlign.Center)
      .margin({ top: 24, bottom: 8 })
  }

  build() {
    Scroll() {
      Column() {
        this.collegeHeader()
        Text(appString('mindspore_college_title'))
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .margin({ top: 4, bottom: 2 })
        ForEach(collegeItems, (item: CollegeItem) => {
          if (item.type === 'quickStart') {
            this.quickStartCard(item)
          } else if (item.type === 'footer') {
            this.collegeFooter(item)
          } else {
            this.collegeEntryCard(item)
          }
        }, (item: CollegeItem) => item.id)
      }
      .width('100%')
      .padding({
        left: collegePageInsetVp,
        right: collegePageInsetVp,
        bottom: 28
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor(AppColor.pageBackground)
  }
}
