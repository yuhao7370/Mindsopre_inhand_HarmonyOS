# HarmonyOS App Shell UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove global startup blockers, make first-run consent accessible, keep the existing floating tabs stateful, and align the system launch identity with the light HarmonyOS UI.

**Architecture:** Keep the existing `Index -> SplashPage/MainPage` structure. Delete startup-only permission/countdown state, keep permission requests at the workflow boundary, and use the current ArkUI components with one focused static guard. Keep Experience and Me mounted directly; do not add a navigation/cache layer.

**Tech Stack:** HarmonyOS 6.1 / API 24, ArkTS, ArkUI, Hypium LocalUnit, PowerShell source guards, Hvigor, HDC `uitest`, `dumpLayout`, and `snapshot_display`.

## Global Constraints

- Follow `AGENTS.md`; keep the existing floating bottom-navigation visual.
- Do not add a third-party dependency, shared shell framework, state repository, responsive breakpoint system, custom route animation, or dark theme.
- Keep system-managed safe areas; do not add `expandSafeArea()` or manual system-bar insets.
- Keep `FeatureCatalog.visibleByDefault`, routes, workflow inputs, permission requirements, and inference behavior unchanged.
- `mainTabs` must continue to expose only Experience and Me.
- Use native HDC touch and screenshots for emulator validation; do not use Computer Use as the primary path.
- Every task ends with a focused check, independent review, and one commit.

---

## File Map

- `entry/src/main/ets/pages/SplashPage.ets`: first-run privacy UI only.
- `entry/src/main/ets/services/splash/SplashStartupService.ets`: Index back-consumption contract only.
- `entry/src/main/ets/services/permissions/PermissionService.ets`: workflow permission requests plus explicit Dance camera request.
- `entry/src/main/ets/pages/DancePage.ets`: calls camera-only permission API.
- `entry/src/main/ets/entryability/EntryAbility.ets`: locks the application to the implemented light theme.
- `entry/src/main/module.json5`: reuses the existing flat MindSpore logo for launch/application identity.
- `entry/src/main/resources/dark/element/color.json`: matches the base light launch background.
- `entry/src/main/ets/common/components/BottomTabBar.ets`: native semantics and bounded floating layout.
- `entry/src/main/ets/common/data/BottomTabBarLayoutSpec.ets`: one 500vp maximum-width constant.
- `entry/src/main/ets/pages/MainPage.ets`: keeps Experience and Me mounted.
- `entry/src/test/LocalUnit.test.ets`: removes obsolete startup-permission expectations and keeps pure shell contracts.
- `entry/src/test/ExperienceFontScaleUnit.test.ets`: checks the bottom-bar maximum width.
- `scripts/check-app-shell-ui.ps1`: focused structural guard for shell behavior.
- `scripts/test-app-shell-ui-guard.ps1`: deletion mutations for the focused guard.

---

### Task 1: Request sensitive permissions only when a workflow needs them

**Files:**
- Modify: `entry/src/main/ets/services/permissions/PermissionService.ets`
- Modify: `entry/src/main/ets/pages/DancePage.ets`
- Modify: `entry/src/main/ets/pages/SplashPage.ets`
- Modify: `entry/src/main/ets/services/splash/SplashStartupService.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Create: `scripts/check-app-shell-ui.ps1`
- Create: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Produces: `PermissionService.requestCamera(context): Promise<PermissionRequestSummary>`.
- Preserves: `PermissionService.requestForWorkflow(context, workflow)`.
- Produces: `shouldConsumeIndexBackPress(showMainPage: boolean): boolean` as the only remaining Splash service contract.

- [ ] **Step 1: Add a failing focused guard**

Create `scripts/check-app-shell-ui.ps1` with checks equivalent to:

```powershell
$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw

