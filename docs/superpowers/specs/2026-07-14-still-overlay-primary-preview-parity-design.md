# Still Overlay Primary Preview Android Parity Design

## Context

Three default still-image workflows currently show the selected image twice on
HarmonyOS after a successful inference: once in the generic input preview card
and again in a result preview containing boxes or skeletons.

Android uses one visual surface for each workflow:

- Object Photo sets the mutable bitmap on `preview`, draws detections onto that
  bitmap, and leaves the same ImageView in place;
- PoseNet places `img_origin` and `skeleton_previewOverlay` in the same
  FrameLayout;
- Gesture Still uses the same ImageView-plus-GraphicOverlay structure.

The original image remains visible before inference and when no usable overlay
result exists. Only a successful, renderable overlay replaces it visually.

## Chosen Approach

Add one pure route policy,
`shouldShowPrimaryImageInputPreview(workflow, overlayReady)`. It returns false
only when `overlayReady` is true for Object Photo, PoseNet Still, or Gesture
Still. Every other workflow and every not-ready state keeps the generic image
preview.

`FeatureRuntimePage` computes whether the active route has a renderable primary
overlay from the same state used by its result builders:

- Object Photo: non-empty result image URI and at least one detection;
- PoseNet Still: non-empty result image URI and at least one pose point;
- Gesture Still: non-empty result image URI and at least one visible gesture.

Use the policy both when deciding whether the generic preview card has any
visible content and when rendering `imageInputUri`. This avoids leaving an
empty card title after the original image is hidden. Other input previews,
including selected model files, remain visible.

## State Behavior

| Workflow | Overlay not ready | Overlay ready |
| --- | --- | --- |
| Object Photo | show input image | show detection result only |
| PoseNet Still | show input/sample image | show pose result only |
| Gesture Still | show input image | show gesture result only |
| Any other route | show input image | show input image |

Failed, empty, cancelled, or stale inference never sets a renderable overlay,
so the source image is not hidden.

## Verification

Add exact route-by-ready tests for the three target workflows, related live
routes, unrelated still routes, and `undefined`. Add focused tests for the page
overlay-ready computation if extracted as a pure helper; otherwise compile and
independently review that the same predicate gates both the preview-card
presence and `imageInputUri` rendering.

Completion requires the full Hypium suite, unified main/ohosTest HAP
acceptance, clean Git state, and an independent review against the Android
ImageView/GraphicOverlay implementations.

## Non-Goals

- No change to inference, overlay geometry, image orientation, or result data.
- No change to live-camera workflows.
- No removal of model-file or secondary Style Transfer previews.
- No device execution or visual-accuracy claim.

## Success Criteria

After a valid result, each target workflow shows one primary image surface with
its Android-equivalent overlay. Before a result or after failure, the selected
image remains visible. All tests and both HAP builds pass.
