# Still Image Segmentation Android Layout and State Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task by task. Use TDD for behavior and source guards.

**Goal:** Replace the HarmonyOS still-segmentation generic runtime form with the Android page hierarchy while preserving the existing local MindSpore Lite, picker, camera, live-link, permission, secure-save, stale-request, and `PixelMap` ownership implementations.

**Architecture:** Keep `FeatureRuntimePage` as the sole controller. Add exact pure route/state policies in `FeatureWorkflowCatalog`, select a dedicated builder before the generic fallback, and adapt only still-segmentation state edges. The source URI changes immediately after a pick; the prior foreground owner and Save target survive until a current foreground conversion atomically succeeds.

**Tech Stack:** ArkTS, ArkUI, Hypium, HarmonyOS API 24, MindSpore Lite, PowerShell 5+, Hvigor/DevEco Studio.

## Global Constraints

- Add no model, SDK, native bridge, route, dependency, permission, string, or media asset.
- Do not duplicate picker/camera/inference/live/save logic in a new page.
- Preserve live segmentation, portrait segmentation, Style Transfer, and generic scene behavior.
- Photo/camera ready, run start, permission denial, failed AI result, thrown run, and current conversion rejection preserve the previous foreground and Save target.
- Still foreground conversion is awaited; `workflowRunning` remains true until it settles. A current success atomically replaces the map, a current failure preserves the old owner and Toasts failure, and a stale conversion releases its new map silently.
- Still segmentation must process valid foreground bytes even when the optional rectangle list is empty.
- All four bottom actions are disabled while running. Save and Real-time also have handler-side guards; picker actions retain the existing controller guard.
- Save feedback is route-scoped and does not add Toast behavior to shared generic, live, or portrait save callers.
- Real-device validation remains deferred. Host tests/build/package evidence is not a claim about device rendering, secure SaveButton presentation, camera/picker feel, accuracy, latency, memory, or lifecycle stability.

## File Structure

- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`: exact selector, failure Toast, and state-preservation policies.
- `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: policy contracts and sibling negatives.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`: dedicated builder, awaited atomic foreground replacement, failure feedback, and Save wrapper.
- `Mindspore_inhand_HarmonyOS/scripts/check-still-segmentation-layout-parity.ps1`: production source guard.
- `Mindspore_inhand_HarmonyOS/scripts/test-still-segmentation-layout-parity-guard.ps1`: valid fixture and mutation negatives.
- `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`: guard wiring before assembly.
- `docs/harmonyos-platform-differences.md`: reduce the remaining generic-fallback inventory from two routes to one.

### Task 1: Define Exact State Policies With Hypium

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

- [ ] Add failing tests for `usesAndroidStillSegmentationLayout` and `stillSegmentationResultToastKey`. Require exact `SEGMENTATION_STILL` positives and live/portrait/style/undefined negatives; successful runs never Toast.
- [ ] Extend tests for `shouldPreserveRuntimeResultAfterInputReady` so exact-route photo/camera inputs preserve results, while unrelated still inputs and sibling routes remain unchanged.
- [ ] Require `shouldClearRuntimeResultAtWorkflowStart(stillWorkflow)` false.
- [ ] Require `shouldPreserveRuntimeVisualResultOnAiResult(stillWorkflow, false, '')` and successful `dataKind === 'segmentation'` true, but successful wrong-kind and sibling cases false. Retain existing Style Transfer and portrait positives.
- [ ] Run Hvigor test and verify RED because exports/behavior are absent.
- [ ] Implement the smallest pure exact-route policies, rerun Hvigor, and verify all tests GREEN.
- [ ] Commit as `test: define still segmentation android state policy`.

### Task 2: Define A Build-Wired Layout Guard Before Production UI

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-still-segmentation-layout-parity.ps1`
- Create: `Mindspore_inhand_HarmonyOS/scripts/test-still-segmentation-layout-parity-guard.ps1`

