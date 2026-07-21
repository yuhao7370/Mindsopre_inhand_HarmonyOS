import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { skeletonDetection, visionBase } from '@kit.CoreVisionKit';
import {
  RawfileContentReader,
  mindSporeLiteCpuContext,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';
import {
  decodingOptionsWithImageRotation,
  imageRotationDegreesFromImageSource,
  rotatedImageSize
} from './ImageDecodeOrientation';
import { PosePointType } from './PosePointType';

export interface PosePoint {
  readonly type: number;
  readonly score: number;
  readonly x: number;
  readonly y: number;
}

export interface PoseResult {
  readonly ok: boolean;
  readonly skeletonCount: number;
  readonly pointCount: number;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly points: Array<PosePoint>;
  readonly similarity?: number;
  readonly executionMs: number;
}

export interface PosePointPercent {
  readonly x: number;
  readonly y: number;
}

export interface PoseLine {
  readonly start: PosePoint;
  readonly end: PosePoint;
}

export interface PoseLinePercent {
  readonly startX: number;
  readonly startY: number;
  readonly endX: number;
  readonly endY: number;
  readonly length: number;
  readonly angle: number;
}

interface PoseLineTypePair {
  readonly startType: number;
  readonly endType: number;
}

interface PoseBounds {
  readonly minX: number;
  readonly minY: number;
  readonly width: number;
  readonly height: number;
}

interface NormalizedPosePoint {
  readonly x: number;
  readonly y: number;
}

export type PoseDetectionMode = 'normal' | 'yoga';

export interface PoseRunner {
  detectPose(imageUri: string, mode?: PoseDetectionMode): Promise<PoseResult>;
}

export interface PoseServiceOptions {
  readonly runner: PoseRunner;
  readonly mode?: PoseDetectionMode;
}

export interface HarmonySkeletonDetectionRunnerOptions {
  readonly resourceManager?: RawfileContentReader;
}

export interface MoveNetLetterbox {
  readonly originalWidth: number;
  readonly originalHeight: number;
  readonly resizedWidth: number;
  readonly resizedHeight: number;
  readonly padX: number;
  readonly padY: number;
}

export interface MoveNetInput {
  readonly inputBuffer: ArrayBuffer;
  readonly letterbox: MoveNetLetterbox;
}

export interface MoveNetInputPreprocessor {
  createInput(imageUri: string): Promise<MoveNetInput>;
}

export interface MoveNetRuntime {
  loadModel(content: Uint8Array): Promise<void>;
  predict(input: Uint8Array): Promise<Float32Array>;
}

export interface LocalMoveNetPoseRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
  readonly preprocessor?: MoveNetInputPreprocessor;
  readonly runtime?: MoveNetRuntime;
}

export interface PoseImageSourceInput {
  readonly imageSource: image.ImageSource;
  readonly imageFile?: fileIo.File;
}

export interface PoseImageSourceFactory {
  createSourceFromRawfileContent(content: Uint8Array): image.ImageSource;
  createSourceFromFile(imageFile: fileIo.File): image.ImageSource;
}

export interface PoseImageFileOpener {
  open(imageUri: string): Promise<fileIo.File>;
  close(imageFile: fileIo.File): Promise<void>;
}

export interface PoseImageSourceForUriOptions {
  readonly resourceManager?: RawfileContentReader;
  readonly sourceFactory?: PoseImageSourceFactory;
  readonly fileOpener?: PoseImageFileOpener;
}

export const poseMinPointScore = 0.2;
export const poseRawfileUriPrefix = 'rawfile://';
export const moveNetModelRawfilePath: string = 'model/movenet_singlepose_lightning_float16_v4.ms';
export const moveNetInputSize: number = 192;
export const moveNetInputChannelCount: number = 3;
export const moveNetInputByteCount: number = moveNetInputSize * moveNetInputSize * moveNetInputChannelCount;
export const moveNetPointCount: number = 17;
export const moveNetOutputFloatCount: number = moveNetPointCount * 3;
const moveNetOutputByteCount: number = moveNetOutputFloatCount * Float32Array.BYTES_PER_ELEMENT;
const moveNetInputName: string = 'serving_default_input:0';
const moveNetOutputName: string = 'StatefulPartitionedCall:0';
const moveNetMinVisiblePointCount: number = 6;
const moveNetMinVisibleLineCount: number = 4;

