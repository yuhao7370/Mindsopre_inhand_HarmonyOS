import { MainTab, TabItem } from '../../app/AppState';
import { iconLabel } from '../icons/IconSymbols';
import { appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

@Component
export struct BottomTabBar {
  @Prop selected: MainTab;
  tabs: TabItem[] = [];
  onChange: (tab: MainTab) => void = () => {};

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabItem) => {
        Column() {
          Text(iconLabel(tab.icon))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .fontColor(this.selected === tab.id ? Color.White : AppColor.textSecondary)
            .backgroundColor(this.selected === tab.id ? AppColor.accent : '#F0F3FF')
            .borderRadius(12)
          Text(appString(tab.titleKey))
            .fontSize(13)
            .maxLines(1)
            .fontColor(this.selected === tab.id ? AppColor.accent : AppColor.textSecondary)
        }
        .layoutWeight(1)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.onChange(tab.id))
      }, (tab: TabItem) => `${tab.id}`)
    }
    .width('100%')
    .height(56)
    .backgroundColor(AppColor.cardBackground)
  }
}
