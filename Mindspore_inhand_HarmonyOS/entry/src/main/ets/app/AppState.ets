export enum MainTab {
  EXPERIENCE = 0,
  COLLEGE = 1,
  ME = 2
}

export interface TabItem {
  readonly id: MainTab;
  readonly title: string;
  readonly icon: string;
}

export const mainTabs: TabItem[] = [
  { id: MainTab.EXPERIENCE, title: 'Experience', icon: 'rocket' },
  { id: MainTab.COLLEGE, title: 'College', icon: 'college' },
  { id: MainTab.ME, title: 'Me', icon: 'me' }
];