export const androidLiveSkeletonTemplatePoints: Array<PosePoint> = [
  { x: 416.6629, y: 312.46442, type: 101, score: 0.8042025 },
  { x: 382.3348, y: 519.43396, type: 102, score: 0.86383355 },
  { x: 381.0387, y: 692.09515, type: 103, score: 0.7551306 },
  { x: 659.49194, y: 312.24445, type: 104, score: 0.8305682 },
  { x: 693.5356, y: 519.4844, type: 105, score: 0.8932837 },
  { x: 694.0054, y: 692.4169, type: 106, score: 0.8742422 },
  { x: 485.08786, y: 726.8787, type: 107, score: 0.6004682 },
  { x: 485.02808, y: 935.4897, type: 108, score: 0.7334503 },
  { x: 485.09384, y: 1177.127, type: 109, score: 0.67240065 },
  { x: 623.7807, y: 726.7474, type: 110, score: 0.5483011 },
  { x: 624.5828, y: 936.3222, type: 111, score: 0.730425 },
  { x: 625.81915, y: 1212.2491, type: 112, score: 0.72417295 },
  { x: 521.47363, y: 103.95903, type: 113, score: 0.7780853 },
  { x: 521.6231, y: 277.2533, type: 114, score: 0.7745689 }
];

const poseSkeletonLineTypePairs: Array<PoseLineTypePair> = [
  {
    startType: PosePointType.NOSE,
    endType: PosePointType.LEFT_SHOULDER
  },
  {
    startType: PosePointType.NOSE,
    endType: PosePointType.RIGHT_SHOULDER
  },
  {
    startType: PosePointType.LEFT_SHOULDER,
    endType: PosePointType.LEFT_ELBOW
  },
  {
    startType: PosePointType.LEFT_ELBOW,
    endType: PosePointType.LEFT_WRIST
  },
  {
    startType: PosePointType.LEFT_SHOULDER,
    endType: PosePointType.LEFT_HIP
  },
  {
    startType: PosePointType.LEFT_HIP,
    endType: PosePointType.LEFT_KNEE
  },
  {
    startType: PosePointType.LEFT_KNEE,
    endType: PosePointType.LEFT_ANKLE
  },
  {
    startType: PosePointType.RIGHT_SHOULDER,
    endType: PosePointType.RIGHT_ELBOW
  },
  {
    startType: PosePointType.RIGHT_ELBOW,
    endType: PosePointType.RIGHT_WRIST
  },
  {
    startType: PosePointType.RIGHT_SHOULDER,
    endType: PosePointType.RIGHT_HIP
  },
  {
    startType: PosePointType.RIGHT_HIP,
    endType: PosePointType.RIGHT_KNEE
  },
  {
    startType: PosePointType.RIGHT_KNEE,
    endType: PosePointType.RIGHT_ANKLE
  }
];

export class PoseService {
  private readonly runner: PoseRunner;
  private readonly mode: PoseDetectionMode;

  constructor(options: PoseServiceOptions) {
    this.runner = options.runner;
    this.mode = options.mode ?? 'normal';
  }

