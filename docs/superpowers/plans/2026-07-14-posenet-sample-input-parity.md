# PoseNet Sample Input Android Parity Implementation Plan

> **For Codex:** Execute with subagent-driven development and TDD. Keep the
> change limited to the PoseNet catalog entry, focused host contracts, and
> parity documentation.

**Goal:** Remove the extra HarmonyOS Sample Image input chip while preserving
Android's preloaded PoseNet sample and all four reachable Android actions.

**Architecture:** Treat `inputKinds` as the visible input controls and the
existing initial preview action as the independent sample-loading mechanism.
No page conditional or runtime service change is needed.

**Tech stack:** ArkTS, Hypium, PowerShell HAP acceptance.

---

## Task 1: Match Android's PoseNet inputs

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `docs/harmonyos-platform-differences.md`

### Step 1: Write the failing visible-input contract

Update the PoseNet platform-needs test to assert
`runtimeInputKindsForWorkflow(posenet)` contains exactly `photo` and `camera`
and excludes `sampleImage`. Keep the sample rawfile URI assertion.

Strengthen the existing initial-preview test to assert the sample preview URI,
`inputKind='sampleImage'`, and `shouldRunWorkflow=false` remain intact.

Run complete Hypium before production changes and capture RED from the current
three-item visible input list.

### Step 2: Implement the minimal catalog correction

Change only the PoseNet `inputKinds` value from
`['sampleImage', 'photo', 'camera']` to `['photo', 'camera']`.

Do not change `FeatureInputKind`, `sampleImageRawfilePath`,
`initialPreviewActionForWorkflow()`, `sampleImageUriForWorkflow()`, page input
handling, auto-run policy, or pose services.

Run complete Hypium and require no Hypium `ERROR` output.

### Step 3: Correct PoseNet documentation

Describe the sample as the entry preview and Photo/Camera as the visible image
inputs. Retain the separate Detect and Real-time behavior description.

### Step 4: Verify and review

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Then run `git diff --check`, inspect the exact three-file scope, commit as
`fix: match android posenet sample input`, and request independent task and
whole-branch reviews before merging to `master`.

Device tests are compiled but not executed in this scope.
