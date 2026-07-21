import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import objectDetectionMnn from 'libobject_detection_mnn.so';
import { FileUriContentReader } from './FileUriContentReader';
import {
  mindSporeLiteCpuContext,
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from './MindSporeLiteModelRunner';

export const objectCategoryLabelRawfilePath: string = 'labels/object_category.txt';
export const objectCategoryLabelCount: number = 81;
export const objectDetectionModelRawfilePath: string = 'model/nanodet_plus_m_320.mnn';
export const objectDetectionModelDownloadUrl: string =
  'https://github.com/RangiLyu/nanodet/releases/download/v1.0.0-alpha-1/nanodet-plus-m_320.onnx';
export const objectDetectionInputSize: number = 320;
export const objectDetectionInputChannels: number = 3;
export const objectDetectionInputFloatCount: number =
  objectDetectionInputSize * objectDetectionInputSize * objectDetectionInputChannels;
export const objectDetectionMean: Array<number> = [103.53, 116.28, 123.675];
export const objectDetectionStd: Array<number> = [57.375, 57.12, 58.395];
export const objectDetectionAnchorCount: number = 2125;
export const objectDetectionClassCount: number = objectCategoryLabelCount;
export const objectDetectionOutputChannelCount: number = 112;
export const objectDetectionOutputFloatCount: number = objectDetectionAnchorCount * objectDetectionOutputChannelCount;
const objectDetectionNanoDetClassCount: number = 80;
const objectDetectionDflBins: number = 8;
const objectDetectionNanoDetStrides: Array<number> = [8, 16, 32, 64];
const objectDetectionNanoDetScoreThreshold: number = 0.35;
const objectDetectionNanoDetNmsThreshold: number = 0.6;
const objectDetectionNanoDetMaxResults: number = 100;
const objectDetectionFeatureSizes: Array<number> = [19, 10, 5, 3, 2, 1];
const objectDetectionDefaultCounts: Array<number> = [3, 6, 6, 6, 6, 6];
const objectDetectionSteps: Array<number> = [16, 32, 64, 100, 150, 300];
const objectDetectionMinScale: number = 0.2;
const objectDetectionMaxScale: number = 0.95;
const objectDetectionNmsThreshold: number = 0.3;
const objectDetectionMaxResultsPerClass: number = 100;
const objectDetectionScoreThresholds: Array<number> = [
  0, 0.635, 0.627, 0.589, 0.585, 0.648, 0.664, 0.655, 0.481, 0.529,
  0.611, 0.641, 0.774, 0.549, 0.513, 0.652, 0.552, 0.590, 0.650, 0.575,
  0.583, 0.650, 0.656, 0.696, 0.653, 0.438, 0.515, 0.459, 0.561, 0.545,
  0.635, 0.540, 0.560, 0.721, 0.544, 0.548, 0.511, 0.611, 0.592, 0.542,
  0.512, 0.635, 0.531, 0.437, 0.525, 0.445, 0.484, 0.546, 0.490, 0.581,
  0.566, 0.516, 0.445, 0.541, 0.613, 0.560, 0.483, 0.509, 0.464, 0.543,
  0.538, 0.490, 0.576, 0.617, 0.577, 0.595, 0.640, 0.585, 0.598, 0.592,
  0.514, 0.397, 0.592, 0.504, 0.548, 0.642, 0.581, 0.497, 0.545, 0.154,
  0.580
];

export interface ObjectDetection {
  readonly imageId: number;
  readonly labelId: number;
  readonly label: string;
  readonly score: number;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
}

export interface ObjectDetectionBoxPercent {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface ObjectDetectionLiveLabelOffset {
  readonly x: number;
  readonly y: number;
}

export const objectDetectionOverlayPalette: Array<string> = [
  '#FFFFFF',
  '#6DA7FF',
  '#F8E71C',
  '#FF844D',
  '#66B50A'
];

export interface ObjectDetectionNormalBox {
  readonly y: number;
  readonly x: number;
  readonly h: number;
  readonly w: number;
}

interface ObjectDetectionDecodedBox {
  readonly ymin: number;
  readonly xmin: number;
  readonly ymax: number;
  readonly xmax: number;
}

export type ObjectDetectionRunCode =
  'MISSING_INPUT' |
  'MODEL_PENDING' |
  'DETECTION_DONE' |
  'DETECTION_INVALID_OUTPUT';

export interface ObjectDetectionRunResult {
  readonly ok: boolean;
  readonly code: ObjectDetectionRunCode;
  readonly detections: Array<ObjectDetection>;
}

export interface ObjectDetectionRunner {
  detectObjects(imageUri: string, modelUri?: string): Promise<Array<ObjectDetection>>;
}

export interface ObjectDetectionInput {
  readonly inputBuffer: ArrayBuffer;
  readonly imageWidth: number;
  readonly imageHeight: number;
}

export interface ObjectDetectionInputPreprocessor {
  createInput(imageUri: string): Promise<ObjectDetectionInput>;
}

export interface ObjectDetectionModelOutput {
  readonly scores: Float32Array;
  readonly boxes: Float32Array;
}

export interface ObjectDetectionTensorRunner {
  predictOutput(inputBuffer: ArrayBuffer, modelUri?: string): Promise<ObjectDetectionModelOutput>;
}

export interface ObjectDetectionMindSporeRunnerOptions {
  readonly preprocessor: ObjectDetectionInputPreprocessor;
  readonly tensorRunner: ObjectDetectionTensorRunner;
}

export class ObjectDetectionMindSporeRunner implements ObjectDetectionRunner {
  private readonly preprocessor: ObjectDetectionInputPreprocessor;
  private readonly tensorRunner: ObjectDetectionTensorRunner;

  constructor(options: ObjectDetectionMindSporeRunnerOptions) {
    this.preprocessor = options.preprocessor;
    this.tensorRunner = options.tensorRunner;
  }

  async detectObjects(imageUri: string, modelUri?: string): Promise<Array<ObjectDetection>> {
    const input = await this.preprocessor.createInput(imageUri);
    const output = await this.tensorRunner.predictOutput(input.inputBuffer, modelUri);
    return decodeSsdObjectDetections(output.scores, output.boxes, [], input.imageWidth, input.imageHeight);
  }
}

export interface MindSporeLiteObjectDetectionTensorRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
  readonly modelContentReader?: FileUriContentReader;
}

export class MindSporeLiteObjectDetectionTensorRunner implements ObjectDetectionTensorRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly modelRawfilePath: string;
  private readonly modelContentReader: FileUriContentReader;
  private cachedRawfileModel?: mindSporeLite.Model;
  private readonly cachedSelectedModels: Map<string, mindSporeLite.Model> = new Map<string, mindSporeLite.Model>();

  constructor(options: MindSporeLiteObjectDetectionTensorRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.modelRawfilePath = options.modelRawfilePath;
    this.modelContentReader = options.modelContentReader ?? new FileUriContentReader();
  }

  async predictOutput(inputBuffer: ArrayBuffer, modelUri?: string): Promise<ObjectDetectionModelOutput> {
    const model = await this.loadModel(modelUri);
    const inputs = model.getInputs();
    if (inputs.length === 0) {
      return emptyObjectDetectionModelOutput();
    }

    inputs[0].setData(inputBuffer);
    const outputs = await model.predict(inputs);
    const floatOutputs: Array<Float32Array> = [];
    for (let index = 0; index < outputs.length; index++) {
      floatOutputs.push(new Float32Array(outputs[index].getData()));
    }
    return objectDetectionModelOutputFromFloatArrays(floatOutputs);
  }

  private async loadModel(modelUri?: string): Promise<mindSporeLite.Model> {
    if (modelUri !== undefined && modelUri.length > 0) {
      return this.loadSelectedModel(modelUri);
    }
    if (this.cachedRawfileModel !== undefined) {
      return this.cachedRawfileModel;
    }

    const content = await this.resourceManager.getRawFileContent(this.modelRawfilePath);
    const model = await mindSporeLite.loadModelFromBuffer(rawfileContentToArrayBuffer(content), mindSporeLiteCpuContext());
    this.cachedRawfileModel = model;
    return model;
  }

  private async loadSelectedModel(modelUri: string): Promise<mindSporeLite.Model> {
    const cachedModel = this.cachedSelectedModels.get(modelUri);
    if (cachedModel !== undefined) {
      return cachedModel;
    }

    const modelContent = await this.modelContentReader.readFileContent(modelUri);
    const model =
      await mindSporeLite.loadModelFromBuffer(rawfileContentToArrayBuffer(modelContent), mindSporeLiteCpuContext());
    this.cachedSelectedModels.set(modelUri, model);
    return model;
  }
}

