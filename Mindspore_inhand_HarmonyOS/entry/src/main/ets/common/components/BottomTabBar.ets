import { MainTab, mainTabIconMediaResource, TabItem } from '../../app/AppState';
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
          Image(mainTabIconMediaResource(tab, this.selected === tab.id))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
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
