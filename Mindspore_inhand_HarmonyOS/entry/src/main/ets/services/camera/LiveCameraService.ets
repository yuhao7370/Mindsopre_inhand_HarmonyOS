import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { display } from '@kit.ArkUI';
import { AppStringKey } from '../../common/i18n/AppStrings';

export const liveCameraXComponentId = 'liveCameraPreview';
export const liveRuntimeIntervalMs = 1000;
export const fastLiveRuntimeIntervalMs = 500;
export const liveImageClassificationIntervalMs = liveRuntimeIntervalMs;
export const liveFrameImageFileName = 'mindspore_live_frame.jpg';
export const liveFrameImagePackingOption: image.PackingOption = {
  format: 'image/jpeg',
  quality: 90
};

export interface LiveCameraPreviewResult {
  readonly ok: boolean;
  readonly surfaceId: string;
  readonly messageKey: AppStringKey;
  readonly previewRotationDegrees?: number;
  readonly previewAspectRatio?: number;
}

export type LiveCameraPosition = 'back' | 'front';

export const defaultLiveCameraPosition: LiveCameraPosition = 'back';

export function livePreviewContentRotationDegrees(
  cameraOrientation: number,
  displayRotation: number,
  position: LiveCameraPosition,
  reportedPreviewRotation: number
): number {
  const normalizedReported = normalizedQuarterTurnDegrees(reportedPreviewRotation);
  const normalizedCamera = normalizedQuarterTurnDegrees(cameraOrientation);
  if (normalizedCamera < 0 || !Number.isInteger(displayRotation) || displayRotation < 0 || displayRotation > 3) {
    return normalizedReported >= 0 ? normalizedReported : 0;
  }
  const displayDegrees = displayRotation * 90;
  const contentRotation = position === 'front' ?
    normalizedCamera + displayDegrees : normalizedCamera - displayDegrees;
  return (contentRotation + 360) % 360;
}

export function livePreviewAspectRatioForRotation(rotationDegrees: number): number {
  const rotation = normalizedQuarterTurnDegrees(rotationDegrees);
  return rotation === 90 || rotation === 270 ? 3 / 4 : 4 / 3;
}

export function livePreviewWidthForAspectRatio(aspectRatio: number): string {
  return Number.isFinite(aspectRatio) && aspectRatio > 0 && aspectRatio < 1 ? '78%' : '100%';
}

function normalizedQuarterTurnDegrees(rotationDegrees: number): number {
  if (!Number.isFinite(rotationDegrees)) {
    return -1;
  }
  const normalized = ((rotationDegrees % 360) + 360) % 360;
  return normalized % 90 === 0 ? normalized : -1;
}

export interface LiveDisplayRotationProvider {
  currentDisplayRotation(): number;
}

export interface LivePreviewRotationOutput {
  getPreviewRotation(displayRotation: number): number;
}

export class LivePreviewRotationTracker {
  private readonly cameraOrientation: number;
  private readonly cameraPosition: LiveCameraPosition;
  private readonly previewOutput: LivePreviewRotationOutput;
  private readonly displayRotationProvider: LiveDisplayRotationProvider;
  private lastRotation: number = 0;

  constructor(
    cameraOrientation: number,
    cameraPosition: LiveCameraPosition,
    previewOutput: LivePreviewRotationOutput,
    displayRotationProvider: LiveDisplayRotationProvider
  ) {
    this.cameraOrientation = cameraOrientation;
    this.cameraPosition = cameraPosition;
    this.previewOutput = previewOutput;
    this.displayRotationProvider = displayRotationProvider;
  }

  currentRotationDegrees(): number {
    let displayRotation = -1;
    try {
      displayRotation = this.displayRotationProvider.currentDisplayRotation();
    } catch (_) {
      return this.lastRotation;
    }
    if (!Number.isInteger(displayRotation) || displayRotation < 0 || displayRotation > 3) {
      return this.lastRotation;
    }
    if (normalizedQuarterTurnDegrees(this.cameraOrientation) >= 0) {
      this.lastRotation = livePreviewContentRotationDegrees(
        this.cameraOrientation,
        displayRotation,
        this.cameraPosition,
        -1
      );
      return this.lastRotation;
    }
    try {
      const reportedRotation = normalizedQuarterTurnDegrees(
        this.previewOutput.getPreviewRotation(displayRotation)
      );
      if (reportedRotation >= 0) {
        this.lastRotation = reportedRotation;
      }
    } catch (_) {
    }
    return this.lastRotation;
  }
}

