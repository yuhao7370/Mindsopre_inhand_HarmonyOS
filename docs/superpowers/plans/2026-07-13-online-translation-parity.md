# Online Translation Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the finite production phrase dictionary with an ArkTS remote translation runner and a credential-safe proxy so arbitrary Chinese and English text, including OCR output, matches the Android HMS behavior.

**Architecture:** Keep `TextTranslationService`, `DefaultAiService`, OCR, picker, and page generation logic as the stable application flow. Add one testable ArkTS HTTP runner, inject it from the existing runtime factory, and run a minimal Node standard-library proxy that owns the Huawei Cloud token and normalizes provider responses.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, `@ohos.net.http`, Core Vision OCR, Hypium, Node.js 20+ standard library, `node:test`, Huawei Cloud NLP REST API.

## Global Constraints

- Chinese input defaults to target `en`; all other input defaults to target `zh` through the existing `androidDefaultTranslationTargetLanguage()` function.
- Production translation uses runtime source `remote`; `offlineDictionary` remains explicit development fallback only.
- The provider request limit is 2,000 characters; the app and proxy both reject longer input with `TEXT_TOO_LONG`.
- Client total timeout is 15,000 ms and retries at most once, only for transport failure, timeout, or HTTP 5xx.
- HTTP 4xx, 429, authentication failure, invalid payload, and malformed response are never retried by the client.
- HAP, ArkTS, rawfiles, logs, and tests contain no Huawei Cloud AK, SK, reusable token, or server administration key.
- Production proxy traffic is HTTPS. Plain HTTP is allowed only for host-side proxy tests, never as the shipped base URL.
- Existing text, camera, and photo inputs and OCR-to-translation chaining remain unchanged.
- Every asynchronous layer supports invalidation so an old request cannot update UI after a new request, route change, or page exit.

---

### Task 1: Lock the ArkTS result and transport contracts

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TextRecognitionService.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RemoteTextTranslationRunner.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: existing `TextTranslationRunner.translate(text: string, targetLanguage: string): Promise<TextTranslationResult>`.
- Produces: `RemoteTextTranslationRunner`, `TranslationHttpClient`, stable error codes, and cancellable `stop()` used by later lifecycle and factory tasks.

- [ ] **Step 1: Write failing contract tests**

Extend the translation imports in `LocalUnit.test.ets` with the new runner types. Add a fake transport that records calls and returns queued responses:

```ts
class FakeTranslationHttpClient implements TranslationHttpClient {
  readonly requests: Array<TranslationHttpRequest> = [];
  responses: Array<TranslationHttpResponse> = [];
  cancelled: boolean = false;

  async post(request: TranslationHttpRequest): Promise<TranslationHttpResponse> {
    this.requests.push(request);
    return this.responses.shift() ?? { statusCode: 503, body: '' };
  }

  cancelAll(): void {
    this.cancelled = true;
  }
}
```

Add cases asserting:

```ts
const client = new FakeTranslationHttpClient();
client.responses.push({
  statusCode: 200,
  body: '{"translatedText":"A new sentence","sourceLanguage":"zh","targetLanguage":"en","requestId":"r-1"}'
});
const runner = new RemoteTextTranslationRunner({
  baseUrl: 'https://translate.example.test',
  httpClient: client,
  requestIdFactory: (): string => 'r-1'
});
const result = await runner.translate('这是未收录的新句子', 'en');
expect(result.ok).assertTrue();
expect(result.translatedText).assertEqual('A new sentence');
expect(result.runtimeSource).assertEqual('remote');
expect(client.requests.length).assertEqual(1);
expect(client.requests[0].url).assertEqual('https://translate.example.test/v1/translate');
```

Also assert trimmed empty input returns `INVALID_TEXT` without a request, 2,001 characters returns `TEXT_TOO_LONG`, 503 then 200 makes exactly two calls, 400/401/429 make one call, malformed 200 JSON returns `BAD_RESPONSE`, and `stop()` calls `cancelAll()` and makes an outstanding generation stale.

- [ ] **Step 2: Run the suite to verify RED**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: compile failure because `RemoteTextTranslationRunner` and the new result fields do not exist.

- [ ] **Step 3: Add the exact result contract**

Change the translation contract in `TextRecognitionService.ets` to:

