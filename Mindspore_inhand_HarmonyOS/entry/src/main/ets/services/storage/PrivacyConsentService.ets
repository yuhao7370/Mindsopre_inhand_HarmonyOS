import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const privacyConsentPreferenceName: string = 'mindspore_privacy_consent';
export const privacyConsentPreferenceKey: string = 'preferences_privacy';

export interface PrivacyConsentStore {
  getBoolean(key: string, defaultValue: boolean): boolean;
  putBoolean(key: string, value: boolean): void;
  flush(): void;
}

export class HarmonyPrivacyConsentStore implements PrivacyConsentStore {
  private readonly store: preferences.Preferences;

  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: privacyConsentPreferenceName });
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

export class PrivacyConsentService {
  private readonly store: PrivacyConsentStore;

  constructor(store: PrivacyConsentStore) {
    this.store = store;
  }

  hasAcceptedPrivacy(): boolean {
    return this.store.getBoolean(privacyConsentPreferenceKey, false);
  }

  acceptPrivacy(): void {
    this.store.putBoolean(privacyConsentPreferenceKey, true);
    this.store.flush();
  }

  declinePrivacy(): void {
    this.store.putBoolean(privacyConsentPreferenceKey, false);
    this.store.flush();
  }
}
