import { AppStringKey } from '../i18n/AppStrings';
import { collegeSummaryDialogTitleKey } from './CollegeCatalog';

export type CollegeSummaryDialogContentAlignment = 'start' | 'center';

export interface CollegeSummaryDialogSpec {
  readonly titleKey: AppStringKey;
  readonly contentKey: AppStringKey;
  readonly confirmKey: AppStringKey;
  readonly contentAlignment: CollegeSummaryDialogContentAlignment;
  readonly showBottomLogo: boolean;
  readonly logoMedia: string;
}

export const collegeSummaryDialogLogoMedia: string = 'app.media.logo_with_title';

export function androidCollegeSummaryDialogSpec(): CollegeSummaryDialogSpec {
  return {
    titleKey: collegeSummaryDialogTitleKey,
    contentKey: 'college_dialog_content',
    confirmKey: 'dialog_btn_confirm',
    contentAlignment: 'start',
    showBottomLogo: true,
    logoMedia: collegeSummaryDialogLogoMedia
  };
}
