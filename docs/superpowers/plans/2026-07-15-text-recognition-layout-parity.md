# Text Recognition Android Layout Parity Implementation Plan

**Goal:** Replace Text Recognition's generic cards with Android's image,
Photo/Camera, recognized-text, and Copy screen without changing OCR behavior.

**Architecture:** One exact workflow selector chooses a dedicated builder. The
builder is presentation-only and reuses all existing state and actions.

## Task 1: Lock the selector in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Import the missing `usesAndroidTextRecognitionLayout()` helper. Assert only
Text Recognition is true across the complete workflow catalog, all other
workflows are false, and `undefined` is false. Run Hypium and record the
missing-export compile failure.

## Task 2: Add the selector and Android asset

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/media/icon_style.png`

Implement the exact route helper. Copy HMS Android's xxhdpi `icon_style.png`
unchanged and verify bytes/hash. Do not change catalog visibility or routes.

## Task 3: Build the dedicated image and action areas

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add a full-size Stack/Column builder with `runtimeActionToolbar(false)`, a 1vp
divider, a weight-5 `#E6E6E6` image Stack, Android empty prompt, input image
with 10vp inset, and centered 80vp LoadingProgress. Add the 50vp action Row
with exact external margins and two equal 37vp Android-style buttons calling
the existing Photo and Camera preparation paths.

## Task 4: Build recognized text and fixed Copy

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add a weight-3 `#E6E6E6` Scroll with 24vp horizontal padding and only
`recognizedTextForCopy()`. Preserve newlines and enable local text selection.
Add the full-width bottom Copy button, always visible, calling the existing
clipboard path. Render permission recovery last. Add the exact selector branch
before the generic fallback so no summary/input/permission/result/debug cards
appear for OCR.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the exact result count, compare the
asset hash, run `git diff --check`, and run unified HAP/AI acceptance. Obtain
independent review, fast-forward into `master`, repeat master verification,
then remove the worktree and branch.
