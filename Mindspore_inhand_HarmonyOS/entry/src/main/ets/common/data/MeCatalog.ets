import { AppStringKey } from '../i18n/AppStrings';
import {
  meCodeUrl,
  meHelpUrl,
  meStarUrl,
  mindSporeBaseUrl,
  userPrivacyRulesUrl
} from './WebDestination';

export interface MeItem {
  readonly id: string;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly icon: string;
  readonly visibleByDefault: boolean;
  readonly url?: string;
}

export const meItems: MeItem[] = [
  { id: 'share', title: 'Share', titleKey: 'me_share_title', icon: 'share', visibleByDefault: false },
  { id: 'qr', title: 'My QR Code', titleKey: 'me_my_qr_code', icon: 'qr', visibleByDefault: false },
  { id: 'star', title: 'Star', titleKey: 'me_up_title', icon: 'star', visibleByDefault: true, url: meStarUrl },
  { id: 'official', title: 'Official Website', titleKey: 'me_official_title', icon: 'official', visibleByDefault: true, url: mindSporeBaseUrl },
  { id: 'code', title: 'Code', titleKey: 'me_official_code_title', icon: 'code', visibleByDefault: true, url: meCodeUrl },
  { id: 'feedback', title: 'FeedBack', titleKey: 'me_qa_title', icon: 'feedback', visibleByDefault: true, url: meHelpUrl },
  { id: 'version', title: 'Version', titleKey: 'me_version_title', icon: 'version', visibleByDefault: true },
  { id: 'privacy', title: 'User Agreement and Privacy Policy', titleKey: 'me_user_agreements', icon: 'privacy', visibleByDefault: true, url: userPrivacyRulesUrl }
];

export const visibleMeItems: MeItem[] = meItems.filter((item: MeItem) => item.visibleByDefault);

export function isMeItemUrlNavigable(item: MeItem): boolean {
  return item.url !== undefined && item.url.length > 0;
}
