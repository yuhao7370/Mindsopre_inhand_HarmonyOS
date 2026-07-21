export interface ObjectDetectionModelInfo {
  readonly inputName: string;
  readonly inputShape: number[];
  readonly outputName: string;
  readonly outputShape: number[];
}

export const loadModel: (modelBytes: Uint8Array) => Promise<ObjectDetectionModelInfo>;
export const validateModel: (modelBytes: Uint8Array) => Promise<boolean>;
export const predict: (input: Float32Array) => Promise<Float32Array>;
export const release: () => void;
