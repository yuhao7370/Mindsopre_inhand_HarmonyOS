# Runtime Layout Closure Design

## Goal

Lock the completed Android-to-Harmony runtime-page migration so every registered
AI workflow is rendered by exactly one dedicated Android-compatible layout and
the generic layout remains reachable only for an unknown route.

## Current state

`featureWorkflows` contains 16 routes. The runtime page currently covers them
with 13 selector branches:

- ten one-route still/specialized selectors;
- two values returned by `specializedAndroidLiveLayoutForWorkflow`;
- one simple-live selector covering four routes.

The union is complete today, but existing tests are distributed by feature.
They do not prove that every registered workflow matches exactly one layout
family. Existing static guards also do not bind every selector branch to its
intended builder, so a sibling-builder call can pass a per-feature selector
test.

## Design

### Exhaustive workflow contract

Add one Hypium test over the production `featureWorkflows` catalog. For each
workflow, count matches across the ten boolean selectors, the two specialized
live values, and the simple-live selector. Require exactly one match. Require
the catalog size to remain 16 and `undefined` to match none.

This intentionally derives coverage from production selectors rather than a
second route table. Adding a workflow without a layout or widening two
selectors onto the same route fails the test.

### Selector-to-builder structural guard

Add one production PowerShell guard that reads the `build()` method of
`FeatureRuntimePage.ets` and requires the exact ordered 13-branch chain:

1. Text Translation → `textTranslationAndroidLayout`
2. Text Recognition → `textRecognitionAndroidLayout`
3. PoseNet still → `poseNetStillAndroidLayout`
4. Gesture still → `gestureStillAndroidLayout`
5. Object Photo → `objectPhotoAndroidLayout`
6. Style Transfer → `styleTransferAndroidLayout`
7. Custom Model → `customModelAndroidLayout`
8. Still Segmentation → `stillSegmentationAndroidLayout`
9. Still Scene → `stillSceneAndroidLayout`
10. Portrait Segmentation → `portraitSegmentationAndroidLayout`
11. specialized image classification → `imageClassificationAndroidLiveLayout`
12. specialized object detection → `objectDetectionAndroidLiveLayout`
13. simple live → `simpleAndroidLiveLayout`

The final generic `else` must follow those branches. The guard is bounded to
the `build()` method and must ignore selector/builder text in comments or quoted
strings.

### Guard qualification

Add a mutation suite with a minimal valid fixture. It must prove rejection of:

- a missing branch;
- swapped sibling builders;
- a widened or changed selector;
- reordered branches;
- generic fallback inserted before the final specialized branch;
- quoted/comment decoys;
- missing top-level build-script wiring.

Wire the mutation suite and production guard into `build-hap.ps1` before
Hvigor assembly.

## Scope

This change adds acceptance coverage only. It does not change a route,
selector, builder, model, service, UI, or device boundary. The current 16-route
catalog remains the Android-reachable migration baseline; a deliberate future
route addition must extend both the catalog and its dedicated layout.

## Verification

- observe the aggregate Hypium test fail against an intentionally incomplete
  local expression before adding its final form;
- observe the mutation suite reject every mutation and accept the valid
  fixture;
- run production guard, PowerShell parsing, full Hypium, `build-hap.ps1`, and
  unified AI-runtime acceptance;
- obtain independent review before merging to `master`.
