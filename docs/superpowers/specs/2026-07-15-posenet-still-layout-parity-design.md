# PoseNet Still Layout Android Parity Design

## Goal

Match Android's `/hms/PosenetMainActivitys` screen without changing the
working HarmonyOS pose inference pipeline. Device-only visual tuning remains
deferred.

## Source behavior

Android renders a Back/title toolbar, one 1dp `#E4E4E4` divider, a weight-9
`#E6E6E6` image and skeleton overlay, and a weight-1 row of Photo, Camera,
Real-time, and Detect buttons. The bundled `skeleton_image` is the initial
image. Photo and Camera run detection after selection; Detect restores the
bundled image and runs it; Real-time opens Live Skeleton. Completed and failed
detections use Toast feedback.

HarmonyOS already has the bundled sample, Photo/Camera auto-run, live-route
navigation, permission recovery, request-current checks, and pose overlay.
The remaining gap is that PoseNet still uses the generic Scroll/Card runtime
page and its generic Run action.

## Approaches considered

1. Add a PoseNet-only builder to `FeatureRuntimePage`. This is the selected
   approach because it reuses all working state and service paths and follows
   the existing dedicated-layout pattern.
2. Generalize the Gesture and PoseNet still layouts. Their divider count,
   preview inset, empty state, button count, and Detect behavior differ, so a
   shared abstraction would add branching without useful reuse.
3. Add a separate page. This would duplicate or force extraction of picker,
   permission, inference-session, and stale-request behavior.

## Page structure

Add `usesAndroidPoseNetStillLayout()` scoped only to `AppRoute.POSENET` and
select a new `poseNetStillAndroidLayout()` before the generic fallback.

The dedicated page contains:

- the existing 56vp toolbar with actions hidden;
- one 1vp `#E4E4E4` divider;
- one weight-9 `#E6E6E6` preview surface;
- one weight-1 action row with a 14vp top margin;
- Photo, Camera, Real-time, and Detect buttons in Android order and geometry;
- the existing permission recovery overlay above the page.

The preview is a single image/overlay coordinate surface. Before a valid pose
result it shows `imageInputUri`, including the initial bundled sample. With a
result it shows the result image and reuses the existing pose coordinate and
skeleton calculations. PoseNet still uses dedicated overlay builders with
Android's `#00FF00` lines and `#FF0000` points; the shared builders keep their
current colors so Live Skeleton is unchanged. The image keeps its aspect ratio
and starts at the top. Line width and point radius stay unchanged until device
evidence justifies px-to-vp tuning.

The dedicated branch does not render the generic summary, input, permission,
URI, status, result, or debug cards.

## Actions and result feedback

Photo and Camera keep the current picker and automatic detection path.
Real-time keeps `openLinkedLiveRoute()`.

Detect resolves the existing PoseNet initial preview action, restores its
sample URI as the current primary image, clears stale visual results through
the existing input path, and runs pose detection. It does not introduce a
second sample constant or a second inference entry point.

Add these Android-specific keys in base, `zh_CN`, and `en_US`:

- `feature_runtime_pose_detect_android`: `检测` / `detect`;
- `feature_runtime_pose_detect_success_android`: `检测成功` /
  `Detection succeeded`;
- `feature_runtime_pose_detect_failed_android`: `检测失败` /
  `Detection failed`.

A successful current PoseNet result maps to the success key. A failed current
PoseNet result or runtime exception maps to the failure key. Permission denial
does not show a Toast and remains represented by the permission recovery
overlay. Existing current/stale request checks continue to prevent late
Toasts after navigation or input replacement.

## Verification

- Hypium exhaustively tests the PoseNet-only selector across all workflows and
  `undefined`.
- Policy tests cover PoseNet success/failure Toasts and exclude every other
  route.
- Existing tests continue to prove sample URI, Photo/Camera auto-run, and the
  linked Live Skeleton route.
- A dependency-free PowerShell guard checks the dedicated build branch,
  one-divider and weight-9/1 structure, background color, button order,
  Detect sample handler, generic-card exclusions, and both result/failure
  Toast call sites.
- The guard is wired into `scripts/build-hap.ps1`.
- Complete Hypium, unified AI runtime HAP acceptance, and `git diff --check`
  must pass.

No pose model, native library, preprocessing, thresholds, service selection,
or live-camera implementation changes are in scope.

## Deferred device checks

Real-device validation is limited to image letterboxing and EXIF orientation,
raw-pixel versus vp overlay thickness, Toast presentation, and camera/picker
interaction feel. These do not block source migration or build acceptance.
