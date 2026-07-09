import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { GradientTitleBar } from '../common/components/GradientTitleBar';
import { SectionTitle } from '../common/components/SectionTitle';
import { MeItem, isMeItemPageNavigable, isMeItemUrlNavigable, visibleMeItems } from '../common/data/MeCatalog';
import { webPagePath } from '../common/data/WebDestination';
import { iconLabel } from '../common/icons/IconSymbols';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { AppVersionService } from '../services/app/AppVersionService';
import {
  HarmonySystemShareTextWriter,
  ShareService,
  mindSporeInhandShareText
} from '../services/share/ShareService';

@Component
export struct MePage {
  @State versionLabel: string = 'V1.0.0';
  @State statusKey: AppStringKey = 'empty';

  aboutToAppear() {
    this.versionLabel = new AppVersionService().currentVersionLabel();
  }

  private openItem(item: MeItem): void {
    if (item.id === 'share') {
      this.shareApp();
      return;
    }
    if (isMeItemPageNavigable(item)) {
      router.pushUrl({
        url: item.page ?? '',
        params: {
          titleKey: item.titleKey
        }
      });
      return;
    }
    if (!isMeItemUrlNavigable(item)) {
      return;
    }
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: item.titleKey,
        url: item.url ?? ''
      }
    });
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private shareApp(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'me_share_failed';
      return;
    }

    this.shareAppWithContext(context).catch(() => {
      this.statusKey = 'me_share_failed';
    });
  }

  private async shareAppWithContext(context: common.UIAbilityContext): Promise<void> {
    const title = await context.resourceManager.getStringValue($r('app.string.title_share').id);
    const recommendation = await context.resourceManager.getStringValue($r('app.string.title_share_commend').id);
    const result = await new ShareService(new HarmonySystemShareTextWriter(context)).shareText({
      title: title,
      text: mindSporeInhandShareText(recommendation)
    });
    this.statusKey = result.messageKey;
  }

  private valueForItem(item: MeItem): string {
    if (item.id === 'version') {
      return this.versionLabel;
    }
    return '';
  }

  @Builder
  meRow(item: MeItem) {
    Row() {
      Text(iconLabel(item.icon))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(32)
        .height(32)
        .backgroundColor(AppColor.accent)
        .borderRadius(16)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: 8 })
      Text(appString(item.titleKey))
        .fontSize(15)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(1)
      Text(this.valueForItem(item))
        .fontSize(13)
        .fontColor(AppColor.textSecondary)
      if (isMeItemUrlNavigable(item) || isMeItemPageNavigable(item)) {
        Text('>')
          .fontSize(14)
          .fontColor(AppColor.textMuted)
          .margin({ left: AppSpacing.sm })
      }
    }
    .width('100%')
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.md })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => this.openItem(item))
  }

  build() {
    Scroll() {
      Column() {
        GradientTitleBar({
          titleKey: 'me_head_title',
          subtitleKey: 'me_head_subtitle'
        })
        Column() {
          SectionTitle({ titleKey: 'account_title' })
          Column() {
            ForEach(visibleMeItems, (item: MeItem) => {
              Column() {
                this.meRow(item)
              }
                .margin({ top: AppSpacing.md })
            }, (item: MeItem) => item.id)
          }
          if (this.statusKey !== 'empty') {
            Text(appString(this.statusKey))
              .fontSize(13)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ top: AppSpacing.md })
          }
        }
        .width('100%')
        .padding(AppSpacing.page)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.pageBackground)
  }
}
