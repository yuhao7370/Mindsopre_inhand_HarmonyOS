# Simple Live Camera Layout Android Parity Implementation Plan

**Goal:** Port Live Gesture, Live Scene, and Live Segmentation to Android's
toolbar-plus-full-camera layout without changing the specialized live routes.

**Architecture:** An exact route helper selects a second page branch. The
existing live-camera Stack children are extracted once and reused by the normal
card and the new flex-fill preview. Permission recovery becomes a conditional
in-preview overlay.

## Task 1: Add the failing layout-route contract

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Add `usesSimpleAndroidLiveLayout` tests over all workflows and `undefined`,
with exactly Segmentation Live, Gesture Live, and Scene Live positive. Confirm
RED because the export is missing.

## Task 2: Add the exact route helper

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Implement the three-route set and run the focused contract to GREEN.

## Task 3: Reuse the camera surface

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Extract XComponent lifecycle plus scene, segmentation, object, pose, gesture,
template, and classification overlays into one builder. Keep the existing
260vp card builder visually unchanged for all non-simple routes.

## Task 4: Add the simple full-screen page branch

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Build a non-scroll Column with compact back/title toolbar and a
`layoutWeight(1)` preview Stack. Place the existing switch at bottom center
inside that Stack. Add a centered conditional permission-retry/settings overlay
using existing handlers. Select this page only through the exact route helper.

## Task 5: Verify and integrate

Run full Hypium and record the exact count, `git diff --check`, unified AI
runtime HAP acceptance, and independent task/whole-branch reviews. Fix
findings, fast-forward into `master`, repeat verification on `master`, and
remove the temporary branch/worktree.
