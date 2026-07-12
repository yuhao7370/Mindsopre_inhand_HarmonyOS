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
  readonly selectedIconMediaName: string;
  readonly unselectedIconMediaName: string;
}

export const mainTabs: TabItem[] = [
  {
    id: MainTab.EXPERIENCE,
    title: 'Experience',
    titleKey: 'main_tab_title_one',
    icon: 'rocket',
    selectedIconMediaName: 'experience_checked',
    unselectedIconMediaName: 'experience_uncheck'
  },
  {
    id: MainTab.ME,
    title: 'Me',
    titleKey: 'main_tab_title_three',
    icon: 'me',
    selectedIconMediaName: 'me_checked',
    unselectedIconMediaName: 'me_uncheck'
  }
];

export function mainTabIconMediaResource(tab: TabItem, selected: boolean): Resource {
  const mediaName = selected ? tab.selectedIconMediaName : tab.unselectedIconMediaName;
  switch (mediaName) {
    case 'experience_checked':
      return $r('app.media.experience_checked');
    case 'experience_uncheck':
      return $r('app.media.experience_uncheck');
    case 'college_checked_icon':
      return $r('app.media.college_checked_icon');
    case 'college_uncheck':
      return $r('app.media.college_uncheck');
    case 'me_checked':
      return $r('app.media.me_checked');
    case 'me_uncheck':
      return $r('app.media.me_uncheck');
    default:
      return $r('app.media.experience_uncheck');
  }
}
