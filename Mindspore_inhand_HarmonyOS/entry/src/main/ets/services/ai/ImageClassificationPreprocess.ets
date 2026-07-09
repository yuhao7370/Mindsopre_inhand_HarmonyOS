export const imageClassificationResizedSize: number = 256;
export const imageClassificationCropSize: number = 224;
export const imageClassificationCropOffset: number = 16;
export const imageClassificationInputChannels: number = 3;
export const imageClassificationInputFloatCount: number =
  imageClassificationCropSize * imageClassificationCropSize * imageClassificationInputChannels;
export const imageClassificationMean: Array<number> = [0.485, 0.456, 0.406];
export const imageClassificationStd: Array<number> = [0.229, 0.224, 0.225];

export function normalizedRgbInputFromResizedRgba(rgba: Uint8Array): ArrayBuffer {
  const expectedLength = imageClassificationResizedSize * imageClassificationResizedSize * 4;
  if (rgba.length !== expectedLength) {
    throw new Error(`Expected ${expectedLength} RGBA bytes, got ${rgba.length}.`);
  }

  const input = new Float32Array(imageClassificationInputFloatCount);
  let outputIndex = 0;
  for (let y = 0; y < imageClassificationCropSize; y++) {
    const sourceY = y + imageClassificationCropOffset;
    for (let x = 0; x < imageClassificationCropSize; x++) {
      const sourceX = x + imageClassificationCropOffset;
      const rgbaIndex = ((sourceY * imageClassificationResizedSize) + sourceX) * 4;
      input[outputIndex] = normalizeChannel(rgba[rgbaIndex], 0);
      input[outputIndex + 1] = normalizeChannel(rgba[rgbaIndex + 1], 1);
      input[outputIndex + 2] = normalizeChannel(rgba[rgbaIndex + 2], 2);
      outputIndex += imageClassificationInputChannels;
    }
  }
  return input.buffer as ArrayBuffer;
}

function normalizeChannel(value: number, channel: number): number {
  return ((value / 255) - imageClassificationMean[channel]) / imageClassificationStd[channel];
}
