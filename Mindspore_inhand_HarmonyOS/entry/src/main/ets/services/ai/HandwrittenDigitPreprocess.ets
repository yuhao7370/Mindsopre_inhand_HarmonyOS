export interface HandwrittenDigitPrediction {
  readonly digit: number;
  readonly confidence: number;
}

export const handwrittenDigitInputSize: number = 28;
export const handwrittenDigitBodySize: number = 20;
export const handwrittenDigitInputFloatCount: number = handwrittenDigitInputSize * handwrittenDigitInputSize;
export const handwrittenDigitMean: number = 0.1307;
export const handwrittenDigitStd: number = 0.3081;

const minimumContrast: number = 32 / 255;
const foregroundThreshold: number = 0.15;
const foregroundPaddingRatio: number = 0.1;

export function handwrittenDigitInputFromRgba(rgba: Uint8Array, width: number, height: number): ArrayBuffer {
  validateRgba(rgba, width, height);
  const grayscale = grayscaleFromRgba(rgba, width * height);
  const background = borderBackground(grayscale, width, height);
  const ink = inkFromGrayscale(grayscale, background);
  const bounds = foregroundBounds(ink, width, height);
  if (bounds === undefined) {
    throw new Error('Handwritten digit image is blank or low contrast.');
  }

  const resized = resizeForegroundToMnist(ink, width, height, bounds);
  const translated = translateHandwrittenDigitToCenter(resized);
  const input = new Float32Array(handwrittenDigitInputFloatCount);
  for (let index = 0; index < input.length; index++) {
    input[index] = (translated[index] - handwrittenDigitMean) / handwrittenDigitStd;
  }
  return input.buffer as ArrayBuffer;
}

export function topHandwrittenDigitResults(
  logits: Array<number>, limit: number = 3
): Array<HandwrittenDigitPrediction> {
  if (logits.length !== 10 || !Number.isInteger(limit) || limit < 1 || limit > 10) {
    throw new Error('Handwritten digit logits must contain ten values and a valid result limit.');
  }
  let maximum = logits[0];
  for (let index = 0; index < logits.length; index++) {
    if (!Number.isFinite(logits[index])) {
      throw new Error('Handwritten digit logits must be finite.');
    }
    maximum = Math.max(maximum, logits[index]);
  }

  const confidences: Array<number> = [];
  let total = 0;
  for (let index = 0; index < logits.length; index++) {
    const confidence = Math.exp(logits[index] - maximum);
    confidences.push(confidence);
    total += confidence;
  }
  if (!Number.isFinite(total) || total <= 0) {
    throw new Error('Handwritten digit softmax is invalid.');
  }

  const predictions: Array<HandwrittenDigitPrediction> = [];
  for (let digit = 0; digit < confidences.length; digit++) {
    predictions.push({ digit: digit, confidence: confidences[digit] / total });
  }
  predictions.sort((left: HandwrittenDigitPrediction, right: HandwrittenDigitPrediction): number => {
    if (right.confidence !== left.confidence) {
      return right.confidence - left.confidence;
    }
    return left.digit - right.digit;
  });
  return predictions.slice(0, limit);
}

interface ForegroundBounds {
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
}

function validateRgba(rgba: Uint8Array, width: number, height: number): void {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0 ||
    width > 4096 || height > 4096 || rgba.length !== width * height * 4) {
    throw new Error('Handwritten digit RGBA dimensions do not match the pixel data.');
  }
}

function grayscaleFromRgba(rgba: Uint8Array, pixelCount: number): Float32Array {
  const grayscale = new Float32Array(pixelCount);
  for (let pixel = 0; pixel < pixelCount; pixel++) {
    const offset = pixel * 4;
    grayscale[pixel] = (rgba[offset] * 0.299 + rgba[offset + 1] * 0.587 + rgba[offset + 2] * 0.114) / 255;
  }
  return grayscale;
}

function borderBackground(grayscale: Float32Array, width: number, height: number): number {
  let total = 0;
  let count = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (x === 0 || y === 0 || x === width - 1 || y === height - 1) {
        total += grayscale[y * width + x];
        count++;
      }
    }
  }
  return total / count;
}

function inkFromGrayscale(grayscale: Float32Array, background: number): Float32Array {
  const ink = new Float32Array(grayscale.length);
  let minimum = grayscale[0];
  let maximum = grayscale[0];
  const darkInk = background > 0.5;
  for (let index = 0; index < grayscale.length; index++) {
    minimum = Math.min(minimum, grayscale[index]);
    maximum = Math.max(maximum, grayscale[index]);
    ink[index] = Math.min(1, Math.max(0, darkInk ? background - grayscale[index] : grayscale[index] - background));
  }
  if (maximum - minimum < minimumContrast) {
    throw new Error('Handwritten digit image is blank or low contrast.');
  }
  return ink;
}

