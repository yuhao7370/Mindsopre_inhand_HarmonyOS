import { common } from '@kit.AbilityKit';

export interface KeepScreenOnWindow {
  setWindowKeepScreenOn(isKeepScreenOn: boolean): Promise<void>;
}

export interface KeepScreenOnWindowProvider {
  mainWindow(): Promise<KeepScreenOnWindow | undefined>;
}

export class HarmonyKeepScreenOnWindowProvider implements KeepScreenOnWindowProvider {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async mainWindow(): Promise<KeepScreenOnWindow | undefined> {
    try {
      const mainWindow = await this.context.windowStage.getMainWindow();
      return mainWindow as KeepScreenOnWindow;
    } catch (_) {
      return undefined;
    }
  }
}

export class KeepScreenOnService {
  private readonly provider: KeepScreenOnWindowProvider;

  constructor(provider: KeepScreenOnWindowProvider) {
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