  async detectPose(imageUri: string): Promise<PoseResult> {
    const startMs = Date.now();
    try {
      const result = poseResultWithEmptySuccessGuard(await this.runner.detectPose(imageUri, this.mode));
      if (this.mode === 'yoga') {
        return poseResultWithAndroidTemplateSimilarity(result);
      }
      return poseResultWithoutSimilarity(result);
    } catch (_) {
      return {
        ok: false,
        skeletonCount: 0,
        pointCount: 0,
        points: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

function poseResultWithEmptySuccessGuard(result: PoseResult): PoseResult {
  if (!result.ok || (result.skeletonCount > 0 && result.pointCount > 0 && result.points.length > 0)) {
    return result;
  }
  return {
    ok: false,
    skeletonCount: result.skeletonCount,
    pointCount: result.pointCount,
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    points: result.points,
    executionMs: result.executionMs
  };
}

export class HarmonySkeletonDetectionRunner implements PoseRunner {
  private readonly resourceManager?: RawfileContentReader;

  constructor(options?: HarmonySkeletonDetectionRunnerOptions) {
    this.resourceManager = options?.resourceManager;
  }

  async detectPose(imageUri: string, _mode?: PoseDetectionMode): Promise<PoseResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let detector: skeletonDetection.SkeletonDetector | undefined = undefined;
    const startMs = Date.now();
    try {
      const input = await createPoseImageSourceForUri(imageUri, {
        resourceManager: this.resourceManager
      });
      imageSource = input.imageSource;
      imageFile = input.imageFile;
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
      const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);
      pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({}, rotationDegrees));
      detector = await skeletonDetection.SkeletonDetector.create();
      const request = new visionBase.Request();
      const inputData: visionBase.ImageData = {
        pixelMap: pixelMap
      };
      request.inputData = inputData;
      const response = await detector.process(request);
      return poseResultFromCoreVision(
        response.skeletons,
        Date.now() - startMs,
        displaySize.width,
        displaySize.height
      );
    } finally {
      if (detector !== undefined) {
        await destroySkeletonDetector(detector);
      }
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closePoseImageFile(imageFile);
      }
    }
  }
}

export class CoreVisionFallbackPoseRunner implements PoseRunner {
  private readonly coreVisionRunner: PoseRunner;
  private readonly localRunner: PoseRunner;

  constructor(coreVisionRunner: PoseRunner, localRunner: PoseRunner) {
    this.coreVisionRunner = coreVisionRunner;
    this.localRunner = localRunner;
  }

  async detectPose(imageUri: string, mode?: PoseDetectionMode): Promise<PoseResult> {
    try {
      const result = await this.coreVisionRunner.detectPose(imageUri, mode);
      if (isUsablePoseResult(result)) {
        return result;
      }
    } catch (_) {
    }
    return this.localRunner.detectPose(imageUri, mode);
  }
}

export class HarmonyMoveNetInputPreprocessor implements MoveNetInputPreprocessor {
  private readonly resourceManager?: RawfileContentReader;

  constructor(resourceManager?: RawfileContentReader) {
    this.resourceManager = resourceManager;
  }

  async createInput(imageUri: string): Promise<MoveNetInput> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      const sourceInput = await createPoseImageSourceForUri(imageUri, {
        resourceManager: this.resourceManager
      });
      imageSource = sourceInput.imageSource;
      imageFile = sourceInput.imageFile;
      const imageInfo = await imageSource.getImageInfo();
      const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);
      const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);
      const letterbox = moveNetLetterboxForImage(displaySize.width, displaySize.height);
      pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      }, rotationDegrees));
      await pixelMap.scale(
        letterbox.resizedWidth / displaySize.width,
        letterbox.resizedHeight / displaySize.height,
        image.AntiAliasingLevel.LOW
      );
      const rgba = new Uint8Array(letterbox.resizedWidth * letterbox.resizedHeight * 4);
      await pixelMap.readPixelsToBuffer(rgba.buffer as ArrayBuffer);
      return {
        inputBuffer: moveNetRgbInputFromResizedRgba(rgba, letterbox),
        letterbox: letterbox
      };
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closePoseImageFile(imageFile);
      }
    }
  }
}

class MindSporeLiteMoveNetRuntime implements MoveNetRuntime {
  private model?: mindSporeLite.Model;

  async loadModel(content: Uint8Array): Promise<void> {
    const candidate = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(content),
      mindSporeLiteCpuContext()
    );
    const inputs = candidate.getInputs();
    if (inputs.length !== 1 || !moveNetInputTensorMatches(inputs[0])) {
      throw new Error('MoveNet input tensor contract mismatch.');
    }
    this.model = candidate;
  }

  async predict(input: Uint8Array): Promise<Float32Array> {
    if (this.model === undefined || input.length !== moveNetInputByteCount) {
      throw new Error('MoveNet runtime is not ready.');
    }
    const inputs = this.model.getInputs();
    if (inputs.length !== 1 || !moveNetInputTensorMatches(inputs[0])) {
      throw new Error('MoveNet input tensor contract mismatch.');
    }
    const inputBuffer = new ArrayBuffer(input.length);
    new Uint8Array(inputBuffer).set(input);
    inputs[0].setData(inputBuffer);
    const outputs = await this.model.predict(inputs);
    if (outputs.length !== 1 || !moveNetOutputTensorMatches(outputs[0])) {
      throw new Error('MoveNet output tensor contract mismatch.');
    }
    const output = new Float32Array(outputs[0].getData());
    if (!moveNetOutputValuesAreFiniteAndNormalized(output)) {
      throw new Error('MoveNet output contains invalid values.');
    }
    return output;
  }
}

