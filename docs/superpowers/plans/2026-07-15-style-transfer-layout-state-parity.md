# Style Transfer Android Layout and State Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the reachable HarmonyOS Style Transfer generic runtime form with the Android page hierarchy while preserving the existing local MindSpore Lite, picker, atomic model-cache, secure-save, stale-request, and `PixelMap` ownership implementations.

**Architecture:** Keep `FeatureRuntimePage` as the sole controller. Add exact, pure route/state policies in `FeatureWorkflowCatalog`, route Style Transfer to one dedicated builder before the generic fallback, and adapt only its view-state edges. Preserve the last styled `PixelMap` independently from the original-preview flag so content replacement, Recovery, failed inference, and Save match Android's separate `originBitmap`/`resultBitmap` behavior.

**Tech Stack:** ArkTS, ArkUI, Hypium, HarmonyOS API 24, MindSpore Lite, PowerShell 5+, Hvigor/DevEco Studio.

## Global Constraints

- No new route, dependency, model, preprocessor, decoder, cache service, picker service, save service, or string resource.
- Do not duplicate inference/session/picker/cache/save logic in a separate page.
- Preserve both cached model URIs after one compatible model slot is replaced; discard only the active inference session.
- Cancelled, failed, incompatible, undefined, or stale model cache work must preserve the current page and last stable cache.
- Content/camera/style picks preserve the last styled Save target. Content/camera picks show the new original; style picks keep the current preview until success.
- Run start, failed AI result, permission failure, and thrown run must not clear the Style Transfer preview or Save target.
- Recovery and secure Save are disabled and handler-guarded while inference runs.
- Style Transfer save feedback is Toast-based without adding Toast behavior to the shared segmentation save path.
- Real-device validation remains deferred. Build/test/package evidence is not a claim about device rendering, picker/camera feel, secure SaveButton presentation, accuracy, latency, memory, or lifecycle stability.

---

## File Structure

- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`: exact Style Transfer layout, Toast, reset, preview-switching, and result-preservation policies.
- `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: policy contracts and negative sibling-route/input/result cases.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`: dedicated builder plus route-scoped state, feedback, model-reset, Recovery, and Save edges.
- `Mindspore_inhand_HarmonyOS/scripts/check-style-transfer-layout-parity.ps1`: comment/string/template-resistant production source guard.
- `Mindspore_inhand_HarmonyOS/scripts/test-style-transfer-layout-parity-guard.ps1`: valid fixture plus mutation negatives.
- `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`: invoke production Style Transfer guard before assembly.
- `docs/harmonyos-platform-differences.md`: reduce the remaining generic-fallback inventory from three routes to two.

### Task 1: Define Style Transfer State Policies With Hypium

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

**Interfaces:**
- Produces: `usesAndroidStyleTransferLayout(workflow)`.
- Produces: `styleTransferResultToastKey(workflow, resultOk)`.
- Produces: `styleTransferModelCacheToastKey(workflow, inputKind, messageKey)`.
- Produces: `shouldResetStyleTransferPageAfterModelCacheResult(workflow, inputKind, resultOk)`.
- Produces: `shouldShowStyleOriginalAfterInputReady(workflow, inputKind)`.
- Extends: `shouldPreserveRuntimeResultAfterInputReady`, `shouldClearRuntimeResultAtWorkflowStart`, and `shouldPreserveRuntimeVisualResultOnAiResult` without changing existing sibling behavior.

- [ ] **Step 1: Add exact failing policy tests**

Import the five new functions. Add tests requiring:

```typescript
expect(usesAndroidStyleTransferLayout(workflowForRoute(AppRoute.STYLE_TRANSFER.name))).assertTrue();
expect(usesAndroidStyleTransferLayout(workflowForRoute(AppRoute.OBJECT_PHOTO.name))).assertFalse();
expect(usesAndroidStyleTransferLayout(undefined)).assertFalse();

expect(styleTransferResultToastKey(styleWorkflow, false))
  .assertEqual('feature_runtime_style_transfer_failed');
