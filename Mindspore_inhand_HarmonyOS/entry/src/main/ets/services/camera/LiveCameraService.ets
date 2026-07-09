import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
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

export interface LiveFrameImageResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface LiveFrameImageEncoder {
  encodeSurfaceFrame(surfaceId: string): Promise<ArrayBuffer>;
}

export interface LiveFrameImageStore {
  writeJpeg(cacheDir: string, bytes: ArrayBuffer): Promise<string>;
}

export function shouldCaptureLiveFrameImage(
  hasLiveCameraInput: boolean,
  imageInputUri: string,
  liveCameraActive: boolean
): boolean {
  if (!hasLiveCameraInput) {
    return false;
  }
  if (imageInputUri.length > 0 && !liveCameraActive) {
    return false;
  }
  return true;
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

export class LiveFrameImageService {
  private readonly encoder: LiveFrameImageEncoder;
  private readonly store: LiveFrameImageStore;

  constructor(encoder: LiveFrameImageEncoder, store: LiveFrameImageStore) {
    this.encoder = encoder;
    this.store = store;
  }

  async captureToCacheImage(surfaceId: string, cacheDir: string): Promise<LiveFrameImageResult> {
    if (surfaceId.length === 0) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_live_camera_surface_missing' };
    }

    try {
      const bytes = await this.encoder.encodeSurfaceFrame(surfaceId);
      const uri = await this.store.writeJpeg(cacheDir, bytes);
      return { ok: uri.length > 0, uri: uri, messageKey: uri.length > 0 ? 'feature_runtime_image_ready' : 'feature_runtime_live_frame_failed' };
    } catch (_) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_live_frame_failed' };
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

export class HarmonyLiveFrameImageEncoder implements LiveFrameImageEncoder {
  async encodeSurfaceFrame(surfaceId: string): Promise<ArrayBuffer> {
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await image.createPixelMapFromSurface(surfaceId);
      const packer = image.createImagePacker();
      return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 });
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
    }
  }
}

export class HarmonyLiveFrameImageStore implements LiveFrameImageStore {
  async writeJpeg(cacheDir: string, bytes: ArrayBuffer): Promise<string> {
    const path = `${cacheDir}/mindspore_live_frame.jpg`;
    const file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, bytes);
      return path;
    } finally {
      await fileIo.close(file);
    }
  }
}
