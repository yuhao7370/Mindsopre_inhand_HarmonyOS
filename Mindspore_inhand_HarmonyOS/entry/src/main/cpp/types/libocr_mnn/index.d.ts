export const loadModels: (detectorBytes: Uint8Array, recognizerBytes: Uint8Array) => void;
export const predictDetector: (input: Float32Array) => Promise<ArrayBuffer>;
export const predictRecognizer: (input: Float32Array) => Promise<ArrayBuffer>;
export const release: () => void;
