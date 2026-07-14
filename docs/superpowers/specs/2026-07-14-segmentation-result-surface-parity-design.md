# Segmentation Result Surface Android Parity Design

## Context

The HarmonyOS shared runtime currently renders every completed segmentation
foreground a second time in the result card and enables the direct image Save
control whenever any result image exists. This differs across the three Android
segmentation activities:

- `ImageSegmentationActivity` is a still-image workflow with a foreground
  result and Save action;
- `ImageSegmentationLiveAnalyseActivity` contains only the full-screen camera
  preview, segmentation overlay, and camera switch, with no Save action;
- `PortraitSegmentationActivity` overlays the foreground on a selected
  background and exposes `item_save` from `menu_setting`; that action saves the
  complete `mPreview` composition, not the foreground alone.

The Portrait Save behavior is declared in Java rather than the layout XML, so
layout-only comparison would incorrectly remove a real Android feature.

## Chosen Approach

Keep the shared runtime page and make the three route decisions explicit in
pure catalog helpers:

1. direct result Save is enabled only for Style Transfer and still
   Segmentation;
2. standalone segmentation foreground preview is enabled only for still
   Segmentation;
3. composite segmentation Save is enabled only for Portrait Segmentation.

Wire the result card through those helpers. Live Segmentation and Portrait keep
their foreground on the camera preview overlay and no longer render a duplicate
standalone foreground card. Portrait retains the background-replacement preview
and its component-snapshot Save control, preserving Android's composite save.

## Behavioral Matrix

| Workflow | Camera overlay | Standalone foreground | Direct Save | Composite Save |
| --- | --- | --- | --- | --- |
| Segmentation Still | no | yes | yes | no |
| Segmentation Live | yes | no | no | no |
| Portrait Segmentation | yes | no | no | yes |
| Style Transfer | n/a | n/a | yes | no |

The direct Save helper remains true before a processed image exists for Style
Transfer and still Segmentation, matching their existing always-reachable
Android controls. Actual save handlers continue to report failure if invoked
without a result.

## Verification

Add an exact route matrix to `LocalUnit.test.ets` for ready and not-ready
states. Tests must cover undefined and unrelated workflows, prove that the
Portrait direct Save assertion flips to false, and prove that only Portrait can
show composite Save. A separate matrix must prove that only still Segmentation
renders the standalone foreground result.

Run the full Hypium suite, compile both HAP variants through the unified AI
runtime acceptance, and independently review the page wiring against the three
Android activities.

## Non-Goals

- No change to segmentation inference, foreground mirroring, background
  selection, or media-write implementation.
- No change to the current shared page's 260vp live preview height; full-screen
  live-route layout parity is a separate layout increment.
- No device execution or segmentation accuracy claim.
- No removal of component snapshot infrastructure, which remains required for
  the Android-equivalent Portrait composite Save.

## Success Criteria

The increment is complete when live segmentation has only its camera overlay
and no Save, Portrait has only composite Save, still segmentation retains its
standalone foreground and direct Save, all tests and both HAP builds pass, and
the branch is reviewed and merged cleanly.
