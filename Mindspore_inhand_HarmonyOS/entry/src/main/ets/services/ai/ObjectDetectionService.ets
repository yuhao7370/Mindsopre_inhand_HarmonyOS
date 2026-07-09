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

export interface ObjectDetection {
  readonly imageId: number;
  readonly labelId: number;
  readonly label: string;
  readonly score: number;
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
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

    return this.runResult(true, 'DETECTION_DONE', mapObjectDetectionLabels(detections, this.labels));
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
      left: detection.left,
      top: detection.top,
      right: detection.right,
      bottom: detection.bottom
    };
  });
}
