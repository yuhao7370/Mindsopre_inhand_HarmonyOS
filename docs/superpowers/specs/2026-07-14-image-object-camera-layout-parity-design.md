# Image/Object Camera Android Layout Parity Design

## Goal

Port the two default-visible Android live camera activities to dedicated
HarmonyOS layouts while preserving the already working ArkTS camera, model,
permission, and inference pipelines.

The target routes are:

- `IMAGE_CAMERA` (`ImageCameraActivity`)
- `OBJECT_CAMERA` (`ObjectCameraActivity`)

This is a layout and visible-interaction increment. Camera/surface behavior is
build-tested only; device framing and overlay alignment remain deferred.

## Android source of truth

`ImageCameraActivity` uses a full camera preview with a white action toolbar at
the top and a white, 100dp classification strip at the bottom. The strip is
empty before the first result and then displays the category name in dark,
14sp bold text. Help and More are toolbar actions. The rear camera is fixed and
classification runs every 1000ms.

`ObjectCameraActivity` places a white Help/More toolbar above a camera preview,
draws detection rectangles directly over that preview, and floats a Select
Model button 16dp from the lower-right corner. It has no separate result card
and no camera switch. Rectangle strokes are 2dp and use the Android five-color
palette; labels are 16sp in the same color without a filled label background.

Both routes are directly reachable from the default catalog and therefore are
P0 visible-parity work.

## HarmonyOS design

### Exact route boundary

Add a pure catalog selector returning one of:

- `imageClassification`
- `objectDetection`
- `undefined`

Only the two target workflows may return a specialized layout. The three
simple-live routes, Live Skeleton, Portrait, and all still workflows must stay
outside this selector.

### Shared runtime surface

Keep one `XComponent` declaration and one lifecycle path. The existing
`liveCameraSurfaceContent()` continues to own surface load/destroy and all
camera overlays. Dedicated pages compose that builder; they do not copy camera
startup, frame capture, inference, or cleanup.

Extract the in-preview permission recovery UI into one builder and reuse it in
the simple-live and both new specialized layouts. Retry and Open Settings keep
their existing handlers.

### Image Camera

Render a non-scroll page with:

1. a 56vp back/title/Help/More toolbar;
2. a camera stack filling all remaining height;
3. a full-width, 100vp white classification strip at the bottom of the camera.

The strip shows the first classification row, using 14fp bold dark text with
15vp horizontal inset. Before a result it may retain Harmony's existing
"recognizing" prompt: that is a deliberate usability fix for Android's
unreachable loading view, not a missing feature.

Change image-classification live scheduling from 500ms to Android's 1000ms.
Gesture and scene scheduling remain unchanged.

### Object Camera

Render a non-scroll page with:

1. a 56vp back/title/Help/More toolbar;
2. a camera/rectangle stack filling all remaining height;
3. a Select Model button floated at the lower right with 16vp inset.

The button calls the existing `prepareInput('modelFile')` path. Existing cache,
restoration, cancellation, and runtime reload behavior is retained. In
particular, do not reproduce Android's `recreate()` bug that discards the
selected model.

For this live route only, render 16fp palette-colored labels without a filled
background. Still Object Photo keeps its existing overlay styling.

### Excluded work

- no new routes or catalog entries;
- no new camera or AI service;
- no change to fixed rear-camera behavior;
- no device-only crop/rotation/coordinate tuning;
- no Live Skeleton or Portrait layout changes in this increment.

## Verification

- TDD selector tests exhaustively traverse all workflows.
- Update interval tests to require 1000ms for classification and retain the
  existing gesture/scene values.
- Preserve tests for fixed rear camera, automatic camera startup, model-file
  cache/restore, overlay colors/labels, and permission recovery.
- Run full Hypium and read the exact generated count.
- Run `git diff --check` and the unified AI runtime HAP acceptance.
- Require independent task and whole-branch review before fast-forward merge.