export interface ObjectDetectionServiceOptions {
  readonly labels: Array<string>;
  readonly runner?: ObjectDetectionRunner;
}

export class ObjectDetectionService {
  private readonly labels: Array<string>;
  private readonly runner?: ObjectDetectionRunner;

  constructor(options: ObjectDetectionServiceOptions) {
    this.labels = options.labels;
    this.runner = options.runner;
  }

  async detectObjects(imageUri: string, modelUri?: string): Promise<ObjectDetectionRunResult> {
    if (imageUri.length === 0) {
      return this.runResult(false, 'MISSING_INPUT', []);
    }
    if (!this.runner) {
      return this.runResult(false, 'MODEL_PENDING', []);
    }

    let detections: Array<ObjectDetection>;
    try {
      detections = await this.runner.detectObjects(imageUri, modelUri);
    } catch (_) {
      return this.runResult(false, 'DETECTION_INVALID_OUTPUT', []);
    }

    if (detections.length === 0) {
      return this.runResult(true, 'DETECTION_DONE', []);
    }
    const mappedDetections = mapObjectDetectionLabels(detections, this.labels);
    if (mappedDetections.length === 0) {
      return this.runResult(false, 'DETECTION_INVALID_OUTPUT', []);
    }
    return this.runResult(true, 'DETECTION_DONE', mappedDetections);
  }

