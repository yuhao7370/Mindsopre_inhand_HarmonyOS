# Segmentation Result Surface Android Parity Implementation Plan

**Goal:** Match Android's still, live, and Portrait segmentation result and
save surfaces without changing inference or media persistence.

**Architecture:** Put route decisions in pure `FeatureWorkflowCatalog`
helpers and keep `FeatureRuntimePage` declarative. Direct pixel-map Save,
standalone foreground preview, and composite snapshot Save use separate exact
route policies.

## Task 1: Add failing route matrices

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Extend the direct Save test across Style Transfer, Segmentation Still,
Segmentation Live, Portrait, translation, object, classification, and undefined
workflows for both ready states. Add tests for the new standalone foreground and
composite Save helpers. Confirm RED because Portrait currently exposes direct
Save and live/Portrait foreground previews are unconditional in the page.

## Task 2: Implement route-specific result policies

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Restrict `shouldShowResultSaveAction` to Style Transfer and Segmentation Still.
Add exact helpers for standalone still-segmentation foreground preview and
Portrait composite Save. Run the focused Hypium suite to GREEN.

## Task 3: Wire the shared result card

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Gate the standalone foreground preview with the new helper. Gate the component
snapshot Save inside the Portrait replacement preview with the composite helper.
Keep the existing live-camera foreground overlay unchanged. Compile and rerun
all Hypium tests.

## Task 4: Verify and integrate

Run `git diff --check`, the exact Hypium result check, and
`build-ai-runtime-acceptance.ps1`. Request independent task and whole-branch
reviews, fix any findings, fast-forward into `master`, repeat focused/full
verification on `master`, and remove the temporary worktree and branch.
