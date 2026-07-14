# Text Translation Reachable Save Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the HarmonyOS-only translation result snapshot/save action while preserving Android-reachable translation, OCR, and copy behavior.

**Architecture:** Keep the shared result-image save service for features whose Android pages expose saving. Delete only the translation-specific visibility, component, and result-row helpers, and bind the absence of those markers into the existing translation parity guard.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, Hypium, Hvigor, PowerShell build guards.

## Global Constraints

- Preserve typed text, camera, and album-photo translation inputs.
- Preserve the packaged local Chinese-English bidirectional model and OCR chaining.
- Preserve translation result copying.
- Preserve save controls for style transfer, segmentation, QR code, dance, and poetry.
- Do not add a feature flag, dependency, network service, or device-only assertion.

---

### Task 1: Remove The Unreachable Translation Save Action

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureRuntimeViewIds.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: `shouldShowCopyTextAction('translateText')` and the shared `shouldShowResultSaveAction(workflow, resultImageReady)` policy.
- Produces: a translation route for which `shouldShowResultSaveAction()` is always false and a build guard that rejects translation snapshot-save markers.

- [ ] **Step 1: Add failing parity checks**

Extend `check-text-translation-input-parity.ps1` to read
`FeatureRuntimePage.ets` and reject all three removed markers:

```powershell
$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$page = (Get-Content -Raw -Encoding UTF8 -LiteralPath $pagePath) -replace "`r`n", "`n"
foreach ($marker in @(
  'shouldShowTranslationSnapshotSaveAction',
  'translationSnapshotPreview',
  'translationSnapshotComponentId'
)) {
  if ($page.Contains($marker)) {
    throw "Text translation parity guard failed: Android has no reachable translation snapshot save action ($marker)."
  }
}
```

Replace the positive snapshot-save unit tests with this route-level contract:

```typescript
it('keepsAndroidTranslationCopyWithoutResultImageSave', 0, () => {
  const textTranslation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;

  expect(shouldShowCopyTextAction('translateText')).assertTrue();
  expect(shouldShowResultSaveAction(textTranslation, false)).assertFalse();
  expect(shouldShowResultSaveAction(textTranslation, true)).assertFalse();
});
```

- [ ] **Step 2: Run RED verification**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-text-translation-input-parity.ps1
.\hvigorw.bat test --no-daemon
```

Expected: the guard fails on a translation snapshot marker, and Hypium fails
because `shouldShowResultSaveAction(textTranslation, true)` still returns true.

- [ ] **Step 3: Delete the translation-only save path**

Make `shouldShowResultSaveAction()` explicitly reject translation before its
shared processed-image branch:

```typescript
export function shouldShowResultSaveAction(
  workflow: FeatureWorkflow | undefined,
  resultImageReady: boolean
): boolean {
  if (workflow?.aiMethod === 'translateText') {
    return false;
  }
  if (resultImageReady) {
    return true;
  }
  return workflow?.routeName === AppRoute.STYLE_TRANSFER.name ||
    workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;
}
```

Delete `shouldShowTranslationSnapshotSaveAction`,
`translationSnapshotComponentId`, `translationSnapshotTranslatedTextReady`,
the page's `shouldShowTranslationSnapshotSave()` method,
`translationSnapshotPreview()` builder, related imports, and the conditional
snapshot/save branch. Render `resultRows` directly when non-empty. Remove only
unit assertions that call the deleted helpers; keep failure-row and copy
assertions.

Update `docs/harmonyos-platform-differences.md` to state that image translation
shows and copies source/translated text but does not add the unreachable Android
save action.

- [ ] **Step 4: Run focused GREEN verification**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-text-translation-input-parity.ps1
.\hvigorw.bat test --no-daemon
```

Expected: the parity guard passes and Hypium reports zero failures and errors.

- [ ] **Step 5: Run repository verification**

Run from the repository root, then the HarmonyOS project:

```powershell
python -m unittest discover -s tools\translation -p 'test_*.py'
Set-Location Mindspore_inhand_HarmonyOS
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Expected: all translation Python tests pass; main HAP, `ohosTest` HAP, and the
AI-runtime HAP structure/pairing guard all succeed. Device tests are compiled
but not executed.

- [ ] **Step 6: Commit**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureRuntimeViewIds.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-parity.ps1 docs/harmonyos-platform-differences.md
git commit -m "fix: match android translation result actions"
```