```ts
export type TextTranslationRuntimeSource = 'remote' | 'offlineDictionary';

export type TextTranslationErrorCode =
  'INVALID_TEXT' | 'TEXT_TOO_LONG' | 'UNSUPPORTED_LANGUAGE' |
  'RATE_LIMITED' | 'PROVIDER_UNAVAILABLE' | 'AUTH_MISCONFIGURED' |
  'NETWORK_UNAVAILABLE' | 'TIMEOUT' | 'BAD_RESPONSE' | 'CANCELLED';

export interface TextTranslationResult {
  readonly ok: boolean;
  readonly sourceText: string;
  readonly translatedText: string;
  readonly targetLanguage: string;
  readonly sourceLanguage?: string;
  readonly requestId?: string;
  readonly runtimeSource?: TextTranslationRuntimeSource;
  readonly errorCode?: TextTranslationErrorCode;
}

export interface TextTranslationRunner {
  translate(text: string, targetLanguage: string): Promise<TextTranslationResult>;
  stop?(): void;
}
```

Add `TextTranslationService.stop(): void` that invokes `this.runner.stop?.()`.

- [ ] **Step 4: Implement the minimal runner**

Create `RemoteTextTranslationRunner.ets` with these public types:

```ts
export interface TranslationHttpRequest {
  readonly url: string;
  readonly requestId: string;
  readonly body: string;
  readonly timeoutMs: number;
}

export interface TranslationHttpResponse {
  readonly statusCode: number;
  readonly body: string;
  readonly transportError?: 'NETWORK_UNAVAILABLE' | 'TIMEOUT';
}

export interface TranslationHttpClient {
  post(request: TranslationHttpRequest): Promise<TranslationHttpResponse>;
  cancelAll(): void;
}

export interface RemoteTextTranslationRunnerOptions {
  readonly baseUrl: string;
  readonly httpClient: TranslationHttpClient;
  readonly requestIdFactory: () => string;
  readonly timeoutMs?: number;
}
```

Implement `translate()` as two iterations. Build JSON with `{ text, targetLanguage, sourceLanguage: targetLanguage === 'en' ? 'zh' : 'en' }`, retry only when `transportError` exists or `statusCode >= 500`, and map proxy error JSON to the stable union. Before returning, compare the captured generation with the current generation and return `CANCELLED` if they differ. `stop()` increments generation and calls `cancelAll()`.

- [ ] **Step 5: Run GREEN and commit**

Run the Hypium command from Step 2. Expected: `Failure: 0, Error: 0`.

```powershell
git add entry/src/main/ets/services/ai/TextRecognitionService.ets entry/src/main/ets/services/ai/RemoteTextTranslationRunner.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat: add remote translation runner contract"
```

---

### Task 2: Implement the HarmonyOS HTTP adapter

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RemoteTextTranslationRunner.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `TranslationHttpClient` from Task 1 and HarmonyOS `http.HttpRequest`.
- Produces: `HarmonyTranslationHttpClient` used by the production runtime factory.

- [ ] **Step 1: Write failing adapter tests around an injected request factory**

Define a small adapter boundary in the test instead of mocking the system Kit:

```ts
interface TranslationHttpHandle {
  request(url: string, options: http.HttpRequestOptions): Promise<http.HttpResponse>;
  destroy(): void;
}

interface TranslationHttpHandleFactory {
  create(): TranslationHttpHandle;
}
```

Test that POST, `Content-Type`, `X-Request-Id`, body, `connectTimeout`, `readTimeout`, `expectDataType: STRING`, and `usingCache: false` are passed exactly, `destroy()` runs in success and failure paths, and `cancelAll()` destroys all active handles.

- [ ] **Step 2: Run RED**

Run the Task 1 Hypium command. Expected: compile failure because `HarmonyTranslationHttpClient` does not exist.

- [ ] **Step 3: Implement the adapter using the system HTTP Kit**

Add:

```ts
import http from '@ohos.net.http';

export class HarmonyTranslationHttpClient implements TranslationHttpClient {
  private readonly active: Array<http.HttpRequest> = [];

  async post(request: TranslationHttpRequest): Promise<TranslationHttpResponse> {
    const handle = http.createHttp();
    this.active.push(handle);
    try {
      const response = await handle.request(request.url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'X-Request-Id': request.requestId
        },
        extraData: request.body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: request.timeoutMs,
        readTimeout: request.timeoutMs,
        usingCache: false
      });
      return {
        statusCode: response.responseCode,
        body: typeof response.result === 'string' ? response.result : ''
      };
    } catch (_) {
      return { statusCode: 0, body: '', transportError: 'NETWORK_UNAVAILABLE' };
    } finally {
      const index = this.active.indexOf(handle);
      if (index >= 0) {
        this.active.splice(index, 1);
      }
      handle.destroy();
    }
  }

  cancelAll(): void {
    const handles = this.active.splice(0);
    handles.forEach((handle: http.HttpRequest): void => handle.destroy());
  }
}
```