  private runResult(
    ok: boolean,
    code: ObjectDetectionRunCode,
    detections: Array<ObjectDetection>
  ): ObjectDetectionRunResult {
    return {
      ok: ok,
      code: code,
      detections: detections
    };
  }
}

export function parseObjectCategoryLabels(rawText: string): Array<string> {
  const labels: Array<string> = [];
  rawText.split('\n').forEach((line: string) => {
    const label = line.split('\r').join('').trim();
    if (label.length > 0) {
      labels.push(label);
    }
  });
  return labels;
}

export function objectDetectionDecodeOptions(): image.DecodingOptions {
  return {
    desiredSize: {
      width: objectDetectionInputSize,
      height: objectDetectionInputSize
    },
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  };
}

export function normalizedObjectDetectionRgbInputFromRgba(rgba: Uint8Array): ArrayBuffer {
  const expectedLength = objectDetectionInputSize * objectDetectionInputSize * 4;
  if (rgba.length !== expectedLength) {
    throw new Error(`Expected ${expectedLength} RGBA bytes, got ${rgba.length}.`);
  }

  const input = new Float32Array(objectDetectionInputFloatCount);
  const planeSize = objectDetectionInputSize * objectDetectionInputSize;
  let pixelIndex = 0;
  for (let index = 0; index < rgba.length; index += 4) {
    input[pixelIndex] = normalizeObjectDetectionChannel(rgba[index + 2], 0);
    input[planeSize + pixelIndex] = normalizeObjectDetectionChannel(rgba[index + 1], 1);
    input[planeSize * 2 + pixelIndex] = normalizeObjectDetectionChannel(rgba[index], 2);
    pixelIndex++;
  }
  return input.buffer as ArrayBuffer;
}

export interface LocalMnnObjectDetectionRunnerOptions {
  readonly resourceManager: RawfileContentReader;
  readonly modelRawfilePath: string;
  readonly preprocessor: ObjectDetectionInputPreprocessor;
  readonly modelContentReader?: FileUriContentReader;
  readonly runtime?: ObjectDetectionMnnRuntime;
}

