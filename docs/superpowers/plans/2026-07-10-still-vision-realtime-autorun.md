# Still Vision Real-time + Auto-run Plan

**Goal:** Restore Android still-page behavior for Image Segmentation, Gesture Recognition, and Scene Detection.

**Scope:**
- Still Image Segmentation, Gesture Recognition, and Scene Detection expose their Android Real-time route action.
- Their `photo` and `camera` inputs auto-run analysis after the image is ready.
- Live routes continue to auto-start camera preview through the existing live-camera path.
- Do not migrate Android APK update/download behavior.

## Steps

- [x] Add failing tests for linked Real-time routes and still-image auto-run.
- [x] Add the minimal workflow catalog configuration.
- [x] Update platform-difference documentation.
- [x] Verify with Hypium tests, HAP build, diff check, read-only review, and commit.
