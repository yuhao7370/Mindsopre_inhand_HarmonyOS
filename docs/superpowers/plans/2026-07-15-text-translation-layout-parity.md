# Text Translation Android Layout Parity Implementation Plan

**Goal:** Replace Text Translation's generic cards with Android's editor/image,
Translation, output, and Photo/Camera/Copy screen without changing AI behavior.

**Architecture:** One exact pure selector chooses a presentation-only builder
that reuses all existing state, actions, and local runtime services.

## Task 1: Lock the selector in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Import the missing `usesAndroidTextTranslationLayout()` helper. Assert only
Text Translation is true across all 16 workflows and `undefined` is false. Run
Hypium and record the missing-export compile failure. Also specify the pure
translated-output projection: translated row returns its exact multiline text,
while source-only rows return an empty string.

## Task 2: Add the exact route selector

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`

Implement the selector without changing workflow catalog data, routes, input
kinds, permissions, primary-action rules, or runtime services. Add the minimal
pure `translatedTextForAiResult()` row projection without changing inference or
the existing generic copy helper.

## Task 3: Build the Android input and Translation areas

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`

Add a full-size Stack/Column builder with `runtimeActionToolbar(false)`. Add the
weight-5 top area: TextArea with Android placeholder/font/border and 5vp inset
while text input is visible, otherwise the selected image with Contain and
10vp inset. Bind the TextArea to `userText`/`updateUserText()`. Add the 50vp,
5vp-margin Translation button using `runPrimaryAction()` and
`runActionEnabled()`.

## Task 4: Build output and bottom actions

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-parity.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

Add a weight-4 bordered Scroll displaying only `translatedTextForAiResult()` at
18fp. Add a weight-1 centered Row with equal 37vp Photo, Camera, and Copy
buttons using Android normal-state colors and exact 20/5vp horizontal margins.
Photo/Camera call existing preparation paths; Copy sends the same translated-
only value through the existing clipboard service/status path. Render
permission recovery last. Select this branch before generic
fallbacks so no summary/input/permission/result/debug/save UI is reachable.

Update `docs/harmonyos-platform-differences.md` so it describes the dedicated
single translated-output field and its honest empty/failure Copy behavior.
Extend the existing build guard to require the dedicated selector branch,
translated-only binding, Photo/Camera/Copy ordering, and to reject generic
debug/result/save rendering within the dedicated builder.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the exact result count, run the
existing translation parity guard, `git diff --check`, and unified HAP/AI
acceptance. Obtain independent review, fast-forward to master, repeat master
verification, then remove the worktree and branch.