export interface ObjectDetectionMnnRuntime {
  loadModel(content: Uint8Array): Promise<void>;
  predict(input: Float32Array): Promise<Float32Array>;
}

class NativeObjectDetectionMnnRuntime implements ObjectDetectionMnnRuntime {
  async loadModel(content: Uint8Array): Promise<void> {
    await objectDetectionMnn.loadModel(content);
  }

  async predict(input: Float32Array): Promise<Float32Array> {
    return await objectDetectionMnn.predict(input);
  }
}

const nativeObjectDetectionMnnRuntime: ObjectDetectionMnnRuntime = new NativeObjectDetectionMnnRuntime();

class ObjectDetectionMnnRuntimeState {
  loadedBuiltinModelKey: string = '';
  operationTail: Promise<void> = Promise.resolve();
}

const objectDetectionMnnRuntimeStates: Map<ObjectDetectionMnnRuntime, ObjectDetectionMnnRuntimeState> = new Map();

function getObjectDetectionMnnRuntimeState(runtime: ObjectDetectionMnnRuntime): ObjectDetectionMnnRuntimeState {
  const existingState = objectDetectionMnnRuntimeStates.get(runtime);
  if (existingState !== undefined) {
    return existingState;
  }
  const state = new ObjectDetectionMnnRuntimeState();
  objectDetectionMnnRuntimeStates.set(runtime, state);
  return state;
}

export class LocalMnnObjectDetectionRunner implements ObjectDetectionRunner {
  private readonly resourceManager: RawfileContentReader;
  private readonly modelRawfilePath: string;
  private readonly preprocessor: ObjectDetectionInputPreprocessor;
  private readonly modelContentReader: FileUriContentReader;
  private readonly runtime: ObjectDetectionMnnRuntime;
  private readonly runtimeState: ObjectDetectionMnnRuntimeState;

  constructor(options: LocalMnnObjectDetectionRunnerOptions) {
    this.resourceManager = options.resourceManager;
    this.modelRawfilePath = options.modelRawfilePath;
    this.preprocessor = options.preprocessor;
    this.modelContentReader = options.modelContentReader ?? new FileUriContentReader();
    this.runtime = options.runtime ?? nativeObjectDetectionMnnRuntime;
    this.runtimeState = getObjectDetectionMnnRuntimeState(this.runtime);
  }

  detectObjects(imageUri: string, modelUri?: string): Promise<Array<ObjectDetection>> {
    const result = this.runtimeState.operationTail.then(async (): Promise<Array<ObjectDetection>> =>
      await this.detectObjectsExclusive(imageUri, modelUri));
    this.runtimeState.operationTail = result.then((): void => {}, (): void => {});
    return result;
  }

  private async detectObjectsExclusive(imageUri: string, modelUri?: string): Promise<Array<ObjectDetection>> {
    const input = await this.preprocessor.createInput(imageUri);
    await this.ensureModelLoaded(modelUri);
    const output = await this.runtime.predict(new Float32Array(input.inputBuffer));
    if (!isValidNanoDetObjectDetectionOutput(output)) {
      throw new Error('Invalid NanoDet output tensor');
    }
    return decodeNanoDetObjectDetections(output, input.imageWidth, input.imageHeight);
  }

  private async ensureModelLoaded(modelUri?: string): Promise<void> {
    if (modelUri !== undefined && modelUri.length > 0) {
      const content = await this.modelContentReader.readFileContent(modelUri);
      await this.runtime.loadModel(content);
      this.runtimeState.loadedBuiltinModelKey = '';
      return;
    }

    const modelKey = `rawfile:${this.modelRawfilePath}`;
    if (this.runtimeState.loadedBuiltinModelKey === modelKey) {
      return;
    }
    const content = await this.resourceManager.getRawFileContent(this.modelRawfilePath);
    await this.runtime.loadModel(content);
    this.runtimeState.loadedBuiltinModelKey = modelKey;
  }
}

export async function validateObjectDetectionModelContent(content: Uint8Array): Promise<boolean> {
  return await objectDetectionMnn.validateModel(content);
}

function normalizeObjectDetectionChannel(value: number, channel: number): number {
  return (value - objectDetectionMean[channel]) / objectDetectionStd[channel];
}

