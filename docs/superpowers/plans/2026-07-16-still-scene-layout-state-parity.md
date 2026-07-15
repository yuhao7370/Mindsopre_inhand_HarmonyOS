# Still Scene Detection Android Layout and State Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task by task. Use TDD for behavior and source guards.

**Goal:** Replace the last HarmonyOS generic runtime workflow, still-scene detection, with the Android page hierarchy and visible state/failure semantics while retaining the existing local Places365 MindSpore Lite runtime.

**Architecture:** Keep `FeatureRuntimePage` as the controller. Add exact pure route/state/Toast policies in `FeatureWorkflowCatalog`, preserve empty-versus-runtime failure provenance through the scene service and `AiService`, adapt successful scene data to Android-shaped result rows, and select a dedicated builder before the generic fallback.

**Tech Stack:** ArkTS, ArkUI, Hypium, HarmonyOS API 24, MindSpore Lite, PowerShell 5+, Hvigor/DevEco Studio.

## Global Constraints

- Add no model, SDK, native bridge, route, dependency, permission, user-visible string, or media asset.
- Reuse the current picker, camera, permission recovery, request-generation, local Places365 inference, label localization, and linked live route.
- Preserve live scene detection and every sibling workflow.
- Match Android's visible result contract: Scene Count followed by separate Scene and Score rows for each candidate, with percent scores using at most two fractional digits; omit image path, execution time, status, summary, input, permission, and debug cards.
- Preserve the prior preview/result on cancellation, new accepted input, run start, permission denial, empty result, and runtime failure until a successful current result replaces the text rows.
- Toast only for a successful analyzer call that returns no scenes. Keep analyzer/runtime exceptions silent and distinguish them with a non-user-visible result code.
- Disable Photo, Camera, and Real-time while running; enforce photo/camera and live navigation guards in handlers/pure policies too.
- Do not render Android's declared progress indicator because the Android activity never makes it visible.
- Real-device validation remains deferred. Host tests/build/package evidence is not a claim about device rendering, picker/camera feel, accuracy, latency, memory, or lifecycle stability.

## File Structure

- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/SceneDetectionService.ets`: explicit empty/runtime failure provenance.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`: distinct failure codes and Android-shaped still result-row adapter.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`: exact selector, Toast, text preservation, run-start, input-ready, and running-input policies.
- `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: focused contracts and sibling negatives.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`: dedicated builder and scoped state/result integration.
- `Mindspore_inhand_HarmonyOS/scripts/check-still-scene-layout-parity.ps1`: production source guard.
- `Mindspore_inhand_HarmonyOS/scripts/test-still-scene-layout-parity-guard.ps1`: valid fixture and mutation negatives.
- `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`: guard wiring before assembly.
- `docs/harmonyos-platform-differences.md`: record that no registered workflow remains on the generic fallback.

### Task 1: Define Failure Provenance, Exact Rows, And Page Policies With Hypium

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/SceneDetectionService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

- [ ] Add failing tests requiring scene runner/service catches to return runtime-failure provenance while ordinary zero-scene results retain empty-result provenance.
- [ ] Require `AiService` to map empty results to `SCENE_DETECTION_FAILED` and runtime failures to `SCENE_DETECTION_RUNTIME_FAILED`, retaining the existing localized failure message key for non-visible status handling.
- [ ] Add a pure successful-result adapter that returns exactly Scene Count, then alternating Scene and Score rows with Android-style percent scores (`50%`, `74.1%`, `74.12%`) and no image/execution rows. Keep the existing generic/live result-row contract unchanged.
- [ ] Add failing tests for exact `usesAndroidStillSceneLayout`, empty-code-only `stillSceneResultToastKey`, and failed-only `shouldPreserveRuntimeTextResultOnAiResult`, including live scene, segmentation, Style Transfer, other routes, success, runtime failure, and undefined negatives.
- [ ] Extend `shouldPreserveRuntimeResultAfterInputReady` and `shouldClearRuntimeResultAtWorkflowStart` for exact still-scene photo/camera behavior.
- [ ] Extend `shouldAllowRuntimeInputChange` so running still-scene photo/camera changes are rejected, while idle inputs and sibling behavior remain unchanged.
- [ ] Run Hvigor tests and verify RED before production exports/behavior exist.
- [ ] Implement the smallest explicit contracts, rerun Hvigor, and require all tests GREEN.
- [ ] Commit as `test: define still scene android state contract`.

### Task 2: Define A Build-Wired Layout Guard Before Production UI

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-still-scene-layout-parity.ps1`
- Create: `Mindspore_inhand_HarmonyOS/scripts/test-still-scene-layout-parity-guard.ps1`

