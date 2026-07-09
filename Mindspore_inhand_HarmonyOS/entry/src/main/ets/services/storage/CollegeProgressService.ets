import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const collegeProgressPreferenceName: string = 'mindspore_college_progress';
export const collegeQuickActionIds: Array<string> = ['train', 'inference', 'applications', 'video'];

export interface CollegeProgressStore {
  getBoolean(key: string, defaultValue: boolean): boolean;
  putBoolean(key: string, value: boolean): void;
  flush(): void;
}

export class HarmonyCollegeProgressStore implements CollegeProgressStore {
  private readonly store: preferences.Preferences;

  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: collegeProgressPreferenceName });
  }

  getBoolean(key: string, defaultValue: boolean): boolean {
    return this.store.getSync(key, defaultValue) === true;
  }

  putBoolean(key: string, value: boolean): void {
    this.store.putSync(key, value);
  }

  flush(): void {
    this.store.flushSync();
  }
}

export class CollegeProgressService {
  private readonly store: CollegeProgressStore;

  constructor(store: CollegeProgressStore) {
    this.store = store;
  }

  isItemChecked(itemId: string): boolean {
    const key = collegeProgressKeyForItemId(itemId);
    return key.length > 0 ? this.store.getBoolean(key, false) : false;
  }

  isQuickActionChecked(actionId: string): boolean {
    const key = collegeProgressKeyForQuickActionId(actionId);
    return key.length > 0 ? this.store.getBoolean(key, false) : false;
  }

  markItemChecked(itemId: string): void {
    const key = collegeProgressKeyForItemId(itemId);
    if (key.length === 0) {
      return;
    }
    this.store.putBoolean(key, true);
    this.store.flush();
  }

  markQuickActionChecked(actionId: string): void {
    const key = collegeProgressKeyForQuickActionId(actionId);
    if (key.length === 0) {
      return;
    }
    this.store.putBoolean(key, true);
    this.store.putBoolean(collegeProgressKeyForItemId('quick'), this.allQuickActionsChecked());
    this.store.flush();
  }

  checkedItemIds(itemIds: Array<string>): Array<string> {
    return itemIds.filter((itemId: string) => this.isItemChecked(itemId));
  }

  checkedQuickActionIds(actionIds: Array<string>): Array<string> {
    return actionIds.filter((actionId: string) => this.isQuickActionChecked(actionId));
  }

  private allQuickActionsChecked(): boolean {
    return collegeQuickActionIds.find((actionId: string) => !this.isQuickActionChecked(actionId)) === undefined;
  }
}

export function collegeProgressKeyForItemId(itemId: string): string {
  switch (itemId) {
    case 'summary':
      return 'preferences_college_summary';
    case 'cloud':
      return 'preferences_college_cloud';
    case 'quick':
      return 'preferences_college_quick';
    case 'faq':
      return 'preferences_college_faq';
    case 'forum':
      return 'preferences_college_ask';
    default:
      return '';
  }
}

export function collegeProgressKeyForQuickActionId(actionId: string): string {
  switch (actionId) {
    case 'train':
      return 'preferences_college_train';
    case 'inference':
      return 'preferences_college_execute';
    case 'applications':
      return 'preferences_college_app';
    case 'video':
      return 'preferences_college_video';
    default:
      return '';
  }
}
