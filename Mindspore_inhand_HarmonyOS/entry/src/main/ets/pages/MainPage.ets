import { MainTab, mainTabs } from '../app/AppState';
import { BottomTabBar } from '../common/components/BottomTabBar';
import { AppColor } from '../common/theme/AppTheme';
import { ExperiencePage } from './ExperiencePage';
import { MePage } from './MePage';

@Component
export struct MainPage {
  @State selectedTab: MainTab = MainTab.EXPERIENCE;

  build() {
    Column() {
      Stack() {
        ExperiencePage()
          .visibility(this.selectedTab === MainTab.EXPERIENCE ? Visibility.Visible : Visibility.Hidden)
          .hitTestBehavior(this.selectedTab === MainTab.EXPERIENCE ? HitTestMode.Default : HitTestMode.None)
        MePage()
          .visibility(this.selectedTab === MainTab.ME ? Visibility.Visible : Visibility.Hidden)
          .hitTestBehavior(this.selectedTab === MainTab.ME ? HitTestMode.Default : HitTestMode.None)
      }
      .layoutWeight(1)
      .width('100%')

      BottomTabBar({
        selected: this.selectedTab,
        tabs: mainTabs,
        onChange: (tab: MainTab) => {
          this.selectedTab = tab;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
