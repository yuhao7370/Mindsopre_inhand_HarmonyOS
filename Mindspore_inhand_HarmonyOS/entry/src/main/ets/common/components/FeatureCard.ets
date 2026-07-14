import { FeatureItem } from '../data/FeatureCatalog';
import { experienceGridCardHeightVp } from '../data/ExperienceLayoutSpec';
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
        .width(28)
        .height(22)
        .objectFit(ImageFit.Contain)
        .margin({ right: 5 })
    } else {
      Text(iconLabel(this.item.icon))
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(28)
        .height(22)
        .backgroundColor(AppColor.accent)
        .borderRadius(11)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: 5 })
    }
  }

  build() {
    Row() {
      this.iconView()
      Text(appString(this.item.titleKey))
        .fontSize(12)
        .fontColor('#333333')
        .fontWeight(FontWeight.Normal)
        .layoutWeight(1)
        .maxLines(1)
      if (this.item.badge || this.item.badgeKey) {
        Text(this.item.badgeKey ? appString(this.item.badgeKey) : (this.item.badge ?? ''))
          .fontSize(10)
          .fontColor(AppColor.danger)
          .fontStyle(FontStyle.Italic)
      }
    }
    .width('100%')
    .height(experienceGridCardHeightVp)
    .padding({ left: 4, right: 4 })
    .backgroundColor(Color.Transparent)
    .border({ width: 1, color: '#E6E6E6', radius: 5 })
    .onClick(() => this.action(this.item))
  }
}
