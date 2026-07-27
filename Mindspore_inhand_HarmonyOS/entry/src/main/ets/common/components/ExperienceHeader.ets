import { experienceHeaderMinHeightVp } from '../data/ExperienceHeaderBranding';
import { appString } from '../i18n/AppStrings';

@Component
export struct ExperienceHeader {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column() {
          Text(appString('experience_head_title'))
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(appString('experience_head_subtitle'))
            .fontSize(13)
            .fontColor('#E6FFFFFF')
            .margin({ top: 6 })
        }
        .width('62%')
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 20 })
      }
      .width('100%')
      .constraintSize({ minHeight: experienceHeaderMinHeightVp })
      .padding({ top: 28, bottom: 28 })
      .alignItems(HorizontalAlign.Start)
      .linearGradient({
        angle: 90,
        colors: [['#D91667E8', 0], ['#A0308DF1', 0.56], ['#7068B8FF', 1]]
      })
    }
    .width('100%')
    .constraintSize({ minHeight: experienceHeaderMinHeightVp })
    .backgroundImage($r('app.media.experience_hero_harmony'))
    .backgroundImageSize(ImageSize.Cover)
  }
}