class MoveNetRuntimeState {
  loadedModelKey: string = '';
  operationTail: Promise<void> = Promise.resolve();
}

const sharedMindSporeLiteMoveNetRuntime: MoveNetRuntime = new MindSporeLiteMoveNetRuntime();
const moveNetRuntimeStates: Map<MoveNetRuntime, MoveNetRuntimeState> = new Map<MoveNetRuntime, MoveNetRuntimeState>();

function moveNetRuntimeState(runtime: MoveNetRuntime): MoveNetRuntimeState {
  const existing = moveNetRuntimeStates.get(runtime);
  if (existing !== undefined) {
    return existing;
  }
  const state = new MoveNetRuntimeState();
  moveNetRuntimeStates.set(runtime, state);
  return state;
}

export class LocalMoveNetPoseRunner implements PoseRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly modelRawfilePath: string;
  private readonly preprocessor: MoveNetInputPreprocessor;
  private readonly runtime: MoveNetRuntime;
  private readonly runtimeState: MoveNetRuntimeState;

  constructor(options: LocalMoveNetPoseRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.modelRawfilePath = options.modelRawfilePath;
    this.preprocessor = options.preprocessor ?? new HarmonyMoveNetInputPreprocessor(options.resourceManager);
    this.runtime = options.runtime ?? sharedMindSporeLiteMoveNetRuntime;
    this.runtimeState = moveNetRuntimeState(this.runtime);
  }

  detectPose(imageUri: string, _mode?: PoseDetectionMode): Promise<PoseResult> {
    const operation = this.runtimeState.operationTail.then(async (): Promise<PoseResult> =>
      await this.detectPoseExclusive(imageUri));
    this.runtimeState.operationTail = operation.then((): void => {}, (): void => {});
    return operation;
  }

  private async detectPoseExclusive(imageUri: string): Promise<PoseResult> {
    const startMs = Date.now();
    const input = await this.preprocessor.createInput(imageUri);
    if (input.inputBuffer.byteLength !== moveNetInputByteCount) {
      throw new Error('MoveNet input byte length mismatch.');
    }
    const modelKey = `rawfile:${this.modelRawfilePath}`;
    if (this.runtimeState.loadedModelKey !== modelKey) {
      const content = await this.resourceManager.getRawFileContent(this.modelRawfilePath);
      await this.runtime.loadModel(content);
      this.runtimeState.loadedModelKey = modelKey;
    }
    const output = await this.runtime.predict(new Uint8Array(input.inputBuffer));
    return moveNetPoseResultFromOutput(output, input.letterbox, Date.now() - startMs);
  }
}

function isUsablePoseResult(result: PoseResult): boolean {
  return result.ok && result.skeletonCount > 0 && result.pointCount > 0 && result.points.length > 0;
}

function moveNetInputTensorMatches(tensor: mindSporeLite.MSTensor): boolean {
  return moveNetTensorContractMatches(
    1,
    tensor.name,
    tensor.shape,
    tensor.dtype,
    tensor.dataSize,
    1,
    moveNetOutputName,
    [1, 1, moveNetPointCount, 3],
    mindSporeLite.DataType.NUMBER_TYPE_FLOAT32,
    moveNetOutputByteCount
  ) && tensor.elementNum === moveNetInputByteCount;
}

function moveNetOutputTensorMatches(tensor: mindSporeLite.MSTensor): boolean {
  return tensor.name === moveNetOutputName &&
    tensor.dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 &&
    tensor.elementNum === moveNetOutputFloatCount && tensor.dataSize === moveNetOutputByteCount &&
    numberArraysEqual(tensor.shape, [1, 1, moveNetPointCount, 3]);
}

