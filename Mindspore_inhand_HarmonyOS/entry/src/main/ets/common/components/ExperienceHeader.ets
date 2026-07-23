import { experienceHeaderHeightVp } from '../data/ExperienceHeaderBranding';
import { appString } from '../i18n/AppStrings';

@Component
export struct ExperienceHeader {
  build() {
    Stack() {
      Image($r('app.media.experience_hero_harmony'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Row()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 90,
          colors: [['#D91667E8', 0], ['#A0308DF1', 0.56], ['#7068B8FF', 1]]
        })
      Column() {
        Text(appString('experience_head_title'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
        Text(appString('experience_head_subtitle'))
          .fontSize(13)
          .fontColor('#E6FFFFFF')
          .maxLines(2)
          .margin({ top: 6 })
      }
      .width('62%')
      .alignItems(HorizontalAlign.Start)
      .position({ x: 20, y: 28 })
    }
    .width('100%')
    .height(experienceHeaderHeightVp)
  }
}