- [ ] Reuse the proven comment/string/template-raw stripping and fail-closed section bounding from the Style Transfer guard.
- [ ] Require an exact selector, a bounded `stillSegmentationAndroidLayout()` selected before generic fallback, title-only toolbar, 1vp divider, black full-height body, two full-width `layoutWeight(4)` previews, 20vp result margin, two `icon_default` branches, source URI, foreground `PixelMap`, and contain image fit.
- [ ] Require the weighted 14vp-top bottom row and 37vp Photo/Camera/Real-time/secure-Save order with Android margins, neutral styling, running disables, handler guards, exact input/live calls, and full-page permission overlay.
- [ ] Require route-scoped result/save Toast call sites, input pending-owner invalidation, run/permission/result/throw preservation, awaited current foreground replacement, silent stale release, current conversion-failure preservation, and zero rectangle prerequisite for exact still foreground.
- [ ] Reject generic summary/Inputs/Permissions/status/result rows, rectangle/background overlays, file previews, Help/More, and generic Run markers inside the dedicated builder.
- [ ] Add valid-fixture plus mutations for wrong selectors/order/layout, comment/string decoys, missing preservation, fire-and-forget conversion, stale acceptance, missing failure/save Toast, missing running guards, injected generic surfaces, and absent build wiring. Normalize fixture line endings before exact replacements.
- [ ] Run the production guard and verify RED because the builder is absent; commit as `test: define still segmentation layout parity guard` without wiring it into the build yet.

### Task 3: Implement The Android Page And Async State Edges

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-still-segmentation-layout-parity-guard.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

- [ ] Import the Task 1 policies. For accepted still photo/camera picks, invalidate a pending foreground replacement without clearing its current owner, preserve the old result, set the new source URI, and retain existing auto-run.
- [ ] Preserve still foreground at run start, permission denial, failed/success-before-conversion AI results, and thrown failures. Add a still-only failure Toast method called for failed AI results and thrown runs.
- [ ] Make segmentation preview/foreground updates awaitable. Keep non-still behavior scoped and unchanged. On exact still route, accept foreground bytes even with no rectangles, await conversion, atomically accept only a current map, and keep running until settlement. Invalid/rejected current output sets segmentation-failed status, Toasts once, invalidates only the pending replacement, and preserves the previous owner. Stale conversion releases its map silently.
- [ ] Add a still-only async Save wrapper around `saveResultPixelMapAsync`. It guards running, Toasts missing/success/failure, and maps catch/security denial to save-failed. Do not change shared save feedback.
- [ ] Build a full-height `Stack`: title-only toolbar, divider, black weighted double-preview body, and exact four-action row. Use secure Save in the fourth position and retain the full-page permission recovery overlay. Select it immediately after Style Transfer and before Custom Model/generic fallback.
- [ ] Wire production and mutation guards into `build-hap.ps1`. Update the platform-differences document so only still scene remains on generic fallback.
- [ ] Run production guard, mutation suite, Hvigor test, and `build-hap.ps1`; require all GREEN and `BUILD SUCCESSFUL`.
- [ ] Commit as `fix: match android still segmentation layout`.

### Task 4: Independent Review, Merge, And Master Acceptance

- [ ] Request independent code review against Android XML/Activity, the design, plan, and complete branch diff. Require Critical/Important/Minor counts and Ready yes/no.
- [ ] For each accepted behavioral finding, add a failing Hypium case or guard mutation first, verify RED, apply the smallest fix, verify GREEN, and commit review fixes separately.
- [ ] Run `git diff --check`, focused guards, full Hypium, and unified `scripts/build-ai-runtime-acceptance.ps1` in the worktree.
- [ ] Merge the feature branch into `master` without discarding unrelated work. Rerun the same master acceptance and record fresh main/ohosTest HAP hashes.
- [ ] Remove only the verified feature worktree and delete the merged feature branch. Confirm `master` is clean and only the primary worktree remains.
- [ ] Update the overall migration progress, then continue with the final still-scene generic fallback.
