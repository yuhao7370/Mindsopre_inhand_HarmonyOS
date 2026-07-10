# Live Gesture Scene Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make HarmonyOS live Gesture Recognition and Scene Detection run continuously, matching Android analyzer transactor behavior.

**Architecture:** Reuse the existing `LiveRuntimeLoopService` and 1000ms interval. Extend only the live-loop eligibility helper to include `detectGesture` and `detectScene`; no new camera service or runtime runner is required.

**Tech Stack:** ArkTS, HarmonyOS camera loop service, Hypium local unit tests.

## Global Constraints

- Do not change gesture or scene fallback recognition logic.
- Do not alter still gesture/scene workflows.
- Do not migrate Android APK update/download-new-version behavior.

---

### Task 1: Enable Live Loop Eligibility

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/camera/LiveCameraService.ets`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify docs: `docs/harmonyos-platform-differences.md`

- [x] **Step 1: Write failing tests**

Assert:

```ts
expect(shouldRunLiveRuntimeLoop('detectGesture', true, true, true)).assertTrue();
expect(shouldRunLiveRuntimeLoop('detectScene', true, true, true)).assertTrue();
expect(shouldAutoRunLiveRuntimeAfterPreview('detectGesture', true, true)).assertTrue();
expect(shouldAutoRunLiveRuntimeAfterPreview('detectScene', true, true)).assertTrue();
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

- [x] **Step 3: Implement minimal eligibility update**

Add `detectGesture` and `detectScene` to `shouldRunLiveRuntimeLoop`.

- [x] **Step 4: Verify, review, and commit**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
```

Ask a read-only review subagent to inspect the staged diff before committing.