if ($permission -match 'requestStartup|startupPermissionNames') {
  throw 'Startup permission API must not exist.'
}
if ($splash -match 'PermissionService|showPermissionDialog|permissionDialog') {
  throw 'Splash must not request or recover runtime permissions.'
}
if ($permission -notmatch 'async\s+requestCamera\([^)]*\)[\s\S]*?\{\s*return\s+this\.requestPermissionNames\(context,\s*\[\s*cameraPermissionName\s*\]\);\s*\}') {
  throw 'Dance camera permission must have an explicit camera-only API.'
}
if ($dance -notmatch 'new PermissionService\(\)\.requestCamera\(context\)') {
  throw 'Dance must request camera only.'
}
```

Create `scripts/test-app-shell-ui-guard.ps1` to copy those four source strings in memory, remove each required clause once, and assert that the same predicate rejects the mutation. Include a mutation that changes `[cameraPermissionName]` to `[cameraPermissionName, mediaPermissionName]`; it must be rejected.

- [ ] **Step 2: Run RED**

Run:

```powershell
& .\scripts\check-app-shell-ui.ps1
```

Expected: FAIL because `requestStartup`, permission dialog state, and the Dance startup request still exist.

- [ ] **Step 3: Replace the startup permission API**

In `PermissionService.ets`, delete `startupPermissionNames()` and `requestStartup()`, then add:

```typescript
async requestCamera(context: common.UIAbilityContext): Promise<PermissionRequestSummary> {
  return this.requestPermissionNames(context, [cameraPermissionName]);
}
```

In `DancePage.ets`, replace:

```typescript
new PermissionService().requestStartup(context)
```

with:

```typescript
new PermissionService().requestCamera(context)
```

- [ ] **Step 4: Remove Splash permission gating but preserve the temporary countdown**

In `SplashPage.ets`:

- delete permission imports, permission state, permission dialog, retry/settings/exit handlers, and startup request transitions;
- when stored privacy is accepted, call `startCountdown()`;
- when privacy is accepted for the first time, store consent and call `finishSplash()` immediately;
- let `finishSplash()` call `onFinished()` without permission state.

Reduce `SplashStartupService.ets` to:

```typescript
export function shouldConsumeIndexBackPress(showMainPage: boolean): boolean {
  return !showMainPage;
}
```

Remove obsolete startup-permission imports/tests from `LocalUnit.test.ets`. Keep the privacy persistence and Index back tests.

- [ ] **Step 5: Run GREEN**

Run:

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: both guards pass; LocalUnit prints `BUILD SUCCESSFUL` with no assertion-failure marker.

- [ ] **Step 6: Commit**

```powershell
git add entry/src/main/ets/services/permissions/PermissionService.ets entry/src/main/ets/pages/DancePage.ets entry/src/main/ets/pages/SplashPage.ets entry/src/main/ets/services/splash/SplashStartupService.ets entry/src/test/LocalUnit.test.ets scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(startup): request sensitive permissions on demand"
```

---

### Task 2: Remove the redundant three-second branded delay

**Files:**
- Modify: `entry/src/main/ets/pages/SplashPage.ets`
- Modify: `scripts/check-app-shell-ui.ps1`
- Modify: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Consumes: stored privacy consent.
- Produces: accepted users call `onFinished()` during `aboutToAppear()`.

- [ ] **Step 1: Extend the guard and verify RED**

Add:

```powershell
if ($splash -match 'countdownTimer|countdownValue|startCountdown|countdownButton|setInterval') {
  throw 'Returning users must not wait on a second splash countdown.'
}
```

Add one deletion mutation that injects `setInterval` into the Splash source and confirm rejection.

Run both guards. Expected: RED on the existing countdown.

- [ ] **Step 2: Delete the countdown**

Delete countdown state, timer lifecycle methods, the countdown button builder, and its row. Make:

```typescript
aboutToAppear() {
  const service = this.privacyConsentService();
  if (service !== undefined && service.hasAcceptedPrivacy()) {
    this.onFinished();
    return;
  }
  this.showPrivacyDialog = true;
}
```

Keep the brand background only as the first-run consent backdrop.

- [ ] **Step 3: Run GREEN and commit**

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
git add entry/src/main/ets/pages/SplashPage.ets scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(startup): enter immediately after privacy consent"
```

Expected: guards pass and no countdown token remains.

---

### Task 3: Make first-run consent reachable and accessible

**Files:**
- Modify: `entry/src/main/ets/pages/SplashPage.ets`
- Modify: `entry/src/main/ets/common/theme/AppTheme.ets`
- Modify: localized `entry/src/main/resources/*/element/string.json` only if an existing full accessibility label is unavailable
- Modify: `scripts/check-app-shell-ui.ps1`
- Modify: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Preserves: `PrivacyConsentService.acceptPrivacy()`, `declinePrivacy()`, `openPrivacyPolicy()`.
- Produces: one scrollable consent card with 48vp actions.