export class HarmonyPoseImageSourceFactory implements PoseImageSourceFactory {
  createSourceFromRawfileContent(content: Uint8Array): image.ImageSource {
    return image.createImageSource(rawfileContentToArrayBuffer(content));
  }

  createSourceFromFile(imageFile: fileIo.File): image.ImageSource {
    return image.createImageSource(imageFile.fd);
  }
}

export class HarmonyPoseImageFileOpener implements PoseImageFileOpener {
  async open(imageUri: string): Promise<fileIo.File> {
    return openPoseImageFile(imageUri);
  }

  async close(imageFile: fileIo.File): Promise<void> {
    await closePoseImageFile(imageFile);
  }
}

export async function createPoseImageSourceForUri(
  imageUri: string,
  options?: PoseImageSourceForUriOptions
): Promise<PoseImageSourceInput> {
  const sourceFactory = options?.sourceFactory ?? new HarmonyPoseImageSourceFactory();
  const rawfilePath = rawfilePathFromPoseImageUri(imageUri);
  if (rawfilePath.length > 0) {
    if (options?.resourceManager === undefined) {
      throw new Error('Unable to read built-in pose image without rawfile reader.');
    }
    const rawfileContent = await options.resourceManager.getRawFileContent(rawfilePath);
    return {
      imageSource: sourceFactory.createSourceFromRawfileContent(rawfileContent)
    };
  }

  const fileOpener = options?.fileOpener ?? new HarmonyPoseImageFileOpener();
  const imageFile = await fileOpener.open(imageUri);
  try {
    return {
      imageSource: sourceFactory.createSourceFromFile(imageFile),
      imageFile: imageFile
    };
  } catch (_) {
    await fileOpener.close(imageFile);
    throw new Error('Unable to create image source for pose detection.');
  }
}

export function rawfilePathFromPoseImageUri(uri: string): string {
  if (!uri.startsWith(poseRawfileUriPrefix)) {
    return '';
  }
  return uri.substring(poseRawfileUriPrefix.length);
}

export function moveNetLetterboxForImage(imageWidth: number, imageHeight: number): MoveNetLetterbox {
  if (imageWidth <= 0 || imageHeight <= 0) {
    throw new Error('MoveNet image dimensions must be positive.');
  }
  const scale = Math.min(moveNetInputSize / imageWidth, moveNetInputSize / imageHeight);
  const resizedWidth = Math.min(moveNetInputSize, Math.max(1, Math.round(imageWidth * scale)));
  const resizedHeight = Math.min(moveNetInputSize, Math.max(1, Math.round(imageHeight * scale)));
  return {
    originalWidth: imageWidth,
    originalHeight: imageHeight,
    resizedWidth: resizedWidth,
    resizedHeight: resizedHeight,
    padX: Math.floor((moveNetInputSize - resizedWidth) / 2),
    padY: Math.floor((moveNetInputSize - resizedHeight) / 2)
  };
}

export function moveNetRgbInputFromResizedRgba(
  rgba: Uint8Array,
  letterbox: MoveNetLetterbox
): ArrayBuffer {
  const expectedRgbaLength = letterbox.resizedWidth * letterbox.resizedHeight * 4;
  if (rgba.length !== expectedRgbaLength || !validMoveNetLetterbox(letterbox)) {
    throw new Error('MoveNet resized RGBA input mismatch.');
  }
  const rgb = new Uint8Array(moveNetInputByteCount);
  for (let y = 0; y < letterbox.resizedHeight; y++) {
    for (let x = 0; x < letterbox.resizedWidth; x++) {
      const sourceOffset = (y * letterbox.resizedWidth + x) * 4;
      const targetOffset = ((y + letterbox.padY) * moveNetInputSize + x + letterbox.padX) * 3;
      rgb[targetOffset] = rgba[sourceOffset];
      rgb[targetOffset + 1] = rgba[sourceOffset + 1];
      rgb[targetOffset + 2] = rgba[sourceOffset + 2];
    }
  }
  return rgb.buffer as ArrayBuffer;
}

