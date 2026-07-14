# Portrait Camera Android Layout Parity Design

## Goal

Port the registered Portrait Segmentation route to Android's full-screen
background-replacement activity while preserving its current hidden status.
Neither Android nor Harmony exposes this route from the normal catalog, so this
increment must not add an entry.

## Android source of truth

`activity_portrait.xml`, `menu_setting.xml`, and
`PortraitSegmentationActivity` define:

- a white toolbar with Back, title, camera switch, and Save actions;
- a preview filling the remaining page;
- an opaque selected background and transparent segmented person over the
  camera preview;
- front camera by default and horizontal foreground mirroring for front camera;
- a bottom 5dp gray divider plus a 100dp horizontal background picker;
- five bundled backgrounds and a sixth custom-gallery tile;
- 95dp by 120dp picker images with `fitXY`, clipped by the 100dp strip;
- saving the combined background/person preview rather than foreground alone.

The Android save helper also crops the preview to its upper-left 90%. That is a
legacy defect, not a desired UI behavior.

## HarmonyOS design

### Route boundary

Add a pure `usesAndroidPortraitSegmentationLayout()` helper that is true only
for `PORTRAIT_SEGMENTATION`. The route remains absent from the visible feature
catalog.

### One camera surface, separate composite layer

Keep the one existing `XComponent` and all camera/frame lifecycle logic. For
Portrait only, suppress the generic foreground-only camera overlay and compose
these ArkUI layers in a dedicated full-size Stack:

1. selected background image, Fill;
2. segmented foreground PixelMap when available, Fill and mirrored for front
   camera.

Bind `segmentationBackgroundReplacementComponentId` to this composite Stack.
The save action snapshots only that Stack, so the XComponent, toolbar,
permission recovery, divider, and picker are excluded reliably.

### Toolbar

Render Back, title, the Android `icon_camera.png`, and an icon-only native
`SaveButton`. Camera invokes the existing switch path. `SaveButton` is retained
instead of a normal Image click because Harmony uses it to grant temporary
media-save authorization.

Save the complete composite. Do not reproduce Android's accidental 90% crop.

### Background picker

Overlay a 5vp gray divider and a 100vp horizontal `List` at the bottom of the
preview. Each of the five presets and the custom tile is 95vp by 120vp, uses
Fill, and has no caption, border, or selected decoration. Clip the List to its
100vp height. Presets call the existing selection state path; the custom tile
calls `prepareInput('backgroundImage')` and retains existing cancellation
state.

### Existing behavior retained

- five Android-identical background images and default `portrait1`;
- custom picker and cancellation behavior;
- foreground-only body segmentation and front-camera mirroring;
- front camera default, capability-aware switching, and live loop;
- full composite snapshot/media writer and success/failure status;
- topmost permission retry/settings recovery.

## Excluded work

- no catalog/linked route entry;
- no new AI/camera service;
- no 25fps change without device profiling;
- no Android 90% save crop;
- no device-only crop/rotation/snapshot/media validation.

## Verification

- TDD an exhaustive route helper contract including `undefined`.
- Preserve existing tests for default background, five presets, custom cancel,
  mirror, composite-save eligibility, and background state retention.
- Confirm exactly one XComponent and the Android camera asset in the HAP.
- Run full Hypium, `git diff --check`, unified HAP/AI acceptance, and two-stage
  independent review before merge.

