export interface SegmentationModelInfo {
  readonly inputName: string;
  readonly inputShape: number[];
  readonly outputName: string;
  readonly outputShape: number[];
}

export const loadModel: (modelBytes: Uint8Array) => SegmentationModelInfo;
export const predict: (input: Float32Array) => Promise<ArrayBuffer>;
export const release: () => void;
