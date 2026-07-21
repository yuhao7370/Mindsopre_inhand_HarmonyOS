import { describe, expect, it } from '@ohos/hypium';
import { TranslationWorkerClient, TranslationWorkerClientDependencies, TranslationWorkerPort } from '../../../main/ets/services/ai/TranslationWorkerClient';
import { TranslationProductionBundleOptions } from '../../../main/ets/services/ai/MindSporeLiteTranslationRunner';

class WorkerEvent { readonly data: Object; constructor(data: Object) { this.data = data; } }
class WorkerMessage { readonly kind: string; readonly id: number; readonly ok: boolean; readonly result?: Object; constructor(kind: string, id: number, ok: boolean, result?: Object) { this.kind = kind; this.id = id; this.ok = ok; this.result = result; } }
class WorkerResult { readonly ok: boolean = true; readonly sourceText: string; readonly translatedText: string; readonly targetLanguage: string; constructor(sourceText: string, translatedText: string, targetLanguage: string) { this.sourceText = sourceText; this.translatedText = translatedText; this.targetLanguage = targetLanguage; } }
class FakeWorker implements TranslationWorkerPort {
  onmessage?: (event: WorkerEvent) => void; onerror?: (event: Object) => void; onAllErrors?: (event: Object) => void; onexit?: (code: number) => void;
  readonly messages: Array<Object> = []; terminateCount: number = 0; throwOnPost: number = 0;
  postMessage(message: Object): void { this.messages.push(message); if (this.throwOnPost === this.messages.length) throw new Error('post failed'); }
  terminate(): void { this.terminateCount++; }
  reply(message: Object): void { this.onmessage?.(new WorkerEvent(message)); }
  exit(): void { this.onexit?.(9); }
}
class FakeOptions implements TranslationProductionBundleOptions { readonly resourceManager = new Object() as never; readonly cacheRoot: string = '/test'; }
class Prepared { readonly directory: string = '/test'; readonly manifest: Object = new Object(); }
class Dependencies implements TranslationWorkerClientDependencies {
  private readonly workers: Array<FakeWorker>; readonly requestTimeoutMs: number;
  constructor(workers: Array<FakeWorker>, timeoutMs: number = 50) { this.workers = workers; this.requestTimeoutMs = timeoutMs; }
  async prepare(): Promise<Prepared> { return new Prepared(); }
  async getTokenizerRuntime(): Promise<string> { return 'test'; }
  createWorker(): TranslationWorkerPort { return this.workers.shift() as TranslationWorkerPort; }
}
class MessageId { readonly id: number; constructor(id: number) { this.id = id; } }
async function turn(): Promise<void> { await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 0); }); }

export default function translationWorkerClientTest() {
  describe('TranslationWorkerClientTest', () => {
    it('terminates pending work once and ignores an old worker exit', 0, async () => {
      const oldWorker = new FakeWorker(); const replacement = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(), new Dependencies([oldWorker, replacement]));
      const first = client.translate('first', 'zh'); await turn();
      oldWorker.reply(new WorkerMessage('ready', (oldWorker.messages[0] as MessageId).id, true)); await turn();
      client.terminate(); client.terminate();
      expect((await first).ok).assertFalse(); expect(oldWorker.terminateCount).assertEqual(1);
      const second = client.translate('second', 'zh'); await turn();
      replacement.reply(new WorkerMessage('ready', (replacement.messages[0] as MessageId).id, true)); await turn();
      oldWorker.exit();
      replacement.reply(new WorkerMessage('result', (replacement.messages[1] as MessageId).id, true, new WorkerResult('second', '第二', 'zh')));
      expect((await second).translatedText).assertEqual('第二'); client.terminate();
    });
    it('settles initialization when initialize postMessage throws', 0, async () => {
      const worker = new FakeWorker(); worker.throwOnPost = 1;
      const result = await new TranslationWorkerClient(new FakeOptions(), new Dependencies([worker])).translate('init', 'zh');
      expect(result.ok).assertFalse(); expect(worker.terminateCount).assertEqual(1);
    });

    it('settles translation when translate postMessage throws', 0, async () => {
      const worker = new FakeWorker(); worker.throwOnPost = 2;
      const client = new TranslationWorkerClient(new FakeOptions(), new Dependencies([worker]));
      const pending = client.translate('translate', 'zh'); await turn();
      worker.reply(new WorkerMessage('ready', (worker.messages[0] as MessageId).id, true));
      const result = await pending;
      expect(result.ok).assertFalse(); expect(worker.terminateCount).assertEqual(1);
    });
  });
}
