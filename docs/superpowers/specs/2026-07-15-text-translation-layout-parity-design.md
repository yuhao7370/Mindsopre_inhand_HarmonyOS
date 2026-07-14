# Text Translation Android Layout Parity Design

## Goal

Replace Text Translation's generic runtime cards with the production Android
screen while preserving the packaged local Chinese-English translation model,
Harmony OCR, picker/camera permissions, cancellation, request-generation, and
clipboard behavior.

## Android source of truth

`activity_text_translation.xml` and `TextTranslationActivity` define:

- a white 56dp Back/title toolbar with no Help or More actions;
- a weight-5 top `FrameLayout` showing either a multiline `EditText` with 5dp
  margin or the selected image with 10dp margin;
- the editor and image use `bg_edit_text`: transparent/white content, a
  one-pixel `#B6B2B2` stroke, and 5dp corners;
- an 18sp black editor with a `#666666` placeholder and vertical scrolling;
- a full-width 50dp Translation button with 5dp margins;
- a weight-4, 18sp black, vertically scrollable result field with 5dp margin
  and the same border;
- a weight-1 bottom row containing equal 37dp Photo, Camera, and Copy buttons;
- 20dp outer and 5dp inter-button horizontal margins;
- normal small-button fill `#F4F3F8`, 5dp corners, 14sp `#666666` text;
  Android's pressed selector changes to `#6189FF`, 3dp corners, and white text.

Typed input is visible initially and Translation explicitly starts translation.
Photo or Camera hides the editor, shows the chosen image, performs local OCR,
then translates automatically. The output field contains the translation only.
Copy is always present. Android has no summary, Inputs, Permissions, Result,
metadata, target-language, source-text label, or reachable Save control.

## HarmonyOS design

### Exact route boundary

Add `usesAndroidTextTranslationLayout()` to the pure workflow catalog. It is
true only for `TEXT_TRANSLATION`, false for the other 15 workflows and
`undefined`. Select the dedicated builder before all generic fallbacks.

### Reused behavior

The builder uses existing state and actions:

- `userText`, `textInputVisible`, `updateUserText()`;
- `imageInputUri`, `prepareInput('photo'|'camera')`;
- `runPrimaryAction()` and `runActionEnabled()`;
- `workflowRunning` and the existing clipboard service;
- `runtimePermissionRecoveryOverlay()`.

This retains manual typed translation, automatic image OCR then translation,
Android's Chinese-to-English/other-to-Chinese direction rule, the local
MindSpore Lite model, permission recovery, picker cancellation restoration,
non-overlapping execution, stale-request invalidation, and page-exit safety.

### Dedicated screen

Use a full-size outer Stack and render permission recovery last. Its content
Column contains:

1. `runtimeActionToolbar(false)`.
2. A weight-5 input area. When `textInputVisible` is true, show a full-height
   multiline TextArea inside a 5vp inset. Otherwise show `imageInputUri` with
   Contain inside a 10vp inset. Both use the Android border.
3. A full-width 50vp Translation button with 5vp margin. It calls the existing
   primary action and is disabled while the guarded run is active.
4. A weight-4 bordered Scroll containing only translated output at 18fp.
5. A weight-1 centered Row with equal 37vp Photo, Camera, and Copy buttons and
   Android's exact normal-state spacing and colors.

Add a pure `translatedTextForAiResult()` projection that reads only
`feature_runtime_result_translated_text`. Both the visible result field and its
Copy action use this projection. The generic `copyableTextForAiResult()` source
fallback remains available to other internal/generic callers, but must not make
the Android-shaped output field present source text as a successful
translation. An empty or failed translation therefore copies nothing and keeps
the existing `feature_runtime_copy_failed` outcome.

The dedicated builder never renders `resultRows`, `resultText`, URI summaries,
target-language/runtime-source/timing metadata, generic status cards, or Save.
The main Translation button keeps the Harmony primary-button visual because the
Android XML also relies on its platform theme instead of a project drawable.
The small-button pressed animation is excluded until a reliable ArkUI state
style can be introduced consistently; their normal state is exact.

## Existing behavior retained

- default feature catalog count, ordering, and route;
- exactly the Android text/camera/photo input capabilities;
- local offline Chinese-English translation model and packaged assets;
- photo/camera OCR, automatic image translation, EXIF rotation;
- cancellation restore, permission retry/settings, and request guards;
- translated-output copy with honest empty/failure behavior;
- all other workflow layouts.

## Excluded work

- no model, tokenizer, native archive, OCR, or AI execution changes;
- no network translation or Internet permission;
- no unreachable Android Save method;
- no device-only quality, latency, memory, camera, picker, or visual validation.

## Verification

- TDD an exhaustive selector matrix for 16 workflows plus `undefined`;
- retain existing text/image translation, newline, copy, permission,
  cancellation, and generation tests;
- extend the existing translation parity guard to require the dedicated branch,
  translated-only output, Photo/Camera/Copy order, and absence of generic
  debug/save content inside the dedicated builder;
- run full Hypium, `git diff --check`, and unified HAP/AI acceptance;
- obtain independent review before fast-forwarding to master.