class HarmonyLiveDisplayRotationProvider implements LiveDisplayRotationProvider {
  currentDisplayRotation(): number {
    return display.getDefaultDisplaySync().rotation;
  }
}

class HarmonyLivePreviewRotationOutput implements LivePreviewRotationOutput {
  private readonly previewOutput: camera.PreviewOutput;

  constructor(previewOutput: camera.PreviewOutput) {
    this.previewOutput = previewOutput;
  }

  getPreviewRotation(displayRotation: number): number {
    return this.previewOutput.getPreviewRotation(displayRotation);
  }
}

export interface LiveCameraPreviewDriver {
  start(surfaceId: string, position: LiveCameraPosition): Promise<void>;
  stop(): Promise<void>;
  previewRotationDegrees?(): number;
  previewAspectRatio?(): number;
}

export interface LiveCameraDevicePositionProvider {
  supportedCameraPositions(): Array<LiveCameraPosition>;
}

export interface LiveCameraSwitchCapability {
  readonly canSwitch: boolean;
  readonly preferredPosition: LiveCameraPosition;
}

export interface LiveFrameImageResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface LiveFrameImageEncoder {
  encodeSurfaceFrame(surfaceId: string, rotationDegrees: number): Promise<ArrayBuffer>;
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

export function liveFrameImageCachePath(cacheDir: string): string {
  const normalizedCacheDir = cacheDir.endsWith('/') ? cacheDir.substring(0, cacheDir.length - 1) : cacheDir;
  return `${normalizedCacheDir}/${liveFrameImageFileName}`;
}

export function shouldCaptureLiveFrameImage(
  liveCameraInputSelected: boolean,
  _imageInputUri: string,
  _liveCameraActive: boolean
): boolean {
  return liveCameraInputSelected;
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
    aiMethod === 'detectScene' ||
    aiMethod === 'translateText';
}

export function isLiveRuntimeGenerationCurrent(
  expectedGeneration: number | undefined,
  currentGeneration: number
): boolean {
  return expectedGeneration === undefined || expectedGeneration === currentGeneration;
}

export function liveRuntimeIntervalForAiMethod(aiMethod: string): number {
  if (aiMethod === 'detectGesture' || aiMethod === 'detectScene') {
    return fastLiveRuntimeIntervalMs;
  }
  return liveRuntimeIntervalMs;
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

export function liveCameraSwitchAvailableForPositions(positions: Array<LiveCameraPosition>): boolean {
  return positions.indexOf('back') >= 0 && positions.indexOf('front') >= 0;
}

export function liveCameraPreferredPositionForAvailablePositions(
  preferredPosition: LiveCameraPosition,
  positions: Array<LiveCameraPosition>
): LiveCameraPosition {
  if (positions.indexOf(preferredPosition) >= 0 || positions.length === 0) {
    return preferredPosition;
  }
  return positions[0];
}

export function liveCameraPositionFromHarmonyPosition(
  position: camera.CameraPosition
): LiveCameraPosition | undefined {
  if (position === camera.CameraPosition.CAMERA_POSITION_BACK) {
    return 'back';
  }
  if (position === camera.CameraPosition.CAMERA_POSITION_FRONT) {
    return 'front';
  }
  return undefined;
}

export class HarmonyLiveCameraDevicePositionProvider implements LiveCameraDevicePositionProvider {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  supportedCameraPositions(): Array<LiveCameraPosition> {
    const positions: Array<LiveCameraPosition> = [];
    const manager = camera.getCameraManager(this.context);
    manager.getSupportedCameras().forEach((device: camera.CameraDevice) => {
      const position = liveCameraPositionFromHarmonyPosition(device.cameraPosition);
      if (position !== undefined && positions.indexOf(position) < 0) {
        positions.push(position);
      }
    });
    return positions;
  }
}

export class LiveCameraSwitchCapabilityService {
  private readonly provider: LiveCameraDevicePositionProvider;

  constructor(provider: LiveCameraDevicePositionProvider) {
    this.provider = provider;
  }

  canSwitch(): boolean {
    return this.capability(defaultLiveCameraPosition).canSwitch;
  }

  capability(preferredPosition: LiveCameraPosition): LiveCameraSwitchCapability {
    try {
      const positions = this.provider.supportedCameraPositions();
      return {
        canSwitch: liveCameraSwitchAvailableForPositions(positions),
        preferredPosition: liveCameraPreferredPositionForAvailablePositions(preferredPosition, positions)
      };
    } catch (_) {
      return {
        canSwitch: true,
        preferredPosition: preferredPosition
      };
    }
  }
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
      return {
        ok: true,
        surfaceId: surfaceId,
        messageKey: 'feature_runtime_live_camera_ready',
        previewRotationDegrees: this.driver.previewRotationDegrees?.() ?? 0,
        previewAspectRatio: this.driver.previewAspectRatio?.() ?? 4 / 3
      };
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

  previewRotationDegrees(): number {
    return this.driver.previewRotationDegrees?.() ?? 0;
  }

  previewAspectRatio(): number {
    return this.driver.previewAspectRatio?.() ?? 4 / 3;
  }
}

export class LiveFrameImageService {
  private readonly encoder: LiveFrameImageEncoder;
  private readonly store: LiveFrameImageStore;

  constructor(encoder: LiveFrameImageEncoder, store: LiveFrameImageStore) {
    this.encoder = encoder;
    this.store = store;
  }

  async captureToCacheImage(
    surfaceId: string,
    cacheDir: string,
    rotationDegrees: number = 0
  ): Promise<LiveFrameImageResult> {
    if (surfaceId.length === 0) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_live_camera_surface_missing' };
    }

    try {
      const bytes = await this.encoder.encodeSurfaceFrame(surfaceId, rotationDegrees);
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
  private previewRotation: number = 0;
  private rotationTracker: LivePreviewRotationTracker | undefined = undefined;

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
      const requestedPosition = position === 'front' ?
        camera.CameraPosition.CAMERA_POSITION_FRONT : camera.CameraPosition.CAMERA_POSITION_BACK;
      const device = manager.getSupportedCameras().find((candidate: camera.CameraDevice) =>
        candidate.cameraPosition === requestedPosition
      );
      if (device === undefined) {
        throw new Error('requested live camera is unavailable');
      }
      const outputCapability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const previewProfile = outputCapability.previewProfiles[0];
      if (previewProfile === undefined) {
        throw new Error('requested live camera has no preview profile');
      }
      this.cameraInput = manager.createCameraInput(device);
      await this.cameraInput.open();
      this.previewOutput = manager.createPreviewOutput(previewProfile, surfaceId);
      this.session = manager.createSession<camera.Session>(camera.SceneMode.NORMAL_PHOTO);
      this.session.beginConfig();
      this.session.addInput(this.cameraInput);
      this.session.addOutput(this.previewOutput);
      await this.session.commitConfig();
      await this.session.start();
      this.rotationTracker = new LivePreviewRotationTracker(
        device.cameraOrientation,
        position,
        new HarmonyLivePreviewRotationOutput(this.previewOutput),
        new HarmonyLiveDisplayRotationProvider()
      );
      this.previewRotation = this.rotationTracker.currentRotationDegrees();
    } catch (_) {
      await this.stop();
      throw new Error('live camera preview failed');
    }
  }

  async stop(): Promise<void> {
    this.previewRotation = 0;
    this.rotationTracker = undefined;
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

  previewRotationDegrees(): number {
    if (this.rotationTracker !== undefined) {
      this.previewRotation = this.rotationTracker.currentRotationDegrees();
    }
    return this.previewRotation;
  }

  previewAspectRatio(): number {
    return livePreviewAspectRatioForRotation(this.previewRotationDegrees());
  }
}

export class HarmonyLiveFrameImageEncoder implements LiveFrameImageEncoder {
  async encodeSurfaceFrame(surfaceId: string, rotationDegrees: number): Promise<ArrayBuffer> {
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      pixelMap = await image.createPixelMapFromSurface(surfaceId);
      if (normalizedQuarterTurnDegrees(rotationDegrees) > 0) {
        await pixelMap.rotate(rotationDegrees);
      }
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
    const path = liveFrameImageCachePath(cacheDir);
    const file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, bytes);
      return path;
    } finally {
      await fileIo.close(file);
    }
  }
}