Use an internal factory constructor argument for unit tests while keeping `http.createHttp()` as the default.

- [ ] **Step 4: Run GREEN and commit**

Run Hypium. Expected: all tests pass.

```powershell
git add entry/src/main/ets/services/ai/RemoteTextTranslationRunner.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat: add HarmonyOS translation HTTP adapter"
```

---

### Task 3: Switch production factory configuration to remote translation

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/config/TextTranslationConfig.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/hms/translation_proxy.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `RawfileContentReader`, `HarmonyTranslationHttpClient`, `RemoteTextTranslationRunner`.
- Produces: validated public proxy configuration and production `TextTranslationService` with runtime source `remote`.

- [ ] **Step 1: Add failing config and factory tests**

Use a fake rawfile reader containing:

```json
{"baseUrl":"https://translate.example.test"}
```

Assert `loadTextTranslationConfig()` trims a trailing slash, rejects `http://`, rejects credentials in the URL, and rejects missing/empty configuration. Assert `createHarmonyTextTranslationService()` with no injected runner uses a remote runner; an explicitly injected `LocalTextTranslationRunner` remains possible for tests/development.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: failures because the config loader and remote default are absent.

- [ ] **Step 3: Implement strict public configuration**

Create the rawfile with the deployment URL used by the current environment. The checked-in example value is non-secret and must be replaced during deployment through the same file:

```json
{"baseUrl":"https://translation-proxy.invalid"}
```

`TextTranslationConfig.ets` exports:

```ts
export const textTranslationConfigRawfilePath = 'hms/translation_proxy.json';

export interface TextTranslationConfig {
  readonly baseUrl: string;
}

export async function loadTextTranslationConfig(
  reader: RawfileContentReader
): Promise<TextTranslationConfig>;
```

Parse UTF-8 JSON, require `https://`, no username/password, no query/fragment, and remove trailing `/`. Treat the `.invalid` hostname as `AUTH_MISCONFIGURED` at request time so a development build fails honestly rather than using the dictionary.

- [ ] **Step 4: Wire the remote runner in the existing factory**

In `createHarmonyTextTranslationService()` keep injected runners first. Otherwise load config and construct:

```ts
new RemoteTextTranslationRunner({
  baseUrl: config.baseUrl,
  httpClient: new HarmonyTranslationHttpClient(),
  requestIdFactory: createTranslationRequestId,
  timeoutMs: 15000
})
```

Use a request ID composed only of timestamp and an incrementing process counter; no new UUID dependency is required.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/common/config/TextTranslationConfig.ets entry/src/main/resources/rawfile/hms/translation_proxy.json entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat: use remote translation in production"
```

Expected: all tests pass and an unconfigured deployment reports configuration failure, never offline success.

---

### Task 4: Propagate cancellation and stable user-facing failures

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TextRecognitionService.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/storage/OnlineTranslationConsentService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/privacy.html`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: optional runner `stop()`, existing page `RuntimeAiServiceSession.invalidate()` calls, translation error codes.
- Produces: actual transport cancellation and distinct timeout/network/rate-limit/configuration messages.

- [ ] **Step 1: Write failing lifecycle tests**

Add a fake translation runner whose `stop()` increments a counter. Assert:

- `TextTranslationService.stop()` calls it once;
- `DefaultAiService.stop()` calls the translation service;
- `RuntimeAiServiceSession.invalidate()` stops the cached service;
- changing route stops the previous service before caching the next one;
- a rejected creator is not cached;
- OCR success followed by remote failure remains `TEXT_TRANSLATION_FAILED`, not OCR success.
- a translation run without recorded consent shows disclosure before any HTTP call; accepting records consent and continues once; declining performs no request.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: lifecycle assertions fail because the stop chain ends at the session.

- [ ] **Step 3: Add the stop chain and error mapping**

Add idempotent `stop()` methods to `TextTranslationService` and `DefaultAiService`. Update `RuntimeAiServiceSession.invalidate()` to capture the cached service, clear the cache first, then call `service.stop()`.

Map error codes to new string keys:

