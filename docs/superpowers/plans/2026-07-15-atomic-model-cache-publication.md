# Atomic Model Cache Publication Review-Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development and superpowers:test-driven-development. This plan closes the final-review blocker on the approved Custom Model parity branch.

**Goal:** Ensure stale or failed model selections cannot overwrite the current/last-valid fixed model cache while keeping every existing cache filename, compatibility contract, route message key, and restore policy.

**Architecture:** Stage each compatible selection in a same-directory request-private temporary file. After the complete write is closed, call the page's current-request predicate and, only when current, synchronously replace the fixed stable path with `fileIo.moveFileSync(temp, stable, 0)`. The predicate and synchronous publish form one JavaScript turn; stale/failing requests only remove their own temp. Keep the page's post-await current check for UI/Toast suppression.

**Tech Stack:** ArkTS, CoreFileKit `fileIo`, Hypium, PowerShell, Hvigor.

## Constraints

- Keep stable filenames `custom_model.ms`, `object_detection_model.ms`, `custom_predict.ms`, and `custom_transfer.ms` unchanged.
- Compatibility checks still run against selected in-memory content and receive the stable target URI.
- A stale result is represented by `undefined`, not a cache-failure Toast/status.
- Cache/read/compatibility/write/publish exceptions retain each route's existing failure key.
- `TRUNC` may only target a request-private temp path, never a stable path.
- The temp token combines `Date.now()`, a module-level monotonic sequence, and the page request id; a bare page-local request id is insufficient.
- After the async temp write and close, no `await` may occur between `isCurrent()` and `moveFileSync(temp, stable, 0)`.
- Any error or stale result performs best-effort temp cleanup and never deletes/truncates the stable file.
- Do not change model preprocessing, tensor contracts, AI services, layout, i18n, or route restoration behavior.

### Task 1: Add failing publication and last-valid regression tests

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/picker/ModelFileCacheService.ets`

- [ ] Add a small injectable `ModelFileCacheFileBackend` contract around open/write/close/synchronous replace/remove so Hypium can exercise the production `HarmonyModelFileCacheWriter` without CoreFileKit host I/O.
- [ ] Add RED tests proving current publish replaces the fixed stable bytes and removes temp.
- [ ] Add RED tests proving `isCurrent=false` returns `undefined`, removes temp, and leaves pre-existing stable bytes unchanged.
- [ ] Add RED tests proving partial write, write throw, close throw, and replace throw clean only temp and preserve the old stable bytes.
- [ ] Add RED concurrency coverage where B becomes current and publishes before delayed A completes; A then becomes stale and cannot replace B.
- [ ] Add RED token tests proving two calls are unique, temp/stable share a directory, and the stable filename is unchanged.
- [ ] Retain coverage that Custom/Object/Style compatibility receives the stable URI and all success/failure message keys stay unchanged.
- [ ] Run Hypium and record RED from the missing publication interfaces/behavior, not unrelated baseline failures.

### Task 2: Implement staged synchronous publication and page gating

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/picker/ModelFileCacheService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-custom-model-layout-parity.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

- [ ] Extend `ModelFileCacheWriter.writeModelFile()` and `RuntimeModelFileCacheService.cachePickedModelFile()` with a request token and `() => boolean` current predicate. Return `undefined` only for stale publication.
- [ ] Generate a same-directory temp path from the stable path plus process-unique time/sequence/request token.
- [ ] In the Harmony writer, open/truncate only temp, write the full byte slice, close, then synchronously check current and either unlink temp or `moveFileSync(temp, stable, 0)`. Catch paths best-effort unlink temp and rethrow.
- [ ] In `cacheAndApplyPickedModelFile()`, pass the request id token and a closure over `isInputPreparationRequestCurrent()`. After await, keep the existing current check before handling `undefined` or applying result/Toast.
- [ ] Harden the Custom Model guard to check request token/predicate wiring, post-await current ordering, stale early return, temp-only `TRUNC`, cleanup, and zero `await` between predicate and `moveFileSync`.
- [ ] Update the platform-differences Custom Model section to state that cache publication is staged/atomic and stale/failing selections preserve last-valid content.
- [ ] Run focused guards, i18n, Hypium, unified AI runtime acceptance, and `git diff --check`.
- [ ] Commit as `fix: publish model cache atomically` and request a focused review of the final-review blocker.

### Task 3: Re-run whole-branch review and integration

- [ ] Ask the prior final reviewer to verify the stale A/current B schedule and failure preservation from source/tests.
- [ ] Obtain a fresh whole-branch Ready-to-merge decision with no Critical/Important findings.
- [ ] Fast-forward the reviewed branch into `master`.
- [ ] On merged `master`, rerun the Custom/Static/Pose guards, i18n, Hypium, unified acceptance, and `git diff --check`.
- [ ] Remove the temporary worktree and feature branch, preserving the existing gesture/translation archive branch.

Do not claim real-device behavior was verified.