interface NanoDetCandidate {
  readonly imageId: number;
  readonly labelId: number;
  readonly score: number;
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
}

function isValidNanoDetObjectDetectionOutput(output: Float32Array): boolean {
  if (output.length !== objectDetectionOutputFloatCount) {
    return false;
  }
  for (let index = 0; index < output.length; index++) {
    if (!Number.isFinite(output[index])) {
      return false;
    }
  }
  return true;
}

export function decodeNanoDetObjectDetections(
  output: Float32Array,
  imageWidth: number,
  imageHeight: number
): Array<ObjectDetection> {
  if (!isValidNanoDetObjectDetectionOutput(output) || imageWidth <= 0 || imageHeight <= 0) {
    return [];
  }
  let hasSignal = false;
  for (let index = 0; index < output.length; index++) {
    if (Math.abs(output[index]) > 1.0e-12) {
      hasSignal = true;
    }
  }
  if (!hasSignal) {
    return [];
  }

  const candidates: Array<NanoDetCandidate> = [];
  let pointIndex = 0;
  for (let strideIndex = 0; strideIndex < objectDetectionNanoDetStrides.length; strideIndex++) {
    const stride = objectDetectionNanoDetStrides[strideIndex];
    const featureSize = Math.ceil(objectDetectionInputSize / stride);
    for (let row = 0; row < featureSize; row++) {
      for (let column = 0; column < featureSize; column++) {
        const outputOffset = pointIndex * objectDetectionOutputChannelCount;
        for (let classIndex = 0; classIndex < objectDetectionNanoDetClassCount; classIndex++) {
          const score = output[outputOffset + classIndex];
          if (score >= objectDetectionNanoDetScoreThreshold) {
            const leftDistance = nanoDetDflDistance(output, outputOffset + objectDetectionNanoDetClassCount, 0) * stride;
            const topDistance = nanoDetDflDistance(output, outputOffset + objectDetectionNanoDetClassCount, 1) * stride;
            const rightDistance = nanoDetDflDistance(output, outputOffset + objectDetectionNanoDetClassCount, 2) * stride;
            const bottomDistance = nanoDetDflDistance(output, outputOffset + objectDetectionNanoDetClassCount, 3) * stride;
            candidates.push({
              imageId: pointIndex,
              labelId: classIndex + 1,
              score: score,
              left: Math.max(0, (column * stride - leftDistance) * imageWidth / objectDetectionInputSize),
              top: Math.max(0, (row * stride - topDistance) * imageHeight / objectDetectionInputSize),
              right: Math.min(imageWidth, (column * stride + rightDistance) * imageWidth / objectDetectionInputSize),
              bottom: Math.min(imageHeight, (row * stride + bottomDistance) * imageHeight / objectDetectionInputSize)
            });
          }
        }
        pointIndex++;
      }
    }
  }
  if (pointIndex !== objectDetectionAnchorCount) {
    return [];
  }

  candidates.sort((left: NanoDetCandidate, right: NanoDetCandidate): number => right.score - left.score);
  const kept: Array<NanoDetCandidate> = [];
  for (let index = 0; index < candidates.length && kept.length < objectDetectionNanoDetMaxResults; index++) {
    const candidate = candidates[index];
    let suppressed = false;
    for (let keptIndex = 0; keptIndex < kept.length; keptIndex++) {
      if (kept[keptIndex].labelId === candidate.labelId &&
        nanoDetIntersectionOverUnion(kept[keptIndex], candidate) > objectDetectionNanoDetNmsThreshold) {
        suppressed = true;
        break;
      }
    }
    if (!suppressed && candidate.right > candidate.left && candidate.bottom > candidate.top) {
      kept.push(candidate);
    }
  }
  return kept.map((candidate: NanoDetCandidate): ObjectDetection => ({
    imageId: candidate.imageId,
    labelId: candidate.labelId,
    label: `${candidate.labelId}`,
    score: candidate.score,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    left: candidate.left,
    top: candidate.top,
    right: candidate.right,
    bottom: candidate.bottom
  }));
}

