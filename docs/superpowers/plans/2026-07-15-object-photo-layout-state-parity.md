# Object Photo Android Layout and State Parity Implementation Plan

> Execute in an isolated worktree with subagent-driven development, TDD, an
> independent task review, and a whole-branch review.

## Goal

Replace Object Photo's generic runtime cards with the reachable Android page's
toolbar, centered detection image, and bottom-right Select Model action while
preserving the real SSD pipeline and matching Android failure/model-reload
state.

## Constraints

- Reuse the current object detector, overlay geometry, picker, fixed cache
  filename, compatibility checker, Help dialog, and More URL.
- Do not change Object Camera or any other route selector.
- Add no dependency and no new string resource.
- Device-only rendering, picker, Toast, accuracy, and performance checks remain
  deferred.

## Task 1: Define the exact route and state policies

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`

First add focused failing tests for:

1. `usesAndroidObjectPhotoLayout` is true only for `OBJECT_PHOTO`;
2. `objectPhotoResultToastKey` returns
   `feature_runtime_object_detection_failed` only for failed Object Photo;
3. `objectPhotoFollowupInputKindAfterModelCacheSuccess` returns `photo` only
   for Object Photo plus `modelFile`;
4. Object Camera, Style Transfer, other input kinds, success, and undefined
   workflows remain negative.

Run Hypium and record RED from missing policies. Implement the three pure
functions with exact route checks, rerun Hypium to GREEN, and commit:

```text
test: define object photo android state policy
```

## Task 2: Add a hardened failing layout guard

Files:

- Create: `Mindspore_inhand_HarmonyOS/scripts/check-object-photo-layout-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`

Create a dependency-free source guard using the comment/template-safe stripping
and bounded-section approach from `check-custom-model-layout-parity.ps1`.
Require:

- the exact Object Photo selector and a dedicated builder selected before the
  generic fallback;
- a 56vp white toolbar with Android back, localized title, Help, and More;
- a centered preview surface using the existing orientation/aspect-ratio box
  overlay state;
- a normal blue Select Model button with white 16fp text in a full-size
  bottom-end layer with 16vp right/bottom margins;
- the model button invokes `prepareInput('modelFile')` and is disabled during
  the shared runtime guard;
- the dedicated builder contains none of the generic summary/input/permission/
  status/result/debug/save/Run-card markers;
- failed Object Photo AI results reach the Toast policy call site;
- only a successful cached Object Photo model reaches the follow-up initial
  photo picker call site;
- `build-hap.ps1` executes the guard.

Run the guard before page implementation and record RED. Wire it into
`build-hap.ps1` only in the implementation commit so broken source cannot enter
the normal build.

## Task 3: Implement the dedicated page and terminal state

Files:

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

Implement a dedicated Object Photo builder before the generic fallback:

- full-height white page;
- existing 56vp Android toolbar actions and title;
- centered selected/result image;
- existing object boxes and label text directly over successful result image;
- selected input image remains visible when no boxes are returned;
- bottom-right Select Model action, disabled while a non-live run is active;
- no generic cards or separate result rows.

After `applyAiResult`, show the existing failure string as a Toast only when the
new policy returns it. After a successful `modelFile` cache result, consult the
follow-up policy and call the existing photo picker with `initialPick=true`.
Do not run this path for cancel, incompatible model, cache failure, stale
request, Object Camera, or another input kind.

Update the platform-differences document with the dedicated surface, failure
Toast, Android-equivalent model-success re-pick, preserved real SSD/cache
behavior, and deferred device boundary. Correct the generic-fallback count from
the stale seven-route statement to the actual three remaining routes after this
change.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-object-photo-layout-parity.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-custom-model-layout-parity.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-static-gesture-layout-parity.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-posenet-still-layout-parity.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-i18n-strings.ps1
```

Run fresh Hypium and require all tests pass. Commit:

```text
fix: match android object photo layout
```

## Task 4: Review and harden

Request an independent review of the complete task diff. The reviewer must
compare the Android XML/Activity and verify:

- selector isolation;
- no generic cards on Object Photo;
- success overlay and empty-result image behavior;
- failure Toast is Object Photo-only;
- successful-model follow-up cannot run for stale or failed cache work;
- request-generation and atomic stable-cache guarantees remain intact;
- Object Camera and Style Transfer are unchanged.

Fix every Critical/Important finding. If the source guard can be spoofed by
comments or template interpolation, add guard fixtures or harden it before
acceptance. Commit review fixes separately.

## Task 5: Full acceptance, merge, and cleanup

Run in the feature worktree:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
git diff --check
git status --short
```

Require main and `ohosTest` HAP assembly plus model/native/payload verification.
Do not claim device execution.

Request a whole-branch review and merge only when it reports ready. Fast-forward
`master`, rerun the focused guards, fresh Hypium, and unified acceptance on
merged `master`, then remove the feature worktree and branch, including safe
long-path cleanup if Windows leaves read-only build artifacts.

