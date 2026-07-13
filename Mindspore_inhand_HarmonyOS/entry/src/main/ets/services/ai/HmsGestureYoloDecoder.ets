import { AndroidGestureModelDetection, GestureRectangle } from './GestureService';

export interface HmsGestureOutputTensor {
  name: string;
  shape: Array<number>;
  data: ArrayBuffer;
}

export interface HmsGestureOutputs {
  tensors: Array<HmsGestureOutputTensor>;
}

interface GestureAnchor {
  readonly width: number;
  readonly height: number;
}

interface GestureScale {
  readonly name: string;
  readonly gridSize: number;
  readonly stride: number;
  readonly anchors: Array<GestureAnchor>;
}

interface GestureCandidate extends AndroidGestureModelDetection {
  readonly rect: GestureRectangle;
}

const modelSize: number = 224;
const valuesPerAnchor: number = 20;
const classCount: number = 15;
const nmsThreshold: number = 0.45;
const expLimit: number = 80;

const gestureScales: Array<GestureScale> = [
  {
    name: 'layer89-conv-hand',
    gridSize: 7,
    stride: 32,
    anchors: [{ width: 105, height: 101 }, { width: 133, height: 135 }, { width: 174, height: 150 }]
  },
  {
    name: 'layer101-conv-hand',
    gridSize: 14,
    stride: 16,
    anchors: [{ width: 32, height: 37 }, { width: 47, height: 37 }, { width: 65, height: 56 }]
  },
  {
    name: 'layer113-conv-hand',
    gridSize: 28,
    stride: 8,
    anchors: [{ width: 19, height: 19 }, { width: 25, height: 27 }, { width: 35, height: 26 }]
  }
];

export function decodeHmsGestureOutputs(
  outputs: HmsGestureOutputs,
  sourceWidth: number,
  sourceHeight: number,
  threshold: number
): Array<AndroidGestureModelDetection> {
  validateDecodeArguments(outputs, sourceWidth, sourceHeight, threshold);
  const candidates: Array<GestureCandidate> = [];
  for (let scaleIndex = 0; scaleIndex < gestureScales.length; scaleIndex++) {
    const scale = gestureScales[scaleIndex];
    const tensor = requiredTensor(outputs.tensors, scale);
    decodeScale(new Float32Array(tensor.data), scale, sourceWidth, sourceHeight, threshold, candidates);
  }
  candidates.sort(compareCandidates);
  const kept = classLocalNms(candidates);
  kept.sort(compareCandidates);
  return kept;
}

function validateDecodeArguments(
  outputs: HmsGestureOutputs,
  sourceWidth: number,
  sourceHeight: number,
  threshold: number
): void {
  if (!Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight) || sourceWidth <= 0 || sourceHeight <= 0) {
    throw new Error('Invalid gesture source dimensions.');
  }
  if (!Number.isFinite(threshold) || threshold < 0 || threshold > 1) {
    throw new Error('Invalid gesture confidence threshold.');
  }
  if (outputs.tensors.length !== gestureScales.length) {
    throw new Error('Invalid gesture output tensor count.');
  }
}

function requiredTensor(tensors: Array<HmsGestureOutputTensor>, scale: GestureScale): HmsGestureOutputTensor {
  let matched: HmsGestureOutputTensor | undefined = undefined;
  for (let index = 0; index < tensors.length; index++) {
    if (tensors[index].name === scale.name) {
      if (matched !== undefined) {
        throw new Error(`Duplicate gesture output tensor ${scale.name}.`);
      }
      matched = tensors[index];
    }
  }
  if (matched === undefined || !matchesShape(matched.shape, scale.gridSize)) {
    throw new Error(`Invalid gesture output tensor ${scale.name}.`);
  }
  const expectedByteLength = 60 * scale.gridSize * scale.gridSize * Float32Array.BYTES_PER_ELEMENT;
  if (matched.data.byteLength !== expectedByteLength) {
    throw new Error(`Invalid gesture output tensor length ${scale.name}.`);
  }
  return matched;
}

function matchesShape(shape: Array<number>, gridSize: number): boolean {
  return shape.length === 4 && shape[0] === 1 && shape[1] === 60 &&
    shape[2] === gridSize && shape[3] === gridSize;
}

function decodeScale(
  values: Float32Array,
  scale: GestureScale,
  sourceWidth: number,
  sourceHeight: number,
  threshold: number,
  candidates: Array<GestureCandidate>
): void {
  const planeSize = scale.gridSize * scale.gridSize;
  for (let anchorIndex = 0; anchorIndex < scale.anchors.length; anchorIndex++) {
    const channelBase = anchorIndex * valuesPerAnchor;
    for (let cellY = 0; cellY < scale.gridSize; cellY++) {
      for (let cellX = 0; cellX < scale.gridSize; cellX++) {
        const cellIndex = cellY * scale.gridSize + cellX;
        const objectnessLogit = tensorValue(values, planeSize, channelBase + 4, cellIndex);
        if (!Number.isFinite(objectnessLogit)) {
          continue;
        }
        const category = bestCategory(values, planeSize, channelBase, cellIndex);
        if (category < 0) {
          continue;
        }
        const classLogit = tensorValue(values, planeSize, channelBase + 5 + category, cellIndex);
        const score = sigmoid(objectnessLogit) * sigmoid(classLogit);
        if (!Number.isFinite(score) || score < threshold) {
          continue;
        }
        const candidate = decodedCandidate(
          values,
          planeSize,
          channelBase,
          cellIndex,
          cellX,
          cellY,
          scale,
          anchorIndex,
          category,
          score,
          sourceWidth,
          sourceHeight
        );
        if (candidate !== undefined) {
          candidates.push(candidate);
        }
      }
    }
  }
}

