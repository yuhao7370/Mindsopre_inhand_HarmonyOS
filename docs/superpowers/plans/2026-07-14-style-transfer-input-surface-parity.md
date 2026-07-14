# Style Transfer Input Surface Android Parity Implementation Plan

> Execute in an isolated worktree using TDD and independent review.

## Goal

Match Android's Style Transfer input surface: Album before Camera, no duplicate
style-image action outside the 19+1 style grid, model selectors preserved.

## Task 1: Add the failing exact Style Transfer contract

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Require:

```text
workflow.inputKinds = ['contentImage', 'camera', 'styleImage']
runtimeInputKinds = [
  'contentImage', 'camera', 'styleImage',
  'stylePredictModelFile', 'styleTransferModelFile'
]
visibleInputKinds = [
  'contentImage', 'camera',
  'stylePredictModelFile', 'styleTransferModelFile'
]
```

Also require runtime contains `styleImage` while visible does not. Preserve the
existing 19+1 grid, custom-style, auto-run, Object Photo, live, and still tests.

Run Hypium and record RED against the current Camera-first, duplicate-style
surface using a fresh result file.

## Task 2: Implement the minimum catalog policy

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

Reorder only the Style Transfer `inputKinds` array. In
`visibleInputKindsForWorkflow`, additionally filter `styleImage` only when the
workflow route is Style Transfer. Do not alter the input type, picker behavior,
grid, auto-run policy, optional model arrays, or page.

Re-run Hypium and require a new exact zero-failure summary.

## Task 3: Document and verify

Files:

- Modify: `docs/harmonyos-platform-differences.md`

Document the Album→Camera visible order, preserved model selectors, and that the
custom-style add tile is the sole custom style-image action.

Run unified acceptance and require ordered main HAP, gesture native,
translation native, ohosTest, and dual-HAP verification success.

## Task 4: Review and integrate

- Commit exactly catalog, LocalUnit test, and parity doc.
- Write the SDD report with RED/GREEN, exact counts, acceptance, and scope.
- Run task and whole-branch reviews; resolve all Important findings.
- Fast-forward merge only after `READY TO MERGE`.
- Re-run Hypium and unified acceptance on merged `master`.
- Remove the feature worktree and branch.
