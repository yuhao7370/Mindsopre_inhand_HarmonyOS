import { AppStringKey } from '../i18n/AppStrings';
import {
  collegeMainAskUrl,
  collegeMainCloudUrl,
  collegeMainFaqUrl,
  collegeQuickAppUrl,
  collegeQuickExecuteUrl,
  collegeQuickTrainUrl,
  collegeQuickVideoUrl
} from './WebDestination';

export type CollegeItemType = 'link' | 'quickStart' | 'summary' | 'footer';

export interface CollegeQuickAction {
  readonly id: string;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly icon: string;
  readonly url: string;
}

export interface CollegeItem {
  readonly id: string;
  readonly type: CollegeItemType;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly icon: string;
  readonly url?: string;
  readonly quickActions?: CollegeQuickAction[];
}

export const collegeItems: CollegeItem[] = [
  { id: 'summary', type: 'summary', title: 'MindSpore Summary', titleKey: 'college_summary_title', icon: 'summary' },
  { id: 'cloud', type: 'link', title: 'A One-Hour Trip to MindSpore', titleKey: 'college_cloud_title', icon: 'cloud', url: collegeMainCloudUrl },
  {
    id: 'quick',
    type: 'quickStart',
    title: 'Quick Start',
    titleKey: 'college_quick_title',
    icon: 'new',
    quickActions: [
      { id: 'train', title: 'Train', titleKey: 'college_train_title', icon: 'train', url: collegeQuickTrainUrl },
      { id: 'inference', title: 'Inference', titleKey: 'college_execute_title', icon: 'inference', url: collegeQuickExecuteUrl },
      { id: 'applications', title: 'Applications', titleKey: 'college_app_title', icon: 'app', url: collegeQuickAppUrl },
      { id: 'video', title: 'Video', titleKey: 'college_video_title', icon: 'video', url: collegeQuickVideoUrl }
    ]
  },
  { id: 'faq', type: 'link', title: 'FAQ', titleKey: 'college_faq_title', icon: 'faq', url: collegeMainFaqUrl },
  { id: 'forum', type: 'link', title: 'Ask on forum', titleKey: 'college_ask_title', icon: 'forum', url: collegeMainAskUrl },
  { id: 'footer', type: 'footer', title: '~Illuminate your learning trip~', titleKey: 'college_light_title', icon: 'footer' }
];

export function isCollegeItemUrlNavigable(item: CollegeItem): boolean {
  return item.url !== undefined && item.url.length > 0;
}
