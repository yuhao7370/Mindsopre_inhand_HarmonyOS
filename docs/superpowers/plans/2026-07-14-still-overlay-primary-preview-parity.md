# Still Overlay Primary Preview Android Parity Implementation Plan

**Goal:** Remove duplicate input/result images from Object Photo, PoseNet
Still, and Gesture Still while keeping the source image visible until a usable
overlay exists.

**Architecture:** A pure catalog helper owns the route matrix. The page derives
one overlay-ready boolean from existing result state and applies the policy to
both preview-card visibility and the primary `imageInputUri` builder.

## Task 1: Add the failing route matrix

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Add `shouldShowPrimaryImageInputPreview` assertions for Object Photo, PoseNet,
Gesture Still, their live/related routes, unrelated workflows, and undefined
at ready=false/true. Confirm RED because the helper does not exist.

## Task 2: Implement the route policy

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Return false only for the three target routes when overlayReady is true. Run
the focused matrix to GREEN.

## Task 3: Wire generic preview visibility

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Derive route-specific overlay readiness from the existing detection, pose, and
visible-gesture result state. Gate the primary image inside the preview card
and update `hasInputPreview()` to ignore that image when the overlay replaces
it, while preserving every secondary input preview. Run all Hypium tests and
confirm the exact result count.

## Task 4: Verify and integrate

Run `git diff --check`, unified AI runtime HAP acceptance, and independent task
and whole-branch reviews. Fix findings, fast-forward to `master`, repeat the
full checks on `master`, then remove the temporary worktree and branch.
