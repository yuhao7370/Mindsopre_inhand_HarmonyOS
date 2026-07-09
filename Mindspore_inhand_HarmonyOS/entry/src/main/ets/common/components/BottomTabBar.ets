import { MainTab, TabItem } from '../../app/AppState';
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
          Text(tab.icon)
            .fontSize(22)
            .fontColor(this.selected === tab.id ? AppColor.accent : AppColor.textSecondary)
          Text(tab.title)
            .fontSize(13)
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
