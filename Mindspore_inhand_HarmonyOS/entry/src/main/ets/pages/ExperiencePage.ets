import router from '@ohos.router';
import { findRouteByName } from '../app/AppRoutes';
import { ExperienceHeader } from '../common/components/ExperienceHeader';
import { FeatureCard } from '../common/components/FeatureCard';
import { SectionTitle } from '../common/components/SectionTitle';
import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';
import { appString, AppStringKey } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';

@Component
export struct ExperiencePage {
  private openFeature(item: FeatureItem): void {
    const route = findRouteByName(item.routeName);
    if (!route) {
      return;
    }
    router.pushUrl({
      url: route.page,
      params: {
        routeName: item.routeName,
        title: item.title,
        titleKey: item.titleKey
      }
    });
  }

  @Builder
  private groupTitle(titleKey: AppStringKey) {
    Row() {
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .layoutWeight(1)
      Text(appString(titleKey))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: AppSpacing.md, right: AppSpacing.md })
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .layoutWeight(1)
    }
    .width('100%')
    .height(36)
    .alignItems(VerticalAlign.Center)
    .margin({ top: AppSpacing.sm, bottom: AppSpacing.md })
  }

  build() {
    Scroll() {
      Column() {
        ExperienceHeader()
        Column() {
          ForEach(visibleExperienceSections, (section: FeatureSection) => {
            Column() {
              if (section.groupTitleKey !== undefined) {
                this.groupTitle(section.groupTitleKey)
              }
              SectionTitle({ titleKey: section.titleKey })
              Column() {
                ForEach(section.items, (item: FeatureItem) => {
                  FeatureCard({
                    item: item,
                    action: (clicked: FeatureItem) => this.openFeature(clicked)
                  })
                    .margin({ bottom: AppSpacing.sm })
                }, (item: FeatureItem) => item.id)
              }
              .margin({ top: AppSpacing.md })
            }
            .width('100%')
            .margin({ bottom: AppSpacing.lg })
          }, (section: FeatureSection) => section.id)
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