- [ ] **Step 1: Add RED structural checks**

Require:

```powershell
if ($splash -match '\.height\(180\)|\.height\(38\)') {
  throw 'Consent must not use fixed text or action heights.'
}
function Get-BracedBody([string]$source, [string]$marker) {
  $markerIndex = $source.IndexOf($marker, [System.StringComparison]::Ordinal)
  if ($markerIndex -lt 0) { throw "Missing marker: $marker" }
  $openIndex = $source.IndexOf('{', $markerIndex)
  if ($openIndex -lt 0) { throw "Missing block after: $marker" }
  $depth = 0
  for ($index = $openIndex; $index -lt $source.Length; $index += 1) {
    if ($source[$index] -eq '{') { $depth += 1 }
    if ($source[$index] -eq '}') {
      $depth -= 1
      if ($depth -eq 0) {
        return $source.Substring($openIndex + 1, $index - $openIndex - 1)
      }
    }
  }
  throw "Unclosed block after: $marker"
}

$privacyDialog = Get-BracedBody $splash 'privacyDialog()'
if ([regex]::Matches($privacyDialog, 'Scroll\(\)').Count -ne 1) {
  throw 'Consent must contain exactly one Scroll.'
}
$consentScroll = Get-BracedBody $privacyDialog 'Scroll()'
@('me_user_agreements', 'me_privacy', 'me_user_agreement', 'me_disagree_and_exit', 'me_agree') |
  ForEach-Object {
    if ($consentScroll -notmatch [regex]::Escape($_)) {
      throw "Consent Scroll is missing: $_"
    }
  }
if ($consentScroll.IndexOf('me_user_agreements') -gt $consentScroll.IndexOf('me_agree')) {
  throw 'Consent actions must follow the title and copy.'
}
if ($splash -notmatch "constraintSize\(\{\s*minHeight:\s*48") {
  throw 'Consent actions must be at least 48vp.'
}
if ($splash -notmatch "accessibilityLevel\('no-hide-descendants'\)") {
  throw 'Consent background must be hidden from accessibility.'
}
```

Add mutations that remove the shared Scroll, inject a second `Scroll()`, move `me_agree` after the Scroll closes, remove the 48vp action size, and remove background accessibility hiding. Each mutation must be rejected.

Run both guards. Expected: RED.

- [ ] **Step 2: Build the single-scroll consent card**

Keep the change in `SplashPage.ets`. Use one `Scroll` capped to the available modal region:

```typescript
Scroll() {
  Column() {
    Text(appString('me_user_agreements'))
    Text(appString('me_privacy'))
    Button(appString('me_user_agreement'), { type: ButtonType.Normal })
      .constraintSize({ minHeight: 48 })
      .onClick(() => this.openPrivacyPolicy())
    Button(appString('me_disagree_and_exit'))
      .constraintSize({ minHeight: 48 })
      .onClick(() => this.declinePrivacy())
    Button(appString('me_agree'))
      .constraintSize({ minHeight: 48 })
      .onClick(() => this.acceptPrivacy())
  }
  .padding(AppSpacing.lg)
}
.width('86%')
.height('82%')
.backgroundColor(AppColor.cardBackground)
.borderRadius(AppRadius.sheet)
.accessibilityGroup(true)
```

Always stack the actions vertically. Apply `.accessibilityLevel('no-hide-descendants')` to the brand background Column while the dialog is shown.

Add `AppColor.textAccent` with a dark blue meeting 4.5:1 on white and use it for the agreement link.

- [ ] **Step 3: Run guards, LocalUnit, and HAP compile**

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& .\scripts\build-hap.ps1
```

Expected: guards and LocalUnit pass; HAP build prints `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit**

```powershell
git add entry/src/main/ets/pages/SplashPage.ets entry/src/main/ets/common/theme/AppTheme.ets entry/src/main/resources scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(splash): make privacy consent reachable"
```

---

