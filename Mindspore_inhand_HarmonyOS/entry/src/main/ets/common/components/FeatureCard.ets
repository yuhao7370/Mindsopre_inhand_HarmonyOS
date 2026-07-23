import { FeatureItem } from '../data/FeatureCatalog';
import {
  experienceCardBorderColor,
  experienceCardBorderWidthVp,
  experienceCardPressedScale,
  experienceCardRadiusVp,
  experienceGridCardMinHeightVp
} from '../data/ExperienceLayoutSpec';
import { iconLabel, iconMediaResource } from '../icons/IconSymbols';
import { appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

const DEFAULT_FEATURE_ITEM: FeatureItem = {
  id: '',
  title: '',
  titleKey: 'empty',
  icon: '',
  routeName: '',
  visibleByDefault: false
};

@Component
export struct FeatureCard {
  item: FeatureItem = DEFAULT_FEATURE_ITEM;
  action: (item: FeatureItem) => void = () => {};

  @Builder
  private iconView() {
    if (iconMediaResource(this.item.icon) !== undefined) {
      Image(iconMediaResource(this.item.icon) as Resource)
        .width(44)
        .height(44)
        .objectFit(ImageFit.Contain)
        .margin({ right: 9 })
    } else {
      Text(iconLabel(this.item.icon))
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .backgroundColor(AppColor.accent)
        .borderRadius(22)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: 9 })
    }
  }

  build() {
    Row() {
      this.iconView()
      Text(appString(this.item.titleKey))
        .fontSize(13)
        .fontColor(AppColor.textPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(2)
      if (this.item.badge || this.item.badgeKey) {
        Text(this.item.badgeKey ? appString(this.item.badgeKey) : (this.item.badge ?? ''))
          .fontSize(10)
          .fontColor(AppColor.danger)
          .fontStyle(FontStyle.Italic)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: experienceGridCardMinHeightVp })
    .padding({ left: 12, right: 10 })
    .backgroundColor(Color.White)
    .border({
      width: experienceCardBorderWidthVp,
      color: experienceCardBorderColor,
      radius: experienceCardRadiusVp
    })
    .clickEffect({
      level: ClickEffectLevel.LIGHT,
      scale: experienceCardPressedScale
    })
    .onClick(() => this.action(this.item))
  }
}
