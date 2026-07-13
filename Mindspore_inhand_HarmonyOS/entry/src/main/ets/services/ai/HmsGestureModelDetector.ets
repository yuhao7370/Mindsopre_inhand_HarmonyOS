import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  AndroidGestureModelDetector,
  AndroidGestureModelResult
} from './GestureService';
import { gestureInputFromRgba } from './HmsGesturePreprocessor';
import {
  HmsGestureOutputs,
  decodeHmsGestureOutputs
} from './HmsGestureYoloDecoder';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';
import { RawfileContentReader } from './MindSporeLiteModelRunner';
import {
  HmsGestureModelInfo,
  HmsGestureNativeSession,
  HmsGestureNativeSessionFactory,
  createHarmonyHmsGestureNativeSession
} from './HmsGestureNativeSession';

export {
  HmsGestureModelInfo,
  HmsGestureNativeSession,
  HmsGestureNativeSessionFactory
} from './HmsGestureNativeSession';

export const hmsGestureModelRawfilePath: string = 'models/gesture/GestureDetector.ms';
export const hmsGestureStillConfidenceThreshold: number = 0.6;
export const hmsGestureLiveConfidenceThreshold: number = 0.1;

export function hmsGestureConfidenceThresholdForLiveMode(liveMode: boolean): number {
  return liveMode ? hmsGestureLiveConfidenceThreshold : hmsGestureStillConfidenceThreshold;
}

export interface HmsGesturePixelMap {
  getImageInfo(): Promise<image.ImageInfo>;
  readPixelsToBuffer(buffer: ArrayBuffer): Promise<void>;
  release(): Promise<void>;
}

export interface HmsGestureOpenedImage {
  readonly pixelMap: HmsGesturePixelMap;
  close(): Promise<void>;
}

export interface HmsGestureImageLoader {
  open(imageUri: string): Promise<HmsGestureOpenedImage>;
}

export interface HmsGestureModelDetectorOptions {
  readonly resourceManager: RawfileContentReader;
  readonly nativeSessionFactory?: HmsGestureNativeSessionFactory;
  readonly imageLoader?: HmsGestureImageLoader;
  readonly confidenceThreshold?: number;
}

class HarmonyHmsGestureOpenedImage implements HmsGestureOpenedImage {
  readonly pixelMap: HmsGesturePixelMap;
  private readonly imageSource: image.ImageSource;
  private readonly imageFile: fileIo.File;
  private closed: boolean = false;

  constructor(pixelMap: image.PixelMap, imageSource: image.ImageSource, imageFile: fileIo.File) {
    this.pixelMap = new HarmonyHmsGesturePixelMap(pixelMap);
    this.imageSource = imageSource;
    this.imageFile = imageFile;
  }

  async close(): Promise<void> {
    if (this.closed) {
      return;
    }
    this.closed = true;
    try {
      await this.imageSource.release();
    } catch (_) {
    }
    try {
      await fileIo.close(this.imageFile);
    } catch (_) {
    }
  }
}

class HarmonyHmsGesturePixelMap implements HmsGesturePixelMap {
  private readonly pixelMap: image.PixelMap;

  constructor(pixelMap: image.PixelMap) {
    this.pixelMap = pixelMap;
  }

  getImageInfo(): Promise<image.ImageInfo> {
    return this.pixelMap.getImageInfo();
  }

  readPixelsToBuffer(buffer: ArrayBuffer): Promise<void> {
    return this.pixelMap.readPixelsToBuffer(buffer);
  }

  release(): Promise<void> {
    return this.pixelMap.release();
  }
}

export class HarmonyHmsGestureImageLoader implements HmsGestureImageLoader {
  async open(imageUri: string): Promise<HmsGestureOpenedImage> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      imageFile = await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(imageFile.fd);
      const pixelMap = await createPixelMapWithExifOrientation(imageSource, {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      return new HarmonyHmsGestureOpenedImage(pixelMap, imageSource, imageFile);
    } catch (_) {
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (_) {
        }
      }
      if (imageFile !== undefined) {
        try {
          await fileIo.close(imageFile);
        } catch (_) {
        }
      }
      throw new Error('Unable to decode gesture image input.');
    }
  }
}

export class HmsGestureModelDetector implements AndroidGestureModelDetector {
  private readonly resourceManager: RawfileContentReader;
  private readonly nativeSessionFactory: HmsGestureNativeSessionFactory;
  private readonly imageLoader: HmsGestureImageLoader;
  private readonly confidenceThreshold: number;
  private sessionPromise: Promise<HmsGestureNativeSession> | undefined = undefined;
  private predictionTail: Promise<void> = Promise.resolve();
  private stopPromise: Promise<void> | undefined = undefined;
  private stopped: boolean = false;