### Task 4: Keep the launch identity consistently light and branded

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/resources/dark/element/color.json`
- Modify: `scripts/check-app-shell-ui.ps1`
- Modify: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Reuses: `$media:logo_splash`.
- Produces: light color mode and light start window in all system appearances.

- [ ] **Step 1: Add RED checks**

Require:

```powershell
if ($entryAbility -notmatch 'COLOR_MODE_LIGHT') { throw 'Application must explicitly use the implemented light theme.' }
if ($module -notmatch '"icon": "\$media:logo_splash"') { throw 'Application icon must use the flat MindSpore logo.' }
if ($module -notmatch '"startWindowIcon": "\$media:logo_splash"') { throw 'Start icon must use the flat MindSpore logo.' }
if ($darkColor -notmatch '"value": "#FFFFFF"') { throw 'Dark-qualified start window must remain light.' }
```

Add one mutation for each token and run RED.

- [ ] **Step 2: Apply the native light configuration**

Change:

```typescript
ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
```

to:

```typescript
ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
```

Point `icon` and `startWindowIcon` in `module.json5` to `$media:logo_splash`. Change the dark-qualified start background to `#FFFFFF`. Do not edit the unused DevEco layered PNGs.

- [ ] **Step 3: Run GREEN and commit**

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& .\scripts\build-hap.ps1
git add entry/src/main/ets/entryability/EntryAbility.ets entry/src/main/module.json5 entry/src/main/resources/dark/element/color.json scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(theme): keep launch identity light and branded"
```

---

### Task 5: Add native semantics and a wide-window cap to the floating tabs

**Files:**
- Modify: `entry/src/main/ets/common/components/BottomTabBar.ets`
- Modify: `entry/src/main/ets/common/data/BottomTabBarLayoutSpec.ets`
- Modify: `entry/src/test/ExperienceFontScaleUnit.test.ets`
- Modify: `scripts/check-app-shell-ui.ps1`
- Modify: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Produces: `bottomTabBarMaxWidthVp: number = 500`.
- Preserves: existing selected/unselected PNG resources and 50/62vp minimum heights.

- [ ] **Step 1: Add failing assertions**

In `ExperienceFontScaleUnit.test.ets`, import and assert:

```typescript
expect(bottomTabBarMaxWidthVp).assertEqual(500);
```

Extend the shell guard to require:

```powershell
@(
  'accessibilityGroup\(true\)',
  'accessibilityText\(appString\(tab\.titleKey\)\)',
  'accessibilityRole\(AccessibilityRoleType\.BUTTON\)',
  'accessibilitySelected\(this\.selected === tab\.id\)',
  'constraintSize\(\{\s*minHeight:\s*bottomTabBarMinHeightVp,\s*maxWidth:\s*bottomTabBarMaxWidthVp\s*\}\)'
) | ForEach-Object {
  if ($bottomTab -notmatch $_) { throw "Bottom tab contract missing: $_" }
}
```

Run LocalUnit and guards. Expected: RED.

Add mutations that remove `accessibilityText(appString(tab.titleKey))` and replace the selected-state expression with a constant; both must be rejected.

- [ ] **Step 2: Implement the minimum native semantics**

Add:

```typescript
export const bottomTabBarMaxWidthVp: number = 500;
```

For each tab item:

```typescript
.accessibilityGroup(true)
.accessibilityText(appString(tab.titleKey))
.accessibilityRole(AccessibilityRoleType.BUTTON)
.accessibilitySelected(this.selected === tab.id)
```

Mark the decorative `Image` with `.accessibilityLevel('no')`. Use `AppColor.textAccent` for selected 11fp text.

Change the Row constraint to:

```typescript
.constraintSize({
  minHeight: bottomTabBarMinHeightVp,
  maxWidth: bottomTabBarMaxWidthVp
})
```

Keep `.width('90%')`, current media resources, selected background, radius, and shadow.

- [ ] **Step 3: Run GREEN and commit**

```powershell
& .\scripts\check-bottom-tab-icons.ps1
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
git add entry/src/main/ets/common/components/BottomTabBar.ets entry/src/main/ets/common/data/BottomTabBarLayoutSpec.ets entry/src/test/ExperienceFontScaleUnit.test.ets scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(navigation): make floating tabs accessible"
```

---

### Task 6: Preserve Experience and Me state across tab switches

**Files:**
- Modify: `entry/src/main/ets/pages/MainPage.ets`
- Modify: `scripts/check-app-shell-ui.ps1`
- Modify: `scripts/test-app-shell-ui-guard.ps1`

**Interfaces:**
- Consumes: `MainTab.EXPERIENCE`, `MainTab.ME`.
- Produces: two mounted root instances with visibility and hit-testing tied to `selectedTab`.

- [ ] **Step 1: Add RED checks**

Require that `MainPage.ets`:

- contains one `ExperiencePage()` and one `MePage()` in the same `Stack`;
- contains no `CollegePage()` or College import;
- applies `Visibility.Visible/Hidden`;
- applies `HitTestMode.Default/None`;
- does not use the old `currentPageBuilder()` conditional.

Add mutations that remove the hidden hit-test rule and reinsert `CollegePage()`.

- [ ] **Step 2: Keep both public roots mounted**

Replace the conditional builder with:

```typescript
Stack() {
  ExperiencePage()
    .visibility(this.selectedTab === MainTab.EXPERIENCE ? Visibility.Visible : Visibility.Hidden)
    .hitTestBehavior(this.selectedTab === MainTab.EXPERIENCE ? HitTestMode.Default : HitTestMode.None)
  MePage()
    .visibility(this.selectedTab === MainTab.ME ? Visibility.Visible : Visibility.Hidden)
    .hitTestBehavior(this.selectedTab === MainTab.ME ? HitTestMode.Default : HitTestMode.None)
}
.layoutWeight(1)
.width('100%')
```

Delete the College import and `currentPageBuilder()`.

- [ ] **Step 3: Run GREEN, build, and commit**

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& .\scripts\build-hap.ps1
git add entry/src/main/ets/pages/MainPage.ets scripts/check-app-shell-ui.ps1 scripts/test-app-shell-ui-guard.ps1
git commit -m "fix(navigation): retain public tab state"
```

