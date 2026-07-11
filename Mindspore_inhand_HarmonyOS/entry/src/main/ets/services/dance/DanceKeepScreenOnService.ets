import { common } from '@kit.AbilityKit';

export interface DanceKeepScreenOnWindow {
  setWindowKeepScreenOn(isKeepScreenOn: boolean): Promise<void>;
}

export interface DanceKeepScreenOnWindowProvider {
  mainWindow(): Promise<DanceKeepScreenOnWindow | undefined>;
}

export class HarmonyDanceKeepScreenOnWindowProvider implements DanceKeepScreenOnWindowProvider {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async mainWindow(): Promise<DanceKeepScreenOnWindow | undefined> {
    try {
      const mainWindow = await this.context.windowStage.getMainWindow();
      return mainWindow as DanceKeepScreenOnWindow;
    } catch (_) {
      return undefined;
    }
  }
}

export class DanceKeepScreenOnService {
  private readonly provider: DanceKeepScreenOnWindowProvider;

  constructor(provider: DanceKeepScreenOnWindowProvider) {
    this.provider = provider;
  }

  async setKeepScreenOn(isKeepScreenOn: boolean): Promise<boolean> {
    const mainWindow = await this.provider.mainWindow();
    if (mainWindow === undefined) {
      return false;
    }
    try {
      await mainWindow.setWindowKeepScreenOn(isKeepScreenOn);
      return true;
    } catch (_) {
      return false;
    }
  }
}
