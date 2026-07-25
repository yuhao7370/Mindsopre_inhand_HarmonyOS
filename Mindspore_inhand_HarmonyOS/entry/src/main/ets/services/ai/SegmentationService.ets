import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { subjectSegmentation } from '@kit.CoreVisionKit';
import { RawfileContentReader } from './MindSporeLiteModelRunner';
import {
  decodingOptionsWithImageRotation,
  imageRotationDegreesFromImageSource,
  rotatedImageSize
} from './ImageDecodeOrientation';

export interface SegmentationRectangle {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export type SegmentationFailureReason = 'noSubject' | 'runtimeException';

export interface SegmentationResult {
  readonly ok: boolean;
  readonly subjectCount: number;
  readonly detailCount: number;
  readonly foregroundAvailable: boolean;
  readonly foregroundImageRgba?: ArrayBuffer;
  readonly foregroundImageWidth?: number;
  readonly foregroundImageHeight?: number;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly rectangles: Array<SegmentationRectangle>;
  readonly executionMs: number;
  readonly failureReason?: SegmentationFailureReason;
}

interface SegmentationForegroundImage {
  readonly rgba: ArrayBuffer;
  readonly width: number;
  readonly height: number;
}

export interface SegmentationRectanglePercent {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface SegmentationRunner {
  segmentPerson(imageUri: string): Promise<SegmentationResult>;
}

export type SegmentationAndroidScene = 'all' | 'foregroundOnly';

export interface HarmonySubjectSegmentationRunnerOptions {
  readonly androidScene?: SegmentationAndroidScene;
}

export interface SegmentationServiceOptions {
  readonly runner: SegmentationRunner;
}

export const selfieSegmentationModelRawfilePath: string = 'model/selfie_segmentation.mnn';
export const selfieSegmentationInputSize: number = 256;
export const selfieSegmentationMaskThreshold: number = 0.1;
export const selfieSegmentationMinimumForegroundRatio: number = 0.01;

export interface SegmentationMnnModelInfo {
  readonly inputName: string;
  readonly inputShape: Array<number>;
  readonly outputName: string;
  readonly outputShape: Array<number>;
}

export interface SegmentationMnnNativeSession {
  loadModel(modelBytes: Uint8Array): SegmentationMnnModelInfo;
  predict(input: Float32Array): Promise<ArrayBuffer>;
  release(): void;
}

export type SegmentationMnnNativeSessionFactory = () => Promise<SegmentationMnnNativeSession>;

class HarmonySegmentationMnnNativeSession implements SegmentationMnnNativeSession {
  private readonly nativeModule: ESObject;

  constructor(nativeModule: ESObject) {
    this.nativeModule = nativeModule;
  }

  loadModel(modelBytes: Uint8Array): SegmentationMnnModelInfo {
    return this.nativeModule.loadModel(modelBytes) as SegmentationMnnModelInfo;
  }

  async predict(input: Float32Array): Promise<ArrayBuffer> {
    return await this.nativeModule.predict(input) as ArrayBuffer;
  }

  release(): void {
    this.nativeModule.release();
  }
}

export const createHarmonySegmentationMnnNativeSession: SegmentationMnnNativeSessionFactory = async () => {
  const namespace: ESObject = await import('libsegmentation_mnn.so');
  return new HarmonySegmentationMnnNativeSession(namespace.default);
};

export interface LocalMnnSegmentationRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly androidScene?: SegmentationAndroidScene;
  readonly sessionFactory?: SegmentationMnnNativeSessionFactory;
}

export class CoreVisionFallbackSegmentationRunner implements SegmentationRunner {
  private readonly primary: SegmentationRunner;
  private readonly fallback: SegmentationRunner;
  private primaryAvailable: boolean = true;

