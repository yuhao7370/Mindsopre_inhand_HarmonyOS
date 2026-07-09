import { MainTab, mainTabs } from '../app/AppState';
import { BottomTabBar } from '../common/components/BottomTabBar';
import { FeatureCard } from '../common/components/FeatureCard';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import { FeatureItem, visibleExperienceSections } from '../common/data/FeatureCatalog';
import { collegeItems } from '../common/data/CollegeCatalog';
import { visibleMeItems } from '../common/data/MeCatalog';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';

@Component
export struct MainPage {
  @State selectedTab: MainTab = MainTab.EXPERIENCE;

  experiencePreviewItems(): FeatureItem[] {
    if (visibleExperienceSections.length === 0) {
      return [];
    }
    return visibleExperienceSections[0].items.slice(0, 3);
  }

  @Builder
  experiencePageBuilder() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'Experience',
          subtitle: 'ExperiencePage'
        })
        Column() {
          SectionTitle({ title: 'Quick Start' })
          Text('ExperiencePage')
            .fontSize(14)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.sm, bottom: AppSpacing.md })
          ForEach(this.experiencePreviewItems(), (item: FeatureItem) => {
            FeatureCard({
              item: item,
              action: (_clicked: FeatureItem) => {}
            })
              .margin({ bottom: AppSpacing.sm })
          }, (item: FeatureItem) => item.id)
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  collegePageBuilder() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'College',
          subtitle: 'CollegePage'
        })
        Column() {
          SectionTitle({ title: 'College' })
          Text('CollegePage')
            .fontSize(14)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.sm, bottom: AppSpacing.md })
          Text(`${collegeItems.length} catalog items ready`)
            .fontSize(14)
            .fontColor(AppColor.textPrimary)
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  mePageBuilder() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'Me',
          subtitle: 'MePage'
        })
        Column() {
          SectionTitle({ title: 'Profile' })
          Text('MePage')
            .fontSize(14)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.sm, bottom: AppSpacing.md })
          Text(`${visibleMeItems.length} visible rows ready`)
            .fontSize(14)
            .fontColor(AppColor.textPrimary)
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.pageBackground)
  }

  @Builder
  currentPageBuilder() {
    if (this.selectedTab === MainTab.EXPERIENCE) {
      this.experiencePageBuilder();
    } else if (this.selectedTab === MainTab.COLLEGE) {
      this.collegePageBuilder();
    } else {
      this.mePageBuilder();
    }
  }

  build() {
    Column() {
      Column() {
        this.currentPageBuilder()
      }
      .layoutWeight(1)
      .width('100%')

      BottomTabBar({
        selected: this.selectedTab,
        tabs: mainTabs,
        onChange: (tab: MainTab) => {
          this.selectedTab = tab;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
