import { FeatureItem } from '../data/FeatureCatalog';
import { AppColor, AppRadius } from '../theme/AppTheme';

const DEFAULT_FEATURE_ITEM: FeatureItem = {
  id: '',
  title: '',
  icon: '',
  routeName: '',
  visibleByDefault: false
};

@Component
export struct FeatureCard {
  item: FeatureItem = DEFAULT_FEATURE_ITEM;
  action: (item: FeatureItem) => void = () => {};

  build() {
    Row() {
      Text(this.item.icon)
        .fontSize(24)
        .width(34)
      Text(this.item.title)
        .fontSize(14)
        .fontColor(AppColor.textPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
      if (this.item.badge) {
        Text(this.item.badge)
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
