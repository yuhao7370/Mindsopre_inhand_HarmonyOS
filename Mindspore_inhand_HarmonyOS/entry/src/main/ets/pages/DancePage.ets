import router from '@ohos.router';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  danceResultMessageKey,
  danceScoreText,
  danceTemplateDemoScore
} from '../services/dance/DancePageService';

@Entry
@Component
struct DancePage {
  @State scoreText: string = '--';
  @State resultMessageKey: AppStringKey = 'empty';
  @State hasResult: boolean = false;

  private runTemplateDemo(): void {
    const score = danceTemplateDemoScore();
    this.scoreText = danceScoreText(score);
    this.resultMessageKey = danceResultMessageKey(score);
    this.hasResult = true;
  }

  private reset(): void {
    this.scoreText = '--';
    this.resultMessageKey = 'empty';
    this.hasResult = false;
  }

  @Builder
  header() {
    Row() {
      Text('<')
        .fontSize(24)
        .fontColor(AppColor.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => router.back())
      Text(appString('title_dance'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .height(56)
    .padding({ left: AppSpacing.md, right: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
  }

  @Builder
  preparePanel() {
    Column() {
      Image($r('app.media.skeleton_template'))
        .width(132)
        .aspectRatio(135 / 169)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: AppSpacing.lg })

      Text(appString('dance_prepare_summary'))
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(22)

      Button(appString('dance_start_demo'))
        .width('100%')
        .height(44)
        .margin({ top: AppSpacing.xl })
        .onClick(() => this.runTemplateDemo())
    }
    .width('100%')
    .padding(AppSpacing.xl)
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
  }

  @Builder
  resultPanel() {
    Column() {
      Text(appString('dance_result_title'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
      Text(this.scoreText)
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accent)
        .margin({ top: AppSpacing.sm })
      Text(appString(this.resultMessageKey))
        .fontSize(16)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .margin({ top: AppSpacing.sm })
      Button(appString('dance_start_demo'))
        .width('100%')
        .height(40)
        .margin({ top: AppSpacing.lg })
        .onClick(() => this.runTemplateDemo())
      Button(appString('dance_reset'))
        .width('100%')
        .height(40)
        .margin({ top: AppSpacing.sm })
        .backgroundColor(AppColor.cardBackground)
        .fontColor(AppColor.accent)
        .border({ width: 1, color: AppColor.accent, radius: AppRadius.button })
        .onClick(() => this.reset())
    }
    .width('100%')
    .padding(AppSpacing.xl)
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .margin({ top: AppSpacing.lg })
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column() {
          this.preparePanel()
          if (this.hasResult) {
            this.resultPanel()
          }
          Text(appString('dance_platform_note'))
            .fontSize(12)
            .fontColor(AppColor.textMuted)
            .lineHeight(18)
            .textAlign(TextAlign.Center)
            .margin({ top: AppSpacing.lg })
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