function nanoDetDflDistance(output: Float32Array, distributionOffset: number, side: number): number {
  const offset = distributionOffset + side * objectDetectionDflBins;
  let maximum = output[offset];
  for (let bin = 1; bin < objectDetectionDflBins; bin++) {
    maximum = Math.max(maximum, output[offset + bin]);
  }
  let denominator = 0;
  let numerator = 0;
  for (let bin = 0; bin < objectDetectionDflBins; bin++) {
    const weight = Math.exp(output[offset + bin] - maximum);
    denominator += weight;
    numerator += bin * weight;
  }
  return denominator > 0 ? numerator / denominator : 0;
}

function nanoDetIntersectionOverUnion(left: NanoDetCandidate, right: NanoDetCandidate): number {
  const intersectionWidth = Math.max(0, Math.min(left.right, right.right) - Math.max(left.left, right.left));
  const intersectionHeight = Math.max(0, Math.min(left.bottom, right.bottom) - Math.max(left.top, right.top));
  const intersection = intersectionWidth * intersectionHeight;
  const leftArea = Math.max(0, left.right - left.left) * Math.max(0, left.bottom - left.top);
  const rightArea = Math.max(0, right.right - right.left) * Math.max(0, right.bottom - right.top);
  const union = leftArea + rightArea - intersection;
  return union > 0 ? intersection / union : 0;
}

export function generateObjectDetectionDefaultBoxes(): Array<ObjectDetectionNormalBox> {
  const boxes: Array<ObjectDetectionNormalBox> = [];
  const fk: Array<number> = objectDetectionSteps.map((step: number): number => objectDetectionInputSize / step);
  const scaleRate =
    (objectDetectionMaxScale - objectDetectionMinScale) / (objectDetectionDefaultCounts.length - 1);
  const scales: Array<number> = [];
  for (let index = 0; index < objectDetectionDefaultCounts.length; index++) {
    scales.push(objectDetectionMinScale + scaleRate * index);
  }
  scales.push(1.0);

  for (let featureIndex = 0; featureIndex < objectDetectionFeatureSizes.length; featureIndex++) {
    const sizes = objectDetectionBoxSizesForFeature(featureIndex, scales);
    const featureSize = objectDetectionFeatureSizes[featureIndex];
    for (let row = 0; row < featureSize; row++) {
      for (let column = 0; column < featureSize; column++) {
        const centerX = (column + 0.5) / fk[featureIndex];
        const centerY = (row + 0.5) / fk[featureIndex];
        sizes.forEach((size: ObjectDetectionWhBox) => {
          boxes.push({
            y: centerY,
            x: centerX,
            h: size.h,
            w: size.w
          });
        });
      }
    }
  }
  return boxes;
}

export function decodeSsdObjectDetections(
  scores: Float32Array,
  boxes: Float32Array,
  labels: Array<string>,
  imageWidth: number,
  imageHeight: number
): Array<ObjectDetection> {
  if (scores.length < objectDetectionAnchorCount * objectDetectionClassCount ||
    boxes.length < objectDetectionAnchorCount * 4) {
    return [];
  }

  const defaultBoxes = generateObjectDetectionDefaultBoxes();
  const decodedBoxes = decodeObjectDetectionBoxes(boxes, defaultBoxes);
  const detections: Array<ObjectDetection> = [];
  for (let classId = 1; classId < objectDetectionClassCount; classId++) {
    const candidateIndexes: Array<number> = [];
    for (let anchorIndex = 0; anchorIndex < objectDetectionAnchorCount; anchorIndex++) {
      const score = objectDetectionScore(scores, anchorIndex, classId);
      if (score > objectDetectionScoreThresholds[classId]) {
        candidateIndexes.push(anchorIndex);
      }
    }
    if (candidateIndexes.length === 0) {
      continue;
    }

    candidateIndexes.sort((left: number, right: number): number =>
      objectDetectionScore(scores, right, classId) - objectDetectionScore(scores, left, classId));
    const keptIndexes = objectDetectionNms(decodedBoxes, candidateIndexes);
    keptIndexes.forEach((anchorIndex: number) => {
      const box = decodedBoxes[anchorIndex];
      detections.push({
        imageId: anchorIndex,
        labelId: classId,
        label: classId < labels.length ? labels[classId] : `${classId}`,
        score: objectDetectionScore(scores, anchorIndex, classId),
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        left: box.xmin * imageWidth / objectDetectionInputSize,
        top: box.ymin * imageHeight / objectDetectionInputSize,
        right: box.xmax * imageWidth / objectDetectionInputSize,
        bottom: box.ymax * imageHeight / objectDetectionInputSize
      });
    });
  }
  return detections;
}

