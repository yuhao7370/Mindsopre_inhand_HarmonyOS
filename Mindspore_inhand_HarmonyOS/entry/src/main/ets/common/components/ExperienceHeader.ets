import { experienceHeaderHeightVp } from '../data/ExperienceHeaderBranding';
import { appString } from '../i18n/AppStrings';

@Component
export struct ExperienceHeader {
  build() {
    Stack() {
      Image($r('app.media.experience_head'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        Text(appString('experience_head_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(appString('experience_head_subtitle'))
          .fontSize(13)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .margin({ top: 22 })
          .padding({ left: 20, right: 20 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ top: 40 })
    }
    .width('100%')
    .height(experienceHeaderHeightVp)
  }
}
