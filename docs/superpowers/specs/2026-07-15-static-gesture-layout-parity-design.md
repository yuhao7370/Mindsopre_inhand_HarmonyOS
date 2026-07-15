# Static Gesture Android Layout Parity Design

## Goal

Replace the generic HarmonyOS runtime cards on
`/hms/StillHandGestureAnalyseActivity` with the Android static-gesture screen
while preserving the exact packaged HMS `GestureDetector.ms` model, the MNN
native runtime, still-image preprocessing, permissions, picker/camera flows,
request cancellation, and the existing live-gesture route.

## Android Source Of Truth

`activity_gesture_recognition.xml` and `StillHandGestureAnalyseActivity` define:

- a white 56dp Back/title toolbar with no Help or More actions;
- two consecutive 1dp `#E4E4E4` dividers declared by the production XML;
- a weight-9 `#E6E6E6` preview FrameLayout;
- an image inset by 50dp on every side;
- a centered empty state using the original `icon_style.png`, 10dp spacing,
  the Android image/camera/real-time prompt, 16sp `#666666` text, and no
  generic summary or result card;
- a full-size `GraphicOverlay` above the image for gesture rectangles and
  labels;
- a weight-1 horizontal action area with 14dp top margin;
- equal 37dp Photo, Camera, and Real-time buttons in that order, using the
  Android small-button normal state (`#F4F3F8`, 5dp radius, 14sp `#666666`)
  and the XML's 20dp/5dp horizontal margins.

Photo and Camera replace the empty prompt, retain the selected image, and
automatically run gesture inference. Real-time opens
`/hms/LiveHandGestureAnalyseActivity`. Successful analysis draws only on the
preview overlay. Empty or failed analysis keeps the selected image and shows a
short failure Toast. Android does not show an Inputs section, permission chips,
URI/file-name rows, runtime source, execution time, structured result cards,
or a separate gesture-result preview.

## Considered Approaches

### Dedicated branch in `FeatureRuntimePage` — chosen

Add a route selector and a dedicated builder before the generic fallback. This
reuses the current page state, actions, overlay math, permission recovery, and
AI service session. It is the smallest change and follows the existing Text
Recognition and Text Translation parity pattern.

### Separate gesture page

A new routed page would make the layout file smaller, but it would duplicate
or extract picker, permission, generation, inference, orientation, and result
state. That broader refactor adds risk without improving Android parity.

### Refactor every still workflow into shared visual components

This could eventually reduce the size of `FeatureRuntimePage`, but PoseNet,
Scene, Segmentation, Style Transfer, Object Photo, and Custom Model have
different Android structures. A cross-workflow refactor would mix several P1
increments and is excluded here.

## HarmonyOS Design

### Exact Route Boundary

Add `usesAndroidGestureStillLayout(workflow)` to
`FeatureWorkflowCatalog.ets`. It returns true only for
`AppRoute.GESTURE_STILL`, false for the other 15 workflows and `undefined`.
`FeatureRuntimePage.build()` selects the dedicated builder after Text
Translation/Text Recognition and before live or generic layout fallbacks.

### Reused Runtime Behavior

The dedicated screen calls only existing actions:

- `prepareInput('photo')` and `prepareInput('camera')`;
- `openLinkedLiveRoute()` for Real-time;
- `runtimePermissionRecoveryOverlay()` for denied camera/media access.

It reuses `imageInputUri`, `gestureImageUri`, `gestureImageOrientation`,
`gestureDetections`, `gestureImageWidth`, `gestureImageHeight`,
`visibleGestureDetections()`, `gestureBox()`, and `workflowRunning`. Therefore
album/camera cancellation, EXIF rotation, automatic inference, overlapping-run
protection, stale-result rejection, page-exit invalidation, MNN session reuse,
and detector cleanup remain unchanged.

No dictionary, ImageNet classifier, injected fake detector, or alternate
MediaPipe model is introduced. Production continues to use the exact HMS model
through `libgesture_mnn.so` and MNN.

### Dedicated Screen

Use a full-size outer Stack so the existing permission-recovery overlay remains
topmost. The content Column contains:

1. `runtimeActionToolbar(false)`.
2. Two 1vp `#E4E4E4` divider rows.
3. A weight-9, full-width, clipped `#E6E6E6` preview Stack.
4. A weight-1 action Row with the Android margins and equal 37vp buttons.

When no image has been selected, center the existing byte-identical
`app.media.icon_style` above
`workflow_summary_gesture_still_android_prompt`. When an image exists, keep it
visible with Contain semantics and the Android 50vp inset. When a successful
gesture result has renderable rectangles, use the existing oriented gesture
image and rectangle/label builders on that same primary surface. Do not render
the generic source-image preview or the separate labeled
`gesturePreview()` result card.

The dedicated surface preserves the current overlay normalization and clipping
contracts. Phone-specific letterboxing and coordinate tuning remain a device
validation item; this increment must not invent host-only offsets that differ
from the production detector output.

The three buttons use the existing Android-specific localized keys:

- `feature_input_photo_android`;
- `feature_input_camera_android`;
- `feature_runtime_go_live_android_hms`.

The normal visual state matches Android exactly. Pressed-state color/radius is
excluded until the project adopts one consistent ArkUI pressed-state pattern;
the same limitation already applies to the specialized Text Translation page.

### Failure Feedback

Removing the generic status/result cards must not make failures silent. After
a current, non-live Gesture Still request completes unsuccessfully, show the
existing localized result message through `showRuntimeToast()`. Successful
results do not show a Toast. Permission denial remains handled by the existing
recovery overlay, and stale/cancelled requests do not emit a late failure.

This matches Android's `processFailure()` behavior without changing AI result
contracts or affecting other workflows.

## Existing Behavior Retained

- all 16 workflow registrations and route names;
- the still Gesture Experience entry and linked live route;
- the exact HMS MNN model, thresholds, YOLO decoding, NMS, and category mapping;
- photo/camera permissions, picker cancellation, and automatic analysis;
- oriented image preview and existing gesture rectangle/label rendering;
- live gesture camera layout and front-camera mirroring;
- runtime request generation, session reuse, and cleanup;
- every non-Gesture-Still layout.

## Excluded Work

- no model extraction, conversion, training, or inference change;
- no MediaPipe branch merge or online translation code;
- no live-gesture layout or camera-loop change;
- no broad `FeatureRuntimePage` decomposition;
- no device-only accuracy, crop, orientation, font-metric, or overlay tuning;
- no translation-model quality work.

## Verification

- TDD an exhaustive `usesAndroidGestureStillLayout()` matrix for all 16
  workflows plus `undefined`;
- add a focused static guard requiring the dedicated build branch, the two
  dividers, empty-state icon/prompt, Photo/Camera/Real-time order, 50vp inset,
  and absence of generic cards inside the dedicated builder;
- retain existing tests for automatic still-gesture execution, HMS thresholds,
  gesture overlay normalization, request generation, permissions, and linked
  live routing;
- verify the Android and Harmony `icon_style.png` files remain byte-identical;
- run focused RED/GREEN checks, full Hypium, `git diff --check`, and unified
  main/`ohosTest` HAP AI-runtime acceptance;
- obtain an independent task review before accepting the implementation.

## Success Criteria

The static Gesture route no longer enters the generic card layout. It presents
the Android toolbar, dividers, weighted preview, prompt or selected image with
gesture overlay, and three-button action row while continuing to execute the
current HMS MNN detector. No other route changes, all host tests pass, both HAP
variants assemble and pass package inspection, and device-only evidence remains
explicitly deferred.
