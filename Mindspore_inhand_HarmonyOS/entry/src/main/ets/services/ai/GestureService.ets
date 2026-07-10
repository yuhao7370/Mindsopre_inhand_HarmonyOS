export interface GestureRectangle {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface GestureRectanglePercent {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

export interface GestureDetection {
  readonly category: number;
  readonly label: string;
  readonly score: number;
  readonly rect?: GestureRectangle;
}

export interface GestureResult {
  readonly ok: boolean;
  readonly gestures: Array<GestureDetection>;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs: number;
}

export interface GestureRunner {
  detectGesture(imageUri: string): Promise<GestureResult>;
}

export interface GestureServiceOptions {
  readonly runner: GestureRunner;
}

export class GestureService {
  private readonly runner: GestureRunner;

  constructor(options: GestureServiceOptions) {
    this.runner = options.runner;
  }

  async detectGesture(imageUri: string): Promise<GestureResult> {
    const startMs = Date.now();
    try {
      return await this.runner.detectGesture(imageUri);
    } catch (_) {
      return {
        ok: false,
        gestures: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export function gestureDetectionLabel(gesture: GestureDetection): string {
  const runnerLabel = gesture.label.trim();
  if (runnerLabel.length > 0) {
    return runnerLabel;
  }
  return androidGestureLabel(gesture.category);
}

export function androidGestureLabel(category: number): string {
  switch (category) {
    case 0:
      return 'One';
    case 1:
      return 'Two';
    case 2:
      return 'Three';
    case 3:
      return 'Four';
    case 4:
      return 'Five';
    case 5:
      return 'Six';
    case 6:
      return 'Seven';
    case 7:
      return 'Eight';
    case 8:
      return 'Nine';
    case 9:
      return 'Dislike';
    case 10:
      return 'Fist';
    case 11:
      return 'Thumb up';
    case 12:
      return 'Heart';
    case 13:
      return 'OK';
    default:
      return 'Other gesture';
  }
}

export function gestureRectanglePercent(
  rectangle: GestureRectangle,
  imageWidth: number,
  imageHeight: number
): GestureRectanglePercent {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return {
      left: 0,
      top: 0,
      width: 0,
      height: 0
    };
  }

  const left = gesturePercent(rectangle.left, imageWidth);
  const top = gesturePercent(rectangle.top, imageHeight);
  const right = gesturePercent(rectangle.left + rectangle.width, imageWidth);
  const bottom = gesturePercent(rectangle.top + rectangle.height, imageHeight);
  return {
    left: left,
    top: top,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top)
  };
}

function gesturePercent(value: number, sourceLength: number): number {
  return Math.min(100, Math.max(0, value * 100 / sourceLength));
}