function bestCategory(values: Float32Array, planeSize: number, channelBase: number, cellIndex: number): number {
  let category = -1;
  let bestLogit = Number.NEGATIVE_INFINITY;
  for (let classIndex = 0; classIndex < classCount; classIndex++) {
    const logit = tensorValue(values, planeSize, channelBase + 5 + classIndex, cellIndex);
    if (Number.isFinite(logit) && logit > bestLogit) {
      category = classIndex;
      bestLogit = logit;
    }
  }
  return category;
}

function decodedCandidate(
  values: Float32Array,
  planeSize: number,
  channelBase: number,
  cellIndex: number,
  cellX: number,
  cellY: number,
  scale: GestureScale,
  anchorIndex: number,
  category: number,
  score: number,
  sourceWidth: number,
  sourceHeight: number
): GestureCandidate | undefined {
  const tx = tensorValue(values, planeSize, channelBase, cellIndex);
  const ty = tensorValue(values, planeSize, channelBase + 1, cellIndex);
  const tw = tensorValue(values, planeSize, channelBase + 2, cellIndex);
  const th = tensorValue(values, planeSize, channelBase + 3, cellIndex);
  if (!Number.isFinite(tx) || !Number.isFinite(ty) || !Number.isFinite(tw) || !Number.isFinite(th)) {
    return undefined;
  }

  const centerX = (sigmoid(tx) + cellX) * scale.stride;
  const centerY = (sigmoid(ty) + cellY) * scale.stride;
  const anchor = scale.anchors[anchorIndex];
  const boxWidth = Math.exp(clamp(tw, -expLimit, expLimit)) * anchor.width;
  const boxHeight = Math.exp(clamp(th, -expLimit, expLimit)) * anchor.height;
  const modelLeft = clamp(centerX - boxWidth / 2, 0, modelSize);
  const modelTop = clamp(centerY - boxHeight / 2, 0, modelSize);
  const modelRight = clamp(centerX + boxWidth / 2, 0, modelSize);
  const modelBottom = clamp(centerY + boxHeight / 2, 0, modelSize);
  if (modelRight <= modelLeft || modelBottom <= modelTop) {
    return undefined;
  }

  const left = modelLeft / modelSize * sourceWidth;
  const top = modelTop / modelSize * sourceHeight;
  const right = modelRight / modelSize * sourceWidth;
  const bottom = modelBottom / modelSize * sourceHeight;
  if (!Number.isFinite(left) || !Number.isFinite(top) || !Number.isFinite(right) || !Number.isFinite(bottom)) {
    return undefined;
  }
  return {
    category: category,
    score: score,
    rect: {
      left: left,
      top: top,
      width: right - left,
      height: bottom - top
    }
  };
}

function tensorValue(values: Float32Array, planeSize: number, channel: number, cellIndex: number): number {
  return values[channel * planeSize + cellIndex];
}

function sigmoid(value: number): number {
  if (value >= 0) {
    return 1 / (1 + Math.exp(-value));
  }
  const exponential = Math.exp(value);
  return exponential / (1 + exponential);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function classLocalNms(candidates: Array<GestureCandidate>): Array<GestureCandidate> {
  const kept: Array<GestureCandidate> = [];
  for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
    const candidate = candidates[candidateIndex];
    let suppressed = false;
    for (let keptIndex = 0; keptIndex < kept.length; keptIndex++) {
      if (kept[keptIndex].category === candidate.category &&
        intersectionOverUnion(kept[keptIndex].rect, candidate.rect) >= nmsThreshold) {
        suppressed = true;
        break;
      }
    }
    if (!suppressed) {
      kept.push(candidate);
    }
  }
  return kept;
}

function intersectionOverUnion(left: GestureRectangle, right: GestureRectangle): number {
  const intersectionLeft = Math.max(left.left, right.left);
  const intersectionTop = Math.max(left.top, right.top);
  const intersectionRight = Math.min(left.left + left.width, right.left + right.width);
  const intersectionBottom = Math.min(left.top + left.height, right.top + right.height);
  const intersectionWidth = Math.max(0, intersectionRight - intersectionLeft);
  const intersectionHeight = Math.max(0, intersectionBottom - intersectionTop);
  const intersectionArea = intersectionWidth * intersectionHeight;
  const unionArea = left.width * left.height + right.width * right.height - intersectionArea;
  return unionArea > 0 ? intersectionArea / unionArea : 0;
}

function compareCandidates(left: GestureCandidate, right: GestureCandidate): number {
  if (left.score !== right.score) {
    return right.score - left.score;
  }
  if (left.category !== right.category) {
    return left.category - right.category;
  }
  if (left.rect.left !== right.rect.left) {
    return left.rect.left - right.rect.left;
  }
  if (left.rect.top !== right.rect.top) {
    return left.rect.top - right.rect.top;
  }
  if (left.rect.width !== right.rect.width) {
    return left.rect.width - right.rect.width;
  }
  return left.rect.height - right.rect.height;
}
