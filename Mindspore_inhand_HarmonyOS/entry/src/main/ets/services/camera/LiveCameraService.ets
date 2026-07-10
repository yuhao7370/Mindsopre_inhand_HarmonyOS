import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { AppStringKey } from '../../common/i18n/AppStrings';

export const liveCameraXComponentId = 'liveCameraPreview';
export const liveRuntimeIntervalMs = 1000;
export const liveImageClassificationIntervalMs = liveRuntimeIntervalMs;
export const liveFrameImagePackingOption: image.PackingOption = {
  format: 'image/jpeg',
  quality: 90
};

export interface LiveCameraPreviewResult {
  readonly ok: boolean;
  readonly surfaceId: string;
  readonly messageKey: AppStringKey;
}

export type LiveCameraPosition = 'back' | 'front';

export const defaultLiveCameraPosition: LiveCameraPosition = 'back';

export interface LiveCameraPreviewDriver {
  start(surfaceId: string, position: LiveCameraPosition): Promise<void>;
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

export interface LiveRuntimeFrameRunner {
  runOnce(): Promise<void>;
}

export interface LiveRuntimeLoopScheduler {
  schedule(intervalMs: number, tick: () => void): number;
  cancel(timerId: number): void;
}

export function shouldCaptureLiveFrameImage(
  liveCameraInputSelected: boolean,
  imageInputUri: string,
  liveCameraActive: boolean
): boolean {
  if (!liveCameraInputSelected) {
    return false;
  }
  if (imageInputUri.length > 0 && !liveCameraActive) {
    return false;
  }
  return true;
}

export function shouldRunLiveImageClassificationLoop(
  aiMethod: string,
  liveCameraInputSelected: boolean,
  liveCameraActive: boolean
): boolean {
  return aiMethod === 'classifyImage' && liveCameraInputSelected && liveCameraActive;
}

export function shouldRunLiveRuntimeLoop(
  aiMethod: string,
  workflowLiveMode: boolean,
  liveCameraInputSelected: boolean,
  liveCameraActive: boolean
): boolean {
  if (!workflowLiveMode || !liveCameraInputSelected || !liveCameraActive) {
    return false;
  }
  return aiMethod === 'classifyImage' ||
    aiMethod === 'detectObjects' ||
    aiMethod === 'segmentPerson' ||
    aiMethod === 'detectPose' ||
    aiMethod === 'detectGesture' ||
    aiMethod === 'detectScene';
}

export function shouldAutoRunLiveRuntimeAfterPreview(
  aiMethod: string,
  workflowLiveMode: boolean,
  previewReady: boolean
): boolean {
  return shouldRunLiveRuntimeLoop(aiMethod, workflowLiveMode, true, previewReady);
}

export function nextLiveCameraPosition(position: LiveCameraPosition): LiveCameraPosition {
  return position === 'back' ? 'front' : 'back';
}

export class HarmonyLiveRuntimeLoopScheduler implements LiveRuntimeLoopScheduler {
  schedule(intervalMs: number, tick: () => void): number {
    return setInterval(tick, intervalMs);
  }

  cancel(timerId: number): void {
    clearInterval(timerId);
  }
}

export class LiveRuntimeLoopService {
  private readonly scheduler: LiveRuntimeLoopScheduler;
  private timerId: number = -1;
  private running: boolean = false;
  private frameRunning: boolean = false;

  constructor(scheduler?: LiveRuntimeLoopScheduler) {
    this.scheduler = scheduler ?? new HarmonyLiveRuntimeLoopScheduler();
  }

  start(intervalMs: number, runner: LiveRuntimeFrameRunner): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.runFrame(runner);
    this.timerId = this.scheduler.schedule(intervalMs, () => this.runFrame(runner));
  }

  stop(): void {
    this.running = false;
    if (this.timerId >= 0) {
      this.scheduler.cancel(this.timerId);
      this.timerId = -1;
    }
  }

  isRunning(): boolean {
    return this.running;
  }

  private runFrame(runner: LiveRuntimeFrameRunner): void {
    if (!this.running || this.frameRunning) {
      return;
    }
    this.frameRunning = true;
    runner.runOnce()
      .then(() => {
        this.frameRunning = false;
      })
      .catch(() => {
        this.frameRunning = false;
      });
  }
}

export class LiveCameraPreviewService {
  private readonly driver: LiveCameraPreviewDriver;

  constructor(driver: LiveCameraPreviewDriver) {
    this.driver = driver;
  }

  async start(
    surfaceId: string,
    position: LiveCameraPosition = defaultLiveCameraPosition
  ): Promise<LiveCameraPreviewResult> {
    if (surfaceId.length === 0) {
      return { ok: false, surfaceId: '', messageKey: 'feature_runtime_live_camera_surface_missing' };
    }

    try {
      await this.driver.start(surfaceId, position);
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

  async start(
    surfaceId: string,
    position: LiveCameraPosition = defaultLiveCameraPosition
  ): Promise<void> {
    await this.stop();
    try {
      const manager = camera.getCameraManager(this.context);
      this.cameraInput = manager.createCameraInput(
        position === 'front' ? camera.CameraPosition.CAMERA_POSITION_FRONT : camera.CameraPosition.CAMERA_POSITION_BACK,
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
    let packer: image.ImagePacker | undefined = undefined;
    try {
      pixelMap = await image.createPixelMapFromSurface(surfaceId);
      packer = image.createImagePacker();
      return await packer.packToData(pixelMap, liveFrameImagePackingOption);
    } finally {
      if (packer !== undefined) {
        await packer.release();
      }
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