export function moveNetPoseResultFromOutput(
  output: Float32Array,
  letterbox: MoveNetLetterbox,
  executionMs: number
): PoseResult {
  if (!validMoveNetLetterbox(letterbox) || !moveNetOutputValuesAreFiniteAndNormalized(output)) {
    return emptyMoveNetPoseResult(executionMs, letterbox);
  }
  const points: Array<PosePoint> = [];
  for (let index = 0; index < moveNetPointCount; index++) {
    const normalizedY = output[index * 3];
    const normalizedX = output[index * 3 + 1];
    const score = output[index * 3 + 2];
    const resizedX = normalizedX * moveNetInputSize - letterbox.padX;
    const resizedY = normalizedY * moveNetInputSize - letterbox.padY;
    points.push({
      type: index,
      score: score,
      x: clampPoseCoordinate(resizedX * letterbox.originalWidth / letterbox.resizedWidth, letterbox.originalWidth),
      y: clampPoseCoordinate(resizedY * letterbox.originalHeight / letterbox.resizedHeight, letterbox.originalHeight)
    });
  }
  let visiblePointCount = 0;
  points.forEach((point: PosePoint) => {
    if (isPosePointVisible(point)) {
      visiblePointCount++;
    }
  });
  const usable = visiblePointCount >= moveNetMinVisiblePointCount &&
    poseSkeletonLines(points).length >= moveNetMinVisibleLineCount;
  return {
    ok: usable,
    skeletonCount: usable ? 1 : 0,
    pointCount: points.length,
    imageWidth: letterbox.originalWidth,
    imageHeight: letterbox.originalHeight,
    points: points,
    executionMs: executionMs
  };
}

export function moveNetTensorContractMatches(
  inputCount: number,
  inputName: string,
  inputShape: Array<number>,
  inputDtype: number,
  inputDataSize: number,
  outputCount: number,
  outputName: string,
  outputShape: Array<number>,
  outputDtype: number,
  outputDataSize: number
): boolean {
  return inputCount === 1 && inputName === moveNetInputName &&
    numberArraysEqual(inputShape, [1, moveNetInputSize, moveNetInputSize, moveNetInputChannelCount]) &&
    inputDtype === mindSporeLite.DataType.NUMBER_TYPE_UINT8 && inputDataSize === moveNetInputByteCount &&
    outputCount === 1 && outputName === moveNetOutputName &&
    numberArraysEqual(outputShape, [1, 1, moveNetPointCount, 3]) &&
    outputDtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 && outputDataSize === moveNetOutputByteCount;
}

function validMoveNetLetterbox(letterbox: MoveNetLetterbox): boolean {
  return letterbox.originalWidth > 0 && letterbox.originalHeight > 0 &&
    letterbox.resizedWidth > 0 && letterbox.resizedHeight > 0 &&
    letterbox.resizedWidth <= moveNetInputSize && letterbox.resizedHeight <= moveNetInputSize &&
    letterbox.padX >= 0 && letterbox.padY >= 0 &&
    letterbox.padX + letterbox.resizedWidth <= moveNetInputSize &&
    letterbox.padY + letterbox.resizedHeight <= moveNetInputSize;
}

function moveNetOutputValuesAreFiniteAndNormalized(output: Float32Array): boolean {
  if (output.length !== moveNetOutputFloatCount) {
    return false;
  }
  for (let index = 0; index < output.length; index++) {
    if (!Number.isFinite(output[index]) || output[index] < 0 || output[index] > 1) {
      return false;
    }
  }
  return true;
}

function emptyMoveNetPoseResult(executionMs: number, letterbox: MoveNetLetterbox): PoseResult {
  return {
    ok: false,
    skeletonCount: 0,
    pointCount: 0,
    imageWidth: letterbox.originalWidth,
    imageHeight: letterbox.originalHeight,
    points: [],
    executionMs: executionMs
  };
}

function numberArraysEqual(left: Array<number>, right: Array<number>): boolean {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index++) {
    if (left[index] !== right[index]) {
      return false;
    }
  }
  return true;
}

function clampPoseCoordinate(value: number, length: number): number {
  return Math.min(length, Math.max(0, value));
}