  constructor(primary: SegmentationRunner, fallback: SegmentationRunner) {
    this.primary = primary;
    this.fallback = fallback;
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    if (this.primaryAvailable) {
      try {
        return await this.primary.segmentPerson(imageUri);
      } catch (_) {
        this.primaryAvailable = false;
      }
    }
    return await this.fallback.segmentPerson(imageUri);
  }
}

export class LocalMnnSegmentationRunner implements SegmentationRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly androidScene: SegmentationAndroidScene;
  private readonly sessionFactory: SegmentationMnnNativeSessionFactory;
  private sessionPromise: Promise<SegmentationMnnNativeSession> | undefined = undefined;

  constructor(options: LocalMnnSegmentationRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.androidScene = options.androidScene ?? 'all';
    this.sessionFactory = options.sessionFactory ?? createHarmonySegmentationMnnNativeSession;
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    const startMs = Date.now();
    const input = await selfieSegmentationInputFromImageUri(imageUri);
    const session = await this.modelSession();
    const output = new Float32Array(await session.predict(input.normalizedRgb));
    return localSegmentationResultFromMask(
      input.resizedRgba,
      output,
      this.androidScene,
      Date.now() - startMs
    );
  }

  private async modelSession(): Promise<SegmentationMnnNativeSession> {
    if (this.sessionPromise === undefined) {
      this.sessionPromise = this.createModelSession();
    }
    return await this.sessionPromise;
  }

  private async createModelSession(): Promise<SegmentationMnnNativeSession> {
    const session = await this.sessionFactory();
    try {
      const modelBytes = await this.resourceManager.getRawFileContent(selfieSegmentationModelRawfilePath);
      const info = session.loadModel(modelBytes);
      if (info.inputName !== 'input_1' || info.inputShape.join(',') !== '1,256,256,3' ||
        info.outputName !== 'activation_10' || info.outputShape.join(',') !== '1,256,256,1') {
        throw new Error('Portrait segmentation model tensor contract mismatch.');
      }
      return session;
    } catch (_) {
      session.release();
      throw new Error('Unable to initialize the portrait segmentation model.');
    }
  }
}

interface SelfieSegmentationInput {
  readonly normalizedRgb: Float32Array;
  readonly resizedRgba: Uint8Array;
}

export class SegmentationService {
  private readonly runner: SegmentationRunner;

  constructor(options: SegmentationServiceOptions) {
    this.runner = options.runner;
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    const startMs = Date.now();
    try {
      const result = await this.runner.segmentPerson(imageUri);
      if (!result.ok || result.foregroundAvailable) {
        return result;
      }
      return {
        ok: false,
        subjectCount: result.subjectCount,
        detailCount: result.detailCount,
        foregroundAvailable: false,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
        rectangles: result.rectangles,
        executionMs: result.executionMs,
        failureReason: 'runtimeException'
      };
    } catch (_) {
      return {
        ok: false,
        subjectCount: 0,
        detailCount: 0,
        foregroundAvailable: false,
        rectangles: [],
        executionMs: Date.now() - startMs,
        failureReason: 'runtimeException'
      };
    }
  }
}

export class HarmonySubjectSegmentationRunner implements SegmentationRunner {
  private readonly androidScene: SegmentationAndroidScene;

  constructor(options?: HarmonySubjectSegmentationRunnerOptions) {
    this.androidScene = options?.androidScene ?? 'all';
  }

  async segmentPerson(imageUri: string): Promise<SegmentationResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    const startMs = Date.now();
    try {
      imageFile = await openSegmentationImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
      const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);
      pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({}, rotationDegrees));
      const result = await subjectSegmentation.doSegmentation({
        pixelMap: pixelMap
      }, segmentationConfigForAndroidScene(this.androidScene));
      const segmentationResult = await segmentationResultFromCoreVision(
        result,
        Date.now() - startMs,
        displaySize.width,
        displaySize.height
      );
      await releaseSegmentationResultImages(result);
      return segmentationResult;
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeSegmentationImageFile(imageFile);
      }
    }
  }
}

export function segmentationConfigForAndroidScene(
  scene: SegmentationAndroidScene
): subjectSegmentation.SegmentationConfig {
  return {
    maxCount: 6,
    enableSubjectDetails: scene === 'all',
    enableSubjectForegroundImage: true
  };
}

