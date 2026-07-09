import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonyQrCodeAssetWriter,
  HarmonyQrCodeMediaReader,
  QrCodeSaveResult,
  QrCodeSaveService
} from '../services/media/QrCodeSaveService';

interface QrCodePageParams {
  titleKey?: AppStringKey;
}

@Entry
@Component
struct QrCodePage {
  @State titleKey: AppStringKey = 'me_my_qr_code';
  @State statusKey: AppStringKey = 'empty';

  aboutToAppear() {
    const params = router.getParams() as QrCodePageParams;
    this.titleKey = params?.titleKey ?? 'me_my_qr_code';
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private saveQrCodeImage(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'qr_code_save_failed';
      return;
    }

    new QrCodeSaveService(
      new HarmonyQrCodeMediaReader(context.resourceManager, $r('app.media.my_qr_code')),
      new HarmonyQrCodeAssetWriter(context)
    ).save()
      .then((result: QrCodeSaveResult) => {
        this.statusKey = result.messageKey;
      })
      .catch(() => {
        this.statusKey = 'qr_code_save_failed';
      });
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
        Text(appString(this.titleKey))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.md, right: AppSpacing.md })
      .backgroundColor(AppColor.cardBackground)

      Column() {
        Image($r('app.media.my_qr_code'))
          .width('78%')
          .aspectRatio(1)
          .objectFit(ImageFit.Contain)

        Row() {
          SaveButton({
            icon: SaveIconStyle.FULL_FILLED,
            text: SaveDescription.SAVE_IMAGE,
            buttonType: ButtonType.Capsule
          })
            .height(44)
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
              if (result === SaveButtonOnClickResult.SUCCESS) {
                this.saveQrCodeImage();
                return;
              }
              this.statusKey = 'qr_code_save_failed';
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
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
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