export function poseResultFromCoreVision(
  skeletons: Array<skeletonDetection.Skeleton>,
  executionMs: number,
  imageWidth: number = 0,
  imageHeight: number = 0
): PoseResult {
  const points: Array<PosePoint> = [];
  skeletons.forEach((skeleton: skeletonDetection.Skeleton) => {
    skeleton.points.forEach((point: skeletonDetection.SkeletonPoint) => {
      points.push({
        type: point.type,
        score: point.score,
        x: point.point.x,
        y: point.point.y
      });
    });
  });
  return {
    ok: skeletons.length > 0,
    skeletonCount: skeletons.length,
    pointCount: points.length,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    points: points,
    executionMs: executionMs
  };
}

export function posePointPercent(point: PosePoint, imageWidth: number, imageHeight: number): PosePointPercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      x: 0,
      y: 0
    };
  }
  return {
    x: posePercent(point.x, imageWidth),
    y: posePercent(point.y, imageHeight)
  };
}

export function isPosePointVisible(point: PosePoint): boolean {
  return point.score >= poseMinPointScore && (point.x !== 0 || point.y !== 0);
}

export function poseSimilarityToAndroidTemplate(points: Array<PosePoint>): number | undefined {
  const similarity = poseSimilarityToTemplate(points, androidLiveSkeletonTemplatePoints);
  if (similarity !== undefined) {
    return similarity;
  }
  return poseSimilarityToTemplate(coreVisionPosePointsAsAndroidYogaPoints(points), androidLiveSkeletonTemplatePoints);
}

export function poseSimilarityPercent(similarity: number): string {
  return `${Math.floor(clampPoseSimilarity(similarity) * 100)}%`;
}

function poseResultWithAndroidTemplateSimilarity(result: PoseResult): PoseResult {
  if (!result.ok || result.similarity !== undefined) {
    return result;
  }
  const similarity = poseSimilarityToAndroidTemplate(result.points);
  if (similarity === undefined) {
    return result;
  }
  return {
    ok: result.ok,
    skeletonCount: result.skeletonCount,
    pointCount: result.pointCount,
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    points: result.points,
    similarity: similarity,
    executionMs: result.executionMs
  };
}

function poseResultWithoutSimilarity(result: PoseResult): PoseResult {
  if (result.similarity === undefined) {
    return result;
  }
  return {
    ok: result.ok,
    skeletonCount: result.skeletonCount,
    pointCount: result.pointCount,
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    points: result.points,
    executionMs: result.executionMs
  };
}

