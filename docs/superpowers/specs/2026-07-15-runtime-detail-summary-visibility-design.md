# Runtime Detail Summary Visibility Design

## Goal

Stop the generic Feature Runtime screen from exposing raw AI `detailText`
summaries while retaining all structured results, localized statuses, visual
previews, copy/save behavior, and internal metadata state.

## Evidence

`FeatureRuntimePage` stores `AiRunResult.detailText` in `resultText`. Depending
on the workflow, that value contains implementation-oriented summaries such as
image/model file names, target language, subject/point/output counts, Boolean
flags, and execution timing. The generic fallback currently renders it as a
small muted paragraph after all normal result controls.

The seven workflows that still use the generic fallback (PoseNet, still
segmentation, still gesture, still scene, photo object detection, Style
Transfer, and Custom Model) already have user-facing surfaces:

- `aiRunResultRows()` projects classification, object, style, OCR,
  translation, segmentation, pose, gesture, scene, and Custom Model results;
- specialized builders and visual state render camera overlays and generated
  images;
- `statusKey` renders localized success, missing-input, permission, and failure
  states in the generic result card;
- copy and save actions read structured rows or visual state, not the trailing
  paragraph.

Custom Model is not dependent on visible raw text: its output row is derived by
`customModelOutputRowValue()` while `aiRunResultRows()` processes the result.

## Design

Delete only the final generic builder block that creates
`Text(this.resultText)`. Do not remove `resultText` state or any assignment.
It remains an internal carrier because portrait-segmentation background changes
update both structured rows and the matching detail summary through
`segmentationMetadataWithBackground()`.

Extend `check-runtime-debug-ui.ps1` to reject a Text component directly bound
to `this.resultText`, including whitespace/newline formatting variants. The
guard change is written first so the current page fails, then the UI block is
removed so it passes.

Update the platform-differences documentation to state that raw detail
summaries remain internal and only structured/localized output is rendered.

## Existing behavior retained

- all workflow routes, catalog data, inputs, permissions, and services;
- AI result creation and `detailText` diagnostics;
- structured result rows and visual overlays/previews;
- localized result status, permission recovery, copy, and save actions;
- portrait background metadata synchronization;
- dedicated Text Recognition and Text Translation layouts.

## Excluded work

- no result schema or AI service refactor;
- no removal of internal `resultText` state;
- no new dedicated layouts;
- no device-only validation.

## Verification

- prove the extended debug-UI guard fails before the render block is removed;
- prove it passes after the minimal deletion;
- run full Hypium, `git diff --check`, and unified HAP/AI acceptance;
- obtain independent review before fast-forwarding to master.
