import router from '@ohos.router';
import { findRouteByName } from '../app/AppRoutes';
import { ExperienceHeader } from '../common/components/ExperienceHeader';
import { FeatureCard } from '../common/components/FeatureCard';
import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';
import {
  experienceContentBottomPaddingVp,
  experienceGroupTitleMinHeightVp,
  experienceGridColumnGapVp,
  experienceGridMinHeightVp,
  experienceGridRowGapVp,
  experienceGridSideInsetVp,
  experienceSectionTitleMinHeightVp,
  experienceStickyTitleMinHeightVp,
  experienceStickyTitleVisible
} from '../common/data/ExperienceLayoutSpec';
import { appString, AppStringKey } from '../common/i18n/AppStrings';
import { AppColor } from '../common/theme/AppTheme';

@Component
export struct ExperiencePage {
  @State stickyTitleVisible: boolean = false;
  private scrollController: Scroller = new Scroller();

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
    Text(appString(titleKey))
    .width('100%')
    .constraintSize({ minHeight: experienceGroupTitleMinHeightVp })
    .fontSize(17)
    .fontWeight(FontWeight.Bold)
    .fontColor(AppColor.textPrimary)
    .padding({ left: experienceGridSideInsetVp, right: experienceGridSideInsetVp })
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
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: experienceSectionTitleMinHeightVp })
    .padding({ left: experienceGridSideInsetVp })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 16 })
  }

  @Builder
  private stickyTitle() {
    Row() {
      Text(appString('experience_head_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
    }
    .width('100%')
    .constraintSize({ minHeight: experienceStickyTitleMinHeightVp })
    .padding({ left: experienceGridSideInsetVp, right: experienceGridSideInsetVp })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
    .border({ width: { bottom: 1 }, color: '#EDF0F5' })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scrollController) {
        Column() {
          ExperienceHeader()
          Column() {
            ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {
              Column() {
                if (section.groupTitleKey !== undefined) {
                  this.groupTitle(section.groupTitleKey, sectionIndex === 0 ? 18 : 22)
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
                .constraintSize({ minHeight: experienceGridMinHeightVp(section.items.length) })
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
          .padding({ bottom: experienceContentBottomPaddingVp })
          .backgroundColor(Color.White)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .onScroll(() => {
        const visible = experienceStickyTitleVisible(this.scrollController.currentOffset().yOffset);
        if (visible !== this.stickyTitleVisible) {
          this.stickyTitleVisible = visible;
        }
      })

      if (this.stickyTitleVisible) {
        this.stickyTitle()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
