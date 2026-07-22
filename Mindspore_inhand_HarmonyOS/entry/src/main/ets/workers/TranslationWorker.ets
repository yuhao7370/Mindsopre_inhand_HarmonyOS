import worker from '@ohos.worker';
import { TranslationWorkerRuntime } from '../services/ai/TranslationWorkerRuntime';

interface TranslationWorkerRequest {
  readonly kind: string;
  readonly id: number;
  readonly directory?: string;
  readonly manifest?: Object;
  readonly text?: string;
  readonly targetLanguage?: string;
}

interface TranslationWorkerManifestLike { readonly schemaVersion?: number; readonly directions?: Object; }

type TranslationWorkerRequestKind = 'initialize' | 'translate';

const runtime = new TranslationWorkerRuntime();
let initialized: boolean = false;
let initCount: number = 0;
let tail: Promise<void> = Promise.resolve();

worker.workerPort.onmessage = (event): void => {
  const request = parseTranslationWorkerRequest(event.data);
  if (request === undefined) {
    worker.workerPort.postMessage({ kind: 'error', id: 0, ok: false, error: 'Translation worker received an invalid request.' });
    return;
  }
  const operation = async (): Promise<void> => {
    try {
      if (request.kind === 'initialize') {
        if (initialized) {
          throw new Error('Translation worker is already initialized.');
        }
        await runtime.initialize({
          directory: request.directory ?? '',
          manifest: request.manifest as never
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

function parseTranslationWorkerRequest(value: Object): TranslationWorkerRequest | undefined {
  const request = value as TranslationWorkerRequest;
  if (request === undefined || request === null || !Number.isInteger(request.id) || request.id <= 0 ||
    (request.kind !== 'initialize' && request.kind !== 'translate')) {
    return undefined;
  }
  if (request.kind === 'initialize') {
    if (typeof request.directory !== 'string' || !hasTranslationManifestShape(request.manifest)) {
      return undefined;
    }
    return request;
  }
  if (typeof request.text !== 'string' || typeof request.targetLanguage !== 'string') {
    return undefined;
  }
  return request;
}

function hasTranslationManifestShape(value: Object | undefined): boolean {
  if (value === undefined || value === null) return false;
  const manifest = value as TranslationWorkerManifestLike;
  return manifest.schemaVersion === 2 && manifest.directions !== undefined;
}
