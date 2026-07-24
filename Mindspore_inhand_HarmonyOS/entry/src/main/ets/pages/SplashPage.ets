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
  private countdownTimer: number = -1;
  @State countdownValue: number = 3;
  @State showPrivacyDialog: boolean = false;

  aboutToAppear() {
    const service = this.privacyConsentService();
    if (service !== undefined && service.hasAcceptedPrivacy()) {
      this.startCountdown();
      return;
    }
    this.showPrivacyDialog = true;
  }

  aboutToDisappear() {
    this.stopCountdown();
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

  private startCountdown(): void {
    this.stopCountdown();
    this.countdownValue = 3;
    this.countdownTimer = setInterval(() => {
      if (this.countdownValue <= 1) {
        this.finishSplash();
        return;
      }
      this.countdownValue -= 1;
    }, 1000);
  }

  private stopCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private finishSplash(): void {
    this.stopCountdown();
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
  countdownButton() {
    Row() {
      Text(`${this.countdownValue}`)
        .fontSize(14)
        .fontColor(AppColor.accent)
        .fontWeight(FontWeight.Bold)
      Text(appString('splash_count_down'))
        .fontSize(14)
        .fontColor(AppColor.accent)
    }
    .height(34)
    .padding({ left: AppSpacing.md, right: AppSpacing.md })
    .border({ width: 1, color: AppColor.accent, radius: 17 })
    .onClick(() => this.finishSplash())
  }

  @Builder
  privacyDialog() {
    Column() {
      Column() {
        Text(appString('me_user_agreements'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)
        Scroll() {
          Text(appString('me_privacy'))
            .fontSize(13)
            .fontColor(AppColor.textSecondary)
            .lineHeight(20)
            .width('100%')
        }
        .height(180)
        .margin({ top: AppSpacing.md })
        Text(appString('me_user_agreement'))
          .fontSize(13)
          .fontColor(AppColor.accent)
          .textAlign(TextAlign.Center)
          .margin({ top: AppSpacing.sm })
          .onClick(() => this.openPrivacyPolicy())
        Row() {
          Button(appString('me_disagree_and_exit'))
            .height(38)
            .layoutWeight(1)
            .margin({ right: AppSpacing.sm })
            .onClick(() => this.declinePrivacy())
          Button(appString('me_agree'))
            .height(38)
            .layoutWeight(1)
            .onClick(() => this.acceptPrivacy())
        }
        .width('100%')
        .margin({ top: AppSpacing.lg })
      }
      .width('86%')
      .padding(AppSpacing.lg)
      .backgroundColor(AppColor.cardBackground)
      .borderRadius(AppRadius.sheet)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Blank()
          this.countdownButton()
        }
        .width('100%')
        .padding({ top: AppSpacing.lg, right: AppSpacing.lg })
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
      if (this.showPrivacyDialog) {
        this.privacyDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
