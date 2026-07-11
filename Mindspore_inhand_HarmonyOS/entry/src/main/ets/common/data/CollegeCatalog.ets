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
export type CollegeMediaName =
  'college_summary_uncheck' |
  'college_summary_checked' |
  'college_cloud_uncheck' |
  'college_cloud_checked' |
  'college_quick_uncheck' |
  'college_quick_checked' |
  'college_faq_uncheck' |
  'college_faq_checked' |
  'college_ask_uncheck' |
  'college_ask_checked' |
  'college_train_uncheck' |
  'college_train_checked' |
  'college_execute_uncheck' |
  'college_execute_checked' |
  'college_app_uncheck' |
  'college_app_checked' |
  'college_video_uncheck' |
  'college_video_checked';

export interface CollegeTimelineVisual {
  readonly iconMediaName: CollegeMediaName;
  readonly checkedIconMediaName: CollegeMediaName;
  readonly uncheckedIconMediaName: CollegeMediaName;
  readonly iconSizeVp: number;
  readonly rowHeightVp: number;
  readonly showsTrailingLine: boolean;
  readonly showsProgressDot: boolean;
  readonly lineColor: string;
}

export interface CollegeQuickActionVisual {
  readonly iconMediaName: CollegeMediaName;
  readonly checkedIconMediaName: CollegeMediaName;
  readonly uncheckedIconMediaName: CollegeMediaName;
  readonly widthVp: number;
  readonly heightVp: number;
  readonly borderColor: string;
  readonly textColor: string;
}

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

export const collegeSummaryDialogTitleKey: AppStringKey = 'college_dialog_title';
export const collegeAdapterViewTitleKey: AppStringKey = 'college_adapter_view';

export const collegeTimelineCheckedColor = '#6189FF';
export const collegeTimelineUncheckedColor = '#33999999';
export const collegeQuickActionUncheckedBorderColor = '#E6E6E6';
export const collegeTimelineTextColor = '#303133';

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

function collegeTimelineIconNamesForItem(itemId: string): [CollegeMediaName, CollegeMediaName] {
  switch (itemId) {
    case 'summary':
      return ['college_summary_checked', 'college_summary_uncheck'];
    case 'cloud':
      return ['college_cloud_checked', 'college_cloud_uncheck'];
    case 'quick':
      return ['college_quick_checked', 'college_quick_uncheck'];
    case 'faq':
      return ['college_faq_checked', 'college_faq_uncheck'];
    case 'forum':
      return ['college_ask_checked', 'college_ask_uncheck'];
    default:
      return ['college_summary_checked', 'college_summary_uncheck'];
  }
}

function collegeQuickActionIconNames(actionId: string): [CollegeMediaName, CollegeMediaName] {
  switch (actionId) {
    case 'train':
      return ['college_train_checked', 'college_train_uncheck'];
    case 'inference':
      return ['college_execute_checked', 'college_execute_uncheck'];
    case 'applications':
      return ['college_app_checked', 'college_app_uncheck'];
    case 'video':
      return ['college_video_checked', 'college_video_uncheck'];
    default:
      return ['college_train_checked', 'college_train_uncheck'];
  }
}

function isLastCollegeTimelineItem(itemId: string): boolean {
  const progressItems = collegeItems.filter((item: CollegeItem) => item.type !== 'footer');
  return progressItems.length > 0 && progressItems[progressItems.length - 1].id === itemId;
}

export function collegeTimelineVisualForItem(item: CollegeItem, checked: boolean): CollegeTimelineVisual {
  const iconNames = collegeTimelineIconNamesForItem(item.id);
  const isLast = isLastCollegeTimelineItem(item.id);
  return {
    iconMediaName: checked ? iconNames[0] : iconNames[1],
    checkedIconMediaName: iconNames[0],
    uncheckedIconMediaName: iconNames[1],
    iconSizeVp: 45,
    rowHeightVp: item.type === 'quickStart' ? 150 : 100,
    showsTrailingLine: !isLast,
    showsProgressDot: checked && !isLast,
    lineColor: checked ? collegeTimelineCheckedColor : collegeTimelineUncheckedColor
  };
}

export function collegeQuickActionVisual(
  action: CollegeQuickAction,
  checked: boolean
): CollegeQuickActionVisual {
  const iconNames = collegeQuickActionIconNames(action.id);
  return {
    iconMediaName: checked ? iconNames[0] : iconNames[1],
    checkedIconMediaName: iconNames[0],
    uncheckedIconMediaName: iconNames[1],
    widthVp: 55,
    heightVp: 60,
    borderColor: checked ? collegeTimelineCheckedColor : collegeQuickActionUncheckedBorderColor,
    textColor: checked ? collegeTimelineCheckedColor : collegeTimelineTextColor
  };
}
