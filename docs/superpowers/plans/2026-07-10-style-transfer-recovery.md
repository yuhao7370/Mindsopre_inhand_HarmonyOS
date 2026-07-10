# Style Transfer Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Android Style Transfer's Recovery action in HarmonyOS so users can return the preview to the original/content image after a style result is shown.

**Architecture:** Keep the existing shared `FeatureRuntimePage`. Add one small runtime helper for recovery-control visibility, one localized button key, and one page action that clears `styledImagePixelMap` while leaving selected content/style/model inputs intact.

**Tech Stack:** ArkTS, HarmonyOS declarative UI, existing i18n resources, Hypium local unit tests.

## Global Constraints

- Do not change Style Transfer model execution, built-in style preset selection, or model picker behavior.
- Do not migrate Android APK update/download-new-version behavior.
- Preserve i18n through `AppStringKey` and `string.json` resources.
- The recovery action must not clear selected content image, style image, built-in style, or model file inputs.

---

### Task 1: Add Style Transfer Recovery Control

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify docs: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Produces: `shouldShowStyleRecoveryControl(aiMethod: string, styledImageReady: boolean): boolean`
- Produces: `AppStringKey` values `feature_runtime_style_recovery` and `feature_runtime_style_recovered`

- [x] **Step 1: Write failing tests**

Add tests that assert:

```ts
expect(shouldShowStyleRecoveryControl('runStyleTransfer', true)).assertTrue();
expect(shouldShowStyleRecoveryControl('runStyleTransfer', false)).assertFalse();
expect(shouldShowStyleRecoveryControl('classifyImage', true)).assertFalse();
expect(hasAppStringKey('feature_runtime_style_recovery')).assertTrue();
expect(hasAppStringKey('feature_runtime_style_recovered')).assertTrue();
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: compile or Hypium failure because the helper/string keys do not exist yet.

- [x] **Step 3: Implement minimal helper and i18n**

Add `shouldShowStyleRecoveryControl` near the other workflow helpers:

```ts
export function shouldShowStyleRecoveryControl(aiMethod: string, styledImageReady: boolean): boolean {
  return aiMethod === 'runStyleTransfer' && styledImageReady;
}
```

Add English/base string values:

```json
{ "name": "feature_runtime_style_recovery", "value": "Recovery" },
{ "name": "feature_runtime_style_recovered", "value": "Original image restored." }
```

Add Simplified Chinese string values:

```json
{ "name": "feature_runtime_style_recovery", "value": "恢复原图" },
{ "name": "feature_runtime_style_recovered", "value": "已恢复原图。" }
```

- [x] **Step 4: Wire the UI action**

In `FeatureRuntimePage.ets`, import `shouldShowStyleRecoveryControl`, add:

```ts
private recoverStyleOriginalPreview(): void {
  this.styledImagePixelMap = undefined;
  this.statusKey = 'feature_runtime_style_recovered';
}
```

After the styled result save control, render a button only when the helper returns true:

```ts
if (shouldShowStyleRecoveryControl(this.aiMethod, this.styledImagePixelMap !== undefined)) {
  this.styleRecoveryControl()
}
```

The `styleRecoveryControl` builder calls `recoverStyleOriginalPreview()`.

- [x] **Step 5: Verify and commit**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
```

Ask a read-only review subagent to inspect the staged diff. If clean:

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets docs/harmonyos-platform-differences.md docs/superpowers/plans/2026-07-10-style-transfer-recovery.md
git commit -m "feat: add style transfer recovery"
```
