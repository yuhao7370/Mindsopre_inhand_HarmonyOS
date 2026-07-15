# Object Photo Android Layout and State Parity Design

## Context

Android's reachable `/imageobject/ObjectPhotoActivity` is not a generic AI
form. `activity_object_photo.xml` contains a white 56dp toolbar, one centered
image/result surface, and one blue `Select Model` button fixed 16dp from the
bottom-right corner. The Activity opens the system album immediately, runs SSD
object detection synchronously after a valid pick, draws labels and boxes into
the image, shows a Toast when no object is detected, and finishes when the
initial album pick is invalid or cancelled. A compatible custom model causes
the Activity to recreate and immediately request a new album image.

HarmonyOS already has the important runtime behavior: the initial album pick,
cancel-and-return rule, keep-screen-on policy, bundled SSD runtime, optional
cached model override, localized labels, oriented overlay geometry, automatic
execution, local Help, and More URL. The remaining visible mismatch is that the
route still falls through to the generic runtime cards.

## Goal

Give Object Photo a dedicated Android-shaped page and close its terminal and
model-reload state differences without changing the existing object-detection
runtime, picker service, model contract, or sibling routes.

## Non-Goals

- No new detector, model format, image decoder, or camera path.
- No changes to Object Camera.
- No generic arbitrary-model support.
- No Android APK update/download behavior.
- No claim that picker presentation, image scaling, overlay geometry, Toast
  appearance, latency, or memory behavior was verified on a device.

## Route Policy

Add `usesAndroidObjectPhotoLayout(workflow)` as an exact route predicate. The
dedicated builder must be selected before the generic fallback and must not
change the selectors for Text Translation, Text Recognition, PoseNet, Static
Gesture, Custom Model, Portrait Segmentation, or live-camera routes.

Add two narrow state policies:

- `objectPhotoResultToastKey(workflow, resultOk)` returns the existing
  `feature_runtime_object_detection_failed` key only for a failed Object Photo
  run. Success and every other route return `undefined`.
- `objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind)`
  returns `photo` only after a successful Object Photo `modelFile` cache result.
  The page then opens that photo picker with initial-pick semantics, matching
  Android recreation: selection auto-runs detection and cancellation returns to
  the previous page.

Failed/incompatible/cancelled model picks do not open the photo picker and do
not replace the last valid cached model.

## Dedicated Page

The page is a full-height white `Column`:

1. A 56vp white toolbar with the existing Android back icon, localized Photo
   Detection title, Help icon, and More icon. Existing handlers are reused.
2. A remaining-height centered preview surface. Before a terminal result it
   may show the selected input image; after successful detection it shows the
   existing oriented object overlay with all labels and boxes. Empty detection
   retains the selected image and reports the failure through Toast.
3. A normal Android-blue `Select Model` button with white 16fp text, aligned
   bottom-right with 16vp margins. It invokes the existing `modelFile` picker
   and is disabled while the non-live runtime guard is active.

The dedicated builder renders no summary, input, permission, status, result,
debug, save, or generic Run cards. Detection rows remain internal state used by
the overlay; Android exposes them visually on the image rather than in a
separate result list.

## Existing Behavior Preserved

- The initial page entry still opens `photo` exactly once.
- Cancelling that initial picker still shows the localized invalid-image Toast
  and navigates back.
- A valid photo still auto-runs the bundled or cached SSD model.
- Model files still publish atomically to the fixed object-model cache path and
  are restored on later page creation.
- The Object Photo route alone keeps the screen on.
- Help and More retain their current local-dialog and web destinations.

## Verification

- Hypium tests cover the exact selector, failure Toast policy, and successful
  model-cache follow-up policy, including sibling-route negatives.
- A dependency-free PowerShell guard strips comments, bounds the dedicated
  builder and build selector, and checks the Android toolbar, centered preview,
  bottom-right model button, absence of generic cards, Toast call site,
  model-success follow-up call site, and build-script wiring.
- Existing Object Photo input/lifecycle/cache tests remain green.
- The unified host acceptance builds main and `ohosTest` HAPs and verifies AI
  models, native libraries, translation assets, and packaged bytes.

