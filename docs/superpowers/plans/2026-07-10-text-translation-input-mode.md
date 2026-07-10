# Text Translation Input Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the Android Text Translation page input-mode behavior: typed text starts visible, image/camera input hides the text editor, and re-selecting text input shows it again.

**Architecture:** Extend the existing `WorkflowInputReadyAction` decision object so `FeatureRuntimePage` can update `userText`, auto-run state, and text input visibility through one tested workflow action. Keep route-specific behavior in `FeatureWorkflowCatalog.ets`; keep ArkUI page changes minimal.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, ArkUI, Hypium unit tests, DevEco Studio local Hvigor.

## Global Constraints

- Target HarmonyOS project path: `Mindspore_inhand_HarmonyOS/`.
- Source Android project path: `Mindspore_inhand/`; it is ignored by Git and must remain ignored.
- Preserve current Android behavior: `TextTranslationActivity` starts with the text editor visible; photo/camera hides the editor and shows image preview; image OCR text is translated without refilling the editor; clicking text input mode makes typed input available again.
- Do not add language selectors, offline translation, source-language detection UI, or `Country_pair_new.txt` runtime usage for this slice because the Android page does not use them.
- Do not depend on Android AARs, Android `.so` files, AppCompat, ARouter, Glide, Retrofit, RxJava, or HMS Android SDKs.
- Every phase must leave the HarmonyOS project buildable.
- Command-line builds should use `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`.
- Private signing keys, local SDK paths in committed local config, generated folders, and build outputs must not be committed.

---

## File Structure

- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`: add `textInputVisible` to `WorkflowInputReadyAction` and compute Android text-translation image-mode visibility.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`: track `textInputVisible`, show the text input only when true, hide it after text-translation image/camera input, and show it when text input mode is selected.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: add action-contract assertions for image/camera hiding and text mode re-showing.
- Create `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-mode.ps1`: static page-wiring check for text chip restore, picker action application, and render condition.

## Task 1: Text Translation Input Mode

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-mode.ps1`

**Interfaces:**
- Updates: `WorkflowInputReadyAction` with `readonly textInputVisible: boolean`
- Updates: `workflowInputReadyAction(workflow: FeatureWorkflow, inputKind: FeatureInputKind, currentUserText: string): WorkflowInputReadyAction`
- Consumes: `AppRoute.TEXT_TRANSLATION`, `FeatureRuntimePage.prepareInput()`, and `FeatureRuntimePage.applyPickResult()`

- [ ] **Step 1: Write the failing action contract test**

Extend `computesTextImageInputReadyPageActionBeforeAutoRun` in `LocalUnit.test.ets`:

```typescript
expect(imageTranslationAction.textInputVisible).assertFalse();
expect(workflowInputReadyAction(textTranslation, 'camera', 'typed first').textInputVisible).assertFalse();
expect(typedTranslationAction.textInputVisible).assertTrue();
expect(imageOcrAction.textInputVisible).assertTrue();
expect(styleTransferAction.textInputVisible).assertTrue();
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: FAIL because `WorkflowInputReadyAction` does not expose `textInputVisible`.

- [ ] **Step 3: Implement minimal workflow action**

In `FeatureWorkflowCatalog.ets`, update the interface:

```typescript
export interface WorkflowInputReadyAction {
  readonly userText: string;
  readonly shouldRunWorkflow: boolean;
  readonly textInputVisible: boolean;
}
```

Update `workflowInputReadyAction()`:

```typescript
return {
  userText: shouldClearTextInputAfterInputReady(workflow, inputKind) ? '' : currentUserText,
  shouldRunWorkflow: shouldAutoRunWorkflowAfterInputReady(workflow, inputKind),
  textInputVisible: !shouldClearTextInputAfterInputReady(workflow, inputKind)
};
```

- [ ] **Step 4: Wire page visibility**

In `FeatureRuntimePage.ets`, add state:

```typescript
@State textInputVisible: boolean = true;
```

In `prepareInput()` text branch, show typed input again:

```typescript
if (inputKind === 'text') {
  this.textInputVisible = true;
  this.statusKey = this.userText.length > 0 ? 'feature_runtime_text_ready' : 'feature_runtime_status_idle';
  this.selectedInputSummary = this.userText;
  return;
}
```

In `applyPickResult()` after computing `inputReadyAction`, apply visibility:

```typescript
this.textInputVisible = inputReadyAction.textInputVisible;
```

In `build()`, only render the text input when supported and visible:

```typescript
if (this.inputKinds.indexOf('text') >= 0 && this.textInputVisible) {
  TextInput({ text: this.userText, placeholder: appString('feature_runtime_text_placeholder') })
  ...
}
```

- [ ] **Step 4.5: Add static page wiring check**

Create `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-mode.ps1` to assert:

```powershell
$ErrorActionPreference = 'Stop'
$pagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
$source = Get-Content -Raw -Encoding UTF8 $pagePath
# Check prepareInput text branch restores this.textInputVisible = true.
# Check applyPickResult applies inputReadyAction.userText and inputReadyAction.textInputVisible before runWorkflow().
# Check build renders TextInput only when this.inputKinds contains text and this.textInputVisible is true.
```

- [ ] **Step 5: Verify GREEN**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
.\scripts\check-feature-runtime-view-ids.ps1
.\scripts\check-text-translation-input-mode.ps1
git diff --check
```

Expected: all commands pass, allowing existing ArkTS warnings.

- [ ] **Step 6: Review and commit**

Create a diff package, get subagent review, address Critical/Important findings, then commit:

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets docs/superpowers/plans/2026-07-10-text-translation-input-mode.md
git commit -m "feat: match Android text translation input mode"
```

## Self-Review

- Spec coverage: covers Android text editor visibility for manual text mode and image/camera OCR mode.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: uses the existing `WorkflowInputReadyAction` path consumed by `FeatureRuntimePage`.
