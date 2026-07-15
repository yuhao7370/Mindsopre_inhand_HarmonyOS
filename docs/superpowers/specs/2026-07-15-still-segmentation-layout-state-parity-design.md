# Still Image Segmentation Android Layout and State Parity Design

## Context

Android's `/hms/ImageSegmentationActivity` is a dedicated black page with a
white toolbar, a 1dp divider, two equal-weight image areas, and a bottom row of
Photo, Camera, Real-time, and Save buttons. The upper area displays the current
source image and the lower area displays the transparent foreground returned
by HMS body segmentation. Both areas initially display `icon_default`.

HarmonyOS already has the complete functional path: the preserved still route,
photo and camera input, automatic local MindSpore Lite segmentation,
orientation-aware source handling, RGBA-to-`PixelMap` conversion, a linked live
segmentation route, permission recovery, and secure Gallery saving. The route
still falls through to the generic runtime cards, however, so it exposes UI and
state transitions that Android never renders.

The Android and HarmonyOS default Experience entry both open live
segmentation. The still page is therefore a compatibility route rather than a
default-path blocker, but completing it removes one of the final two generic
fallbacks.

## Goal

Give still image segmentation a dedicated Android-shaped HarmonyOS surface and
match Android's visible result-preservation, failure-feedback, and save
semantics without replacing the existing picker, camera, AI, permission,
`PixelMap`, live-route, or save services.

## Non-Goals

- No new model, SDK, route, dependency, native bridge, permission, string, or
  media asset.
- No changes to live segmentation or portrait segmentation layout/behavior.
- No generic result rows, rectangle overlays, debug/status cards, or manual Run
  control on the dedicated still page.
- No emulation of Android's unsafe external-storage/file-provider details.
- No claim of device rendering, picker/camera feel, segmentation accuracy,
  latency, memory, lifecycle, or secure `SaveButton` presentation validation.

## Chosen Architecture

Keep `FeatureRuntimePage` as the only controller. Add one exact route predicate,
small pure state/feedback policies, and one dedicated builder selected before
the generic fallback. Reuse the current request generation and
`RuntimePixelMapOwner` so stale asynchronous results cannot overwrite a newer
page state and replaced maps are released by their existing owner.

A second page/controller would duplicate the highest-risk inference, lifecycle,
permission, and save paths. Reshaping the generic fallback would retain
unrelated cards and risk changing the final scene route.

## Route And State Policies

Add these pure catalog policies:

- `usesAndroidStillSegmentationLayout(workflow)` is true only for
  `AppRoute.SEGMENTATION_STILL`.
- `stillSegmentationResultToastKey(workflow, resultOk)` returns the existing
  `feature_runtime_segmentation_failed` key only for failed still-segmentation
  results.
- Still-segmentation photo and camera inputs preserve the current foreground
  `PixelMap` and Save target when a new input becomes ready. The upper preview
  immediately switches to the new source URI.
- Still segmentation does not clear its foreground at run start, permission
  denial, a failed AI result, a thrown run, a successful segmentation result
  before its foreground conversion settles, or a rejected conversion.
- A successful current foreground conversion atomically replaces the prior
  `PixelMap`; stale conversions release their newly created map without changing
  the UI or showing feedback.
- Still segmentation accepts a valid foreground result even when its optional
  subject-rectangle list is empty. Rectangle availability remains a concern of
  the generic/live/portrait overlays, not a prerequisite for Android's lower
  foreground preview.

The selector and feedback/preservation policies remain false for live
segmentation, portrait segmentation, Style Transfer, and every other sibling
route.

## Dedicated Page

Render a full-height `Stack` containing the Android-shaped page and the existing
full-page `runtimePermissionRecoveryOverlay`:

1. Reuse the existing 56vp action toolbar with Back and localized title only,
   followed by a 1vp divider.
2. Use a black remaining-height `Column`. The upper and lower preview regions
   each use `layoutWeight(4)` and full width. The lower region has Android's
   20vp top margin. Empty regions center the existing `icon_default`; the upper
   region otherwise displays the current `imageInputUri`, and the lower region
   displays only `segmentationForegroundPixelMap`. Images use contain/fit-center
   behavior. No rectangle or background-composite overlay is rendered.
3. Use a bottom `Row` with `layoutWeight(1)` and 14vp top margin. Render four
   37vp equal-width controls in this exact order and spacing: Photo, Camera,
   Real-time, Save. Photo and Camera call the existing `prepareInput`, and
   Real-time calls `openLinkedLiveRoute`.
4. Save occupies the fourth Android position but remains a HarmonyOS secure
   `SaveButton`. It is always visible, is disabled and defensively rejected
   while inference is running, and uses a still-segmentation-only wrapper to
   show the existing missing/success/failure save result as a Toast. A denied
   secure click immediately maps to the existing save-failed Toast.

Photo, Camera, and Real-time are also visibly disabled while inference is
running; their existing controller guards remain the defensive backstop. This
bounded HarmonyOS safety difference prevents a new picker/navigation action
from racing a request whose controller has not yet left the running state.

The dedicated builder contains no generic summary, Inputs, Permissions,
status/result rows, foreground label, rectangle overlay, file preview, Help,
More, or Run cards.

## Async And Error Flow

- An accepted photo/camera pick first invalidates any pending foreground
  replacement without releasing the currently displayed map. It then updates
  the upper URI and auto-runs the existing workflow. Cancelled picks keep the
  current page state; unlike Android's obsolete null-gallery-data `finish()`
  edge, HarmonyOS does not unexpectedly leave the page.
- Run start and permission preparation retain the previous lower preview and
  Save target. Permission denial leaves the full-page recovery overlay
  available.
- A valid successful segmentation result updates nonvisual metadata as needed
  but keeps the old lower preview until RGBA conversion completes. For the
  still route, `applyAiResult` awaits that conversion so `workflowRunning`
  remains true until the new map is accepted or rejected.
- A current successful conversion atomically accepts the new map and releases
  the old one. Invalid dimensions/bytes or a rejected conversion are treated as
  a visible segmentation failure: the previous lower preview/Save target is
  preserved and the failure Toast is shown. A stale conversion has no user
  feedback.
- An ordinary failed AI result or thrown run preserves the previous lower
  preview/Save target and shows the localized segmentation-failed Toast. The
  selected new source remains visible above, matching Android's independent
  `originBitmap` and `bitmapFore` fields.
- The low-value Android edge where a nominal success assigns a null foreground
  field while leaving the old `ImageView` drawable visible is not reproduced;
  an invalid/missing foreground is consistently a failed replacement and the
  previous owned Save target remains available.

## Verification

- Hypium tests cover the exact selector, result Toast, input-ready
  preservation, run-start preservation, AI-result preservation, and sibling
  negatives.
- A dependency-free PowerShell guard bounds the dedicated builder and critical
  input/result/save call sites, verifies toolbar/divider/black page, two
  weighted previews, default placeholders, button order/margins, secure Save,
  running guards, permission overlay, awaited atomic replacement, and exclusion
  of generic cards/overlays.
- Mutation fixtures prove comments, strings, wrong selectors, wrong order,
  removed preservation, fire-and-forget conversion, missing Toast/save guards,
  and injected generic surfaces cannot satisfy the production guard.
- Existing segmentation service, live/portrait segmentation, save service,
  Style Transfer, Object Photo, model, route, and i18n tests remain green.
- Fresh Hypium and unified acceptance must pass in the isolated feature
  worktree and again on merged `master`; main and `ohosTest` HAP structures and
  model payloads remain verified.
