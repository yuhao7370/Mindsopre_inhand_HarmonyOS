import { FeatureItem } from '../data/FeatureCatalog';
import { iconLabel, iconMediaResource } from '../icons/IconSymbols';
import { appString } from '../i18n/AppStrings';
import { AppColor, AppRadius } from '../theme/AppTheme';

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
        .width(32)
        .height(32)
        .objectFit(ImageFit.Contain)
        .margin({ right: 8 })
    } else {
      Text(iconLabel(this.item.icon))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(32)
        .height(32)
        .backgroundColor(AppColor.accent)
        .borderRadius(16)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: 8 })
    }
  }

  build() {
    Row() {
      this.iconView()
      Text(appString(this.item.titleKey))
        .fontSize(14)
        .fontColor(AppColor.textPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
      if (this.item.badge || this.item.badgeKey) {
        Text(this.item.badgeKey ? appString(this.item.badgeKey) : (this.item.badge ?? ''))
          .fontSize(10)
          .fontColor(AppColor.danger)
          .fontStyle(FontStyle.Italic)
      }
    }
    .height(58)
    .padding({ left: 10, right: 10 })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => this.action(this.item))
  }
}
