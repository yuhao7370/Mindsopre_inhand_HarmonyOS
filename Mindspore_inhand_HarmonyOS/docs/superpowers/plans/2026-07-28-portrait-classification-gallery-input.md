# Portrait Segmentation and Classification Gallery Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-image gallery input to portrait segmentation and image classification while keeping live camera as the default mode.

**Architecture:** Reuse `PickerService.pickImage()` and the existing URI-based AI runners. Extend the two workflow descriptors and their specialized runtime layouts so selecting a photo stops live capture, shows the photo with preserved aspect ratio, runs one inference, and can switch back to live camera.

**Tech Stack:** HarmonyOS ArkTS, ArkUI, PhotoViewPicker, Hypium, Hvigor.

## Global Constraints

- Keep live camera as the default input.
- Reuse existing picker and inference services; add no dependency or route.
- Cancelled selection preserves the current preview and result.
- Gallery photos must not inherit front-camera mirroring.
- Verify with unit tests, HAP build, native emulator touches, and screenshots.

---

### Task 1: Gallery input workflow policy

**Files:**
- Modify: `entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Test: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: existing `FeatureWorkflow`, `runtimeInputActionsForWorkflow()`, and `shouldMirrorSegmentationForeground()`.
- Produces: `photo` support for `PORTRAIT_SEGMENTATION` and `IMAGE_CAMERA`, camera auto-start, photo auto-run, and input-aware mirror policy.

- [ ] **Step 1: Write the failing tests**

```ts
const portrait = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
const classification = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
expect(runtimeInputActionsForWorkflow(portrait).join(',')).assertEqual('startLiveCamera,pickImage');
expect(runtimeInputActionsForWorkflow(classification).join(',')).assertEqual('startLiveCamera,pickImage');
expect(autoStartInputKindForWorkflow(portrait)).assertEqual('camera');
expect(autoStartInputKindForWorkflow(classification)).assertEqual('camera');
expect(shouldAutoRunWorkflowAfterInputReady(portrait, 'photo')).assertTrue();
expect(shouldAutoRunWorkflowAfterInputReady(classification, 'photo')).assertTrue();
expect(shouldMirrorSegmentationForeground(portrait, 'front', false)).assertFalse();
```

- [ ] **Step 2: Run the local unit suite and verify RED**

Run:

```powershell
node .\hvigorw.js test --mode module -p module=entry@default -p product=default
```

Expected: assertions fail because the live workflows expose only camera input and do not auto-run selected photos.

- [ ] **Step 3: Implement the minimum workflow policy**

```ts
inputKinds: ['camera', 'photo'],
requiredPermissions: ['camera', 'media'],
```

Preserve camera auto-start for live workflows whose first input is `camera`, auto-run `photo` for the two routes, and make foreground mirroring conditional on live camera input being selected.

- [ ] **Step 4: Run the local unit suite and verify GREEN**

Run the same Hvigor test command. Expected: `BUILD SUCCESSFUL` and no Hypium assertion failure.

### Task 2: Specialized page gallery controls and previews

**Files:**
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Test: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `prepareInput('photo')`, `prepareInput('camera')`, `imageInputUri`, and `liveCameraInputSelected`.
- Produces: toolbar mode action and aspect-preserving static previews for both specialized layouts.

- [ ] **Step 1: Add the toolbar mode action**

In the portrait and classification toolbars, show a 48vp accessible action:

```ts
if (this.liveCameraInputSelected) {
  Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })
    .onClick(() => this.prepareInput('photo'))
} else {
  Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })
    .onClick(() => this.prepareInput('camera'))
}
```

- [ ] **Step 2: Render the selected photo in place of the stopped camera**

```ts
if (!this.liveCameraInputSelected && this.imageInputUri.length > 0) {
  Image(this.imageInputUri)
    .width('100%')
    .height('100%')
    .objectFit(ImageFit.Contain)
} else {
  this.liveCameraSurfaceContent()
}
```

Use this behavior in both portrait original preview and image classification preview.

- [ ] **Step 3: Pass input mode into the segmentation mirror policy**

```ts
shouldMirrorSegmentationForeground(
  workflowForRoute(this.routeName),
  this.liveCameraPosition,
  this.liveCameraInputSelected
)
```

- [ ] **Step 4: Run unit tests and build the HAP**

```powershell
node .\hvigorw.js test --mode module -p module=entry@default -p product=default
node .\hvigorw.js assembleHap --mode module -p module=entry@default -p product=default
```

Expected: both commands report `BUILD SUCCESSFUL`.

- [ ] **Step 5: Verify on the emulator**

Install `entry/build/default/outputs/default/entry-default-unsigned.hap`. With native HDC touches and screenshots, verify both pages default to live camera, open PhotoViewPicker, display a selected image without stretching, produce one inference result, and return to live camera.

- [ ] **Step 6: Commit and push**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets
git commit -m "feat(ai): add gallery inputs"
git push origin master
```
