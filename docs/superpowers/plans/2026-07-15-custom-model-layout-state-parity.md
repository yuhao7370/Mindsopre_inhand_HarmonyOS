# Custom Model Layout and State Android Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic HarmonyOS Custom Model screen with Android's dedicated page and visible state behavior while preserving the existing real MindSpore Lite cache, compatibility check, preprocessing, and inference runtime.

**Architecture:** Add small Custom Model-only pure policies in `FeatureWorkflowCatalog`, consume them from one dedicated `FeatureRuntimePage` builder, and leave the shared picker, model cache, AI service, request-generation, help, and permission-recovery implementations intact. Execute uses the existing runtime only after an image/model/running preflight; the workflow has no broad execute-time permissions because its catalog `requiredPermissions` is empty.

**Tech Stack:** ArkTS, ArkUI, Hypium, PowerShell, Hvigor.

## Global constraints

- `AppRoute.CUSTOM_MODEL` is the only route that may use the new selector, preflight, output, cache-restore, or model-picker Toast policies.
- Do not modify the fixed `[1, 224, 224, 3]` NHWC float32 RGB `[0, 1]` input contract, output decoding, model cache format, `.ms` compatibility validation, or AI service selection.
- Keep the existing system model/photo/camera pickers. Cancellation stays silent and stale requests cannot show late Toasts.
- Custom Model `requiredPermissions` becomes `[]`; every sibling workflow keeps its current permission list and request path.
- Only terminal success and localized terminal failure text persist across later successful model/photo/camera picks. Permission denial, preflight feedback, picker metadata, and cancellation do not become persistent output.
- Output priority is running, permission denial, non-empty terminal `resultText`, then placeholder.
- Input buttons are disabled while running. Execute remains clickable so its preflight can show the already-running Toast.
- Custom Model does not restore a cached model on page creation; sibling routes retain cache restoration.
- Real-device picker, camera, image-fit, progress animation, Toast, and inference-performance checks remain deferred.

---

### Task 1: Define the Custom Model-only state and localization contract

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`

**Interfaces:**

- Produce `usesAndroidCustomModelLayout(workflow)` scoped exactly to `AppRoute.CUSTOM_MODEL`.
- Produce `customModelExecutePreflightToastKey(workflow, imageReady, modelReady, workflowRunning)` with image, model, running priority.
- Produce a Custom Model output fallback-key resolver with running, permission denial, terminal text, placeholder priority.
- Produce `shouldRestoreCachedModelFileInputs(workflow)` and a model-cache Toast mapping policy.
- Extend existing result-preservation and input-change policies only for the Custom Model route.
- Add the four localization keys named in the approved design.

- [ ] **Step 1: Add failing Hypium policy tests**

Add tests that prove:

1. the layout selector is true only for Custom Model across all 16 workflows and false for `undefined`;
2. Custom Model has `requiredPermissions=[]`, while representative camera/media sibling workflows retain their existing permission arrays;
3. Execute preflight returns image-required before model-required before already-running and returns `undefined` when ready or for another route;
4. the output fallback resolver returns running, permission-denied, `undefined` for non-empty terminal text, then placeholder, and does not affect another route;
5. model/photo/camera input-ready paths preserve terminal output only for Custom Model while existing portrait-background behavior remains unchanged;
6. running blocks Custom Model's three input changes, but not its Execute path or unrelated workflows;
7. cache restore is false only for Custom Model and true for existing model-backed sibling routes;
8. model-cache success/failure Toast mapping is Custom Model-only and all four new string keys exist.

- [ ] **Step 2: Run Hypium and record RED**

From `Mindspore_inhand_HarmonyOS`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: ArkTS compilation fails because the new policy exports and localization keys do not exist.

- [ ] **Step 3: Implement the smallest route-scoped policies**

In `FeatureWorkflowCatalog.ets`:

- change only the Custom Model catalog entry to `requiredPermissions: []`;
- implement the selector and preflight in one bounded Custom Model section;
- make the output helper return a localized key for running, permission denial, or empty-output placeholder and `undefined` when `resultText` should render directly;
- make cache restoration false only for Custom Model;
- map current Custom Model cache success to `result.messageKey` and cache/compatibility failure to the same current localized failure key without inventing a new model status;
- extend `shouldPreserveRuntimeResultAfterInputReady()` for Custom Model `modelFile`, `photo`, and `camera`;
- extend `shouldAllowRuntimeInputChange()` so those Custom Model inputs are rejected while running, preserving existing Style Transfer behavior.

Do not add a new page, service, model abstraction, or permission-service bypass.

- [ ] **Step 4: Add exact approved localization resources**

Add these keys to the `AppStringKey` union, `appStringKeys`, `appString()` switch, and base/`zh_CN`/`en_US` resource JSON files using the exact values from the approved design:

- `feature_runtime_custom_model_execute`
- `feature_runtime_custom_model_running_output`
- `feature_runtime_custom_model_already_running`
- `feature_runtime_custom_model_failure_output`

- [ ] **Step 5: Run localization checks and Hypium to GREEN**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-i18n-strings.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
Get-Content .\entry\.test\default\intermediates\test\coverage_data\test_result.txt -Tail 1
```

Expected: i18n guard PASS and all Hypium tests pass with zero failure/error.

