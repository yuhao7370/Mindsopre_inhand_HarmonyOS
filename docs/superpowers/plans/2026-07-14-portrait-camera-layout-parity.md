# Portrait Camera Android Layout Parity Implementation Plan

**Goal:** Replace Portrait's generic cards with Android's toolbar, full
background/person composite, and horizontal background strip without exposing
the hidden route.

**Architecture:** One exact route helper selects a dedicated builder. The
builder composes the existing camera surface and existing segmentation state;
only the composite ArkUI layer receives the snapshot id.

## Task 1: Lock the hidden route boundary in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Add an exhaustive test for the missing
`usesAndroidPortraitSegmentationLayout()` export. Require only Portrait true,
all other workflows and `undefined` false. Run Hypium and record the expected
compile failure.

## Task 2: Add the selector and camera asset

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/media/icon_camera.png`

Implement the exact helper and copy Android's existing `icon_camera.png`
unchanged. Do not add any catalog item or linked route.

## Task 3: Build the Portrait toolbar and composite

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add the dedicated non-scroll Portrait branch. Build a 56vp toolbar with Back,
title, camera action, and icon-only native SaveButton. Under it, use a flex-fill
Stack containing the shared camera surface and a full-size background plus
optional foreground composite. Put the existing replacement component id only
on that composite. Suppress the generic Portrait foreground overlay to avoid a
duplicate layer.

## Task 4: Build the Android horizontal background picker

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Overlay a 5vp divider and 100vp horizontal List at the bottom. Render five
presets and the custom icon as 95vp by 120vp Fill images without text, border,
or selection decoration. Reuse the existing preset/custom handlers. Render the
permission recovery overlay last.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the fresh exact result count, confirm
one XComponent, `git diff --check`, and unchanged camera icon bytes. Run unified
HAP acceptance. Obtain task and whole-branch review, fix findings, fast-forward
into `master`, repeat Hypium and acceptance, then remove the worktree/branch.

