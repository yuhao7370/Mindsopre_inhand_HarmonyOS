import { MainTab, mainTabIconMediaResource, TabItem } from '../../app/AppState';
import { bottomTabBarMinHeightVp, bottomTabItemMinHeightVp } from '../data/BottomTabBarLayoutSpec';
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
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
          Text(appString(tab.titleKey))
            .fontSize(11)
            .fontColor(this.selected === tab.id ? AppColor.accent : AppColor.textSecondary)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: bottomTabItemMinHeightVp })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.selected === tab.id ? '#EEF3FF' : Color.Transparent)
        .borderRadius(18)
        .margin({ top: 6, bottom: 6, left: 4, right: 4 })
        .onClick(() => this.onChange(tab.id))
      }, (tab: TabItem) => `${tab.id}`)
    }
    .width('90%')
    .constraintSize({ minHeight: bottomTabBarMinHeightVp })
    .margin({ top: 6, bottom: 8 })
    .borderRadius(31)
    .border({ width: 1, color: '#E7ECF6' })
    .shadow({ radius: 14, color: '#180D3B80', offsetX: 0, offsetY: 5 })
    .backgroundColor(AppColor.cardBackground)
  }
}
