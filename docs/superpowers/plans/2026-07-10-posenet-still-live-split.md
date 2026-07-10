# PoseNet Still/Live Split Implementation Plan

**Goal:** Restore Android PoseNet's still page and live skeleton page split in the HarmonyOS runtime.

**Scope:**
- `/hms/PosenetMainActivitys` is a still-image workflow with sample image, album image, and camera capture inputs.
- `/posenet/LiveSkeletonAnalyseActivity` stays the live camera workflow and keeps the Android template similarity view.
- The still page exposes a localized Real-time action that navigates to the live route.
- Bundle Android's `skeleton_image.JPG` as a local HarmonyOS rawfile sample input.
- Do not change pose recognition logic or Android APK update/download behavior.

## Steps

- [x] Add failing tests for PoseNet still/live workflow split and sample image metadata.
- [x] Add sample image workflow metadata and input action.
- [x] Add the Real-time route action on the runtime page.
- [x] Copy the Android sample image into HarmonyOS rawfile resources.
- [x] Verify with Hypium tests, HAP build, diff check, read-only review, and commit.