export function objectDetectionModelOutputFromFloatArrays(
  outputs: Array<Float32Array>
): ObjectDetectionModelOutput {
  let scores: Float32Array = new Float32Array(0);
  let boxes: Float32Array = new Float32Array(0);
  outputs.forEach((output: Float32Array) => {
    if (output.length === objectDetectionAnchorCount * objectDetectionClassCount) {
      scores = output;
    }
    if (output.length === objectDetectionAnchorCount * 4) {
      boxes = output;
    }
  });
  return {
    scores: scores,
    boxes: boxes
  };
}

function mapObjectDetectionLabels(
  detections: Array<ObjectDetection>,
  labels: Array<string>
): Array<ObjectDetection> {
  return detections.map((detection: ObjectDetection): ObjectDetection => {
    const label = detection.labelId >= 0 && detection.labelId < labels.length ? labels[detection.labelId] : detection.label;
    return {
      imageId: detection.imageId,
      labelId: detection.labelId,
      label: label,
      score: detection.score,
      imageWidth: detection.imageWidth,
      imageHeight: detection.imageHeight,
      left: detection.left,
      top: detection.top,
      right: detection.right,
      bottom: detection.bottom
    };
  });
}

export function objectDetectionBoxPercent(
  detection: ObjectDetection,
  imageWidth: number,
  imageHeight: number
): ObjectDetectionBoxPercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      left: 0,
      top: 0,
      width: 0,
      height: 0
    };
  }

  const left = objectDetectionPercent(detection.left, imageWidth);
  const top = objectDetectionPercent(detection.top, imageHeight);
  const right = objectDetectionPercent(detection.right, imageWidth);
  const bottom = objectDetectionPercent(detection.bottom, imageHeight);
  return {
    left: left,
    top: top,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top)
  };
}

export function objectDetectionLiveLabelOffset(
  topPercent: number,
  overlayHeightVp: number
): ObjectDetectionLiveLabelOffset {
  if (overlayHeightVp <= 0 || topPercent * overlayHeightVp / 100 < 20) {
    return { x: 5, y: 20 };
  }
  return { x: 0, y: -10 };
}

function objectDetectionPercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}

export function objectDetectionOverlayColor(index: number): string {
  const safeIndex = index < 0 ? 0 : index;
  return objectDetectionOverlayPalette[safeIndex % objectDetectionOverlayPalette.length];
}

export function objectDetectionOverlayTextColor(_index: number): string {
  return '#333333';
}

export function objectDetectionOverlayLabel(detection: ObjectDetection, resultIndex: number): string {
  const rectId = (resultIndex < 0 ? 0 : resultIndex) + 1;
  const label = detection.label.length > 0 ? detection.label : `${detection.labelId}`;
  return `${rectId}-${label}-${(detection.score * 100).toFixed(2)}%`;
}

interface ObjectDetectionWhBox {
  readonly w: number;
  readonly h: number;
}

function objectDetectionBoxSizesForFeature(
  featureIndex: number,
  scales: Array<number>
): Array<ObjectDetectionWhBox> {
  const sizes: Array<ObjectDetectionWhBox> = [];
  const sk1 = scales[featureIndex];
  if (featureIndex === 0) {
    const width = sk1 * Math.sqrt(2);
    const height = sk1 / Math.sqrt(2);
    sizes.push({ w: 0.1, h: 0.1 });
    sizes.push({ w: width, h: height });
    sizes.push({ w: height, h: width });
    return sizes;
  }

  sizes.push({ w: sk1, h: sk1 });
  objectDetectionAspectRatios(featureIndex).forEach((ratio: number) => {
    const width = sk1 * Math.sqrt(ratio);
    const height = sk1 / Math.sqrt(ratio);
    sizes.push({ w: width, h: height });
    sizes.push({ w: height, h: width });
  });
  const sk3 = Math.sqrt(sk1 * scales[featureIndex + 1]);
  sizes.push({ w: sk3, h: sk3 });
  return sizes;
}

