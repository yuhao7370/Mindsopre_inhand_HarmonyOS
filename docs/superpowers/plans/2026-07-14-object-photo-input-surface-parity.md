# Object Photo Input Surface Android Parity Implementation Plan

> Execute in an isolated worktree using TDD and independent review.

## Goal

Hide the redundant Object Photo chip after the route's Android-style automatic
album picker, while retaining Select Model and all runtime behavior.

## Task 1: Add the failing exact Object Photo contract

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Extend the visible-input parity test, or add a focused adjacent test, requiring:

```text
runtimeInputKinds = ['photo', 'modelFile']
initialInputKind = 'photo'
autoStartInputKind = undefined
visibleInputKinds = ['modelFile']
```

Run Hypium and record RED where visible inputs still contain Photo. The result
file must be fresh; do not reuse the previous 458-test summary.

## Task 2: Generalize the implicit-input visibility policy

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

In `visibleInputKindsForWorkflow`, hide the auto-start input when defined;
otherwise hide the initial input returned by `initialInputKindForWorkflow`.
Keep the Portrait background-grid exclusion exactly as-is. Do not alter any
workflow catalog input arrays or `initialInputKindForWorkflow` itself.

Re-run Hypium and require GREEN with a new exact result summary.

## Task 3: Document and verify

Files:

- Modify: `docs/harmonyos-platform-differences.md`

Update the Object Photo parity section to state that after the automatic initial
album pick, only Select Model is shown as an input action, matching Android.

Run the unified acceptance command and require ordered main HAP, gesture native,
translation native, ohosTest HAP, and dual-HAP verification success.

## Task 4: Review and integrate

- Commit exactly the catalog, LocalUnit test, and parity doc.
- Write the SDD task report with RED/GREEN, exact counts, acceptance, scope, and
  environmental warnings.
- Run task review and whole-branch review; resolve all Important findings.
- Fast-forward merge only after `READY TO MERGE`.
- Re-run Hypium and unified acceptance on merged `master`.
- Remove the feature worktree and branch.
