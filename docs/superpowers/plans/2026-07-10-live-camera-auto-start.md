# Live Camera Auto Start Implementation Plan

**Goal:** Make HarmonyOS live-camera runtime routes start preview automatically when the surface is ready, matching Android live Activity startup behavior.

**Scope:**
- Auto-start only live routes whose primary input is camera-only.
- Do not auto-start mixed still/live routes such as `POSENET`, because that route still needs a separate still-mode migration.
- Do not change recognition/model logic.
- Do not migrate Android APK update/download-new-version behavior.

## Steps

- [x] Add a failing unit test for the workflow auto-start decision.
- [x] Add the minimal workflow decision.
- [x] Invoke camera preparation from the live preview `XComponent.onLoad`.
- [x] Verify with Hypium tests, HAP build, diff check, read-only review, and commit.
