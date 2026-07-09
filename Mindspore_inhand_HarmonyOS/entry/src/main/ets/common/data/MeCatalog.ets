import { AppStringKey } from '../i18n/AppStrings';

export interface MeItem {
  readonly id: string;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly icon: string;
  readonly visibleByDefault: boolean;
}

export const meItems: MeItem[] = [
  { id: 'share', title: 'Share', titleKey: 'me_share_title', icon: 'share', visibleByDefault: false },
  { id: 'qr', title: 'My QR Code', titleKey: 'me_my_qr_code', icon: 'qr', visibleByDefault: false },
  { id: 'star', title: 'Star', titleKey: 'me_up_title', icon: 'star', visibleByDefault: false },
  { id: 'official', title: 'Official Website', titleKey: 'me_official_title', icon: 'official', visibleByDefault: false },
  { id: 'code', title: 'Code', titleKey: 'me_official_code_title', icon: 'code', visibleByDefault: false },
  { id: 'feedback', title: 'FeedBack', titleKey: 'me_qa_title', icon: 'feedback', visibleByDefault: false },
  { id: 'version', title: 'Version', titleKey: 'me_version_title', icon: 'version', visibleByDefault: true }
];

export const visibleMeItems: MeItem[] = meItems.filter((item: MeItem) => item.visibleByDefault);
