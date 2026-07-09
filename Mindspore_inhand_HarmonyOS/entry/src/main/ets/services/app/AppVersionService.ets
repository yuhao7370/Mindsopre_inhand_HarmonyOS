import { bundleManager } from '@kit.AbilityKit';

export const defaultAppVersionName: string = '1.0.0';

export interface AppVersionReader {
  getVersionName(): string;
}

export class HarmonyBundleVersionReader implements AppVersionReader {
  getVersionName(): string {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return bundleInfo.versionName;
  }
}

export class AppVersionService {
  private readonly reader: AppVersionReader;

  constructor(reader: AppVersionReader = new HarmonyBundleVersionReader()) {
    this.reader = reader;
  }

  currentVersionLabel(): string {
    try {
      return formattedAppVersionName(this.reader.getVersionName());
    } catch (_) {
      return formattedAppVersionName(defaultAppVersionName);
    }
  }
}

export function formattedAppVersionName(versionName: string): string {
  const trimmed = versionName.trim();
  if (trimmed.length === 0) {
    return `V${defaultAppVersionName}`;
  }
  if (trimmed[0] === 'V' || trimmed[0] === 'v') {
    return `V${trimmed.substring(1)}`;
  }
  return `V${trimmed}`;
}
