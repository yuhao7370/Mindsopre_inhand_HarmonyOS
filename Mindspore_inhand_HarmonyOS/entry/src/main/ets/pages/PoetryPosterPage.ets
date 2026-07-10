import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import router from '@ohos.router';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonyResultImageAssetWriter,
  HarmonyResultImagePixelMapEncoder,
  ResultImageSaveResult,
  ResultImageSaveService
} from '../services/media/ResultImageSaveService';
import {
  HarmonySystemShareImageWriter,
  HarmonySystemShareTextWriter,
  ShareImageResult,
  ShareService
} from '../services/share/ShareService';
import {
  poetryPosterComponentId,
  poetryPosterImageSharePayload,
  poetryPosterTextFromParam
} from '../services/poetry/PoetryPosterService';

interface PoetryPosterPageParams {
  poem?: string;
}

@Entry
@Component
struct PoetryPosterPage {
  @State poemText: string = '';
  @State statusKey: AppStringKey = 'empty';

  aboutToAppear() {
    const params = router.getParams() as PoetryPosterPageParams;
    this.poemText = poetryPosterTextFromParam(params?.poem);
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private async posterPixelMap(): Promise<image.PixelMap | undefined> {
    try {
      return await componentSnapshot.get(poetryPosterComponentId, { waitUntilRenderFinished: true });
    } catch (_) {
      return undefined;
    }
  }

  private async savePosterImage(): Promise<ResultImageSaveResult> {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return { ok: false, uri: '', messageKey: 'poem_save_failed' };
    }
    const poster = await this.posterPixelMap();
    return new ResultImageSaveService(
      new HarmonyResultImagePixelMapEncoder(),
      new HarmonyResultImageAssetWriter(context)
    ).save(poster);
  }

  private savePoster(): void {
    this.savePosterImage()
      .then((result: ResultImageSaveResult) => {
        this.statusKey = result.ok ? 'poem_save_success' : result.messageKey;
      })
      .catch(() => {
        this.statusKey = 'poem_save_failed';
      });
  }

  private sharePoster(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'poem_share_failed';
      return;
    }
    this.savePosterImage()
      .then((saveResult: ResultImageSaveResult) => {
        if (!saveResult.ok) {
          this.statusKey = 'poem_share_failed';
          return;
        }
        this.shareSavedPosterImage(context, saveResult.uri)
          .then((shareResult: ShareImageResult) => {
            this.statusKey = shareResult.messageKey;
          })
          .catch(() => {
            this.statusKey = 'poem_share_failed';
          });
      })
      .catch(() => {
        this.statusKey = 'poem_share_failed';
      });
  }

  private async shareSavedPosterImage(context: common.UIAbilityContext, uri: string): Promise<ShareImageResult> {
    const title = await context.resourceManager.getStringValue($r('app.string.title_intelligent_poetry').id);
    const description = await context.resourceManager.getStringValue($r('app.string.poem_ai_credit').id);
    return new ShareService(
      new HarmonySystemShareTextWriter(context),
      new HarmonySystemShareImageWriter(context)
    ).shareImage(poetryPosterImageSharePayload(uri, title, description));
  }

  @Builder
  posterCard() {
    Column() {
      Text(this.poemText)
        .fontSize(16)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(28)
        .padding({ left: AppSpacing.xl, right: AppSpacing.xl, top: 44, bottom: 44 })
        .width('100%')
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#D8C7A4', radius: AppRadius.card })

      Row() {
        Column() {
          Text('MindSpore')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.primary)
          Text(appString('poem_ai_credit'))
            .fontSize(13)
            .fontColor(AppColor.textMuted)
            .margin({ top: AppSpacing.xs })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.my_qr_code'))
          .width(72)
          .height(72)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: AppSpacing.xl })
    }
    .id(poetryPosterComponentId)
    .width('100%')
    .padding(AppSpacing.xl)
    .linearGradient({
      angle: 180,
      colors: [['#F8F0DC', 0], ['#FFFFFF', 1]]
    })
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(24)
          .fontColor(AppColor.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text(appString('title_intelligent_poetry'))
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

      Scroll() {
        Column() {
          this.posterCard()

          Row() {
            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              text: SaveDescription.SAVE_IMAGE,
              buttonType: ButtonType.Capsule
            })
              .height(44)
              .width('48%')
              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.savePoster();
                  return;
                }
                this.statusKey = 'poem_save_failed';
              })

            Button(appString('poem_share_poster'))
              .height(44)
              .width('48%')
              .backgroundColor(AppColor.cardBackground)
              .fontColor(AppColor.accent)
              .border({ width: 1, color: AppColor.accent, radius: AppRadius.button })
              .onClick(() => this.sharePoster())
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: AppSpacing.lg })

          if (this.statusKey !== 'empty') {
            Text(appString(this.statusKey))
              .fontSize(14)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ top: AppSpacing.md })
              .padding({ left: AppSpacing.lg, right: AppSpacing.lg })
          }
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
