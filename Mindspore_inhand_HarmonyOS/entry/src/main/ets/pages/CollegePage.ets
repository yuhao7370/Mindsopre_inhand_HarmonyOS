import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import {
  collegeItems,
  CollegeItem,
  CollegeQuickAction,
  collegeSummaryDialogTitleKey,
  isCollegeItemUrlNavigable
} from '../common/data/CollegeCatalog';
import { iconLabel } from '../common/icons/IconSymbols';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { webPagePath } from '../common/data/WebDestination';
import {
  CollegeProgressService,
  HarmonyCollegeProgressStore
} from '../services/storage/CollegeProgressService';

@Component
export struct CollegePage {
  private progressService: CollegeProgressService | undefined = undefined;
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
    AlertDialog.show({
      title: appString(collegeSummaryDialogTitleKey),
      message: appString('college_dialog_content'),
      primaryButton: {
        value: appString('confirm'),
        action: () => {}
      }
    });
  }

  @Builder
  quickActionCard(action: CollegeQuickAction) {
    Column() {
      Text(iconLabel(action.icon))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(28)
        .height(28)
        .backgroundColor(AppColor.accent)
        .borderRadius(14)
        .textAlign(TextAlign.Center)
        .maxLines(1)
      Text(appString(action.titleKey))
        .fontSize(12)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ top: AppSpacing.sm })
      if (this.isQuickActionChecked(action.id)) {
        Text(appString('college_checked'))
          .fontSize(10)
          .fontColor(AppColor.accent)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .margin({ top: AppSpacing.xs })
      }
    }
    .width('22%')
    .padding({ top: AppSpacing.md, bottom: AppSpacing.md, left: AppSpacing.xs, right: AppSpacing.xs })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => {
      this.markQuickActionChecked(action);
      this.openWeb(action.titleKey, action.url);
    })
  }

  @Builder
  collegeRow(item: CollegeItem) {
    Row() {
      Text(iconLabel(item.icon))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(32)
        .height(32)
        .backgroundColor(AppColor.accent)
        .borderRadius(16)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: 8 })
      Text(appString(item.titleKey))
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
      if (this.isCollegeItemChecked(item.id)) {
        Text(appString('college_checked'))
          .fontSize(11)
          .fontColor(AppColor.accent)
          .maxLines(1)
          .margin({ right: AppSpacing.sm })
      }
      if (item.type === 'summary' || isCollegeItemUrlNavigable(item)) {
        Text('>')
          .fontSize(14)
          .fontColor(AppColor.textMuted)
      }
    }
    .width('100%')
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
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
              } else if (item.type === 'quickStart') {
                Column() {
                  this.collegeRow(item)
                  if (item.quickActions) {
                    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                      ForEach(item.quickActions, (action: CollegeQuickAction) => {
                        this.quickActionCard(action)
                      }, (action: CollegeQuickAction) => action.id)
                    }
                    .margin({ top: AppSpacing.md })
                  }
                }
                .margin({ top: AppSpacing.md })
              } else {
                Column() {
                  this.collegeRow(item)
                }
                  .margin({ top: AppSpacing.md })
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