  constructor(options: HmsGestureModelDetectorOptions) {
    this.resourceManager = options.resourceManager;
    this.nativeSessionFactory = options.nativeSessionFactory ?? createHarmonyHmsGestureNativeSession;
    this.imageLoader = options.imageLoader ?? new HarmonyHmsGestureImageLoader();
    this.confidenceThreshold = options.confidenceThreshold ?? hmsGestureStillConfidenceThreshold;
    if (!Number.isFinite(this.confidenceThreshold) || this.confidenceThreshold < 0 ||
      this.confidenceThreshold > 1) {
      throw new Error('Invalid gesture confidence threshold.');
    }
  }

  async detectAndroidGestures(imageUri: string): Promise<AndroidGestureModelResult> {
    const startMs = Date.now();
    if (this.stopped) {
      throw new Error('Gesture detector has been stopped.');
    }
    const previous = this.predictionTail;
    let finish: (() => void) | undefined = undefined;
    this.predictionTail = new Promise<void>((resolve: () => void) => {
      finish = resolve;
    });
    await previous;
    try {
      if (this.stopped) {
        throw new Error('Gesture detector has been stopped.');
      }
      return await this.detectSerialized(imageUri, startMs);
    } finally {
      finish!();
    }
  }

  stop(): Promise<void> {
    if (this.stopPromise !== undefined) {
      return this.stopPromise;
    }
    this.stopped = true;
    this.stopPromise = this.predictionTail.then(async () => {
      if (this.sessionPromise === undefined) {
        return;
      }
      try {
        const session = await this.sessionPromise;
        session.release();
      } catch (_) {
      }
    });
    return this.stopPromise;
  }

  private async detectSerialized(imageUri: string, startMs: number): Promise<AndroidGestureModelResult> {
    const session = await this.session();
    const opened = await this.imageLoader.open(imageUri);
    try {
      const imageInfo = await opened.pixelMap.getImageInfo();
      const width = imageInfo.size.width;
      const height = imageInfo.size.height;
      const rgbaLength = width * height * 4;
      if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0 ||
        !Number.isSafeInteger(rgbaLength)) {
        throw new Error('Invalid gesture image dimensions.');
      }
      const rgba = new ArrayBuffer(rgbaLength);
      await opened.pixelMap.readPixelsToBuffer(rgba);
      const outputs = await session.predict(gestureInputFromRgba(new Uint8Array(rgba), width, height));
      validateHmsGestureOutputs(outputs);
      return {
        gestures: decodeHmsGestureOutputs(outputs, width, height, this.confidenceThreshold),
        imageWidth: width,
        imageHeight: height,
        executionMs: Date.now() - startMs
      };
    } finally {
      try {
        await opened.pixelMap.release();
      } finally {
        await opened.close();
      }
    }
  }

  private session(): Promise<HmsGestureNativeSession> {
    if (this.sessionPromise === undefined) {
      this.sessionPromise = this.loadSession();
    }
    return this.sessionPromise;
  }

  private async loadSession(): Promise<HmsGestureNativeSession> {
    const session = await this.nativeSessionFactory();
    try {
      const modelBytes = await this.resourceManager.getRawFileContent(hmsGestureModelRawfilePath);
      const modelInfo = session.loadModel(modelBytes);
      validateHmsGestureModelInfo(modelInfo);
      if (this.stopped) {
        throw new Error('Gesture detector has been stopped.');
      }
      return session;
    } catch (_) {
      session.release();
      throw new Error('Unable to load HMS gesture model.');
    }
  }
}

function validateHmsGestureModelInfo(info: HmsGestureModelInfo): void {
  if (info.inputName !== 'data' || info.inputShape.length !== 4 || info.inputShape[0] !== 1 ||
    info.inputShape[1] !== 3 || info.inputShape[2] !== 224 || info.inputShape[3] !== 224) {
    throw new Error('Invalid HMS gesture model input contract.');
  }
}

function validateHmsGestureOutputs(outputs: HmsGestureOutputs): void {
  for (let tensorIndex = 0; tensorIndex < outputs.tensors.length; tensorIndex++) {
    const values = new Float32Array(outputs.tensors[tensorIndex].data);
    for (let valueIndex = 0; valueIndex < values.length; valueIndex++) {
      if (!Number.isFinite(values[valueIndex])) {
        throw new Error('Gesture model output contains a non-finite value.');
      }
    }
  }
}
