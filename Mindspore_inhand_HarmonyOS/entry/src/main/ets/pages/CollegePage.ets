import router from '@ohos.router';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import {
  collegeItems,
  CollegeItem,
  CollegeQuickAction,
  mindSporeSummary
} from '../common/data/CollegeCatalog';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';

@Component
export struct CollegePage {
  private openStub(title: string, url: string): void {
    router.pushUrl({
      url: 'pages/FeatureStubPage',
      params: {
        title: title,
        url: url
      }
    });
  }

  private showSummary(): void {
    AlertDialog.show({
      title: 'MindSpore Summary',
      message: mindSporeSummary,
      primaryButton: {
        value: 'OK',
        action: () => {}
      }
    });
  }

  @Builder
  quickActionCard(action: CollegeQuickAction) {
    Column() {
      Text(action.icon)
        .fontSize(22)
      Text(action.title)
        .fontSize(12)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .margin({ top: AppSpacing.sm })
    }
    .width('22%')
    .padding({ top: AppSpacing.md, bottom: AppSpacing.md, left: AppSpacing.xs, right: AppSpacing.xs })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => this.openStub(action.title, action.url))
  }

  @Builder
  collegeRow(item: CollegeItem) {
    Row() {
      Text(item.icon)
        .fontSize(22)
        .width(32)
      Text(item.title)
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
      Text('>')
        .fontSize(14)
        .fontColor(AppColor.textMuted)
    }
    .width('100%')
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => {
      if (item.type === 'summary') {
        this.showSummary();
        return;
      }
      this.openStub(item.title, item.url ?? '');
    })
  }

  build() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'College',
          subtitle: 'Learning resources and quick-start links'
        })
        Column() {
          SectionTitle({ title: 'MindSpore College' })
          Column() {
            ForEach(collegeItems, (item: CollegeItem) => {
              if (item.type === 'footer') {
                Text(item.title)
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
