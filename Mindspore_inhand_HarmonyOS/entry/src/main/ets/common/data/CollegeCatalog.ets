export type CollegeItemType = 'link' | 'quickStart' | 'summary' | 'footer';

export interface CollegeQuickAction {
  readonly id: string;
  readonly title: string;
  readonly icon: string;
  readonly url: string;
}

export interface CollegeItem {
  readonly id: string;
  readonly type: CollegeItemType;
  readonly title: string;
  readonly icon: string;
  readonly url?: string;
  readonly quickActions?: CollegeQuickAction[];
}

export const mindSporeSummary =
  'MindSpore is a full-scenario AI computing framework. This HarmonyOS port keeps the learning entry local and opens external resources through the web page flow.';

export const collegeItems: CollegeItem[] = [
  { id: 'summary', type: 'summary', title: 'MindSpore Summary', icon: 'summary' },
  { id: 'cloud', type: 'link', title: 'A One-Hour Trip to MindSpore', icon: 'cloud', url: 'https://www.mindspore.cn/' },
  {
    id: 'quick',
    type: 'quickStart',
    title: 'Quick Start',
    icon: 'new',
    quickActions: [
      { id: 'train', title: 'Train', icon: 'train', url: 'https://www.mindspore.cn/tutorials' },
      { id: 'inference', title: 'Inference', icon: 'inference', url: 'https://www.mindspore.cn/lite' },
      { id: 'applications', title: 'Applications', icon: 'app', url: 'https://www.mindspore.cn/ecosystem' },
      { id: 'video', title: 'Video', icon: 'video', url: 'https://www.mindspore.cn/resources' }
    ]
  },
  { id: 'faq', type: 'link', title: 'FAQ', icon: 'faq', url: 'https://www.mindspore.cn/docs' },
  { id: 'forum', type: 'link', title: 'Ask on forum', icon: 'forum', url: 'https://discuss.mindspore.cn/' },
  { id: 'footer', type: 'footer', title: '~Illuminate your learning trip~', icon: 'footer' }
];