```text
TIMEOUT -> feature_runtime_translation_timeout
NETWORK_UNAVAILABLE -> feature_runtime_translation_network_unavailable
RATE_LIMITED -> feature_runtime_translation_rate_limited
TEXT_TOO_LONG -> feature_runtime_translation_text_too_long
AUTH_MISCONFIGURED -> feature_runtime_translation_not_configured
BAD_RESPONSE / PROVIDER_UNAVAILABLE -> feature_runtime_translation_service_unavailable
```

Do not log source or translated text.

- [ ] **Step 4: Add one-time online text disclosure**

Follow the existing `PrivacyConsentService` preferences pattern. `OnlineTranslationConsentService` uses store name `mindspore_online_translation_consent`, key `translation_text_cloud_processing`, and exposes synchronous `hasConsent()`, `accept()`, and `withdraw()` methods. Before `FeatureRuntimePage` starts a `translateText` workflow, show an `AlertDialog` stating that entered or OCR-derived text is sent to the configured cloud translation service, is not written to application logs, and may incur network usage. Accept records consent and invokes the pending run once; cancel leaves the page ready with no request. Add the same disclosure to `privacy.html`.

- [ ] **Step 5: Run i18n guard, Hypium, and commit**

```powershell
.\scripts\check-i18n-strings.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/AiService.ets entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets entry/src/main/ets/services/ai/TextRecognitionService.ets entry/src/main/ets/services/storage/OnlineTranslationConsentService.ets entry/src/main/ets/pages/FeatureRuntimePage.ets entry/src/main/ets/common/i18n/AppStrings.ets entry/src/main/resources/base/element/string.json entry/src/main/resources/en_US/element/string.json entry/src/main/resources/zh_CN/element/string.json entry/src/main/resources/rawfile/privacy.html entry/src/test/LocalUnit.test.ets
git commit -m "fix: cancel stale translation requests"
```

Expected: guard and tests pass.

---

### Task 5: Build the credential-safe Huawei Cloud proxy

**Files:**
- Create: `translation-proxy/package.json`
- Create: `translation-proxy/.env.example`
- Create: `translation-proxy/src/huaweiCloudTranslator.mjs`
- Create: `translation-proxy/src/server.mjs`
- Create: `translation-proxy/test/server.test.mjs`
- Create: `translation-proxy/README.md`

**Interfaces:**
- Consumes: Huawei Cloud `POST /v1/{project_id}/machine-translation/text-translation` with `X-Auth-Token`.
- Produces: project-owned `POST /v1/translate` and `GET /healthz`.

- [ ] **Step 1: Create the no-dependency Node test package and failing tests**

Use this package manifest:

```json
{
  "name": "mindspore-inhand-translation-proxy",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node src/server.mjs",
    "test": "node --test"
  },
  "engines": { "node": ">=20" }
}
```

With `node:test`, start the server on port `0` and inject a fake provider. Test health, invalid JSON, empty/2,001-character text, unsupported target, normalized successful response, provider 401→`AUTH_MISCONFIGURED`, provider 429→`RATE_LIMITED`, provider 5xx→`PROVIDER_UNAVAILABLE`, and that returned errors contain no upstream body or token.

- [ ] **Step 2: Run RED**

```powershell
Set-Location ..\translation-proxy
npm test
```

Expected: module-not-found failure because server files do not exist.

- [ ] **Step 3: Implement the provider adapter**

`createHuaweiCloudTranslator(env, fetchImpl = fetch)` requires exactly:

```text
HWCLOUD_NLP_ENDPOINT=https://<region-endpoint>
HWCLOUD_PROJECT_ID=<project-id>
HWCLOUD_NLP_TOKEN=<server-side-token>
```

POST provider JSON:

```js
{
  text,
  from: targetLanguage === 'en' ? 'zh' : 'en',
  to: targetLanguage,
  scene: 'common'
}
```

Send `Content-Type: application/json` and `X-Auth-Token`. Accept only non-empty `translated_text`, `from`, and `to`; never expose the token or raw provider error.

- [ ] **Step 4: Implement the HTTP server**

Export `createServer({ translate, maxCharacters: 2000 })`. Read at most 32 KiB, parse JSON once, validate exact language values, return `application/json; charset=utf-8`, set `Cache-Control: no-store`, and use the incoming `X-Request-Id` or generate a process-local ID. Log only request ID, status, duration, and character count.

- [ ] **Step 5: Run GREEN and commit**

