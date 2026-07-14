# Text Recognition Android Layout Parity Design

## Goal

Give the default Text Recognition route its Android-specific screen while
preserving the existing real Harmony OCR, picker, permission, cancellation,
and clipboard implementations.

## Android source of truth

`activity_text_recognition.xml` and `TextRecognitionActivity` define:

- a white 56dp Back/title toolbar and 1dp divider;
- a flex-weight 5 image area with `#E6E6E6` background and 10dp image inset;
- an empty state using the original `icon_style.png`, 10dp spacing, 16sp gray
  prompt, and an 80dp centered progress indicator while OCR runs;
- a 50dp action row with 14dp top, 10dp side/bottom margins;
- two equal 37dp Photo/Camera buttons separated by 10dp;
- a flex-weight 3 `#E6E6E6` recognized-text area with 24dp side padding;
- a full-width, always-present bottom Copy action.

Photo and Camera automatically start local OCR. Copy uses only recognized
text. Android does not show URI, line/block counts, execution time, summary,
permission chips, or result/debug cards.

## HarmonyOS design

### Exact route boundary

Add `usesAndroidTextRecognitionLayout()` to the pure workflow catalog. It is
true only for `TEXT_RECOGNITION`, false for every other workflow and
`undefined`. Select a dedicated non-scroll builder before the generic fallback.

### Reused behavior

The dedicated builder calls the existing `prepareInput('photo'|'camera')` and
therefore retains permission checks, picker/camera cancellation handling,
automatic OCR, async generation invalidation, page-exit protection, and the
real `TextRecognitionService`. It reuses `workflowRunning`, `imageInputUri`,
`recognizedTextForCopy()`, `copyRecognizedText()`, and the permission recovery
overlay. No AI service or result-shaping code changes.

### Dedicated screen

Use a full-size Stack so permission recovery stays topmost. The content Column
contains the existing action toolbar without Help/More, a divider, the weighted
image Stack, the Photo/Camera row, a weighted Scroll containing only recognized
text, and the bottom Copy button.

The empty image area uses the Android `icon_style.png` copied byte-for-byte.
When an input exists, show it with Contain inside the 10vp inset. While
`workflowRunning`, overlay an 80vp `LoadingProgress` in the center.

The text area displays only `recognizedTextForCopy()` and preserves newlines.
It must not render generic result rows or `resultText`, which contain Android-
invisible image, count, and timing metadata.

## Existing behavior retained

- default catalog count/order and Text Recognition route;
- album/camera permissions and recovery;
- picker cancellation and automatic local OCR;
- structured OCR result used by clipboard logic;
- empty-copy failure behavior;
- all other 15 workflow layouts.

## Excluded work

- no OCR model/service replacement;
- no forced Chinese-only OCR beyond Harmony CoreVision capability;
- no Text Translation layout changes in this increment;
- no device-only image orientation, picker, camera, or OCR validation.

## Verification

- TDD an exhaustive selector matrix for all workflows plus `undefined`;
- retain existing OCR auto-run, clipboard, permission, and generation tests;
- compare Android/Harmony `icon_style.png` bytes and SHA-256;
- run full Hypium, `git diff --check`, and unified HAP/AI acceptance;
- obtain independent review before fast-forwarding to master.
