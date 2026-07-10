# Portrait Live Segmentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/hms/PortraitSegmentationActivity` behave like the Android live portrait segmentation page by using the existing HarmonyOS live camera loop and background replacement preview.

**Architecture:** Keep `FeatureRuntimePage` as the shared runtime page. Change only the Portrait workflow contract so its primary input starts live camera preview and the existing `segmentPerson` live loop refreshes the already-ported foreground/background composite. Keep selected and built-in backgrounds as optional inputs.

**Tech Stack:** ArkTS, HarmonyOS CameraKit live preview, CoreVision subject segmentation, existing Hypium local unit tests.

## Global Constraints

- The approved port spec includes `Portrait Segmentation: still/live segmentation preview`.
- Do not migrate Android APK update/download-new-version behavior.
- Preserve i18n string usage through existing `AppStringKey` resource keys.
- Keep the current background preset and custom background picker behavior.
- Reuse existing live frame capture fallback; do not introduce a new native camera frame pipeline in this slice.

---

### Task 1: Enable Portrait Live Segmentation Workflow

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify docs: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: `workflowForRoute(routeName: string): FeatureWorkflow | undefined`
- Consumes: `runtimeInputActionsForWorkflow(workflow: FeatureWorkflow): Array<RuntimeInputAction>`
- Consumes: `shouldRunLiveRuntimeLoop(aiMethod: string, workflowLiveMode: boolean, liveCameraInputSelected: boolean, liveCameraActive: boolean): boolean`
- Produces: `AppRoute.PORTRAIT_SEGMENTATION` workflow with `inputKinds: ['camera']`, `optionalInputKinds: ['backgroundImage']`, `requiredPermissions: ['camera', 'media']`, and `liveMode: true`

- [x] **Step 1: Write the failing workflow test**

Update the existing portrait workflow assertion in `LocalUnit.test.ets`:

```ts
const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
expect(portraitSegmentation.aiMethod).assertEqual('segmentPerson');
expect(portraitSegmentation.inputKinds.indexOf('camera') >= 0).assertTrue();
expect(portraitSegmentation.inputKinds.indexOf('photo')).assertEqual(-1);
expect((portraitSegmentation.optionalInputKinds ?? []).indexOf('backgroundImage') >= 0).assertTrue();
expect(portraitSegmentation.requiredPermissions.indexOf('camera') >= 0).assertTrue();
expect(portraitSegmentation.requiredPermissions.indexOf('media') >= 0).assertTrue();
expect(portraitSegmentation.liveMode).assertTrue();
```

Add a runtime-action assertion near the existing `runtimeInputActionsForWorkflow` test:

```ts
const portraitSegmentation: FeatureWorkflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
expect(runtimeInputActionsForWorkflow(portraitSegmentation).indexOf('startLiveCamera') >= 0).assertTrue();
expect(runtimeInputActionsForWorkflow(portraitSegmentation).indexOf('captureImage')).assertEqual(-1);
expect(runtimeInputKindsForWorkflow(portraitSegmentation).indexOf('backgroundImage') >= 0).assertTrue();
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: Hypium reports failure because Portrait currently uses `photo`, lacks camera permission, and `liveMode` is false.

- [x] **Step 3: Write minimal implementation**

Change only the Portrait workflow entry:

```ts
{
  routeName: AppRoute.PORTRAIT_SEGMENTATION.name,
  titleKey: 'title_segmentation',
  summaryKey: 'workflow_summary_segmentation',
  aiMethod: 'segmentPerson',
  inputKinds: ['camera'],
  optionalInputKinds: ['backgroundImage'],
  requiredPermissions: ['camera', 'media'],
  resultKind: 'segmentationMask',
  liveMode: true
}
```

- [x] **Step 4: Run tests and build**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
```

Expected: tests and build complete without Hypium failures or new compile errors. Existing ArkTS/deprecation/signing warnings may remain.

- [x] **Step 5: Review and commit**

Ask a review subagent to inspect the diff for spec compliance and regressions. If clean, commit:

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets docs/harmonyos-platform-differences.md docs/superpowers/plans/2026-07-10-portrait-live-segmentation.md
git commit -m "feat: enable portrait live segmentation"
```