function objectDetectionAspectRatios(featureIndex: number): Array<number> {
  if (featureIndex === 0) {
    return [2];
  }
  return [2, 3];
}

function decodeObjectDetectionBoxes(
  boxes: Float32Array,
  defaultBoxes: Array<ObjectDetectionNormalBox>
): Array<ObjectDetectionDecodedBox> {
  const decoded: Array<ObjectDetectionDecodedBox> = [];
  for (let index = 0; index < objectDetectionAnchorCount; index++) {
    const boxOffset = index * 4;
    const defaultBox = defaultBoxes[index];
    const centerY = boxes[boxOffset] * 0.1 * defaultBox.h + defaultBox.y;
    const centerX = boxes[boxOffset + 1] * 0.1 * defaultBox.w + defaultBox.x;
    const height = Math.exp(boxes[boxOffset + 2] * 0.2) * defaultBox.h;
    const width = Math.exp(boxes[boxOffset + 3] * 0.2) * defaultBox.w;
    decoded.push({
      ymin: clamp01(centerY - height / 2) * objectDetectionInputSize,
      xmin: clamp01(centerX - width / 2) * objectDetectionInputSize,
      ymax: clamp01(centerY + height / 2) * objectDetectionInputSize,
      xmax: clamp01(centerX + width / 2) * objectDetectionInputSize
    });
  }
  return decoded;
}

function objectDetectionNms(
  decodedBoxes: Array<ObjectDetectionDecodedBox>,
  sortedIndexes: Array<number>
): Array<number> {
  const kept: Array<number> = [];
  const deleted: Array<boolean> = [];
  for (let index = 0; index < objectDetectionAnchorCount; index++) {
    deleted.push(false);
  }

  for (let index = 0; index < sortedIndexes.length; index++) {
    const candidateIndex = sortedIndexes[index];
    if (deleted[candidateIndex]) {
      continue;
    }
    kept.push(candidateIndex);
    if (kept.length === objectDetectionMaxResultsPerClass) {
      break;
    }
    for (let compareIndex = index + 1; compareIndex < sortedIndexes.length; compareIndex++) {
      const peerIndex = sortedIndexes[compareIndex];
      if (objectDetectionIou(decodedBoxes[candidateIndex], decodedBoxes[peerIndex]) > objectDetectionNmsThreshold) {
        deleted[peerIndex] = true;
      }
    }
  }
  return kept;
}

function objectDetectionIou(first: ObjectDetectionDecodedBox, second: ObjectDetectionDecodedBox): number {
  const x1 = Math.max(first.xmin, second.xmin);
  const y1 = Math.max(first.ymin, second.ymin);
  const x2 = Math.min(first.xmax, second.xmax);
  const y2 = Math.min(first.ymax, second.ymax);
  if (x2 - x1 + 1 <= 0 || y2 - y1 + 1 <= 0) {
    return 0;
  }
  const intersectionArea = (x2 - x1 + 1) * (y2 - y1 + 1);
  const firstArea = (first.xmax - first.xmin + 1) * (first.ymax - first.ymin + 1);
  const secondArea = (second.xmax - second.xmin + 1) * (second.ymax - second.ymin + 1);
  const iou = intersectionArea / (firstArea + secondArea - intersectionArea);
  return iou > 0 ? iou : 0;
}

function objectDetectionScore(scores: Float32Array, anchorIndex: number, classId: number): number {
  return scores[anchorIndex * objectDetectionClassCount + classId];
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function emptyObjectDetectionModelOutput(): ObjectDetectionModelOutput {
  return {
    scores: new Float32Array(0),
    boxes: new Float32Array(0)
  };
}
