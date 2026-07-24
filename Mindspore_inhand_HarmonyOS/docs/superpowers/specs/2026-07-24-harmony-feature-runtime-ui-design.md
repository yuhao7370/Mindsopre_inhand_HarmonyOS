# HarmonyOS Feature Runtime UI Design

Date: 2026-07-24

## Goal

Replace the remaining Android-parity presentation in `FeatureRuntimePage.ets`
with the project's HarmonyOS-native visual language while preserving every
route, inference path, permission boundary, camera policy, input state, result
mapping, save gate, and view ID.

The implementation covers all 16 registered workflows and their 13 existing
layout families. Public custom-model entry points and model-file selectors stay
hidden, but their underlying route and cached-input behavior remain intact.

## Design language

- Use the system font, `AppColor`, `AppSpacing`, `AppRadius`, native controls,
  and the existing flat icon resources.
- Use a light page background, white content cards, a subtle 1vp divider, and
  no persistent card shadow.
- Normal feature pages use a content-driven native title bar. Back, help, more,
  camera-switch, and save controls have at least a 48vp hit area and a localized
  accessibility name.
- Titles may wrap to two lines. No user-facing control uses a fixed height that
  is smaller than its scaled text.
- Static-image and text workflows use one top-level `Scroll`. Live-camera
  workflows keep the camera as the main canvas and place only lightweight
  status/result overlays inside safe insets.
- Groups of three or four text actions become a two-column wrapping grid.
  Actions use `minHeight: 48`, content-driven height, and clear primary /
  secondary hierarchy.
- Input, running, success, failure, and retry states are visible. A failure
  preserves the selected input and last valid visual result.
- Preview images preserve aspect ratio. Ordinary input uses `Contain`;
  background imagery may use `Cover`; overlay-coordinate images keep their
  existing fit/orientation/coordinate contract.
- Selection is never expressed by color alone. Style/background choices add a
  native selected mark or localized selected state.

## Shared page contracts

### Runtime title bar

`runtimeActionToolbar` and `portraitSegmentationToolbar` remain the only
specialized title builders. They become content-driven, expose 48vp semantic
actions, permit a two-line title, and retain their current handlers and order.

### Status and recovery

Each specialized layout renders the existing `statusKey` in a compact status
region. Loading remains non-destructive. Failure exposes the existing retry
handler appropriate to the route.

`runtimePermissionRecoveryOverlay` uses a full-screen scrim, blocks the
underlying hit targets, and contains a scrollable/content-driven white card.
Retry is primary; Settings is secondary. Both controls are at least 48vp.

### Static image layouts

The scene, pose, gesture, photo-object, still-segmentation, and OCR layouts use:

1. native title bar;
2. one preview card that switches between empty/input/result states;
3. visible status/retry feedback;
4. a two-column action grid;
5. preserved image, overlay, result, and cancel semantics.

### Live camera layouts

Image classification, object detection, live segmentation, live gesture, live
scene, and live skeleton keep the camera surface full-width. They use:

- safe-inset title/actions;
- a 48vp camera switch only where the route policy allows it;
- bounded high-contrast result labels;
- visible camera/preparation/inference error and retry state;
- no permanent 100vp result panel covering the camera.

### Text layouts

OCR keeps its image preview and long recognized text in the page's single
scroll. Translation uses one top-level scroll for the editable input card,
primary Translate action, result card, and image/camera/copy actions. The
focused input and primary action must remain scroll-reachable with the keyboard
open.

### Style and portrait layouts

Style transfer keeps one main preview, a scrollable style-choice region, a
selected mark, running/result status, and save readiness. Its two model-file
buttons are not rendered.

Portrait segmentation keeps its unique composite view ID, background presets,
camera position policy, selected state, and single-flight save contract.
Background and foreground fits remain consistent with the model-coordinate
mapping.

### Hidden custom-model capability

- `FeatureCatalog.visibleByDefault` remains the only public catalog visibility
  source.
- The complete custom-model route stays implemented for direct smoke testing.
- Public cards and model-file selectors inside object/style workflows remain
  hidden.
- Optional model inputs, cache restoration, inference parameters, and routes
  are not deleted or changed.

## Workflow-to-layout matrix

| Workflow | Existing layout family | Entry status |
| --- | --- | --- |
| PoseNet still | `poseNetStillAndroidLayout` | catalog |
| Live skeleton | `simpleAndroidLiveLayout` | linked from PoseNet |
| Still segmentation | `stillSegmentationAndroidLayout` | associated route |
| Live segmentation | `simpleAndroidLiveLayout` | catalog |
| Portrait segmentation | `portraitSegmentationAndroidLayout` | associated route |
| Live classification | `imageClassificationAndroidLiveLayout` | catalog |
| Gesture still | `gestureStillAndroidLayout` | catalog |
| Gesture live | `simpleAndroidLiveLayout` | linked from still gesture |
| Scene still | `stillSceneAndroidLayout` | hidden |
| Scene live | `simpleAndroidLiveLayout` | linked from hidden scene route |
| Text recognition | `textRecognitionAndroidLayout` | catalog |
| Text translation | `textTranslationAndroidLayout` | catalog |
| Object photo | `objectPhotoAndroidLayout` | catalog |
| Object live | `objectDetectionAndroidLiveLayout` | catalog |
| Style transfer | `styleTransferAndroidLayout` | catalog |
| Custom model | `customModelAndroidLayout` | hidden |

## Frozen functional contracts

- The workflow selector order and 16-to-13 mapping do not change.
- Picker cancellation preserves the previous input.
- Model-cache failure and restoration behavior remain available.
- EXIF orientation and overlay coordinate projection remain paired.
- The portrait composite view ID remains bound only to the outer composite
  Stack.
- Fixed-camera routes never gain a camera-switch action.
- Segmentation and portrait saves retain readiness and single-flight gating.
- Translation restores text mode after image/camera input is cancelled.
- Live workflows request camera at use time; media is requested only by
  photo/gallery use.
- Startup remains permission-free.

## Accessibility and responsive acceptance

Every user-reachable route is verified at default and 3.2x font scale using
HDC native touch, `dumpLayout`, and `snapshot_display`. Hidden routes use an
isolated direct-route harness and are restored to the production HAP afterward.

Acceptance requires:

- no clipped title/action/result text;
- every interactive target at least 44vp, with primary controls at least 48vp;
- the last action clear of the navigation-indicator inset;
- all actions reachable through the page's intended single scroll;
- localized semantic names for icon-only actions;
- initial, running, success, failure/retry, and permission-denied evidence;
- representative 1:1, portrait, landscape, tall, and oriented image evidence
  where the route consumes images;
- no Computer Use unless HDC cannot express the required system interaction,
  with the exception documented before use.

## Commit rule

Shared chrome/recovery and route-neutral simple-live geometry are committed
first as infrastructure and do not claim any workflow complete. After that,
each of the 16 workflows is implemented, verified, and committed before the
next workflow begins. A commit cannot claim a feature complete without its
focused guard/mutation evidence and native HDC evidence.