- [ ] Reuse the proven comment/string/template-raw stripping and fail-closed section bounding from the still-segmentation guard.
- [ ] Require the exact selector and a bounded `stillSceneAndroidLayout()` selected before the generic fallback, with title-only toolbar, 1vp divider, white full page, 376vp `#E6E6E6` frame, centered 266x356 `ImageFit.Fill` input, and 69.33x56.33 `icon_style` plus the exact localized prompt.
- [ ] Require a 37vp, top-14 row in Photo/Camera/Real-time order with exact 20/5, 5/5, 5/5 margins, neutral colors/radius, visible running disables, exact input calls, route-only live wrapper, and handler guards.
- [ ] Require a remaining-height Scroll with 20vp horizontal and 14vp top margins, exact Android still result rows, and the full-page permission recovery overlay.
- [ ] Require call sites for input/run/permission/result/throw preservation, exact successful row replacement, empty-only Toast, silent runtime failure, and distinct scene failure codes.
- [ ] Reject `LoadingProgress`, generic summary/Inputs/Permissions/status/result cards, image path/execution time, combined `Scenes` rows, live camera/overlay, segmentation/style/object surfaces, Help/More, generic Run, and Save controls inside the dedicated builder.
- [ ] Add valid-fixture plus mutations for comment/string decoys, wrong route/order/dimensions/colors/margins, collapsed rows, missing failure provenance/preservation, wrong Toast behavior, missing input/live guards, generic UI injection, and absent build wiring. Normalize fixture line endings before exact replacements.
- [ ] Run the production guard and verify RED because the builder is absent; commit as `test: define still scene layout parity guard` without build wiring yet.

### Task 3: Implement The Dedicated Android Page And Scoped State Flow

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-still-scene-layout-parity-guard.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

- [ ] Import the Task 1 policies and row adapter. Preserve still-scene result text/rows after accepted photo/camera input, at run start, on permission denial, on failed `AiRunResult`, and in `applyRuntimeFailure`; successful scene results replace them with the exact Android rows.
- [ ] Add a still-scene failure Toast wrapper that receives the result code and is called only from completed AI results. Do not call it from thrown-runtime handling.
- [ ] Add a route-only linked-live wrapper with a running guard. Keep the shared picker controller guard authoritative and disable all three dedicated actions while running.
- [ ] Build the exact white full-height `Stack`: toolbar/divider, fixed gray preview frame with source/prompt branches, exact three-action row, remaining scrollable text rows, and permission overlay. Do not add a progress indicator or generic cards.
- [ ] Select the dedicated builder after still segmentation and before portrait/generic fallback without contaminating existing guard section boundaries.
- [ ] Wire the production and mutation guards into `build-hap.ps1`. Update platform differences from one generic fallback to zero registered workflow fallbacks, while retaining the fallback only as unknown-route defense.
- [ ] Run the production guard, mutation suite, affected existing guards, Hvigor tests, and `build-hap.ps1`; require all GREEN and `BUILD SUCCESSFUL`.
- [ ] Commit as `fix: match android still scene layout`.

### Task 4: Independent Review, Merge, And Master Acceptance

- [ ] Request independent code review against Android XML/Activity, the approved design, plan, and complete branch diff. Require Critical/Important/Minor counts and Ready yes/no.
- [ ] For every accepted behavioral finding, add a failing Hypium case or guard mutation first, verify RED, apply the smallest fix, verify GREEN, and commit review fixes separately.
- [ ] Run `git diff --check`, focused guards, full Hypium, and unified `scripts/build-ai-runtime-acceptance.ps1` in the worktree.
- [ ] Merge the feature branch into `master` without discarding unrelated work. Rerun the same master acceptance and record fresh main/ohosTest HAP hashes.
- [ ] Remove only the verified feature worktree and delete the merged feature branch. Confirm `master` is clean and only the primary worktree remains.
- [ ] Re-audit all registered workflows for generic fallthrough and report the remaining non-device migration inventory separately from deferred device validation.