function foregroundBounds(ink: Float32Array, width: number, height: number): ForegroundBounds | undefined {
  let left = width;
  let top = height;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (ink[y * width + x] >= foregroundThreshold) {
        left = Math.min(left, x);
        top = Math.min(top, y);
        right = Math.max(right, x);
        bottom = Math.max(bottom, y);
      }
    }
  }
  if (right < left || bottom < top) {
    return undefined;
  }
  return { left: left, top: top, right: right, bottom: bottom };
}

function resizeForegroundToMnist(
  ink: Float32Array, width: number, height: number, bounds: ForegroundBounds
): Float32Array {
  const output = new Float32Array(handwrittenDigitInputFloatCount);
  const foregroundWidth = bounds.right - bounds.left + 1;
  const foregroundHeight = bounds.bottom - bounds.top + 1;
  const squareSize = Math.max(foregroundWidth, foregroundHeight);
  const paddedSize = squareSize + Math.max(1, Math.round(squareSize * foregroundPaddingRatio)) * 2;
  const cropLeft = bounds.left - (paddedSize - foregroundWidth) / 2;
  const cropTop = bounds.top - (paddedSize - foregroundHeight) / 2;
  const offset = (handwrittenDigitInputSize - handwrittenDigitBodySize) / 2;
  for (let y = 0; y < handwrittenDigitBodySize; y++) {
    for (let x = 0; x < handwrittenDigitBodySize; x++) {
      const sourceX = cropLeft + (x + 0.5) * paddedSize / handwrittenDigitBodySize - 0.5;
      const sourceY = cropTop + (y + 0.5) * paddedSize / handwrittenDigitBodySize - 0.5;
      output[(y + offset) * handwrittenDigitInputSize + x + offset] =
        bilinearSample(ink, width, height, sourceX, sourceY);
    }
  }
  return output;
}

function bilinearSample(
  values: Float32Array, width: number, height: number, sourceX: number, sourceY: number
): number {
  const left = Math.floor(sourceX);
  const top = Math.floor(sourceY);
  const horizontal = sourceX - left;
  const vertical = sourceY - top;
  const topLeft = sample(values, width, height, left, top);
  const topRight = sample(values, width, height, left + 1, top);
  const bottomLeft = sample(values, width, height, left, top + 1);
  const bottomRight = sample(values, width, height, left + 1, top + 1);
  return topLeft * (1 - horizontal) * (1 - vertical) + topRight * horizontal * (1 - vertical) +
    bottomLeft * (1 - horizontal) * vertical + bottomRight * horizontal * vertical;
}

function sample(values: Float32Array, width: number, height: number, x: number, y: number): number {
  if (x < 0 || y < 0 || x >= width || y >= height) {
    return 0;
  }
  return values[y * width + x];
}

export function translateHandwrittenDigitToCenter(values: Float32Array): Float32Array {
  if (values.length !== handwrittenDigitInputFloatCount) {
    throw new Error('Handwritten digit body must be 28x28.');
  }
  let mass = 0;
  let centerX = 0;
  let centerY = 0;
  let left = handwrittenDigitInputSize;
  let top = handwrittenDigitInputSize;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < handwrittenDigitInputSize; y++) {
    for (let x = 0; x < handwrittenDigitInputSize; x++) {
      const value = values[y * handwrittenDigitInputSize + x];
      if (!Number.isFinite(value) || value < 0) {
        throw new Error('Handwritten digit body contains invalid values.');
      }
      mass += value;
      centerX += value * x;
      centerY += value * y;
      if (value > 0) {
        left = Math.min(left, x);
        top = Math.min(top, y);
        right = Math.max(right, x);
        bottom = Math.max(bottom, y);
      }
    }
  }
  if (mass <= 0 || !Number.isFinite(mass)) {
    throw new Error('Handwritten digit image is blank.');
  }
  const desiredShiftX = Math.round((handwrittenDigitInputSize - 1) / 2 - centerX / mass);
  const desiredShiftY = Math.round((handwrittenDigitInputSize - 1) / 2 - centerY / mass);
  const shiftX = Math.min(handwrittenDigitInputSize - 1 - right, Math.max(-left, desiredShiftX));
  const shiftY = Math.min(handwrittenDigitInputSize - 1 - bottom, Math.max(-top, desiredShiftY));
  const translated = new Float32Array(values.length);
  for (let y = 0; y < handwrittenDigitInputSize; y++) {
    for (let x = 0; x < handwrittenDigitInputSize; x++) {
      translated[y * handwrittenDigitInputSize + x] = sample(
        values, handwrittenDigitInputSize, handwrittenDigitInputSize, x - shiftX, y - shiftY
      );
    }
  }
  return translated;
}