```powershell
npm test
git add package.json .env.example src test README.md
git commit -m "feat: add secure translation proxy"
```

Expected: all `node:test` cases pass.

---

### Task 6: Add credential and configuration guards

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-translation-secrets.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: application source/resources and built HAP.
- Produces: build-stopping checks for provider secrets and honest platform documentation.

- [ ] **Step 1: Write the guard and its self-test fixture behavior**

The script scans tracked ArkTS/resources plus the expanded HAP file list for `HWCLOUD_NLP_TOKEN`, `HWCLOUD_ACCESS_KEY`, `HWCLOUD_SECRET_KEY`, `X-Auth-Token`, and common AK/SK assignment patterns. It permits those names only in `translation-proxy/.env.example` where values are descriptive angle-bracket examples. It exits nonzero and prints the file path, never the matching secret value.

- [ ] **Step 2: Attach the guard to the build before assembly**

Add:

```powershell
& (Join-Path $PSScriptRoot 'check-translation-secrets.ps1')
```

before `ensure-mindspore-models.ps1` in `build-hap.ps1`. Add a Hypium source assertion that production factory no longer contains `new LocalTextTranslationRunner()` as its default branch.

- [ ] **Step 3: Document the exact external boundary**

Update the platform differences document to state: ArkTS remote runner and OCR chaining are implemented; the checked-in `.invalid` endpoint intentionally reports not configured; true online completion requires an HTTPS proxy deployment and active Huawei Cloud NLP credentials; Android's embedded API key was not copied.

- [ ] **Step 4: Run guards and commit**

```powershell
.\scripts\check-translation-secrets.ps1
.\scripts\check-text-translation-input-mode.ps1
.\scripts\check-text-translation-input-parity.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add scripts/check-translation-secrets.ps1 scripts/build-hap.ps1 entry/src/test/LocalUnit.test.ets ..\docs\harmonyos-platform-differences.md
git commit -m "test: guard remote translation credentials"
```

Expected: every command succeeds.

---

### Task 7: Deploy, integrate, and verify arbitrary text end to end

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/hms/translation_proxy.json`
- Modify: `translation-proxy/README.md`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: deployed HTTPS URL and server-side Huawei Cloud environment variables.
- Produces: reproducible online translation evidence for direct text and OCR paths.

- [ ] **Step 1: Verify the proxy against Huawei Cloud**

Set the three server environment variables without writing them to disk, start the proxy, and request one sentence in each direction:

```powershell
$env:HWCLOUD_NLP_ENDPOINT='https://nlp-ext.cn-north-4.myhuaweicloud.com'
$env:HWCLOUD_PROJECT_ID=$env:MIH_HWCLOUD_PROJECT_ID
$env:HWCLOUD_NLP_TOKEN=$env:MIH_HWCLOUD_NLP_TOKEN
npm start
```

From a second shell call `/healthz` and `/v1/translate`. Expected: HTTP 200, non-empty `translatedText`, source/target `zh/en` and `en/zh`, and no credential in output.

- [ ] **Step 2: Configure the application deployment URL**

Replace only `baseUrl` in `translation_proxy.json` with the deployed HTTPS origin. Run the secret guard immediately. Expected: it passes because the URL is public configuration.

- [ ] **Step 3: Run all host verification**

```powershell
Set-Location ..\Mindspore_inhand_HarmonyOS
& 'C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat' install
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
Get-FileHash .\entry\build\default\outputs\default\entry-default-unsigned.hap -Algorithm SHA256
```

Expected: dependencies resolve, Hypium reports zero failures/errors, guards pass, `BUILD SUCCESSFUL`, whitespace check passes, and a HAP hash is recorded.

- [ ] **Step 4: Run signed-device acceptance**

Install a signed HAP on an API 24 HarmonyOS phone/emulator. Verify 20 unseen Chinese and 20 unseen English sentences, then one photo OCR and one camera OCR input in each direction. Exit the page during a slow request and confirm no stale result appears. Confirm the displayed runtime source is remote and the result can be copied.

- [ ] **Step 5: Commit deployment-safe documentation**

Do not commit credentials or environment-specific private URLs. Commit only the production public URL if the deployment is intended to be shared, plus the verified commands and limitations.

```powershell
git add entry/src/main/resources/rawfile/hms/translation_proxy.json ..\translation-proxy\README.md ..\docs\harmonyos-platform-differences.md
git commit -m "docs: record online translation verification"
```