expect(styleTransferResultToastKey(styleWorkflow, true)).assertUndefined();
expect(styleTransferResultToastKey(objectWorkflow, false)).assertUndefined();
```

For `styleTransferModelCacheToastKey`, require the supplied success/failure key only for `stylePredictModelFile` and `styleTransferModelFile` on the exact route. Require `undefined` for photo/style image/modelFile/sibling routes.

For `shouldResetStyleTransferPageAfterModelCacheResult`, require true only for successful predict/transfer model results and false for failed results, non-model kinds, siblings, and undefined workflows.

Require result preservation after Style Transfer `contentImage`, `camera`, and `styleImage`, while the existing Custom Model and portrait cases remain true and a Style Transfer model input remains false. Require original-preview switching after `contentImage` and `camera`, but not after `styleImage` or either model input.

Require `shouldClearRuntimeResultAtWorkflowStart(styleWorkflow)` false. Require `shouldPreserveRuntimeVisualResultOnAiResult(styleWorkflow, false, '')` true and the same for a failed `styleTransfer` result. Preserve the existing successful portrait segmentation positive and keep unrelated failed/successful route negatives.

- [ ] **Step 2: Run host tests and verify RED**

From `Mindspore_inhand_HarmonyOS`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;'+$env:PATH
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
```

Expected: ArkTS compilation fails because the new policy exports do not exist.

- [ ] **Step 3: Implement the minimal pure policies**

Use exact `workflow?.routeName === AppRoute.STYLE_TRANSFER.name` checks. Keep the preservation functions as small boolean compositions. Do not place page state or services in the catalog.

- [ ] **Step 4: Run host tests and verify GREEN**

Run the same Hvigor command. Expected: every Hypium case passes, with no Failure, Error, or Ignore count.

- [ ] **Step 5: Commit Task 1**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets
git diff --cached --check
git commit -m "test: define style transfer android state policy"
```

### Task 2: Define The Dedicated Layout Guard Before Production UI

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-style-transfer-layout-parity.ps1`
- Create: `Mindspore_inhand_HarmonyOS/scripts/test-style-transfer-layout-parity-guard.ps1`

**Interfaces:**
- Produces: `check-style-transfer-layout-parity.ps1 [-SourceRoot <Harmony project root>]`.
- Consumes: the catalog, runtime page, and `build-hap.ps1` as UTF-8 source.
- Must fail closed when a required builder/call-site section cannot be bounded exactly.

- [ ] **Step 1: Create the production guard contract**

Reuse the proven comment/string/template-raw stripping and exact-code-line helpers from the Object Photo guard, changing diagnostics to Style Transfer. Require:

- selector contains exactly `AppRoute.STYLE_TRANSFER.name` once;
- a bounded `styleTransferAndroidLayout()` builder selected before the generic fallback;
- full-height white `Stack`, `runtimeActionToolbar(true)`, 1vp divider, 265vp gray preview, centered 256vp image, 80vp loading indicator;
- styled `PixelMap`, original URI, placeholder icon/text, and `workflowRunning` branches;
- first 37vp row in Album/Camera/Recovery/Save order and second 37vp predict/transfer-model row;
- four-column grid, 20vp outer horizontal margin, 10vp column/row gaps, remaining-height weight, and automatic vertical scrollbar;
- Recovery and Save rendered disabled while running and handler-side running guards;
- full-page `runtimePermissionRecoveryOverlay()`;
- exact result-failure/throw Toast calls, cache stale gate before apply/reset/Toast, route-scoped save Toast wrapper, and denied secure-save Toast;
- absence inside the dedicated builder of generic summary, Inputs, Permissions, status/result, debug, file-preview, styled-result, and generic Run markers;
- exact call from `build-hap.ps1`.

- [ ] **Step 2: Create mutation fixtures**

Copy only the three guarded source files into a verified temporary directory. Require the current repository to fail while the builder is absent. After production is implemented, the fixture suite must require a valid copy to pass and reject at least these mutations individually:

