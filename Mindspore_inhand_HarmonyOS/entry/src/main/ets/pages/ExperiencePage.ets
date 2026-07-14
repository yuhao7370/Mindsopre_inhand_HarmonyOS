import router from '@ohos.router';
import { findRouteByName } from '../app/AppRoutes';
import { ExperienceHeader } from '../common/components/ExperienceHeader';
import { FeatureCard } from '../common/components/FeatureCard';
import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';
import {
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
  private dashedDivider() {
    Row() {
    }
    .width('100%')
    .height(2)
    .border({
      width: { top: 2 },
      color: { top: '#66000000' },
      style: { top: BorderStyle.Dashed }
    })
  }

  @Builder
  private groupTitle(titleKey: AppStringKey, topMargin: number) {
    Column() {
      this.dashedDivider()
      Text(appString(titleKey))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ top: 8, bottom: 8 })
      this.dashedDivider()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: topMargin })
  }

  @Builder
  private sectionTitle(titleKey: AppStringKey) {
    Row() {
      Column() {
      }
      .width(3)
      .height(12)
      .backgroundColor('#6189FF')
      .margin({ top: 3 })
      Text(appString(titleKey))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: 7 })
        .maxLines(1)
    }
    .width('100%')
    .height(15)
    .padding({ left: experienceGridSideInsetVp })
    .alignItems(VerticalAlign.Top)
    .margin({ top: 20 })
  }

  build() {
    Column() {
      ExperienceHeader()
      Scroll() {
        Column() {
          ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {
            Column() {
              if (section.groupTitleKey !== undefined) {
                this.groupTitle(section.groupTitleKey, sectionIndex === 0 ? 0 : 24)
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
              .margin({ top: 15 })
              .scrollBar(BarState.Off)
              .enableScrollInteraction(false)
            }
            .width('100%')
          }, (section: FeatureSection) => section.id)
        }
        .width('100%')
        .padding({ top: 30, bottom: 30 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