export async function segmentationResultFromCoreVision(
  result: subjectSegmentation.SegmentationResult,
  executionMs: number,
  imageWidth: number = 0,
  imageHeight: number = 0
): Promise<SegmentationResult> {
  const rectangles: Array<SegmentationRectangle> = [];
  rectangles.push(rectangleFromCoreVision(result.fullSubject.subjectRectangle));
  if (result.subjectDetails !== undefined) {
    result.subjectDetails.forEach((subject: subjectSegmentation.SubjectResult) => {
      rectangles.push(rectangleFromCoreVision(subject.subjectRectangle));
    });
  }
  if (result.subjectCount === 0) {
    return {
      ok: false,
      subjectCount: 0,
      detailCount: result.subjectDetails?.length ?? 0,
      foregroundAvailable: false,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      rectangles: rectangles,
      executionMs: executionMs,
      failureReason: 'noSubject'
    };
  }
  const foreground = await foregroundImageFromSubject(result.fullSubject);
  return {
    ok: true,
    subjectCount: result.subjectCount,
    detailCount: result.subjectDetails?.length ?? 0,
    foregroundAvailable: foreground !== undefined,
    foregroundImageRgba: foreground?.rgba,
    foregroundImageWidth: foreground?.width,
    foregroundImageHeight: foreground?.height,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    rectangles: rectangles,
    executionMs: executionMs
  };
}

export function segmentationRectanglePercent(
  rectangle: SegmentationRectangle,
  imageWidth: number,
  imageHeight: number
): SegmentationRectanglePercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      left: 0,
      top: 0,
      width: 0,
      height: 0
    };
  }

  const left = segmentationPercent(rectangle.left, imageWidth);
  const top = segmentationPercent(rectangle.top, imageHeight);
  const right = segmentationPercent(rectangle.left + rectangle.width, imageWidth);
  const bottom = segmentationPercent(rectangle.top + rectangle.height, imageHeight);
  return {
    left: left,
    top: top,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top)
  };
}

function segmentationPercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}

function rectangleFromCoreVision(rectangle: subjectSegmentation.Rectangle): SegmentationRectangle {
  return {
    left: rectangle.left,
    top: rectangle.top,
    width: rectangle.width,
    height: rectangle.height
  };
}

async function foregroundImageFromSubject(
  subject: subjectSegmentation.SubjectResult
): Promise<SegmentationForegroundImage | undefined> {
  try {
    const imageInfo: image.ImageInfo = await subject.foregroundImage.getImageInfo();
    const width = imageInfo.size.width;
    const height = imageInfo.size.height;
    if (width <= 0 || height <= 0) {
      return undefined;
    }
    const rgba = new ArrayBuffer(width * height * 4);
    await subject.foregroundImage.readPixelsToBuffer(rgba);
    return {
      rgba: rgba,
      width: width,
      height: height
    };
  } catch (_) {
    return undefined;
  }
}

async function releaseSegmentationResultImages(result: subjectSegmentation.SegmentationResult): Promise<void> {
  await releaseSubjectImage(result.fullSubject);
  if (result.subjectDetails !== undefined) {
    for (const subject of result.subjectDetails) {
      await releaseSubjectImage(subject);
    }
  }
}

async function releaseSubjectImage(subject: subjectSegmentation.SubjectResult): Promise<void> {
  try {
    await subject.foregroundImage.release();
  } catch (_) {
  }
}

