# Runtime Reliability And Honest Capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make live AI execution reuse model sessions, release native visual resources, validate the fixed Custom Model tensor contract, and report unavailable/limited capabilities honestly while repairing corrupted retained functionality.

**Architecture:** Keep the shared workflow/page design and extract only two repeated lifecycle responsibilities: `RuntimeAiServiceSession` and `RuntimePixelMapOwner`. Apply capability and data-quality fixes at their shared service/factory boundaries so still and live callers behave consistently.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, MindSpore Lite Kit, CoreVision Kit, ArkUI, Hypium, Hvigor, PowerShell build guards.

## Global Constraints

- Preserve every current route, workflow, and Android-default visibility decision.
- Do not add an unlicensed gesture model, credentials, cloud endpoint, or undocumented HMS call.
- Gesture remains visible but must explicitly report runner unavailable until an authorized runner is injected.
- Offline dictionary translation must identify itself as limited; injected translation runners keep normal messages.
- Custom Model accepts exactly one NHWC float32 input shaped `[1, 224, 224, 3]`.
- A stable cached model path must invalidate the page AI session after a successful replacement.
- Every owned or stale `PixelMap` must be released at most once.
- Do not split the shared page into per-feature pages or add Android-inexistent result sharing.

---

### Task 1: Page-Scoped AI Service Session

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `FeatureWorkflow`, `DefaultAiService`, and the existing `cachedRuntimeAiServiceForHarmonyResourceManager` factory.
- Produces: `RuntimeAiServiceSession.getOrCreate(workflow, creator)` and `invalidate()`.

- [ ] **Step 1: Write failing session lifecycle tests**

Add tests proving that two `getOrCreate` calls for one route invoke the creator once, `invalidate()` causes a second creation, a different route causes a second creation, and a rejected creator is retried instead of remaining cached.

```ts
const session = new RuntimeAiServiceSession();
let creates = 0;
const first = await session.getOrCreate(workflow, async () => {
  creates++;
  return new DefaultAiService();
});
const second = await session.getOrCreate(workflow, async () => {
  creates++;
  return new DefaultAiService();
});
expect(first === second).assertTrue();
expect(creates).assertEqual(1);
```

- [ ] **Step 2: Run RED verification**

Run `hvigorw.bat test --no-daemon` and confirm the new tests fail because `RuntimeAiServiceSession` does not exist.

- [ ] **Step 3: Implement the minimal session owner**

```ts
export type RuntimeAiServiceCreator = () => Promise<DefaultAiService>;

export class RuntimeAiServiceSession {
  private routeName: string = '';
  private servicePromise: Promise<DefaultAiService> | undefined = undefined;

  async getOrCreate(workflow: FeatureWorkflow, creator: RuntimeAiServiceCreator): Promise<DefaultAiService> {
    if (this.servicePromise === undefined || this.routeName !== workflow.routeName) {
      this.routeName = workflow.routeName;
      const created = creator();
      this.servicePromise = created;
      try {
        return await created;
      } catch (error) {
        if (this.servicePromise === created) {
          this.invalidate();
        }
        throw error;
      }
    }
    return await this.servicePromise;
  }

  invalidate(): void {
    this.routeName = '';
    this.servicePromise = undefined;
  }
}
```

Use it in `runWorkflowAsync`. Invalidate on `aboutToDisappear` and immediately after a successful model-cache result before applying the new stable URI.

- [ ] **Step 4: Run GREEN verification and commit**

Run the full Hypium suite, confirm zero failures, then commit `fix: reuse runtime ai service sessions`.

---

### Task 2: PixelMap Ownership And Stale Result Release

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/RuntimePixelMapOwner.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: objects implementing `release(): Promise<void>`.
- Produces: `beginReplacement()`, `accept(requestId, value)`, `isCurrent(requestId)`, `clear()`, and `current()`.

- [ ] **Step 1: Write failing ownership tests**

Use a fake releasable object with a `releaseCount`. Assert replace releases the previous value once, clear releases the current value once, stale acceptance returns false and releases the stale value, and release rejection does not escape.

- [ ] **Step 2: Run RED verification**

Run the Hypium suite and confirm failure because `RuntimePixelMapOwner` is missing.

- [ ] **Step 3: Implement the owner and wire both image slots**

```ts
export interface RuntimeReleasablePixelMap {
  release(): Promise<void>;
}

export class RuntimePixelMapOwner<T extends RuntimeReleasablePixelMap> {
  private generation: number = 0;
  private value: T | undefined = undefined;

  beginReplacement(): number { return ++this.generation; }
  isCurrent(requestId: number): boolean { return requestId === this.generation; }

  accept(requestId: number, next: T): boolean {
    if (!this.isCurrent(requestId)) {
      this.release(next);
      return false;
    }
    const previous = this.value;
    this.value = next;
    if (previous !== undefined && previous !== next) this.release(previous);
    return true;
  }

  current(): T | undefined { return this.value; }

  clear(): void {
    this.generation++;
    const previous = this.value;
    this.value = undefined;
    if (previous !== undefined) this.release(previous);
  }

  private release(value: T): void { value.release().catch(() => {}); }
}
```

Give `FeatureRuntimePage` one owner per PixelMap state. `clearVisualResults` and `aboutToDisappear` clear owners. Async PixelMap creation captures a request id; accepted values update ArkUI state, stale values are released without updating state.

- [ ] **Step 4: Run GREEN verification and commit**

Run the full Hypium suite and commit `fix: release runtime pixelmap results`.

---

