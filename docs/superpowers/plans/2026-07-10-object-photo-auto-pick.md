# Object Photo Auto Pick Implementation Plan

**Goal:** Match Android `ObjectPhotoActivity`: opening the photo route starts album selection, and a selected image immediately runs object detection.

**Scope:**
- `/imageobject/ObjectPhotoActivity` auto-prepares its `photo` input once on page entry.
- A ready `photo` input on Object Photo auto-runs detection.
- Keep the optional `.ms` model picker behavior unchanged.
- Do not migrate Android APK update/download behavior.

## Steps

- [x] Add failing tests for Object Photo initial photo input and photo-ready auto-run.
- [x] Add the minimal workflow decisions.
- [x] Wire `FeatureRuntimePage` to auto-prepare the initial input once.
- [x] Verify with Hypium tests, HAP build, diff check, read-only review, and commit.
