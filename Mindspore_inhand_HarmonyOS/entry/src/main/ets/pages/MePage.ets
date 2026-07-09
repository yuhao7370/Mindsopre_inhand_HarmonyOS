import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import { MeItem, visibleMeItems } from '../common/data/MeCatalog';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';

@Component
export struct MePage {
  private valueForItem(item: MeItem): string {
    if (item.id === 'version') {
      return 'V1.0.0';
    }
    return '';
  }

  @Builder
  meRow(item: MeItem) {
    Row() {
      Text(item.icon)
        .fontSize(22)
        .width(32)
      Text(item.title)
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
      Text(this.valueForItem(item))
        .fontSize(13)
        .fontColor(AppColor.textSecondary)
    }
    .width('100%')
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
  }

  build() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'Me',
          subtitle: 'Profile and app information'
        })
        Column() {
          SectionTitle({ title: 'Account' })
          Column() {
            ForEach(visibleMeItems, (item: MeItem) => {
              Column() {
                this.meRow(item)
              }
                .margin({ top: AppSpacing.md })
            }, (item: MeItem) => item.id)
          }
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
