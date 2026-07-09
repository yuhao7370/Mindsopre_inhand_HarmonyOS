import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { AppStringKey } from '../../common/i18n/AppStrings';

export const liveCameraXComponentId = 'liveCameraPreview';

export interface LiveCameraPreviewResult {
  readonly ok: boolean;
  readonly surfaceId: string;
  readonly messageKey: AppStringKey;
}

export interface LiveCameraPreviewDriver {
  start(surfaceId: string): Promise<void>;
  stop(): Promise<void>;
}

export class LiveCameraPreviewService {
  private readonly driver: LiveCameraPreviewDriver;

  constructor(driver: LiveCameraPreviewDriver) {
    this.driver = driver;
  }

  async start(surfaceId: string): Promise<LiveCameraPreviewResult> {
    if (surfaceId.length === 0) {
      return { ok: false, surfaceId: '', messageKey: 'feature_runtime_live_camera_surface_missing' };
    }

    try {
      await this.driver.start(surfaceId);
      return { ok: true, surfaceId: surfaceId, messageKey: 'feature_runtime_live_camera_ready' };
    } catch (_) {
      return { ok: false, surfaceId: surfaceId, messageKey: 'feature_runtime_live_camera_failed' };
    }
  }

  async stop(): Promise<void> {
    try {
      await this.driver.stop();
    } catch (_) {
    }
  }
}

export class HarmonyLiveCameraPreviewDriver implements LiveCameraPreviewDriver {
  private readonly context: common.UIAbilityContext;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private session: camera.Session | undefined = undefined;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async start(surfaceId: string): Promise<void> {
    await this.stop();
    try {
      const manager = camera.getCameraManager(this.context);
      this.cameraInput = manager.createCameraInput(
        camera.CameraPosition.CAMERA_POSITION_BACK,
        camera.CameraType.CAMERA_TYPE_DEFAULT
      );
      await this.cameraInput.open();
      this.previewOutput = manager.createPreviewOutput(surfaceId);
      this.session = manager.createSession<camera.Session>(camera.SceneMode.NORMAL_PHOTO);
      this.session.beginConfig();
      this.session.addInput(this.cameraInput);
      this.session.addOutput(this.previewOutput);
      await this.session.commitConfig();
      await this.session.start();
    } catch (_) {
      await this.stop();
      throw new Error('live camera preview failed');
    }
  }

  async stop(): Promise<void> {
    if (this.session !== undefined) {
      try {
        await this.session.stop();
      } catch (_) {
      }
      try {
        await this.session.release();
      } catch (_) {
      }
      this.session = undefined;
    }

    if (this.previewOutput !== undefined) {
      try {
        await this.previewOutput.release();
      } catch (_) {
      }
      this.previewOutput = undefined;
    }

    if (this.cameraInput !== undefined) {
      try {
        await this.cameraInput.close();
      } catch (_) {
      }
      this.cameraInput = undefined;
    }
  }
}