- selector changed to a sibling route or moved into a quoted decoy;
- build selector changed to a quoted/template/comment decoy;
- required toolbar/preview/action/grid/overlay line replaced by a literal decoy;
- Recovery/Save running guard removed;
- save Toast moved into the shared segmentation path;
- cache Toast/reset moved before the stale request gate;
- result/throw failure Toast removed;
- executable generic Inputs, Permissions, status, result, debug, file-preview, or Run marker injected into the dedicated builder.

Temporary cleanup must resolve the absolute path, verify it is inside the OS temp parent, then delete it in one PowerShell/.NET path flow.

- [ ] **Step 3: Run production guard and verify RED**

```powershell
& .\scripts\check-style-transfer-layout-parity.ps1
```

Expected: FAIL because `styleTransferAndroidLayout()` is absent. The test fixture script may also fail until the valid production baseline exists; do not wire either script into `build-hap.ps1` yet.

- [ ] **Step 4: Commit the RED guard contract**

```powershell
git add Mindspore_inhand_HarmonyOS/scripts/check-style-transfer-layout-parity.ps1 `
  Mindspore_inhand_HarmonyOS/scripts/test-style-transfer-layout-parity-guard.ps1
git diff --cached --check
git commit -m "test: define style transfer layout parity guard"
```

### Task 3: Implement Android Layout And Exact State Edges

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-style-transfer-layout-parity-guard.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Produces: `styleTransferAndroidLayout()` and route selection before generic fallback.
- Reuses: `prepareInput`, `runWorkflow`, `styleTransferPixelMapFromRgbaOutput`, `RuntimeAiServiceSession`, `RuntimeModelFileCacheService`, `ResultImageSaveService`, and the existing `PixelMapOwner`.
- Adds no new service or route.

- [ ] **Step 1: Wire route-scoped state preservation and feedback**

Import the Task 1 policies. In `applyPickResult`, preserve the styled result for content/camera/style picks and set `styleOriginalPreviewRecovered = true` only after a successful content/camera pick. Built-in style selection keeps the visible flag unchanged.

Do not clear visual results for Style Transfer at run start, permission failure, failed `AiRunResult`, thrown run, or failed styled-output replacement. Show `styleTransferResultToastKey` for both failed AI results and thrown runs. Successful styled `PixelMap` ownership replacement sets `styleOriginalPreviewRecovered = false` exactly as today.

- [ ] **Step 2: Apply atomic model-cache feedback and Android recreate semantics**

Only after `isInputPreparationRequestCurrent` succeeds and `cacheResult` is defined:

- apply the existing cache result;
- Toast the slot-specific cache message for Style Transfer;
- on a successful predict/transfer slot result, preserve both model URIs, invalidate the session, then clear `imageInputUri`, `contentImageUri`, `styleImageUri`, selected-input summary, styled owner/result, recovery flag, result rows/text, and restore `workflowInitialStatusKey(workflow)`;
- on cancel/failure/incompatible/undefined/stale work, preserve page/session/result and stable cache.

Keep the existing Custom Model Toast and Object Photo follow-up behavior unchanged.

- [ ] **Step 3: Add route-scoped Recovery and Save methods**

Guard Recovery before any state change when `workflowRunning`. If no original exists, set and Toast `feature_runtime_style_original_required`; otherwise switch to the original without destroying the styled Save target.

Add a Style-Transfer-only async Save wrapper around `saveResultPixelMapAsync`. It exits while running, awaits the existing service, and Toasts the resulting missing/success/failure `statusKey`. Its catch maps to and Toasts `feature_runtime_save_image_failed`. The dedicated secure SaveButton is always present, uses `.enabled(!this.workflowRunning)`, calls the wrapper only on `SUCCESS`, and immediately Toasts save-failed on security denial. Do not add Toasts to `resultImageSaveControl` or segmentation callers.

- [ ] **Step 4: Build the dedicated page**

Add a full-height white `Stack` with:

1. existing 56vp action toolbar and 1vp divider;
2. fixed 265vp gray preview containing a centered 256vp styled/original/placeholder branch and centered 80vp `LoadingProgress` while running;
3. a 37vp row ordered Album, Camera, Recovery, secure Save;
4. a 37vp row ordered Select Predict Model, Select Transfer Model;
5. existing Choose a Style title plus all 19 built-ins and custom tile in a four-column, 10vp-gap, 20vp-margin grid that uses remaining height and scrolls;
6. `runtimePermissionRecoveryOverlay()` as the final Stack child.

All non-save action buttons use the existing Android neutral button styling and `.enabled(!this.workflowRunning)`. Keep the existing picker and automatic style-run paths.

Add the exact Style Transfer selector branch immediately after the dedicated Object Photo branch and before Custom Model/generic fallback. Remove no sibling builder.

- [ ] **Step 5: Complete guard wiring and documentation**

Make the valid production fixture pass, retain every negative mutation, then call both the production guard and its fixture test from `build-hap.ps1` before assembly. Update `docs/harmonyos-platform-differences.md` so Style Transfer is described as a dedicated Android-shaped route and the remaining generic-fallback list contains only still image segmentation and still scene.

- [ ] **Step 6: Verify focused GREEN**

From `Mindspore_inhand_HarmonyOS`:

```powershell
& .\scripts\check-style-transfer-layout-parity.ps1
& .\scripts\test-style-transfer-layout-parity-guard.ps1
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
& .\scripts\build-hap.ps1
```

Expected: production guard passes, every mutation is rejected, all host tests pass, model/source preflight passes, HAP inspection passes, and Hvigor reports `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit Task 3**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets `
  Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1 `
  Mindspore_inhand_HarmonyOS/scripts/test-style-transfer-layout-parity-guard.ps1 `
  docs/harmonyos-platform-differences.md
git diff --cached --check
git commit -m "fix: match android style transfer layout"
```

