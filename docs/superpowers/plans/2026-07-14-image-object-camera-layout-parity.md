# Image/Object Camera Android Layout Parity Implementation Plan

**Goal:** Replace the generic runtime cards for Image Camera and Object Camera
with the dedicated Android toolbar/camera/result controls while reusing the
working ArkTS runtime.

**Architecture:** An exhaustive pure selector chooses one of two dedicated
builders. Both builders compose the existing single live-camera surface and a
shared permission recovery overlay. Runtime and picker state remain unchanged.

## Task 1: Lock the specialized route boundary in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Add an exhaustive workflow test for the missing specialized-layout selector.
Require exactly `IMAGE_CAMERA -> imageClassification` and
`OBJECT_CAMERA -> objectDetection`; all other workflows and `undefined` must
return `undefined`. Run Hypium and record the expected compile/test failure.

## Task 2: Add the selector and Android interval contract

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/camera/LiveCameraService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Implement the exact selector. Change live image classification to the normal
1000ms interval while leaving gesture and scene at 500ms. Update the existing
interval assertions and get the focused contract to GREEN.

## Task 3: Reuse toolbar and permission recovery structure

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Extract a full-width back/title toolbar builder with optional Help/More actions
for non-scroll live pages. Reuse it from the existing simple-live page and the
two new layouts. Extract the permission retry/settings overlay so all three
layouts keep one recovery implementation.

Do not introduce a second `XComponent` or copy any surface lifecycle callback.

## Task 4: Implement Image Camera layout

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add the dedicated non-scroll Image Camera branch before the generic form. Use
the action toolbar, a flex-fill shared camera stack, the shared permission
overlay, and a 100vp full-width white bottom classification strip. Render the
first category row as 14fp bold dark text.

## Task 5: Implement Object Camera layout

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add the dedicated non-scroll Object Camera branch. Float the existing Select
Model action at bottom-right with 16vp inset and call
`prepareInput('modelFile')`. For Object Camera only, use 16fp palette-colored
labels without a filled label background. Keep still Object Photo unchanged.

## Task 6: Verify, review, and integrate

Run full Hypium and require the exact new pass count with zero failure/error.
Run `git diff --check` and unified AI runtime HAP acceptance. Obtain independent
task review and final whole-branch review, fix all Important findings, then
fast-forward merge into `master`.

On merged `master`, run `hvigorw test --no-daemon` and read the fresh
`test_result.txt`, then run unified HAP acceptance again. Remove the feature
worktree and branch after both checks pass.