function poseSimilarityToTemplate(
  points: Array<PosePoint>,
  templatePoints: Array<PosePoint>
): number | undefined {
  const pointByType: Map<number, PosePoint> = visiblePosePointMap(points);
  const visibleTemplatePoints: Array<PosePoint> = templatePoints.filter((point: PosePoint) => isPosePointVisible(point));
  const matchedPoints: Array<PosePoint> = [];
  const matchedTemplatePoints: Array<PosePoint> = [];

  visibleTemplatePoints.forEach((templatePoint: PosePoint) => {
    const point = pointByType.get(templatePoint.type);
    if (point !== undefined) {
      matchedPoints.push(point);
      matchedTemplatePoints.push(templatePoint);
    }
  });

  if (matchedPoints.length < 2) {
    return undefined;
  }

  const pointBounds = poseBounds(matchedPoints);
  const templateBounds = poseBounds(matchedTemplatePoints);
  let distanceSum = 0;
  for (let index = 0; index < matchedPoints.length; index++) {
    const point = normalizePosePoint(matchedPoints[index], pointBounds);
    const templatePoint = normalizePosePoint(matchedTemplatePoints[index], templateBounds);
    const deltaX = point.x - templatePoint.x;
    const deltaY = point.y - templatePoint.y;
    distanceSum += Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  const averageDistance = distanceSum / matchedPoints.length;
  return clampPoseSimilarity(1 - averageDistance / Math.SQRT2);
}

function visiblePosePointMap(points: Array<PosePoint>): Map<number, PosePoint> {
  const pointByType: Map<number, PosePoint> = new Map<number, PosePoint>();
  points.forEach((point: PosePoint) => {
    if (isPosePointVisible(point)) {
      pointByType.set(point.type, point);
    }
  });
  return pointByType;
}

function coreVisionPosePointsAsAndroidYogaPoints(points: Array<PosePoint>): Array<PosePoint> {
  const mappedPoints: Array<PosePoint> = [];
  points.forEach((point: PosePoint) => {
    const yogaType = androidYogaPointTypeForCoreVisionPointType(point.type);
    if (yogaType !== undefined) {
      mappedPoints.push({
        type: yogaType,
        score: point.score,
        x: point.x,
        y: point.y
      });
    }
  });
  return mappedPoints;
}

function androidYogaPointTypeForCoreVisionPointType(type: number): number | undefined {
  switch (type) {
    case PosePointType.LEFT_SHOULDER:
      return 101;
    case PosePointType.LEFT_ELBOW:
      return 102;
    case PosePointType.LEFT_WRIST:
      return 103;
    case PosePointType.RIGHT_SHOULDER:
      return 104;
    case PosePointType.RIGHT_ELBOW:
      return 105;
    case PosePointType.RIGHT_WRIST:
      return 106;
    case PosePointType.LEFT_HIP:
      return 107;
    case PosePointType.LEFT_KNEE:
      return 108;
    case PosePointType.LEFT_ANKLE:
      return 109;
    case PosePointType.RIGHT_HIP:
      return 110;
    case PosePointType.RIGHT_KNEE:
      return 111;
    case PosePointType.RIGHT_ANKLE:
      return 112;
    default:
      return undefined;
  }
}

function poseBounds(points: Array<PosePoint>): PoseBounds {
  let minX = points[0].x;
  let maxX = points[0].x;
  let minY = points[0].y;
  let maxY = points[0].y;
  points.forEach((point: PosePoint) => {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
  });
  return {
    minX: minX,
    minY: minY,
    width: maxX - minX,
    height: maxY - minY
  };
}

function normalizePosePoint(point: PosePoint, bounds: PoseBounds): NormalizedPosePoint {
  return {
    x: bounds.width <= 0 ? 0.5 : (point.x - bounds.minX) / bounds.width,
    y: bounds.height <= 0 ? 0.5 : (point.y - bounds.minY) / bounds.height
  };
}

function clampPoseSimilarity(value: number): number {
  return Math.min(1, Math.max(0, value));
}

export function poseSkeletonLines(points: Array<PosePoint>): Array<PoseLine> {
  const pointByType: Map<number, PosePoint> = new Map<number, PosePoint>();
  points.forEach((point: PosePoint) => {
    if (isPosePointVisible(point)) {
      pointByType.set(point.type, point);
    }
  });

  const lines: Array<PoseLine> = [];
  poseSkeletonLineTypePairs.forEach((pair: PoseLineTypePair) => {
    const start = pointByType.get(pair.startType);
    const end = pointByType.get(pair.endType);
    if (start !== undefined && end !== undefined) {
      lines.push({
        start: start,
        end: end
      });
    }
  });
  return lines;
}

export function poseLinePercent(line: PoseLine, imageWidth: number, imageHeight: number): PoseLinePercent {
  const start = posePointPercent(line.start, imageWidth, imageHeight);
  const end = posePointPercent(line.end, imageWidth, imageHeight);
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      startX: start.x,
      startY: start.y,
      endX: end.x,
      endY: end.y,
      length: 0,
      angle: 0
    };
  }

  const deltaX = line.end.x - line.start.x;
  const deltaY = line.end.y - line.start.y;
  return {
    startX: start.x,
    startY: start.y,
    endX: end.x,
    endY: end.y,
    length: Math.sqrt(deltaX * deltaX + deltaY * deltaY) * 100 / imageWidth,
    angle: Math.atan2(deltaY, deltaX) * 180 / Math.PI
  };
}

function posePercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}

async function destroySkeletonDetector(detector: skeletonDetection.SkeletonDetector): Promise<void> {
  try {
    await detector.destroy();
  } catch (_) {
  }
}

async function openPoseImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for pose detection.');
  }
}

async function closePoseImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
