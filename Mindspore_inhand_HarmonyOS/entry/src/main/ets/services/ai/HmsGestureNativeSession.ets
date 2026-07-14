import { HmsGestureOutputs } from './HmsGestureYoloDecoder';

export interface HmsGestureModelInfo {
  readonly inputName: string;
  readonly inputShape: Array<number>;
}

export interface HmsGestureNativeSession {
  loadModel(modelBytes: Uint8Array): HmsGestureModelInfo;
  predict(input: Float32Array): Promise<HmsGestureOutputs>;
  release(): void;
}

export type HmsGestureNativeSessionFactory = () => Promise<HmsGestureNativeSession>;

class HarmonyHmsGestureNativeSession implements HmsGestureNativeSession {
  private readonly nativeModule: ESObject;

  constructor(nativeModule: ESObject) {
    this.nativeModule = nativeModule;
  }

  loadModel(modelBytes: Uint8Array): HmsGestureModelInfo {
    return this.nativeModule.loadModel(modelBytes) as HmsGestureModelInfo;
  }

  async predict(input: Float32Array): Promise<HmsGestureOutputs> {
    return await this.nativeModule.predict(input) as HmsGestureOutputs;
  }

  release(): void {
    this.nativeModule.release();
  }
}

export const createHarmonyHmsGestureNativeSession: HmsGestureNativeSessionFactory = async () => {
  const namespace: ESObject = await import('libgesture_mnn.so');
  return new HarmonyHmsGestureNativeSession(namespace.default);
};
