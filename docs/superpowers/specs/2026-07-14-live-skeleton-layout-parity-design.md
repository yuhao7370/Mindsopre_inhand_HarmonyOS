# Live Skeleton Android Layout Parity Design

## Goal

Port the reachable Android Live Skeleton activity to its toolbar-plus-full
camera layout without changing the working pose/yoga inference pipeline.

Live Skeleton is reached from PoseNet's linked Live action. It is not a new
catalog entry.

## Android source of truth

`activity_live_skeleton_analyse.xml` contains:

- a white action-bar-height toolbar with Back and the PoseNet title;
- a camera/graphic-overlay preview filling all space below the toolbar;
- a 35dp camera switch centered at the bottom with 30dp bottom margin;
- a 135dp by 169dp skeleton template at the lower-right edge;
- a white, 13dp, 18dp-high `similarity:NN%` label immediately above the
  template and aligned to its left edge.

The Android activity always uses yoga analysis. It exposes no normal/yoga
switch despite retaining unused switch-listener code. The camera stream is
configured for 25fps.

## HarmonyOS design

The page shell is structurally identical to the existing simple Android live
layout. Extend `usesSimpleAndroidLiveLayout()` to include exactly
`LIVE_SKELETON` in addition to Live Segmentation, Live Gesture, and Live Scene.
This reuses the one toolbar, one `XComponent` lifecycle, one camera switch, and
one permission recovery overlay.

Update the existing pose-template overlay rather than adding a second one:

- remove its 10vp right/bottom inset;
- use a 135vp by 169vp template with `Contain` fitting;
- show one `similarity:NN%` line, 13fp, white, height 18vp;
- remove the current translucent label background and rounded card styling.

The route already uses yoga mode, the Android template coordinates and image,
pose lines/points, default rear camera, capability-aware switch, and similarity
calculation. Preserve those paths.

Keep the current 1000ms host-side frame interval. Android's 25fps analyzer is a
streaming SDK pipeline, while the Harmony implementation encodes frames and
runs local inference; changing to 25fps without device profiling would risk
overlapping work and is outside the current build-only validation scope.

## Excluded work

- no new route or catalog entry;
- no normal/yoga toggle;
- no copied XComponent or pose service;
- no Portrait changes;
- no device-only frame-rate, crop, rotation, or overlay tuning.

## Verification

- TDD the exhaustive simple-layout route set at exactly four workflows.
- Preserve yoga mode, fixed template coordinates, similarity, camera position,
  switch capability, and live overlay tests.
- Confirm the page still contains exactly one XComponent declaration.
- Run full Hypium, `git diff --check`, unified HAP/AI acceptance, and
  independent reviews before fast-forward merge.

