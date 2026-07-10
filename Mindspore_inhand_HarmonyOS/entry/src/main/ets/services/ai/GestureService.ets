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
