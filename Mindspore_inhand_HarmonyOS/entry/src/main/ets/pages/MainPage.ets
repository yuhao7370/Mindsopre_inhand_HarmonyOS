import { MainTab, mainTabs } from '../app/AppState';
import { BottomTabBar } from '../common/components/BottomTabBar';
import { AppColor } from '../common/theme/AppTheme';
import { CollegePage } from './CollegePage';
import { ExperiencePage } from './ExperiencePage';
import { MePage } from './MePage';

@Component
export struct MainPage {
  @State selectedTab: MainTab = MainTab.EXPERIENCE;

  @Builder
  currentPageBuilder() {
    if (this.selectedTab === MainTab.EXPERIENCE) {
      ExperiencePage();
    } else if (this.selectedTab === MainTab.COLLEGE) {
      CollegePage();
    } else {
      MePage();
    }
  }

  build() {
    Column() {
      Column() {
        this.currentPageBuilder()
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
