# Text Image Auto Run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the Android text feature behavior where image/camera input immediately runs OCR or OCR-plus-translation after the selected image is ready.

**Architecture:** Keep the existing `FeatureRuntimePage` and `DefaultAiService` flow. Add route-specific workflow helpers in `FeatureWorkflowCatalog.ets`, then have `FeatureRuntimePage.applyPickResult()` clear stale typed translation text and call the normal `runWorkflow()` only for Android text image inputs.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, ArkUI, Hypium unit tests, DevEco Studio local Hvigor.

## Global Constraints

- Target HarmonyOS project path: `Mindspore_inhand_HarmonyOS/`.
- Source Android project path: `Mindspore_inhand/`; it is ignored by Git and must remain ignored.
- Preserve current Android behavior: `TextRecognitionActivity` runs OCR after photo/camera input; `TextTranslationActivity` translates typed text only after the Translate button, but runs OCR then translation after photo/camera input.
- Do not depend on Android AARs, Android `.so` files, AppCompat, ARouter, Glide, Retrofit, RxJava, or HMS Android SDKs.
- Every phase must leave the HarmonyOS project buildable.
- Command-line builds should use `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`.
- Private signing keys, local SDK paths in committed local config, generated folders, and build outputs must not be committed.

---

## File Structure

- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`: add `shouldAutoRunWorkflowAfterInputReady(workflow, inputKind)`, `shouldClearTextInputAfterInputReady(workflow, inputKind)`, and `workflowInputReadyAction(workflow, inputKind, currentUserText)`.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`: call the helper after successful pick/camera image input assignment.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: add the route-specific auto-run contract test.

## Task 1: Text Image Input Auto Run

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces: `shouldAutoRunWorkflowAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean`
- Produces: `shouldClearTextInputAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean`
- Produces: `workflowInputReadyAction(workflow: FeatureWorkflow, inputKind: FeatureInputKind, currentUserText: string): WorkflowInputReadyAction`
- Consumes: `workflowForRoute()`, `AppRoute.TEXT_RECOGNITION`, and `AppRoute.TEXT_TRANSLATION`

- [ ] **Step 1: Write the failing helper contract test**

Add this import to `LocalUnit.test.ets`:

```typescript
import {
  FeatureWorkflow,
  WorkflowInputReadyAction,
  inputKindReplacesPrimaryInput,
  runtimeInputKindsForWorkflow,
  shouldAutoRunWorkflowAfterInputReady,
  shouldClearTextInputAfterInputReady,
  workflowInputReadyAction,
  workflowForRoute
} from '../main/ets/features/runtime/FeatureWorkflowCatalog';
```

Add this test near the existing runtime workflow tests:

```typescript
it('autoRunsTextImageInputsAfterAndroidImageInputReadyOnly', 0, () => {
  const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
  const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
  const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
  const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;

  expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'photo')).assertTrue();
  expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'camera')).assertTrue();
  expect(shouldAutoRunWorkflowAfterInputReady(textRecognition, 'text')).assertFalse();

  expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'photo')).assertTrue();
  expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'camera')).assertTrue();
  expect(shouldAutoRunWorkflowAfterInputReady(textTranslation, 'text')).assertFalse();

  expect(shouldAutoRunWorkflowAfterInputReady(styleTransfer, 'camera')).assertFalse();
  expect(shouldAutoRunWorkflowAfterInputReady(styleTransfer, 'contentImage')).assertFalse();
  expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'photo')).assertFalse();
  expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'camera')).assertFalse();
  expect(shouldAutoRunWorkflowAfterInputReady(customModel, 'modelFile')).assertFalse();

  const futureOcrWorkflow: FeatureWorkflow = {
    routeName: '/future/OcrActivity',
    titleKey: 'title_text_extraction',
    summaryKey: 'workflow_summary_text_recognition',
    aiMethod: 'recognizeText',
    inputKinds: ['photo'],
    requiredPermissions: ['media'],
    resultKind: 'recognizedText',
    liveMode: false
  };
  expect(shouldAutoRunWorkflowAfterInputReady(futureOcrWorkflow, 'photo')).assertFalse();
});
```

Add this stale text clearing assertion:

```typescript
it('clearsTypedTranslationTextWhenAndroidImageTranslationInputIsReady', 0, () => {
  const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
  const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

  expect(shouldClearTextInputAfterInputReady(textTranslation, 'photo')).assertTrue();
  expect(shouldClearTextInputAfterInputReady(textTranslation, 'camera')).assertTrue();
  expect(shouldClearTextInputAfterInputReady(textTranslation, 'text')).assertFalse();
  expect(shouldClearTextInputAfterInputReady(textRecognition, 'photo')).assertFalse();
});
```

Add this page-action assertion:

```typescript
it('computesTextImageInputReadyPageActionBeforeAutoRun', 0, () => {
  const textRecognition: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_RECOGNITION.name)!;
  const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
  const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;

  const imageTranslationAction: WorkflowInputReadyAction =
    workflowInputReadyAction(textTranslation, 'photo', 'typed first');
  expect(imageTranslationAction.userText).assertEqual('');
  expect(imageTranslationAction.shouldRunWorkflow).assertTrue();

  const typedTranslationAction: WorkflowInputReadyAction =
    workflowInputReadyAction(textTranslation, 'text', 'typed first');
  expect(typedTranslationAction.userText).assertEqual('typed first');
  expect(typedTranslationAction.shouldRunWorkflow).assertFalse();

  const imageOcrAction: WorkflowInputReadyAction =
    workflowInputReadyAction(textRecognition, 'camera', 'typed first');
  expect(imageOcrAction.userText).assertEqual('typed first');
  expect(imageOcrAction.shouldRunWorkflow).assertTrue();

  const styleTransferAction: WorkflowInputReadyAction =
    workflowInputReadyAction(styleTransfer, 'photo', 'typed first');
  expect(styleTransferAction.userText).assertEqual('typed first');
  expect(styleTransferAction.shouldRunWorkflow).assertFalse();
});
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: FAIL because `shouldAutoRunWorkflowAfterInputReady` and `shouldClearTextInputAfterInputReady` are not exported.

- [ ] **Step 3: Add minimal route-specific helper**

Add this function after `inputKindReplacesPrimaryInput()` in `FeatureWorkflowCatalog.ets`:

```typescript
export function shouldAutoRunWorkflowAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  return (workflow.routeName === AppRoute.TEXT_RECOGNITION.name ||
    workflow.routeName === AppRoute.TEXT_TRANSLATION.name) &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function shouldClearTextInputAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  return workflow.routeName === AppRoute.TEXT_TRANSLATION.name &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function workflowInputReadyAction(workflow: FeatureWorkflow, inputKind: FeatureInputKind,
  currentUserText: string): WorkflowInputReadyAction {
  return {
    userText: shouldClearTextInputAfterInputReady(workflow, inputKind) ? '' : currentUserText,
    shouldRunWorkflow: shouldAutoRunWorkflowAfterInputReady(workflow, inputKind)
  };
}
```

- [ ] **Step 4: Wire successful image input to normal run flow**

In `FeatureRuntimePage.ets`, import the helper:

```typescript
shouldAutoRunWorkflowAfterInputReady,
shouldClearTextInputAfterInputReady,
```

At the end of `applyPickResult()` after the input URI state is updated, add:

```typescript
const workflow = workflowForRoute(this.routeName);
if (workflow) {
  const inputReadyAction = workflowInputReadyAction(workflow, inputKind, this.userText);
  this.userText = inputReadyAction.userText;
  if (inputReadyAction.shouldRunWorkflow) {
    this.runWorkflow();
  }
}
```

- [ ] **Step 5: Verify GREEN**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
.\scripts\check-feature-runtime-view-ids.ps1
git diff --check
```

Expected: all commands pass.

- [ ] **Step 6: Review and commit**

Create a diff package for the three modified files, get a subagent review, address Critical/Important findings, then commit:

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets docs/superpowers/plans/2026-07-10-text-image-auto-run.md
git commit -m "feat: auto-run text workflows after image input"
```

## Self-Review

- Spec coverage: covers the Android text image-input auto-run behavior for Text Extraction and Text Translation while preserving manual typed text translation and preventing stale typed text from overriding image OCR translation.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: helper uses existing `FeatureWorkflow`, `FeatureInputKind`, and `AppRoute` names.
