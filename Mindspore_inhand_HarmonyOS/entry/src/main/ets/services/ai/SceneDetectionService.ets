export interface SceneDetection {
  readonly label: string;
  readonly score: number;
}

export interface SceneDetectionResult {
  readonly ok: boolean;
  readonly scenes: Array<SceneDetection>;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs: number;
}

export interface SceneDetectionRunner {
  detectScenes(imageUri: string): Promise<SceneDetectionResult>;
}

export interface SceneDetectionServiceOptions {
  readonly runner: SceneDetectionRunner;
}

export class SceneDetectionService {
  private readonly runner: SceneDetectionRunner;

  constructor(options: SceneDetectionServiceOptions) {
    this.runner = options.runner;
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    const startMs = Date.now();
    try {
      return await this.runner.detectScenes(imageUri);
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}
