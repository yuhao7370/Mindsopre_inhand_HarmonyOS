# College Main Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the existing College page between Experience and Me in the main bottom navigation.

**Architecture:** Reuse the existing `MainTab.COLLEGE`, college icon resources, `BottomTabBar`, and `CollegePage`. Keep all three pages mounted and switch visibility with the existing selected-tab state.

**Tech Stack:** HarmonyOS ArkTS, ArkUI, Hypium LocalUnit, Hvigor, HDC.

## Global Constraints

- Main tab order is Experience, College, Me.
- Do not change College page content, behavior, or styling.
- Do not add dependencies or media resources.

---

### Task 1: Restore the College main tab

**Files:**
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `entry/src/main/ets/app/AppState.ets`
- Modify: `entry/src/main/ets/pages/MainPage.ets`

**Interfaces:**
- Consumes: existing `MainTab.COLLEGE`, `CollegePage`, `college_checked_icon`, and `college_uncheck`.
- Produces: `mainTabs` ordered as `[EXPERIENCE, COLLEGE, ME]` and a visible College page for `selectedTab === MainTab.COLLEGE`.

- [ ] **Step 1: Write the failing navigation-order test**

```ts
expect(mainTabs.length).assertEqual(3);
expect(mainTabs[0].id).assertEqual(MainTab.EXPERIENCE);
expect(mainTabs[1].id).assertEqual(MainTab.COLLEGE);
expect(mainTabs[2].id).assertEqual(MainTab.ME);
expect(mainTabs[1].selectedIconMediaName).assertEqual('college_checked_icon');
expect(mainTabs[1].unselectedIconMediaName).assertEqual('college_uncheck');
```

- [ ] **Step 2: Run LocalUnit and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: the main-tab test fails because only Experience and Me are present.

- [ ] **Step 3: Add the existing College tab and page**

Add this item between Experience and Me in `mainTabs`:

```ts
{
  id: MainTab.COLLEGE,
  title: 'College',
  titleKey: 'main_tab_title_two',
  icon: 'college',
  selectedIconMediaName: 'college_checked_icon',
  unselectedIconMediaName: 'college_uncheck'
}
```

Import `CollegePage` in `MainPage.ets` and mount it with the same visibility and hit-test pattern as the other two pages.

- [ ] **Step 4: Run LocalUnit, build, and emulator checks**

Run LocalUnit again and require `BUILD SUCCESSFUL` with no `AssertException`, `BUILD FAILED`, or `COMPILE RESULT:FAIL`. Run `assembleHap`, install the generated HAP, and use HDC native taps/screenshots to verify Experience → College → Me.

- [ ] **Step 5: Commit and push**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppState.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MainPage.ets Mindspore_inhand_HarmonyOS/docs/superpowers/plans/2026-07-28-college-main-tab.md
git commit -m "feat(ui): add college main tab"
git push origin master
```
