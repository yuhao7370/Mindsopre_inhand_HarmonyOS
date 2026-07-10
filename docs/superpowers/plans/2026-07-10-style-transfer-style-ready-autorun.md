# Style Transfer Style-ready Auto-run Plan

**Goal:** Restore Android Style Transfer behavior where choosing a built-in or album style image runs transfer immediately once the original/content image is ready.

**Scope:**
- Add a pure workflow decision for style-ready auto-run when content input exists.
- Use it for both picked `styleImage` input and built-in style presets.
- Keep first selecting a style before content from auto-running into missing-input errors.
- Do not migrate Android APK update/download behavior.

## Steps

- [x] Add failing tests for style-ready auto-run decisions.
- [x] Wire `FeatureRuntimePage` style image readiness through the decision.
- [x] Update platform-difference documentation.
- [x] Verify with Hypium tests, HAP build, diff check, local/subagent review, and commit.
