# Live Skeleton Android Layout Parity Implementation Plan

**Goal:** Move Live Skeleton from the generic 260vp runtime card to Android's
full-height camera page and restore the exact template/similarity dimensions.

**Architecture:** Reuse the existing simple-live page shell and shared camera
surface. Only the route selector and the skeleton-only overlay presentation
change.

## Task 1: Extend the exact route contract in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Change the exhaustive `usesSimpleAndroidLiveLayout` contract from three routes
to exactly four by adding `LIVE_SKELETON`. Run Hypium and record the expected
assertion failure before production changes.

## Task 2: Reuse the full-screen live shell

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

Add only `LIVE_SKELETON` to the existing helper. Do not alter input kinds,
auto-start, camera positions, run modes, or specialized Image/Object selectors.

## Task 3: Match the Android template overlay

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Use 135vp by 169vp for the template, remove the 10vp outer inset, and render a
white `similarity:NN%` line at 13fp and 18vp height immediately above it. Remove
the Harmony-only translucent label card. Retain the existing pose lines,
points, switch, and permission overlay order.

## Task 4: Verify and integrate

Run full `hvigorw test --no-daemon`, read the fresh exact result count, confirm
one XComponent and `git diff --check`, then run unified HAP acceptance. Obtain
task and whole-branch review, fix findings, fast-forward into `master`, repeat
Hypium and unified acceptance there, and remove the temporary worktree/branch.

