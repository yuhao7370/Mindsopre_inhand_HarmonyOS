# PoseNet Sample Input Android Parity Design

Date: 2026-07-14
Status: approved by delegated execution authority

## Problem

Android's still PoseNet layout displays `skeleton_image` as the initial preview
and exposes four actions: Photo, Camera, Real-time, and Detect. It does not
expose a separate Sample Image input action.

HarmonyOS currently keeps the correct initial sample preview but also lists
`sampleImage` in PoseNet's visible `inputKinds`. The shared runtime therefore
renders an extra Sample Image chip that has no Android counterpart.

## Constraints

- Keep the bundled `skeleton_image.JPG` and its initial preview.
- Keep the initial sample from auto-running until Detect is selected.
- Keep Photo and Camera visible and auto-running when their selected image is
  ready.
- Keep the manual Detect action and linked Real-time route.
- Keep the internal `sampleImage` input kind because it represents the initial
  preview action and remains useful to shared runtime helpers.
- Do not change pose inference, camera behavior, AI services, permissions,
  resources, navigation, or other workflow input lists.
- Do not add a flag, dependency, or page-specific filter.

## Options Considered

### A. Remove `sampleImage` from PoseNet's visible `inputKinds`

Keep `sampleImageRawfilePath` and `initialPreviewActionForWorkflow()` intact.
This is selected because the catalog's visible input list then directly
matches Android while the initial preview remains independent.

### B. Filter `sampleImage` inside `FeatureRuntimePage`

This would hide a catalog inconsistency with a page-specific exception and
couple shared UI code to PoseNet. It is unnecessary.

### C. Keep the extra chip as a HarmonyOS enhancement

This preserves functionality but violates the requested 1:1 reachable UI.

## Design

PoseNet's `inputKinds` becomes `['photo', 'camera']`. Its
`sampleImageRawfilePath`, linked live route, primary Detect policy, and initial
preview action do not change.

Tests will assert the UI-facing `runtimeInputKindsForWorkflow(posenet)` is
exactly Photo and Camera, while the initial preview is still the Android sample
with `shouldRunWorkflow=false`. Existing generic sample-kind mappings remain.

The PoseNet platform-difference documentation will describe the sample as an
initial preview, not as a visible input control.

## Acceptance

- PoseNet UI-facing input kinds contain Photo and Camera, not Sample Image.
- The bundled sample URI and initial preview action remain unchanged.
- Detect remains visible through the existing primary-action policy.
- Photo/Camera auto-run and Real-time navigation tests remain green.
- Complete Hypium and unified HAP acceptance pass.
- No device execution is claimed.
