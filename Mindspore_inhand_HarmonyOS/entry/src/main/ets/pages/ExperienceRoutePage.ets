import { AppColor } from '../common/theme/AppTheme';
import { ExperiencePage } from './ExperiencePage';

@Entry
@Component
struct ExperienceRoutePage {
  build() {
    Column() {
      ExperiencePage()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
