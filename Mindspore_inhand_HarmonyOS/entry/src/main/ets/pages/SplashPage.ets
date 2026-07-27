import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { splashLogoHeightVp, splashLogoWidthVp } from '../common/data/SplashBranding';
import { userPrivacyRulesUrl, webPagePath } from '../common/data/WebDestination';
import { appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  HarmonyPrivacyConsentStore,
  PrivacyConsentService
} from '../services/storage/PrivacyConsentService';

@Component
export struct SplashPage {
  onFinished: () => void = () => {};
  private consentService: PrivacyConsentService | undefined = undefined;
  @State showPrivacyDialog: boolean = false;

  aboutToAppear() {
    const service = this.privacyConsentService();
    if (service !== undefined && service.hasAcceptedPrivacy()) {
      this.onFinished();
      return;
    }
    this.showPrivacyDialog = true;
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private privacyConsentService(): PrivacyConsentService | undefined {
    if (this.consentService !== undefined) {
      return this.consentService;
    }
    try {
      const context = this.uiAbilityContext();
      if (context === undefined) {
        return undefined;
      }
      this.consentService = new PrivacyConsentService(new HarmonyPrivacyConsentStore(context));
      return this.consentService;
    } catch (_) {
      return undefined;
    }
  }

  private finishSplash(): void {
    this.onFinished();
  }

  private acceptPrivacy(): void {
    const service = this.privacyConsentService();
    if (service !== undefined) {
      service.acceptPrivacy();
    }
    this.showPrivacyDialog = false;
    this.finishSplash();
  }

  private declinePrivacy(): void {
    const service = this.privacyConsentService();
    if (service !== undefined) {
      service.declinePrivacy();
    }
    const context = this.uiAbilityContext();
    if (context !== undefined) {
      context.terminateSelf();
    }
  }

  private openPrivacyPolicy(): void {
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: 'me_user_agreements',
        url: userPrivacyRulesUrl
      }
    });
  }

  @Builder
  privacyDialog() {
    Column() {
      Scroll() {
        Column() {
        Text(appString('me_user_agreements'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text(appString('me_privacy'))
          .fontSize(13)
          .fontColor(AppColor.textSecondary)
          .lineHeight(20)
          .width('100%')
          .margin({ top: AppSpacing.md })
        Button(appString('me_user_agreement'), { type: ButtonType.Normal })
          .constraintSize({ minHeight: 48 })
          .fontSize(13)
          .fontColor(AppColor.textAccent)
          .backgroundColor(AppColor.cardBackground)
          .width('100%')
          .accessibilityText(appString('me_user_agreement') as Resource)
          .onClick(() => this.openPrivacyPolicy())
        Button(appString('me_disagree_and_exit'), { type: ButtonType.Normal })
          .constraintSize({ minHeight: 48 })
          .width('100%')
          .margin({ top: AppSpacing.md })
          .onClick(() => this.declinePrivacy())
        Button(appString('me_agree'))
          .constraintSize({ minHeight: 48 })
          .width('100%')
          .margin({ top: AppSpacing.sm })
          .onClick(() => this.acceptPrivacy())
        }
        .width('100%')
        .padding(AppSpacing.lg)
      }
      .width('86%')
      .height('82%')
      .backgroundColor(AppColor.cardBackground)
      .borderRadius(AppRadius.sheet)
      .accessibilityGroup(true)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  build() {
    Stack() {
      Column() {
        Image($r('app.media.logo_splash'))
          .width(splashLogoWidthVp)
          .height(splashLogoHeightVp)
          .objectFit(ImageFit.Contain)
          .margin({ top: 88 })
        Text(appString('EntryAbility_label'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .margin({ top: AppSpacing.xl })
        Text(appString('title_splash_welcome'))
          .fontSize(15)
          .fontColor(AppColor.textSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(22)
          .width('78%')
          .margin({ top: AppSpacing.md })
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColor.pageBackground)
      .accessibilityLevel(this.showPrivacyDialog ? 'no-hide-descendants' : 'auto')
      if (this.showPrivacyDialog) {
        this.privacyDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
