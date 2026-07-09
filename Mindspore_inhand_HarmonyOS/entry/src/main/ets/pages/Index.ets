import { MainPage } from './MainPage';
import { SplashPage } from './SplashPage';

@Entry
@Component
struct Index {
  @State showMainPage: boolean = false;

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