### Task 3: Custom Model Tensor Contract Validation

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/picker/ModelFileCacheService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/CustomModelService.ets`
- Modify: `docs/harmonyos-platform-differences.md`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: MindSpore `MSTensor.shape`, `dtype`, `format`, `elementNum`, and `dataSize`.
- Produces: `ModelFileTensorMetadata` and `customModelInputContractCompatible(inputs)`.

- [ ] **Step 1: Write failing contract tests**

Assert that one `[1,224,224,3]`, float32, NHWC input with 150,528 elements and 602,112 bytes is accepted. Assert rejection for multiple inputs, NCHW/wrong shape, non-float32, wrong element count, or wrong byte size. Assert non-Custom routes still accept any model that loads.

- [ ] **Step 2: Run RED verification**

Run the Hypium suite and confirm the contract tests fail because metadata is ignored.

- [ ] **Step 3: Return metadata from the loader and enforce the contract**

```ts
export interface ModelFileTensorMetadata {
  readonly shape: Array<number>;
  readonly dtype: mindSporeLite.DataType;
  readonly format: mindSporeLite.Format;
  readonly elementNum: number;
  readonly dataSize: number;
}
```

`MindSporeLiteModelCompatibilityLoader.loadModel` loads the model and maps `getInputs()` into metadata. `BasicModelFileCompatibilityChecker` applies the exact contract only to `AppRoute.CUSTOM_MODEL` + `modelFile`; all other routes retain loadability validation. Before decoding the first output, `CustomModelSelectedFileRunner` requires `NUMBER_TYPE_FLOAT32` and non-empty data.

- [ ] **Step 4: Update documentation, run GREEN verification, and commit**

Document the exact supported input/output protocol. Run the full Hypium suite and commit `fix: validate custom model tensor contract`.

---

### Task 4: Honest Gesture And Offline Translation Results

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TextRecognitionService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`
- Modify: `docs/harmonyos-platform-differences.md`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: existing injected `GestureRunner`/`TextTranslationRunner` boundaries.
- Produces: `TextTranslationRuntimeSource = 'offlineDictionary'` and two localized offline status keys.

- [ ] **Step 1: Write failing capability-message tests**

Assert the production Gesture workflow returns `feature_runtime_gesture_runner_unavailable`. Assert a known local phrase returns `feature_runtime_text_translation_offline_done`, an unknown local phrase returns `feature_runtime_text_translation_offline_unsupported`, and an injected runner still returns the normal done/failed keys.

- [ ] **Step 2: Run RED verification**

Run the Hypium suite and confirm the new message assertions fail.

- [ ] **Step 3: Remove the disabled production gesture service and mark local translations**

The production cached factory returns `new DefaultAiService()` for `detectGesture`; direct `gestureRunner` injection remains supported by `createRuntimeAiServiceForWorkflow`. Add `runtimeSource?: 'offlineDictionary'` to `TextTranslationResult`; only `LocalTextTranslationRunner` sets it. `AiService` selects offline message keys only when that marker is present.

Add localized strings:

```text
zh: 离线示例翻译已完成。 / 当前离线词典不支持这段文本。
en: Offline demo translation completed. / The offline dictionary does not support this text.
```

- [ ] **Step 4: Run guards/tests, update docs, and commit**

Run the full Hypium suite and static translation-input guard. Commit `fix: report limited ai capabilities honestly`.

---

### Task 5: Retained Feature Data Repair And Dead Branch Cleanup

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/SceneDetectionService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/DancePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/dance/DancePageService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/picker/PickerService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `docs/harmonyos-platform-differences.md`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: the existing 103 Android-style scene label identifiers.
- Produces: 103 readable Chinese labels and no `liveCamera` input kind.

- [ ] **Step 1: Write failing data-integrity tests**

Assert English/Chinese scene label counts are equal, representative mappings are readable (`stage -> 舞台`, `beach -> 沙滩`, `other -> 其他`), and no Chinese label contains `?`, Unicode replacement characters, or known mojibake markers such as `鍦`, `绠`, or `鐨`. Update input tests to assert Text Translation has only text/camera/photo and no `liveCamera` action.

- [ ] **Step 2: Run RED verification**

Run the Hypium suite and confirm failures on current corrupted labels/dead input behavior.

- [ ] **Step 3: Repair labels and delete unreachable branches**

Replace every Chinese scene label with a readable one aligned by index. Remove `liveCamera` from `FeatureInputKind`, picker dispatch, translation special-case runtime mode/text handling, and preview-failure restoration. Use normal `camera` for live workflow preview state. Remove the permanently hidden Dance template-demo button branch and page method; keep the pure scoring fixture only where tests use it.

- [ ] **Step 4: Full verification and commit**

Run `ohpm install`, the full Hypium suite, `scripts/build-hap.ps1`, `git diff --check`, and the label/translation static guards. Commit `fix: repair retained feature data and dead paths`.

---

### Task 6: Whole-Branch Review And Runtime Attempt

**Files:**
- Modify only if final review finds a concrete defect.

- [ ] **Step 1: Dispatch a whole-branch code review**

Review from merge base `7ba5020` to HEAD against the full user objective and both design specs. Fix every Critical/Important finding through a single reviewed fix wave.

- [ ] **Step 2: Run final host verification**

Run dependency installation, all Hypium tests, all static/model guards, and HAP assembly. Record test totals, artifact size, SHA-256, branch status, and signing state.

- [ ] **Step 3: Attempt emulator install and launch**

Start the installed Pura 90 API 24 emulator through DevEco Studio. If it reaches `hdc`, generate/use a local debug signing configuration without committing private material, install the HAP, launch `EntryAbility`, capture `hilog`, and smoke-test startup/privacy/main navigation. If DevEco cannot start the emulator or signing requires unavailable account material, record exact evidence and keep the goal active.
