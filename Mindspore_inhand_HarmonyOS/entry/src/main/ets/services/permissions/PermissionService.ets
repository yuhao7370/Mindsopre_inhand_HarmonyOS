import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { FeaturePermissionKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

export const cameraPermissionName: Permissions = 'ohos.permission.CAMERA';
export const mediaPermissionName: Permissions = 'ohos.permission.READ_IMAGEVIDEO';
export const internetPermissionName: Permissions = 'ohos.permission.INTERNET';

export const declaredPermissionNames: Array<Permissions> = [
  cameraPermissionName,
  mediaPermissionName,
  internetPermissionName
];

export interface PermissionRequestSummary {
  readonly ok: boolean;
  readonly requested: Array<Permissions>;
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

export class PermissionService {
  async requestForWorkflow(context: common.UIAbilityContext, workflow: FeatureWorkflow): Promise<PermissionRequestSummary> {
    const permissionNames = runtimePermissionNamesForWorkflow(workflow);
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
