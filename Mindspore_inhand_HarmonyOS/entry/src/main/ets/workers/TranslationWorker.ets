import worker from '@ohos.worker';
import { TranslationWorkerRuntime } from '../services/ai/TranslationWorkerRuntime';

interface TranslationWorkerRequest {
  readonly kind: string;
  readonly id: number;
  readonly directory?: string;
  readonly manifest?: Object;
  readonly tokenizerRuntime?: string;
  readonly text?: string;
  readonly targetLanguage?: string;
}

const runtime = new TranslationWorkerRuntime();
let initialized: boolean = false;
let initCount: number = 0;
let tail: Promise<void> = Promise.resolve();

worker.workerPort.onmessage = (event): void => {
  const request = event.data as TranslationWorkerRequest;
  const operation = async (): Promise<void> => {
    try {
      if (request.kind === 'initialize') {
        await runtime.initialize({
          directory: request.directory ?? '',
          manifest: request.manifest as never,
          tokenizerRuntime: request.tokenizerRuntime ?? ''
        });
        initialized = true;
        initCount++;
        worker.workerPort.postMessage({ kind: 'ready', id: request.id, ok: true, initCount: initCount });
        return;
      }
      if (request.kind !== 'translate' || !initialized) {
        throw new Error('Translation worker request is invalid.');
      }
      const result = await runtime.translate(request.text ?? '', request.targetLanguage ?? '');
      worker.workerPort.postMessage({ kind: 'result', id: request.id, ok: true, result: result });
    } catch (error) {
      console.error(`TranslationWorker request ${request.id} failed: ${error}`);
      worker.workerPort.postMessage({ kind: 'error', id: request.id, ok: false, error: `${error}` });
    }
  };
  tail = tail.then(operation, operation);
};