---

### Task 7: Native runtime verification and final review

**Files:**
- Update ignored evidence: `.superpowers/sdd/emulator-evidence/app-shell/*`
- Update ignored ledger: `.superpowers/sdd/progress.md`

- [ ] **Step 1: Run final static and package acceptance**

```powershell
& .\scripts\check-app-shell-ui.ps1
& .\scripts\test-app-shell-ui-guard.ps1
& .\scripts\check-bottom-tab-icons.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& .\scripts\build-ai-runtime-acceptance.ps1
git diff --check
```

Expected: all guards and LocalUnit pass; main and ohosTest HAPs contain `arm64-v8a,x86_64`.

- [ ] **Step 2: Verify first run with native touch**

Use HDC only:

```powershell
hdc shell bm clean -n com.yuhaofeng.mih
hdc shell aa start -a EntryAbility -b com.yuhaofeng.mih
hdc shell uitest dumpLayout -p /data/local/tmp/app-shell-consent.json
hdc shell snapshot_display -f /data/local/tmp/app-shell-consent.jpeg
```

Capture default and 3.2× consent, scroll to both actions, open the agreement, return, accept, and separately decline.

For the 3.2× capture, use the existing detached test worktree `E:\Mindsopre_inhand_HarmonyOS\.worktrees\shell-runtime-harness`: sync the App Shell commits, temporarily make its `EntryAbility` load `pages/Index`, and add this test-only line in `onCreate()`:

```typescript
this.context.getApplicationContext().setFontSizeScale(3.2);
```

Build/install that HAP, capture the evidence, then remove the temporary line and restore the harness file. Do not commit the font override or copy it into the product worktree.

- [ ] **Step 3: Verify permission timing and returning launch**

After consent, deny/revoke both `CAMERA` and `READ_IMAGEVIDEO`, cold-start the app, and confirm Experience/Me still open without a permission prompt. Then open one camera workflow, one gallery workflow, and Dance; record that requests occur only at use time and Dance requests camera only. Relaunch once more and confirm there is no countdown.

- [ ] **Step 4: Verify state preservation and accessibility**

Scroll Experience into Advanced, switch to Me, and switch back with `uitest uiInput click`; compare layout bounds before/after. Dump layout at default and 3.2× and confirm a single node per tab with selected state.

- [ ] **Step 5: Verify wide/landscape layout**

Use the emulator's supported rotation/window controls, capture the floating bar, and assert its measured width is no more than 500vp while remaining above the system navigation area.

- [ ] **Step 6: Restore the production HAP**

Install:

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

Restart `EntryAbility` and capture the production Experience page.

- [ ] **Step 7: Independent final review**

Dispatch a fresh reviewer over the spec, plan, commits, guards, native screenshots/layout JSON, permission timing, and full acceptance output. Fix every Critical/Important finding and re-review before marking App Shell complete.
