# Android Primary Run Action Parity Implementation Plan

> **For Codex:** Execute with subagent-driven development and TDD. Keep the
> change limited to the route policy, its complete matrix test, and parity
> documentation.

**Goal:** Show the shared primary Run action only on Android routes that expose
a manual Detect, Translate, or Execute control.

**Architecture:** Keep `FeatureRuntimePage`'s existing conditional builder.
Replace the broad non-live policy in `FeatureWorkflowCatalog` with a three-route
allowlist. Do not touch automatic input-ready execution.

**Tech stack:** ArkTS, Hypium, PowerShell HAP acceptance.

---

## Task 1: Match Android's manual-action route matrix

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `docs/harmonyos-platform-differences.md`

### Step 1: Write the failing complete route contract

Replace the partial primary-action assertions with a test covering all 16
workflow routes and `undefined`:

- `true`: `POSENET`, `TEXT_TRANSLATION`, `CUSTOM_MODEL`
- `false`: `LIVE_SKELETON`, `SEGMENTATION_STILL`, `SEGMENTATION_LIVE`,
  `PORTRAIT_SEGMENTATION`, `IMAGE_CAMERA`, `GESTURE_STILL`, `GESTURE_LIVE`,
  `SCENE_STILL`, `SCENE_LIVE`, `TEXT_RECOGNITION`, `OBJECT_PHOTO`,
  `OBJECT_CAMERA`, `STYLE_TRANSFER`
- `false`: `undefined`

Run the complete Hypium suite and capture RED from at least one currently
incorrect automatic route, such as Style Transfer or Gesture Still.

### Step 2: Implement the minimal allowlist

Change only `shouldShowPrimaryRunAction()` so it returns `true` for PoseNet,
Text Translation, and Custom Model. Do not change:

- `autoStartInputKindForWorkflow()`
- `shouldAutoRunWorkflowAfterInputReady()`
- `shouldAutoRunStyleTransferAfterStyleReady()`
- page input handlers or AI services

Run the complete Hypium suite and require no Hypium error output as well as a
successful build.

### Step 3: Correct parity documentation

Update Runtime UI Polish to explain that camera-only live workflows and
automatic still/style workflows omit the generic Run button. Clarify Runtime
Execution Guard wording so it covers both remaining manual actions and
automatic triggers.

### Step 4: Verify the integrated result

From `Mindspore_inhand_HarmonyOS` run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Then run `git diff --check`, inspect the exact diff, commit as
`fix: match android primary run actions`, and request independent task and
whole-branch reviews before merging to `master`.

Device tests are compiled into ohosTest but are not executed in this scope.