### Task 4: Independent Review, Hardening, And Acceptance

**Files:**
- Modify only files justified by review findings.

- [ ] **Step 1: Request independent spec/code review**

Review against Android `activity_main_style.xml` and `StyleMainActivity.java`, the approved design, this plan, and the complete branch diff. Report Critical/Important/Minor counts and a clear Ready decision. The reviewer must check route exactness, state preservation, model-cache stale ordering, `PixelMap` ownership, secure Save behavior, permission recovery, small-screen grid reachability, i18n reuse, and sibling-route non-regression.

- [ ] **Step 2: Resolve findings with regression tests first**

For every accepted behavioral finding, add a failing Hypium or PowerShell mutation case, verify RED, apply the smallest fix, and verify GREEN. Commit review fixes separately, for example:

```powershell
git commit -m "test: harden style transfer layout guard"
```

- [ ] **Step 3: Run final worktree acceptance**

From the repository root and Harmony project:

```powershell
git diff --check
Set-Location .\Mindspore_inhand_HarmonyOS
& .\scripts\check-style-transfer-layout-parity.ps1
& .\scripts\test-style-transfer-layout-parity-guard.ps1
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
& .\scripts\build-ai-runtime-acceptance.ps1
```

Record exact Hypium pass/Failure/Error/Ignore counts and SHA-256 for both generated HAPs. Device suites are compiled/packaged only, not reported as executed.

- [ ] **Step 4: Merge and verify `master` independently**

Fast-forward the clean feature branch into `master`. On merged `master`, rerun fresh Hypium and `build-ai-runtime-acceptance.ps1`; do not rely on worktree artifacts. Require a clean tree after verification.

- [ ] **Step 5: Archive evidence and clean isolation**

Confirm the implementation commits are reachable from `master`, remove the feature worktree, delete its local branch, prune worktree metadata, and verify `git worktree list --porcelain` contains only the primary worktree. If normal removal hits Windows long paths after deregistration, verify the absolute target is inside repository `.worktrees`, then remove that exact target with the long-path-aware .NET filesystem flow.

The final handoff reports completed scope, exact verification evidence, the remaining two low-priority generic routes, and the explicit absence of device validation.
