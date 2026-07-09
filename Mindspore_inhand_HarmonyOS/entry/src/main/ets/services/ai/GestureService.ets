export interface GestureRectangle {
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
