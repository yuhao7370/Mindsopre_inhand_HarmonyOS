import { AppStringKey } from '../common/i18n/AppStrings';

export enum MainTab {
  EXPERIENCE = 0,
  COLLEGE = 1,
  ME = 2
}

export interface TabItem {
  readonly id: MainTab;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly icon: string;
}

export const mainTabs: TabItem[] = [
  { id: MainTab.EXPERIENCE, title: 'Experience', titleKey: 'main_tab_title_one', icon: 'rocket' },
  { id: MainTab.COLLEGE, title: 'College', titleKey: 'main_tab_title_two', icon: 'college' },
  { id: MainTab.ME, title: 'Me', titleKey: 'main_tab_title_three', icon: 'me' }
];
