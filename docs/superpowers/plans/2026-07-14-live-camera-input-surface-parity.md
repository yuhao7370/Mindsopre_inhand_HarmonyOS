# Live Camera Input Surface Android Parity Implementation Plan

> Execute in an isolated worktree using TDD and independent review.

## Goal

Remove the redundant Camera chip from all seven auto-start live routes without
changing their runtime camera input, startup behavior, permissions, preview, or
secondary controls.

## Task 1: Add the exact failing visible-input contract

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Import the not-yet-created `visibleInputKindsForWorkflow` helper. Add an exact
seven-route matrix for:

- `LIVE_SKELETON` → `[]`
- `SEGMENTATION_LIVE` → `[]`
- `PORTRAIT_SEGMENTATION` → `[]`
- `IMAGE_CAMERA` → `[]`
- `GESTURE_LIVE` → `[]`
- `SCENE_LIVE` → `[]`
- `OBJECT_CAMERA` → `['modelFile']`

For each route also require runtime input `camera` and auto-start `camera`.
Require the route names to be unique. Add exact still-route assertions for
PoseNet, Segmentation Still, Gesture Still, and Scene Still as
`['photo', 'camera']`.

Run `hvigorw.bat test --no-daemon` from `Mindspore_inhand_HarmonyOS` and record
RED caused by the missing helper/current visible behavior.

## Task 2: Implement the minimum visible-input policy

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add `visibleInputKindsForWorkflow(workflow)` that filters the auto-start input
from `runtimeInputKindsForWorkflow(workflow)` and continues filtering Portrait's
`backgroundImage` grid input.

Make `FeatureRuntimePage.visibleInputKinds()` delegate to that helper for known
routes, retaining the current state array as the unknown-route fallback. Wrap the
Inputs heading and Flex so they render only when the visible list is non-empty.
Do not change catalog `inputKinds`, auto-start, live preview, picker, or camera
service code.

Re-run Hypium and require GREEN. Read the generated
`entry/.test/default/intermediates/test/coverage_data/test_result.txt` exact
summary rather than relying only on hvigor's exit code.

## Task 3: Align documentation and verify

Files:

- Modify: `docs/harmonyos-platform-differences.md`

Document that auto-start live routes no longer show a duplicate Camera input;
Object Camera retains Select Model and Portrait retains the background grid.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Require ordered success for main HAP, gesture native contract, translation XZ
native contract, ohosTest HAP, and the final dual-HAP guard.

## Task 4: Review and integrate

- Commit exactly the catalog, runtime page, unit test, and parity doc.
- Write the SDD task report with RED/GREEN, exact Hypium counts, acceptance,
  scope, and warnings.
- Run task review and whole-branch review; fix all Important findings.
- Fast-forward merge only after `READY TO MERGE`.
- Re-run Hypium and unified acceptance on merged `master`.
- Remove the feature worktree/branch and retain the old gesture worktree as
  read-only reference.
