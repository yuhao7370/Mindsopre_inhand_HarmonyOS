import router from '@ohos.router';
import { findRouteByName } from '../app/AppRoutes';
import { FeatureCard } from '../common/components/FeatureCard';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';
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
        title: item.title
      }
    });
  }

  build() {
    Scroll() {
      Column() {
        GradientTitleBar({
          title: 'Experience',
          subtitle: 'AI demos ready for the HarmonyOS shell'
        })
        Column() {
          ForEach(visibleExperienceSections, (section: FeatureSection) => {
            Column() {
              SectionTitle({ title: section.title })
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
