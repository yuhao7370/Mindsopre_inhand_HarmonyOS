import router from '@ohos.router';
import { findRouteByName } from '../app/AppRoutes';
import { ExperienceHeader } from '../common/components/ExperienceHeader';
import { FeatureCard } from '../common/components/FeatureCard';
import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';
import {
  experienceContentBottomPaddingVp,
  experienceContentOverlapVp,
  experienceContentTopRadiusVp,
  experienceGridColumnGapVp,
  experienceGridHeightVp,
  experienceGridRowGapVp,
  experienceGridSideInsetVp
} from '../common/data/ExperienceLayoutSpec';
import { appString, AppStringKey } from '../common/i18n/AppStrings';
import { AppColor } from '../common/theme/AppTheme';

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
  private groupTitle(titleKey: AppStringKey, topMargin: number) {
    Row() {
      Row()
        .layoutWeight(1)
        .height(1)
        .backgroundColor('#D9E2F5')
      Text(appString(titleKey))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: 14, right: 14 })
      Row()
        .layoutWeight(1)
        .height(1)
        .backgroundColor('#D9E2F5')
    }
    .width('100%')
    .height(30)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 46, right: 46 })
    .margin({ top: topMargin })
  }

  @Builder
  private sectionTitle(titleKey: AppStringKey) {
    Row() {
      Column() {
      }
      .width(4)
      .height(16)
      .backgroundColor(AppColor.accent)
      .borderRadius(2)
      Text(appString(titleKey))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: 8 })
        .maxLines(1)
    }
    .width('100%')
    .height(20)
    .padding({ left: experienceGridSideInsetVp })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 16 })
  }

  build() {
    Scroll() {
      Column() {
        ExperienceHeader()
        Scroll() {
          Column() {
            ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {
              Column() {
                if (section.groupTitleKey !== undefined) {
                  this.groupTitle(section.groupTitleKey, sectionIndex === 0 ? 0 : 22)
                }
                this.sectionTitle(section.titleKey)
                Grid() {
                  ForEach(section.items, (item: FeatureItem) => {
                    GridItem() {
                      FeatureCard({
                        item: item,
                        action: (clicked: FeatureItem) => this.openFeature(clicked)
                      })
                    }
                  }, (item: FeatureItem) => item.id)
                }
                .columnsTemplate('1fr 1fr')
                .columnsGap(experienceGridColumnGapVp)
                .rowsGap(experienceGridRowGapVp)
                .height(experienceGridHeightVp(section.items.length))
                .width('100%')
                .padding({ left: experienceGridSideInsetVp, right: experienceGridSideInsetVp })
                .margin({ top: 12 })
                .scrollBar(BarState.Off)
                .enableScrollInteraction(false)
              }
              .width('100%')
            }, (section: FeatureSection) => section.id)
          }
          .width('100%')
          .padding({ top: 18, bottom: experienceContentBottomPaddingVp })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: experienceContentTopRadiusVp, topRight: experienceContentTopRadiusVp })
        .margin({ top: -experienceContentOverlapVp })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor('#EDF3FF')
  }
}