async function selfieSegmentationInputFromImageUri(imageUri: string): Promise<SelfieSegmentationInput> {
  let imageFile: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    imageFile = await openSegmentationImageFile(imageUri);
    imageSource = image.createImageSource(imageFile.fd);
    const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
    pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({
      desiredSize: {
        width: selfieSegmentationInputSize,
        height: selfieSegmentationInputSize
      },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    }, rotationDegrees));
    const rgbaBuffer = new ArrayBuffer(selfieSegmentationInputSize * selfieSegmentationInputSize * 4);
    await pixelMap.readPixelsToBuffer(rgbaBuffer);
    const rgba = new Uint8Array(rgbaBuffer);
    const rgb = new Float32Array(selfieSegmentationInputSize * selfieSegmentationInputSize * 3);
    for (let pixel = 0; pixel < selfieSegmentationInputSize * selfieSegmentationInputSize; pixel++) {
      rgb[pixel * 3] = rgba[pixel * 4] / 255;
      rgb[pixel * 3 + 1] = rgba[pixel * 4 + 1] / 255;
      rgb[pixel * 3 + 2] = rgba[pixel * 4 + 2] / 255;
    }
    return {
      normalizedRgb: rgb,
      resizedRgba: rgba
    };
  } finally {
    if (pixelMap !== undefined) {
      await pixelMap.release();
    }
    if (imageSource !== undefined) {
      await imageSource.release();
    }
    if (imageFile !== undefined) {
      await closeSegmentationImageFile(imageFile);
    }
  }
}

export function localSegmentationResultFromMask(
  resizedRgba: Uint8Array,
  mask: Float32Array,
  androidScene: SegmentationAndroidScene,
  executionMs: number
): SegmentationResult {
  const pixelCount = selfieSegmentationInputSize * selfieSegmentationInputSize;
  if (resizedRgba.length !== pixelCount * 4 || mask.length !== pixelCount) {
    throw new Error('Portrait segmentation tensor length mismatch.');
  }
  const foreground = new Uint8Array(pixelCount * 4);
  let foregroundCount = 0;
  let left = selfieSegmentationInputSize;
  let top = selfieSegmentationInputSize;
  let right = -1;
  let bottom = -1;
  for (let pixel = 0; pixel < pixelCount; pixel++) {
    const probability = mask[pixel];
    if (!Number.isFinite(probability)) {
      throw new Error('Portrait segmentation mask contains a non-finite value.');
    }
    if (probability <= selfieSegmentationMaskThreshold) {
      continue;
    }
    foregroundCount++;
    const x = pixel % selfieSegmentationInputSize;
    const y = Math.floor(pixel / selfieSegmentationInputSize);
    left = Math.min(left, x);
    top = Math.min(top, y);
    right = Math.max(right, x);
    bottom = Math.max(bottom, y);
    const offset = pixel * 4;
    foreground[offset] = resizedRgba[offset];
    foreground[offset + 1] = resizedRgba[offset + 1];
    foreground[offset + 2] = resizedRgba[offset + 2];
    foreground[offset + 3] = 255;
  }

  if (foregroundCount / pixelCount < selfieSegmentationMinimumForegroundRatio) {
    return {
      ok: false,
      subjectCount: 0,
      detailCount: 0,
      foregroundAvailable: false,
      imageWidth: selfieSegmentationInputSize,
      imageHeight: selfieSegmentationInputSize,
      rectangles: [],
      executionMs: executionMs,
      failureReason: 'noSubject'
    };
  }

  const rectangle: SegmentationRectangle = {
    left: left,
    top: top,
    width: right - left + 1,
    height: bottom - top + 1
  };
  const rectangles: Array<SegmentationRectangle> = [rectangle];
  const detailCount = androidScene === 'all' ? 1 : 0;
  if (detailCount > 0) {
    rectangles.push(rectangle);
  }
  return {
    ok: true,
    subjectCount: 1,
    detailCount: detailCount,
    foregroundAvailable: true,
    foregroundImageRgba: foreground.buffer as ArrayBuffer,
    foregroundImageWidth: selfieSegmentationInputSize,
    foregroundImageHeight: selfieSegmentationInputSize,
    imageWidth: selfieSegmentationInputSize,
    imageHeight: selfieSegmentationInputSize,
    rectangles: rectangles,
    executionMs: executionMs
  };
}

async function openSegmentationImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for segmentation.');
  }
}

async function closeSegmentationImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
