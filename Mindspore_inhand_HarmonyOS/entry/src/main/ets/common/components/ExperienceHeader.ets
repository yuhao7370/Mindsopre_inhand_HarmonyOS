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
          colors: [['#A81156C9', 0], ['#241B68D9', 0.55], ['#001B68D9', 1]]
        })
      Column() {
        Text(appString('experience_head_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Start)
          .maxLines(1)
        Text(appString('experience_head_subtitle'))
          .fontSize(13)
          .fontColor('#E6FFFFFF')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .margin({ top: 10 })
      }
      .width('56%')
      .alignItems(HorizontalAlign.Start)
      .position({ x: 24, y: 44 })
    }
    .width('100%')
    .height(experienceHeaderHeightVp)
  }
}
