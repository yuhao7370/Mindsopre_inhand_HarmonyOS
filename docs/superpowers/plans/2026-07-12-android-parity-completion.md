# Android Parity Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the HarmonyOS default UI and translation inputs match the currently reachable Android source while removing the misleading ImageNet-based gesture success.

**Architecture:** Keep all already-ported hidden pages, routes, workflows, and platform adapters. Change only catalog visibility/input metadata and the conservative gesture-label mapping; retain dependency injection points for future authorized gesture and translation runners.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, Hypium, Hvigor, PowerShell build guards.

## Global Constraints

- Preserve every existing Android-compatible route and hidden implementation.
- Default navigation must match the current Android source: Experience and Me only; College remains code-retained but hidden.
- Scene Detection remains implemented and route-ready but hidden from the default Experience grid.
- Text Translation exposes only Android's typed text, camera capture, and album image inputs.
- The bundled ImageNet MobileNetV2 model must not report `mitten` as a successful hand gesture.
- Do not add Android AARs, private HMS models, new network services, or unverified model dependencies.

---

### Task 1: Default Navigation And Feature Visibility

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppState.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/FeatureCatalog.ets`

**Interfaces:**
- Consumes: existing `MainTab`, `mainTabs`, `FeatureItem`, and `visibleExperienceSections` contracts.
- Produces: `mainTabs` containing Experience then Me; Scene remains in `allExperienceFeatures` with `visibleByDefault: false`.

- [ ] **Step 1: Change the unit assertions first**

Assert `mainTabs.length === 2`, IDs are `EXPERIENCE` then `ME`, visible feature count is `10`, and the Scene feature exists but is not visible by default or present in `visibleExperienceSections`.

- [ ] **Step 2: Run RED verification**

Run `hvigorw.bat test --no-daemon`. Expected: failures in the changed main-tab and Scene visibility assertions.

- [ ] **Step 3: Implement the minimal catalog changes**

Remove the College object from `mainTabs` without deleting `MainTab.COLLEGE`, `CollegePage`, or College resources. Change only Scene's `visibleByDefault` value to `false`.

- [ ] **Step 4: Run GREEN verification and commit**

Run `hvigorw.bat test --no-daemon`. Expected: `Failure: 0, Error: 0`.

Commit: `fix: match android default navigation visibility`.

### Task 2: Text Translation Input Parity

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-text-translation-input-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Delete: `Mindspore_inhand_HarmonyOS/scripts/check-live-translation-scan.ps1`

**Interfaces:**
- Consumes: existing Text Translation workflow and shared camera lifecycle fixes.
- Produces: exact input kinds `['text', 'camera', 'photo']`; the new build guard rejects any reintroduced `liveCamera` input.

- [ ] **Step 1: Write failing unit and static checks**

Change the workflow assertion to require exactly the three Android inputs. Add a PowerShell guard that extracts the Text Translation workflow block and fails if `liveCamera` appears or if the exact three-input declaration is absent. Wire it into `build-hap.ps1` and remove the obsolete positive live-scan guard.

- [ ] **Step 2: Run RED verification**

Run `hvigorw.bat test --no-daemon` and the new guard. Expected: both fail because the production workflow still contains `liveCamera`.

- [ ] **Step 3: Implement the minimal workflow change**

Change only Text Translation `inputKinds` from `['text', 'camera', 'photo', 'liveCamera']` to `['text', 'camera', 'photo']`. Keep shared generation/request-id and camera-stop race fixes.

- [ ] **Step 4: Run GREEN verification and commit**

Run the new guard and `hvigorw.bat test --no-daemon`. Expected: both pass.

Commit: `fix: match android translation inputs`.

### Task 3: Honest Gesture Fallback

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/GestureService.ets`

**Interfaces:**
- Consumes: the existing injectable `AndroidGestureModelRunner` and ImageNet score-runner fallback.
- Produces: no gesture detection for the bundled model's `mitten` label; real/injected gesture-model aliases remain supported.

- [ ] **Step 1: Change the regression tests first**

Assert that `gestureCategoryForClassificationLabel('mitten')` is undefined and that a score vector selecting the ImageNet `mitten` index produces no gesture detections.

- [ ] **Step 2: Run RED verification**

Run `hvigorw.bat test --no-daemon`. Expected: the new assertions fail because `mitten` currently maps to Android category `Other`.

- [ ] **Step 3: Remove only the false-positive mapping**

Delete the exact `mitten` classification alias. Preserve explicit future/injected aliases such as `Closed_Fist`, `Open_Palm`, `Thumb_Up`, and controlled `gesture_*` wrappers.

- [ ] **Step 4: Run GREEN verification and commit**

Run `hvigorw.bat test --no-daemon`. Expected: all tests pass.

Commit: `fix: reject imagenet mitten as hand gesture`.

### Task 4: Platform Difference Documentation And Final Verification

**Files:**
- Modify: `docs/harmonyos-platform-differences.md`
- Modify: `docs/superpowers/specs/2026-07-09-mindspore-inhand-harmonyos-port-design.md`

**Interfaces:**
- Produces: an accurate record of reachable Android UI, deliberate hidden HarmonyOS capabilities, gesture/translation external blockers, and device/signing limits.

- [ ] **Step 1: Update documentation**

Document two visible main tabs, hidden College and Scene implementations, three Text Translation inputs, the removal of the `mitten` false positive, and the lack of a phone-capable HarmonyOS gesture/translation API in API 24.

- [ ] **Step 2: Run full verification**

Run `ohpm install`, `hvigorw.bat test --no-daemon`, and `scripts/build-hap.ps1`. Expected: dependencies resolve, all Hypium tests pass, all static/model checks pass, and Hvigor reports `BUILD SUCCESSFUL`.

- [ ] **Step 3: Verify artifacts and repository state**

Record HAP path, byte size, SHA-256, test pass count, `hdc list targets`, and `git status --short`. Expected: unsigned HAP exists, no connected device is reported in the current environment, and the tracked worktree contains only intentional changes before commit.

- [ ] **Step 4: Commit**

Commit: `docs: record android parity completion limits`.

