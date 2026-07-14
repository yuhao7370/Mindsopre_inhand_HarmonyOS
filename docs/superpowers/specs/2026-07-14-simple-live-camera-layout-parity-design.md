# Simple Live Camera Layout Android Parity Design

## Context

Android's Live Gesture, Live Scene, and Live Segmentation activities share the
same page structure: a toolbar followed by a camera preview that fills every
remaining pixel, an in-preview analysis overlay, and a 35dp camera-switch
control floating at the bottom center. They do not show separate summary,
input, permission, or result cards.

HarmonyOS currently renders all live workflows inside the shared scrollable
feature form. The camera preview is fixed to 260vp inside an input card, the
switch sits below that card, and summary/permission/result cards consume most
of the page. Although inference and overlay rendering work, the central live
camera experience is not a 1:1 port.

Other live activities are intentionally excluded from this first layout group:

- Image Camera has an Android-specific bottom classification panel;
- Object Camera has a floating model-selection control;
- Live Skeleton adds a template image and similarity label;
- Portrait Segmentation adds a fixed background strip and toolbar Save.

## Chosen Approach

Add `usesSimpleAndroidLiveLayout(workflow)`, true only for Segmentation Live,
Gesture Live, and Scene Live. `FeatureRuntimePage.build()` uses a separate,
non-scroll page branch for that exact set:

1. a compact toolbar containing Android's back action and title only;
2. a camera Stack with `layoutWeight(1)` so it fills the remaining viewport;
3. the existing XComponent and all existing AI overlays;
4. the camera switch floating inside the preview at bottom center.

Extract the common camera-surface children from the existing card builder so
both page branches use one XComponent lifecycle and one set of overlays. The
normal shared form and all excluded live routes keep their current layout until
their dedicated increments.

## Permission Recovery

The shared result card currently owns camera-permission retry and settings
actions. Removing that card must not strand a denied user. The simple live
preview therefore shows a compact centered recovery overlay only when
`shouldShowRuntimePermissionRetry()` is true. It contains the existing status,
Retry, and Open Settings actions and calls the same handlers.

No permanent status or result panel is shown during normal live inference;
gesture boxes, scene labels, and the segmentation foreground remain in-preview
overlays as on Android.

## Layout Boundaries

- The toolbar is fixed at 56vp and the preview flex-fills below it.
- The preview has no card border, rounded clipping, heading, or scroll behavior.
- The switch remains conditional on both camera positions being available and
  uses the existing Android media asset and switching logic.
- The simple branch has no Help/More actions because the corresponding Android
  live toolbars contain only navigation and title.
- Back navigation and XComponent destruction retain their existing handlers.

## Verification

Unit tests lock the helper's exact positive set by iterating all workflows and
assert false for Image Camera, Object Camera, Live Skeleton, Portrait, every
still route, and `undefined`.

Compilation plus independent source review must confirm that the simple branch
contains no Scroll or permanent form/result cards, uses the shared camera
surface content, places the switch inside the preview, and preserves permission
recovery. The full Hypium suite and unified main/ohosTest HAP acceptance must
pass.

## Non-Goals

- No layout change for Image Camera, Object Camera, Live Skeleton, or Portrait.
- No inference, camera, overlay, interval, or permission-state change.
- No device rotation, safe-area, or real-device visual validation claim.
- No redesign of the normal still-workflow form.

## Success Criteria

The three selected routes build as toolbar-plus-flex-fill-camera pages, retain
their existing live overlays and camera switch, provide permission recovery,
show no duplicate form/result cards, and pass all automated checks and review.
