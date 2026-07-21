export interface StyleTransferNativeOutput {
  readonly output: Float32Array;
  readonly predictMs: number;
  readonly transferMs: number;
}

export const loadModels: (predictModel: Uint8Array, transferModel: Uint8Array) => Promise<void>;
export const validatePredictModel: (model: Uint8Array) => Promise<boolean>;
export const validateTransferModel: (model: Uint8Array) => Promise<boolean>;
export const validateModelPair: (predictModel: Uint8Array, transferModel: Uint8Array) => Promise<boolean>;
export const run: (styleInput: Float32Array, contentInput: Float32Array) => Promise<StyleTransferNativeOutput>;
export const release: () => void;
