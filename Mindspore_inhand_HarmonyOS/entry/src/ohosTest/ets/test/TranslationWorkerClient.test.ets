import { describe, expect, it } from '@ohos/hypium';
import { TranslationWorkerClient, TranslationWorkerClientDependencies, TranslationWorkerPort } from '../../../main/ets/services/ai/TranslationWorkerClient';
import { TranslationProductionBundleOptions } from '../../../main/ets/services/ai/MindSporeLiteTranslationRunner';

class WorkerEvent { readonly data: Object; constructor(data: Object) { this.data = data; } }
class WorkerMessage { readonly kind: string; readonly id: number; readonly ok: boolean; readonly result?: Object; constructor(kind: string, id: number, ok: boolean, result?: Object) { this.kind = kind; this.id = id; this.ok = ok; this.result = result; } }
class WorkerFailureMessage { readonly kind: string = 'error'; readonly id: number; readonly ok: boolean = false;
  readonly error: string = 'model failed'; constructor(id: number) { this.id = id; } }
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
class Prepared { readonly directory: string; readonly manifest: Object = new Object();
  constructor(directory: string = '/test') { this.directory = directory; } }
class Dependencies implements TranslationWorkerClientDependencies {
  private readonly workers: Array<FakeWorker>; readonly requestTimeoutMs: number;
  prepareCalls: number = 0; failPrepareCount: number = 0;
  constructor(workers: Array<FakeWorker>, timeoutMs: number = 50) { this.workers = workers; this.requestTimeoutMs = timeoutMs; }
  async prepare(): Promise<Prepared> {
    this.prepareCalls++;
    if (this.failPrepareCount > 0) { this.failPrepareCount--; throw new Error('prepare failed'); }
    return new Prepared();
  }
  createWorker(): TranslationWorkerPort { return this.workers.shift() as TranslationWorkerPort; }
}
class DeferredPrepareDependencies implements TranslationWorkerClientDependencies {
  readonly requestTimeoutMs: number; readonly worker: FakeWorker = new FakeWorker(); createWorkerCalls: number = 0;
  private resolvePrepared?: (value: Prepared) => void;
  constructor(timeoutMs: number) { this.requestTimeoutMs = timeoutMs; }
  prepare(): Promise<Prepared> {
    return new Promise<Prepared>((resolve: (value: Prepared) => void): void => { this.resolvePrepared = resolve; });
  }
  createWorker(): TranslationWorkerPort { this.createWorkerCalls++; return this.worker; }
  finishPrepare(): void { this.resolvePrepared?.(new Prepared()); }
}
class RetryingPrepareDependencies implements TranslationWorkerClientDependencies {
  private readonly workers: Array<FakeWorker>; readonly requestTimeoutMs: number;
  readonly resolvers: Array<(value: Prepared) => void> = [];
  prepareCalls: number = 0; createWorkerCalls: number = 0;
  constructor(workers: Array<FakeWorker>, timeoutMs: number) { this.workers = workers; this.requestTimeoutMs = timeoutMs; }
  prepare(): Promise<Prepared> {
    this.prepareCalls++;
    return new Promise<Prepared>((resolve: (value: Prepared) => void): void => { this.resolvers.push(resolve); });
  }
  createWorker(): TranslationWorkerPort { this.createWorkerCalls++; return this.workers.shift() as TranslationWorkerPort; }
  finishPrepare(attempt: number, prepared: Prepared): void { this.resolvers[attempt]?.(prepared); }
}
class MessageId { readonly id: number; constructor(id: number) { this.id = id; } }
class InitializeDirectory { readonly directory: string = ''; }
async function turn(): Promise<void> { await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 0); }); }
async function wait(milliseconds: number): Promise<void> {
  await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, milliseconds); });
}

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

    it('reuses one direction and replaces the worker after queued work completes', 0, async () => {
      const english = new FakeWorker(); const chinese = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(), new Dependencies([english, chinese]));
      const first = client.translate('first', 'en'); await turn();
      english.reply(new WorkerMessage('ready', (english.messages[0] as MessageId).id, true)); await turn();
      english.reply(new WorkerMessage('result', (english.messages[1] as MessageId).id, true,
        new WorkerResult('first', 'first-en', 'en')));
      expect((await first).translatedText).assertEqual('first-en');
      const same = client.translate('second', 'en'); await turn();
      english.reply(new WorkerMessage('result', (english.messages[2] as MessageId).id, true,
        new WorkerResult('second', 'second-en', 'en')));
      expect((await same).translatedText).assertEqual('second-en');
      expect(english.terminateCount).assertEqual(0);

      const switched = client.translate('third', 'zh'); await turn();
      expect(english.terminateCount).assertEqual(1);
      chinese.reply(new WorkerMessage('ready', (chinese.messages[0] as MessageId).id, true)); await turn();
      chinese.reply(new WorkerMessage('result', (chinese.messages[1] as MessageId).id, true,
        new WorkerResult('third', 'third-zh', 'zh')));
      expect((await switched).translatedText).assertEqual('third-zh');
      client.terminate();
    });

    it('retriesMetadataPreparationAfterTheFirstFailure', 0, async () => {
      const worker = new FakeWorker(); const dependencies = new Dependencies([worker]);
      dependencies.failPrepareCount = 1;
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      expect((await client.translate('first', 'en')).ok).assertFalse();
      const second = client.translate('second', 'en'); await turn();
      worker.reply(new WorkerMessage('ready', (worker.messages[0] as MessageId).id, true)); await turn();
      worker.reply(new WorkerMessage('result', (worker.messages[1] as MessageId).id, true,
        new WorkerResult('second', 'second-en', 'en')));
      expect((await second).ok).assertTrue();
      expect(dependencies.prepareCalls).assertEqual(2); client.terminate();
    });

    it('stopRejectsAlreadyQueuedWorkButANewCallCanStartFresh', 0, async () => {
      const oldWorker = new FakeWorker(); const freshWorker = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(), new Dependencies([oldWorker, freshWorker]));
      const first = client.translate('first', 'en');
      const queued = client.translate('queued', 'en'); await turn();
      client.terminate();
      expect((await first).ok).assertFalse();
      expect((await queued).ok).assertFalse();
      expect(oldWorker.terminateCount).assertEqual(1);
      const fresh = client.translate('fresh', 'en'); await turn();
      freshWorker.reply(new WorkerMessage('ready', (freshWorker.messages[0] as MessageId).id, true)); await turn();
      freshWorker.reply(new WorkerMessage('result', (freshWorker.messages[1] as MessageId).id, true,
        new WorkerResult('fresh', 'fresh-en', 'en')));
      expect((await fresh).ok).assertTrue(); client.terminate();
    });

    it('replacesAWorkerAfterAStableRuntimeError', 0, async () => {
      const failedWorker = new FakeWorker(); const recoveredWorker = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(), new Dependencies([failedWorker, recoveredWorker]));
      const failed = client.translate('failed', 'en'); await turn();
      failedWorker.reply(new WorkerMessage('ready', (failedWorker.messages[0] as MessageId).id, true)); await turn();
      failedWorker.reply(new WorkerFailureMessage((failedWorker.messages[1] as MessageId).id));
      expect((await failed).ok).assertFalse(); expect(failedWorker.terminateCount).assertEqual(1);
      const recovered = client.translate('recovered', 'en'); await turn();
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true)); await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-en', 'en')));
      expect((await recovered).ok).assertTrue(); client.terminate();
    });

    it('terminatesATimedOutWorkerAndRecoversWithAFreshWorker', 0, async () => {
      const timedOutWorker = new FakeWorker(); const recoveredWorker = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(),
        new Dependencies([timedOutWorker, recoveredWorker], 50));
      const timedOut = client.translate('timed-out', 'zh'); await turn();
      timedOutWorker.reply(new WorkerMessage('ready', (timedOutWorker.messages[0] as MessageId).id, true));
      await turn();
      expect((await timedOut).ok).assertFalse();
      expect(timedOutWorker.terminateCount).assertEqual(1);

      const recovered = client.translate('recovered', 'zh'); await turn();
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true));
      await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-zh', 'zh')));
      expect((await recovered).ok).assertTrue(); client.terminate();
    });

    it('replacesAWorkerWhenInitializationReceivesAResultMessage', 0, async () => {
      const mismatchedWorker = new FakeWorker(); const recoveredWorker = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(),
        new Dependencies([mismatchedWorker, recoveredWorker]));
      const mismatched = client.translate('initialize-mismatch', 'en'); await turn();
      mismatchedWorker.reply(new WorkerMessage('result', (mismatchedWorker.messages[0] as MessageId).id, true,
        new WorkerResult('initialize-mismatch', 'wrong-phase', 'en')));
      expect((await mismatched).ok).assertFalse();
      expect(mismatchedWorker.terminateCount).assertEqual(1);

      const recovered = client.translate('recovered', 'en'); await turn();
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true)); await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-en', 'en')));
      expect((await recovered).ok).assertTrue(); client.terminate();
    });

    it('replacesAWorkerWhenTranslationReceivesAReadyMessage', 0, async () => {
      const mismatchedWorker = new FakeWorker(); const recoveredWorker = new FakeWorker();
      const client = new TranslationWorkerClient(new FakeOptions(),
        new Dependencies([mismatchedWorker, recoveredWorker]));
      const mismatched = client.translate('translate-mismatch', 'zh'); await turn();
      mismatchedWorker.reply(new WorkerMessage('ready', (mismatchedWorker.messages[0] as MessageId).id, true)); await turn();
      mismatchedWorker.reply(new WorkerMessage('ready', (mismatchedWorker.messages[1] as MessageId).id, true));
      expect((await mismatched).ok).assertFalse();
      expect(mismatchedWorker.terminateCount).assertEqual(1);

      const recovered = client.translate('recovered', 'zh'); await turn();
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true)); await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-zh', 'zh')));
      expect((await recovered).ok).assertTrue(); client.terminate();
    });

    it('timesOutWhileMetadataPreparationNeverCompletesWithoutCreatingAWorker', 0, async () => {
      const dependencies = new DeferredPrepareDependencies(40);
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      let settled: boolean = false; let ok: boolean = true;
      const pending = client.translate('blocked', 'en');
      pending.then((result): void => { settled = true; ok = result.ok; });
      await wait(120);
      const settledBeforePrepareFinished = settled;
      dependencies.finishPrepare(); await turn();
      const createWorkerCalls = dependencies.createWorkerCalls;
      client.terminate(); await pending;
      expect(settledBeforePrepareFinished).assertTrue();
      expect(ok).assertFalse();
      expect(createWorkerCalls).assertEqual(0);
    });

    it('stopSettlesPreparationImmediatelyAndPreventsALateWorker', 0, async () => {
      const dependencies = new DeferredPrepareDependencies(5000);
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      let settled: boolean = false; let ok: boolean = true;
      const pending = client.translate('stopped', 'zh');
      pending.then((result): void => { settled = true; ok = result.ok; });
      await turn(); await client.stop(); await turn();
      const settledBeforePrepareFinished = settled;
      dependencies.finishPrepare(); await turn();
      const createWorkerCalls = dependencies.createWorkerCalls;
      client.terminate(); await pending;
      expect(settledBeforePrepareFinished).assertTrue();
      expect(ok).assertFalse();
      expect(createWorkerCalls).assertEqual(0);
    });

    it('retriesPreparationAfterTimeoutAndIgnoresTheLateOldAttempt', 0, async () => {
      const recoveredWorker = new FakeWorker(); const cachedWorker = new FakeWorker();
      const dependencies = new RetryingPrepareDependencies([recoveredWorker, cachedWorker], 40);
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      expect((await client.translate('first', 'en')).ok).assertFalse();

      const recovered = client.translate('recovered', 'en'); await turn();
      const prepareCallsAfterRetry = dependencies.prepareCalls;
      dependencies.finishPrepare(1, new Prepared('/second')); await turn();
      if (recoveredWorker.messages.length === 0) {
        dependencies.finishPrepare(0, new Prepared('/old')); await turn();
      }
      const recoveredDirectory = (recoveredWorker.messages[0] as InitializeDirectory).directory;
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true)); await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-en', 'en')));
      const recoveredResult = await recovered;
      const createCallsBeforeOldAttempt = dependencies.createWorkerCalls;
      dependencies.finishPrepare(0, new Prepared('/old')); await turn();
      const createCallsAfterOldAttempt = dependencies.createWorkerCalls;

      client.terminate();
      const cached = client.translate('cached', 'en'); await turn();
      const cachedDirectory = (cachedWorker.messages[0] as InitializeDirectory).directory;
      cachedWorker.reply(new WorkerMessage('ready', (cachedWorker.messages[0] as MessageId).id, true)); await turn();
      cachedWorker.reply(new WorkerMessage('result', (cachedWorker.messages[1] as MessageId).id, true,
        new WorkerResult('cached', 'cached-en', 'en')));
      expect((await cached).ok).assertTrue(); client.terminate();

      expect(prepareCallsAfterRetry).assertEqual(2);
      expect(recoveredResult.ok).assertTrue();
      expect(recoveredDirectory).assertEqual('/second');
      expect(createCallsAfterOldAttempt).assertEqual(createCallsBeforeOldAttempt);
      expect(cachedDirectory).assertEqual('/second');
      expect(dependencies.prepareCalls).assertEqual(2);
    });

    it('retriesPreparationAfterStopAndIgnoresTheLateOldAttempt', 0, async () => {
      const worker = new FakeWorker();
      const dependencies = new RetryingPrepareDependencies([worker], 5000);
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      const stopped = client.translate('stopped', 'zh'); await turn();
      await client.stop(); expect((await stopped).ok).assertFalse();

      const recovered = client.translate('recovered', 'zh'); await turn();
      const prepareCallsAfterRetry = dependencies.prepareCalls;
      dependencies.finishPrepare(1, new Prepared('/second')); await turn();
      if (worker.messages.length === 0) {
        dependencies.finishPrepare(0, new Prepared('/old')); await turn();
      }
      const recoveredDirectory = (worker.messages[0] as InitializeDirectory).directory;
      worker.reply(new WorkerMessage('ready', (worker.messages[0] as MessageId).id, true)); await turn();
      worker.reply(new WorkerMessage('result', (worker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-zh', 'zh')));
      expect((await recovered).ok).assertTrue();
      const createCallsBeforeOldAttempt = dependencies.createWorkerCalls;
      dependencies.finishPrepare(0, new Prepared('/old')); await turn();
      expect(dependencies.createWorkerCalls).assertEqual(createCallsBeforeOldAttempt);
      expect(prepareCallsAfterRetry).assertEqual(2);
      expect(recoveredDirectory).assertEqual('/second');
      client.terminate();
    });

    it('reusesSuccessfulPreparationAcrossWorkerTimeoutStopAndRecovery', 0, async () => {
      const timedOutWorker = new FakeWorker(); const recoveredWorker = new FakeWorker(); const stoppedWorker = new FakeWorker();
      const dependencies = new Dependencies([timedOutWorker, recoveredWorker, stoppedWorker], 40);
      const client = new TranslationWorkerClient(new FakeOptions(), dependencies);
      const timedOut = client.translate('timed-out', 'en'); await turn();
      timedOutWorker.reply(new WorkerMessage('ready', (timedOutWorker.messages[0] as MessageId).id, true)); await turn();
      expect((await timedOut).ok).assertFalse();

      const recovered = client.translate('recovered', 'en'); await turn();
      recoveredWorker.reply(new WorkerMessage('ready', (recoveredWorker.messages[0] as MessageId).id, true)); await turn();
      recoveredWorker.reply(new WorkerMessage('result', (recoveredWorker.messages[1] as MessageId).id, true,
        new WorkerResult('recovered', 'recovered-en', 'en')));
      expect((await recovered).ok).assertTrue();
      await client.stop();

      const afterStop = client.translate('after-stop', 'en'); await turn();
      stoppedWorker.reply(new WorkerMessage('ready', (stoppedWorker.messages[0] as MessageId).id, true)); await turn();
      stoppedWorker.reply(new WorkerMessage('result', (stoppedWorker.messages[1] as MessageId).id, true,
        new WorkerResult('after-stop', 'after-stop-en', 'en')));
      expect((await afterStop).ok).assertTrue();
      expect(dependencies.prepareCalls).assertEqual(1); client.terminate();
    });
  });
}
