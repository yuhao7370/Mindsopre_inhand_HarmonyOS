# Vision Fragment Route Alias Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve Android's `/app/VisionFragment` route in HarmonyOS by routing it to the existing Experience feature catalog.

**Architecture:** Add a thin `ExperienceRoutePage` wrapper around the reusable `ExperiencePage` component. Register the Android fragment route in `AppRoutes` and `main_pages.json` without changing the main tab UI.

**Tech Stack:** ArkTS, HarmonyOS router pages, Hypium local unit tests.

## Global Constraints

- Do not change the visible Experience tab layout.
- Do not create duplicate feature catalog data.
- Do not migrate Android APK update/download-new-version behavior.

---

### Task 1: Add Route Alias

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppRoutes.ets`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/ExperienceRoutePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/profile/main_pages.json`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify docs: `docs/harmonyos-platform-differences.md`

- [x] **Step 1: Write failing tests**

Assert the Android fragment route is present and maps to the wrapper page:

```ts
expect(AppRoute.VISION_FRAGMENT.name).assertEqual('/app/VisionFragment');
expect(findRouteByName(AppRoute.VISION_FRAGMENT.name)?.page).assertEqual('pages/ExperienceRoutePage');
expect(workflowForRoute(AppRoute.VISION_FRAGMENT.name) === undefined).assertTrue();
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

- [x] **Step 3: Implement the alias page and catalog entry**

Create an `@Entry` wrapper that renders `ExperiencePage()`, add `VISION_FRAGMENT` to `AppRouteCatalog`, `AppRoute`, `appRoutes`, and register `pages/ExperienceRoutePage` in `main_pages.json`.

- [x] **Step 4: Verify, review, and commit**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\build-hap.ps1
git diff --check
```

Ask a read-only review subagent to inspect the staged diff before committing.
