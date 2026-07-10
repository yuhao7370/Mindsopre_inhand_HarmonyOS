# Custom Model Local Help Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Android Custom Model's local Help dialog in HarmonyOS with localized content.

**Architecture:** Keep the shared runtime page. Add an optional `helpContentKey` to `FeatureWorkflow`, set it only for Custom Model, and show an `AlertDialog` when a workflow has local help content. Existing URL help behavior remains unchanged for Image/Object/Style workflows.

**Tech Stack:** ArkTS, HarmonyOS declarative UI, existing i18n resources, Hypium local unit tests.

## Global Constraints

- Do not add Android APK update/download-new-version behavior.
- Do not replace the existing Source/web help path for workflows that already use `helpUrl`.
- Preserve Custom Model selected photo/camera/model inputs and runtime behavior.
- All visible text must use `AppStringKey` and `string.json` resources.

---

### Task 1: Add Custom Model Local Help

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify docs: `docs/harmonyos-platform-differences.md`

- [x] **Step 1: Write failing tests**

Assert Custom Model exposes a local help key and the new key is registered:

```ts
expect(workflowForRoute(AppRoute.CUSTOM_MODEL.name)?.helpContentKey)
  .assertEqual('feature_runtime_custom_model_help');
expect(hasAppStringKey('feature_runtime_help')).assertTrue();
expect(hasAppStringKey('feature_runtime_custom_model_help')).assertTrue();
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: compile or Hypium failure because `helpContentKey` and string keys are not implemented yet.

- [x] **Step 3: Implement workflow and i18n**

Add optional `helpContentKey?: AppStringKey` to `FeatureWorkflow`, set it for Custom Model, and register:

```ts
'feature_runtime_help'
'feature_runtime_custom_model_help'
```

- [x] **Step 4: Wire the UI action**

In `FeatureRuntimePage.ets`, store `helpContentKey`, add a `showLocalHelpDialog()` method, and show a localized `Help` button when the key is present.

- [x] **Step 5: Verify, review, and commit**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
```

Ask a read-only review subagent to inspect the staged diff before committing.
