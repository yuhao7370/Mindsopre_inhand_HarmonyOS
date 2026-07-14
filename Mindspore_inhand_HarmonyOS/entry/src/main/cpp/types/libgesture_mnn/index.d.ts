export interface GestureRawTensor {
  readonly name: string;
  readonly shape: number[];
  readonly data: ArrayBuffer;
}

export interface GestureRawOutputs {
  readonly tensors: GestureRawTensor[];
}

export interface GestureModelInfo {
  readonly inputName: string;
  readonly inputShape: number[];
}

export const loadModel: (modelBytes: Uint8Array) => GestureModelInfo;
export const predict: (input: Float32Array) => Promise<GestureRawOutputs>;
export const release: () => void;
