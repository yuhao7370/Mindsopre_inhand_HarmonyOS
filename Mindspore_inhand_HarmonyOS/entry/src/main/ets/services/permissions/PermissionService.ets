import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { FeaturePermissionKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

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
  readonly denied: Array<Permissions>;
}

export interface OpenPermissionSettingsAction {
  readonly openSettings: boolean;
  readonly permissions: Array<Permissions>;
}

export function permissionRequestSummary(
  permissionNames: Array<Permissions>,
  authResults: Array<number>
): PermissionRequestSummary {
  const denied: Array<Permissions> = [];
  permissionNames.forEach((permissionName: Permissions, index: number) => {
    if (authResults[index] !== 0) {
      denied.push(permissionName);
    }
  });
  return {
    ok: denied.length === 0,
    requested: permissionNames,
    denied: denied
  };
}

export function runtimeOpenPermissionSettingsAction(
  deniedPermissions: Array<Permissions>
): OpenPermissionSettingsAction {
  if (deniedPermissions.length === 0) {
    return {
      openSettings: false,
      permissions: []
    };
  }
  return {
    openSettings: true,
    permissions: [deniedPermissions[0]]
  };
}

export type RuntimePermissionRecoveryAction = 'none' | 'retryRun' | 'retryCameraInput';
export type RuntimePermissionRunAction = 'runWorkflow' | 'retryCameraInput';

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

  async requestOnSetting(
    context: common.UIAbilityContext,
    deniedPermissions: Array<Permissions>
  ): Promise<PermissionRequestSummary> {
    const action = runtimeOpenPermissionSettingsAction(deniedPermissions);
    if (!action.openSettings) {
      return { ok: true, requested: [], denied: [] };
    }
    const manager = abilityAccessCtrl.createAtManager();
    try {
      const result: Array<number> = await manager.requestPermissionOnSetting(context, action.permissions);
      return permissionRequestSummary(action.permissions, result);
    } catch (_) {
      return {
        ok: false,
        requested: action.permissions,
        denied: action.permissions
      };
    }
  }

  private async requestPermissionNames(
    context: common.UIAbilityContext,
    permissionNames: Array<Permissions>
  ): Promise<PermissionRequestSummary> {
    if (permissionNames.length === 0) {
      return { ok: true, requested: [], denied: [] };
    }
    const manager = abilityAccessCtrl.createAtManager();
    try {
      const result: PermissionRequestResult = await manager.requestPermissionsFromUser(context, permissionNames);
      return permissionRequestSummary(permissionNames, result.authResults);
    } catch (_) {
      return {
        ok: false,
        requested: permissionNames,
        denied: permissionNames
      };
    }
  }
}
