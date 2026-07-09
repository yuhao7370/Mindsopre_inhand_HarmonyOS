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

export function startupPermissionNames(): Array<Permissions> {
  return [
    cameraPermissionName,
    mediaPermissionName
  ];
}

export class PermissionService {
  async requestStartup(context: common.UIAbilityContext): Promise<PermissionRequestSummary> {
    return this.requestPermissionNames(context, startupPermissionNames());
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
