import { MainPage } from './MainPage';
import { SplashPage } from './SplashPage';
import { shouldConsumeIndexBackPress } from '../services/splash/SplashStartupService';

@Entry
@Component
struct Index {
  @State showMainPage: boolean = false;

  onBackPress(): boolean {
    return shouldConsumeIndexBackPress(this.showMainPage);
  }

  build() {
    Column() {
      if (this.showMainPage) {
        MainPage()
      } else {
        SplashPage({
          onFinished: () => {
            this.showMainPage = true;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
