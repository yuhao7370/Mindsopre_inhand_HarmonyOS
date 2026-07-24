import { common } from '@kit.AbilityKit';
import { FrameCallback, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import router from '@ohos.router';
import { NativePageTitleBar } from '../common/components/NativePageTitleBar';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonyResultImageAssetWriter,
  HarmonyResultImagePixelMapEncoder,
  ResultImageSaveResult,
  ResultImageSaveService,
  withCallerOwnedPixelMap
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
  poetryPosterTextFromParam,
  poetryPosterVisualSpec,
  shouldStartPoetryPosterAction
} from '../services/poetry/PoetryPosterService';

class PosterStatusRevealFrameCallback extends FrameCallback {
  private readonly revealStatus: () => void;

  constructor(revealStatus: () => void) {
    super();
    this.revealStatus = revealStatus;
  }

  onFrame(_frameTimeInNano: number): void {
    this.revealStatus();
  }

  onIdle(_timeLeftInNano: number): void {
  }
}

interface PoetryPosterPageParams {
  poem?: string;
}

@Entry
@Component
struct PoetryPosterPage {
  @State poemText: string = '';
  @State statusKey: AppStringKey = 'empty';
  @State actionInFlight: boolean = false;
  @State bottomNavigationInsetVp: number = 0;
  private posterScroller: Scroller = new Scroller();
  private hostWindow?: window.Window;
  private observingBottomNavigationInset: boolean = false;

  private readonly handleAvoidAreaChange = (options: window.AvoidAreaOptions): void => {
    if (options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      this.updateBottomNavigationInset(options.area);
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as PoetryPosterPageParams;
    this.poemText = poetryPosterTextFromParam(params?.poem);
    this.startObservingBottomNavigationInset();
  }

  aboutToDisappear(): void {
    this.observingBottomNavigationInset = false;
    if (this.hostWindow) {
      this.hostWindow.off('avoidAreaChange', this.handleAvoidAreaChange);
      this.hostWindow = undefined;
    }
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private updateBottomNavigationInset(avoidArea: window.AvoidArea): void {
    this.bottomNavigationInsetVp = avoidArea.visible ?
      this.getUIContext().px2vp(avoidArea.bottomRect.height) : 0;
  }

  private startObservingBottomNavigationInset(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    this.observingBottomNavigationInset = true;
    window.getLastWindow(context)
      .then((hostWindow: window.Window) => {
        if (!this.observingBottomNavigationInset) {
          return;
        }
        this.hostWindow = hostWindow;
        this.updateBottomNavigationInset(
          hostWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        );
        hostWindow.on('avoidAreaChange', this.handleAvoidAreaChange);
      })
      .catch(() => {
        this.bottomNavigationInsetVp = 0;
      });
  }

  private setStatusAndReveal(statusKey: AppStringKey): void {
    this.statusKey = statusKey;
    this.getUIContext().postFrameCallback(new PosterStatusRevealFrameCallback(() => {
      try {
        this.posterScroller.scrollEdge(Edge.Bottom, { velocity: 1200 });
      } catch (_) {
      }
    }));
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
    return withCallerOwnedPixelMap(poster, async (snapshot: image.PixelMap | undefined) =>
      new ResultImageSaveService(
        new HarmonyResultImagePixelMapEncoder(),
        new HarmonyResultImageAssetWriter(context)
      ).save(snapshot));
  }

  private savePoster(): void {
    if (!shouldStartPoetryPosterAction(this.actionInFlight)) {
      return;
    }
    this.actionInFlight = true;
    this.setStatusAndReveal('poem_save_in_progress');
    this.savePosterImage()
      .then((result: ResultImageSaveResult) => {
        this.setStatusAndReveal(result.ok ? 'poem_save_success' : result.messageKey);
      })
      .catch(() => {
        this.setStatusAndReveal('poem_save_failed');
      })
      .finally(() => {
        this.actionInFlight = false;
      });
  }

  private sharePoster(): void {
    if (!shouldStartPoetryPosterAction(this.actionInFlight)) {
      return;
    }
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.setStatusAndReveal('poem_share_failed');
      return;
    }
    this.actionInFlight = true;
    this.setStatusAndReveal('poem_share_in_progress');
    this.savePosterImage()
      .then((saveResult: ResultImageSaveResult) => {
        if (!saveResult.ok) {
          throw new Error('Unable to save poetry poster for sharing');
        }
        return this.shareSavedPosterImage(context, saveResult.uri);
      })
      .then((shareResult: ShareImageResult) => {
        this.setStatusAndReveal(shareResult.messageKey);
      })
      .catch(() => {
        this.setStatusAndReveal('poem_share_failed');
      })
      .finally(() => {
        this.actionInFlight = false;
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
      Column() {
        Text(this.poemText)
          .fontSize(poetryPosterVisualSpec.poemTextFontSizeFp)
          .fontColor(AppColor.textPrimary)
          .textAlign(TextAlign.Center)
          .padding(poetryPosterVisualSpec.poemTextPaddingVp)
          .width('100%')
      }
      .width('100%')
      .margin({ top: poetryPosterVisualSpec.poemTopMarginVp })
      .padding({ top: AppSpacing.xs, bottom: AppSpacing.xs })
      .backgroundImage($r('app.media.poem_frame'))
      .backgroundImageSize(ImageSize.Cover)

      Row() {
        Column() {
          Image($r('app.media.poem_logo2'))
            .width(poetryPosterVisualSpec.logoWidthVp)
            .height(poetryPosterVisualSpec.logoHeightVp)
            .objectFit(ImageFit.Contain)
          Text(appString('poem_ai_credit'))
            .fontSize(poetryPosterVisualSpec.poemTextFontSizeFp)
            .fontColor(AppColor.textSecondary)
            .margin({ top: AppSpacing.xs })
        }
        .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

        Image($r('app.media.my_qr_code'))
          .width(poetryPosterVisualSpec.qrCodeSizeVp)
          .height(poetryPosterVisualSpec.qrCodeSizeVp)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: AppSpacing.xl })
    }
    .id(poetryPosterComponentId)
    .width('100%')
    .constraintSize({
      minHeight: poetryPosterVisualSpec.posterMinHeightVp,
      maxWidth: poetryPosterVisualSpec.posterMaxWidthVp
    })
    .padding(poetryPosterVisualSpec.outerPaddingVp)
    .backgroundImage($r('app.media.poem_bg'))
    .backgroundImageSize(ImageSize.Cover)
  }

  build() {
    Column() {
      NativePageTitleBar({
        title: appString('title_intelligent_poetry'),
        onBack: () => router.back()
      })

      Scroll(this.posterScroller) {
        Column() {
          this.posterCard()

          Column({ space: AppSpacing.md }) {
            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              text: SaveDescription.SAVE_IMAGE,
              buttonType: ButtonType.Capsule
            })
              .width('100%')
              .height(48)
              .enabled(!this.actionInFlight)
              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.savePoster();
                  return;
                }
                this.setStatusAndReveal('poem_save_failed');
              })

            Button(appString('poem_share_poster'))
              .width('100%')
              .height(48)
              .enabled(!this.actionInFlight)
              .backgroundColor(AppColor.cardBackground)
              .fontColor(AppColor.accent)
              .border({ width: 1, color: AppColor.accent, radius: AppRadius.button })
              .onClick(() => this.sharePoster())
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
          .margin({ top: AppSpacing.lg })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: AppSpacing.page,
          right: AppSpacing.page,
          top: AppSpacing.page,
          bottom: AppSpacing.page + this.bottomNavigationInsetVp
        })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
