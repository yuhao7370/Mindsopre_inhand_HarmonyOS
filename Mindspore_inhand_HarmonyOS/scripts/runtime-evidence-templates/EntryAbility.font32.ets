import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      this.context.getApplicationContext().setFontSizeScale(3.2);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to configure application. Cause: %{public}s', JSON.stringify(err));
    }
    const parameters = want.parameters;
    AppStorage.setOrCreate('runtimeEvidenceRunId', `${parameters?.runtimeEvidenceRunId ?? ''}`);
    AppStorage.setOrCreate('runtimeEvidenceMode', `${parameters?.runtimeEvidenceMode ?? ''}`);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/RuntimeHarnessPage');
  }
}
