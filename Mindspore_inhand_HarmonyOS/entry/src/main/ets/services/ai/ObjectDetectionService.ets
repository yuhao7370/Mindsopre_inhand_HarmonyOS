import { image } from '@kit.ImageKit';

export const objectCategoryLabelRawfilePath: string = 'labels/object_category.txt';
export const objectCategoryLabelCount: number = 81;
export const objectDetectionModelRawfilePath: string = 'model/ssd.ms';
export const objectDetectionModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms';
export const objectDetectionInputSize: number = 300;
export const objectDetectionInputChannels: number = 3;
export const objectDetectionInputFloatCount: number =
  objectDetectionInputSize * objectDetectionInputSize * objectDetectionInputChannels;
export const objectDetectionMean: Array<number> = [0.485, 0.456, 0.406];
export const objectDetectionStd: Array<number> = [0.229, 0.224, 0.225];

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
  let outputIndex = 0;
  for (let index = 0; index < rgba.length; index += 4) {
    input[outputIndex] = normalizeObjectDetectionChannel(rgba[index], 0);
    input[outputIndex + 1] = normalizeObjectDetectionChannel(rgba[index + 1], 1);
    input[outputIndex + 2] = normalizeObjectDetectionChannel(rgba[index + 2], 2);
    outputIndex += objectDetectionInputChannels;
  }
  return input.buffer as ArrayBuffer;
}

function normalizeObjectDetectionChannel(value: number, channel: number): number {
  return ((value / 255) - objectDetectionMean[channel]) / objectDetectionStd[channel];
}