- [ ] **Step 6: Commit and request a task review**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json
git commit -m "test: define custom model android state policy"
```

The reviewer must verify route isolation, preflight priority, empty permissions, terminal-output preservation, sibling behavior, and localization completeness before Task 2 starts.

### Task 2: Build the dedicated Custom Model page and hardened guard

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-custom-model-layout-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**

- Consume every Task 1 policy.
- Produce `customModelAndroidLayout()`, a Custom Model Execute handler, and output-text/model-picker feedback helpers.
- Keep shared runtime/picker/cache/service methods as the only implementation of those capabilities.

- [ ] **Step 1: Create a failing structural guard**

Model the dependency-free guard after the existing PoseNet and static-Gesture parity guards. It must normalize line endings, extract bounded source sections, and assert:

- exact Custom Model selector and a dedicated build branch before the generic fallback;
- `runtimeActionToolbar(true)`, exactly one divider, and Model/Photo/Camera action order;
- each input button is 37vp, equally weighted, and disabled while running;
- the image preview is conditional on a non-empty image URI, has a 265vp gray container and centered 256vp image;
- an 80vp loading indicator exists only while running;
- Execute is 40vp with the approved margins, calls the Custom Model preflight handler, and is not `.enabled(this.runActionEnabled())` or otherwise disabled;
- the output panel uses its dedicated title, scroll, gray surface, and output resolver;
- generic summary/input/permission/model-preview/URI/status/result-row/debug/save surfaces are absent from the dedicated builder;
- cache restore is gated by the Task 1 policy;
- success and cache/compatibility failure Toast call sites occur only after the current-request check; cancellation has no Toast call;
- result failure and runtime exception store the localized terminal failure output; Custom Model permission denial does not store requested permission names;
- the Execute handler calls preflight before `runWorkflow()`;
- `build-hap.ps1` has one executable, uncommented invocation of this guard.

Run it and record RED because the dedicated builder/branch do not exist.

- [ ] **Step 2: Integrate the Custom Model state policies**

In `FeatureRuntimePage.ets`:

- gate `restoreCachedModelFileInputsIfNeeded()` before calling `cachedModelFileInputStateForRoute()`;
- on current model-cache success/failure, show the route-scoped Toast; preserve terminal output and the last valid model on failure;
- keep cancellation silent and retain the existing request-id checks;
- add a Custom Model Execute handler that asks the pure preflight for a Toast, returns without changing output on failure, and otherwise calls `runWorkflow()`;
- for Custom Model permission denial, keep `resultText` empty instead of copying `permission.requested`;
- for Custom Model AI failure or runtime exception, store `appString('feature_runtime_custom_model_failure_output')`; keep existing behavior for every sibling route;
- resolve the visible output by the approved priority, rendering terminal `resultText` directly only when the policy returns no fallback key.

- [ ] **Step 3: Add the dedicated Android-shaped builder**

Add `customModelAndroidLayout()` before the current generic fallback and select it with `usesAndroidCustomModelLayout()`.

The builder must contain, in order:

1. `runtimeActionToolbar(true)` and one 1vp divider;
2. a 14vp-top Model/Photo/Camera row using the existing route-specific labels;
3. no preview before image selection; otherwise a 265vp gray container with a centered 256vp `Image` and an 80vp `LoadingProgress` while running;
4. a full-width 40vp Execute button with 20vp side and 14vp top margins, always clickable;
5. a remaining-height white output panel with 20vp side/bottom margins, bold existing output title, and gray scrollable text surface;
6. the existing permission-recovery overlay.

Do not render generic cards or alter the real inference result formatter.

- [ ] **Step 4: Wire documentation and guard into builds**

Add one executable call to `check-custom-model-layout-parity.ps1` in `scripts/build-hap.ps1`. Update the Custom Model section of `docs/harmonyos-platform-differences.md` with the dedicated layout, explicit-pick lifecycle, execute-time empty permissions, real fixed-contract inference preservation, and deferred device checks.

- [ ] **Step 5: Harden the guard with mutation evidence**

Against temporary copies only, prove the guard fails for at least:

- a widened selector;
- reordered Photo/Camera actions;
- an always-visible empty preview;
- a disabled Execute button;
- a generic status or model-preview marker restored to the dedicated builder;
- a commented or removed build-script invocation.

Restore/discard every temporary mutation and rerun the real guard to PASS.

- [ ] **Step 6: Run focused and full verification**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-custom-model-layout-parity.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
git diff --check
git status --short
git diff --name-status HEAD
```

Expected: focused guard PASS, all Hypium tests PASS, main HAP and ohosTest HAP BUILD SUCCESSFUL, all payload/native/model checks PASS, no whitespace errors, and no AI service/model/native files changed.

- [ ] **Step 7: Commit and request task plus whole-branch reviews**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/scripts/check-custom-model-layout-parity.ps1 Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1 docs/harmonyos-platform-differences.md
git commit -m "fix: match android custom model layout"
```

Fix all Critical and Important findings and any focused guard weakness. Re-run the relevant tests after each fix. A fresh final reviewer must explicitly say whether the branch is ready to merge.

### Task 3: Integrate and clean up

- [ ] **Step 1: Fast-forward the reviewed branch into `master` when `master` has not moved; otherwise inspect intervening changes before a normal merge.**
- [ ] **Step 2: On merged `master`, rerun the Custom Model guard, Hypium, unified AI runtime acceptance, and `git diff --check`.**
- [ ] **Step 3: Remove the temporary worktree, prune worktree metadata, and delete the merged feature branch.**
- [ ] **Step 4: Confirm only the intended retained worktrees/branches remain and `master` is clean.**

Do not claim real-device behavior was verified.
