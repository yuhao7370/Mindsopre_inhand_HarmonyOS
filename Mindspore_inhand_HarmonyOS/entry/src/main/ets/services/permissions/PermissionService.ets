import { abilityAccessCtrl, common, PermissionRequestResult, Permissions, Want } from '@kit.AbilityKit';
import { FeaturePermissionKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

export const appDetailsSettingsAction = 'action.settings.app.info';
export const cameraPermissionName: Permissions = 'ohos.permission.CAMERA';
export const mediaPermissionName: Permissions = 'ohos.permission.READ_IMAGEVIDEO';
export const internetPermissionName: Permissions = 'ohos.permission.INTERNET';
export const shortTermWriteImageVideoPermissionName: Permissions = 'ohos.permission.SHORT_TERM_WRITE_IMAGEVIDEO';

export const declaredPermissionNames: Array<Permissions> = [
  cameraPermissionName,
  mediaPermissionName,
  internetPermissionName,
  shortTermWriteImageVideoPermissionName
];

export interface PermissionRequestSummary {
  readonly ok: boolean;
  readonly requested: Array<Permissions>;
}

export interface OpenAppSettingsAction {
  readonly openSettings: boolean;
  readonly want: Want;
}

export type RuntimePermissionRecoveryAction = 'none' | 'retryRun' | 'retryCameraInput';
export type RuntimePermissionRunAction = 'runWorkflow' | 'retryCameraInput';

export function appDetailsSettingsWantForBundle(bundleName: string): Want {
  return {
    action: appDetailsSettingsAction,
    parameters: {
      settingsParamBundleName: bundleName
    }
  };
}

export function runtimeOpenAppSettingsAction(bundleName: string): OpenAppSettingsAction {
  return {
    openSettings: true,
    want: appDetailsSettingsWantForBundle(bundleName)
  };
}

export function permissionNameForKind(kind: FeaturePermissionKind): Permissions {
  switch (kind) {
    case 'camera':
      return cameraPermissionName;
    case 'media':
      return mediaPermissionName;
    case 'internet':
      return internetPermissionName;
  }
}

export function runtimePermissionNamesForWorkflow(workflow: FeatureWorkflow): Array<Permissions> {
  const names: Array<Permissions> = [];
  workflow.requiredPermissions.forEach((kind: FeaturePermissionKind) => {
    if (kind === 'internet') {
      return;
    }
    const name = permissionNameForKind(kind);
    if (names.indexOf(name) < 0) {
      names.push(name);
    }
  });
  return names;
}

export function runtimePermissionRecoveryActionForWorkflow(
  workflow: FeatureWorkflow | undefined,
  statusKey: string
): RuntimePermissionRecoveryAction {
  if (statusKey !== 'feature_runtime_permission_denied' || workflow === undefined) {
    return 'none';
  }
  if (workflow.liveMode && workflow.inputKinds.indexOf('camera') >= 0) {
    return 'retryCameraInput';
  }
  return 'retryRun';
}

export function runtimePermissionRunActionForWorkflow(
  workflow: FeatureWorkflow | undefined,
  statusKey: string
): RuntimePermissionRunAction {
  return runtimePermissionRecoveryActionForWorkflow(workflow, statusKey) === 'retryCameraInput' ?
    'retryCameraInput' :
    'runWorkflow';
}

export class PermissionService {
  async requestCamera(context: common.UIAbilityContext): Promise<PermissionRequestSummary> {
    return this.requestPermissionNames(context, [cameraPermissionName]);
  }

  async requestForWorkflow(context: common.UIAbilityContext, workflow: FeatureWorkflow): Promise<PermissionRequestSummary> {
    return this.requestPermissionNames(context, runtimePermissionNamesForWorkflow(workflow));
  }

  private async requestPermissionNames(
    context: common.UIAbilityContext,
    permissionNames: Array<Permissions>
  ): Promise<PermissionRequestSummary> {
    if (permissionNames.length === 0) {
      return { ok: true, requested: [] };
    }
    const manager = abilityAccessCtrl.createAtManager();
    try {
      const result: PermissionRequestResult = await manager.requestPermissionsFromUser(context, permissionNames);
      return {
        ok: result.authResults.find((authResult: number) => authResult !== 0) === undefined,
        requested: permissionNames
      };
    } catch (_) {
      return { ok: false, requested: permissionNames };
    }
  }
}
