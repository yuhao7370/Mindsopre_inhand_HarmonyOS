# HarmonyOS App Shell UI Design

Date: 2026-07-24

## Goal

Make the application shell reliable before redesigning the remaining feature pages:

- returning users enter the main page immediately;
- sensitive permissions are requested only by the workflow that needs them;
- first-run privacy consent remains usable at 3.2× font scale and in short windows;
- the existing floating bottom navigation keeps state and has native accessibility semantics;
- the system start window and app identity consistently use the existing flat MindSpore branding.

This phase does not redesign `ExperiencePage`, `MePage`, `CollegePage`, feature routes, or business workflows already approved in earlier phases.

## Scope

Files in scope are limited to the visible shell and its direct contracts:

- `Index.ets`
- `SplashPage.ets`
- `SplashStartupService.ets`
- `PermissionService.ets`
- `MainPage.ets`
- `BottomTabBar.ets`
- `BottomTabBarLayoutSpec.ets`
- `EntryAbility.ets`
- the direct camera-permission call in `DancePage.ets`
- startup color/icon resources
- localized shell strings and focused guards/tests

No shared navigation framework, permission manager abstraction, custom animation system, third-party UI package, or dark theme is introduced.

## Startup and privacy

### Returning users

The system start window is the only launch splash. If privacy consent is already stored, `SplashPage.aboutToAppear()` immediately calls `onFinished()`. There is no three-second timer, skip control, camera request, media request, or permission recovery dialog.

### First run

The first run shows one privacy consent card over the existing lightweight brand background.

- The card is capped by the currently available window height. It contains one Scroll, and that single Scroll includes the title, agreement copy, agreement link, and both final actions. There is no nested text-only scroll.
- The agreement link is a real 48vp text button with a complete accessibility label.
- “Agree” is the primary action.
- “Disagree and exit” is a secondary action.
- Actions are always stacked vertically. This is simpler and remains valid for narrow windows, long translations, and 3.2× font scale without breakpoint logic.
- Both actions use content-driven height with a minimum of 48vp.
- The card is one accessibility group; background branding is removed from the accessibility tree while consent is required.
- Back remains consumed until consent is resolved, preserving the current first-run contract.

Accepting stores consent and enters the main page immediately. Declining stores the decision and terminates the ability. Opening the agreement continues to use the existing Web route.

## Permission behavior

`PermissionService.requestForWorkflow()` remains the workflow-based runtime permission path. Dance is not represented by a `FeatureWorkflow`, so its current `requestStartup()` call is replaced by one explicit camera-only permission method.

Startup-only permission names and `requestStartup()` are removed. Camera, media, internet, and short-term save declarations remain in `module.json5`; this phase changes request timing, not declared capabilities or workflow requirements. Dance must not request media permission when it only starts the live camera.

No generic permission UI is added to the shell. Existing runtime pages remain responsible for permission denial, retry, and settings recovery.

Startup transition/retry/settings code in `SplashStartupService` and its old behavior tests are deleted when their final caller is removed. Only the still-required Index back-consumption contract remains.

## Theme and app identity

The current UI is intentionally light-only, so `EntryAbility` explicitly uses `COLOR_MODE_LIGHT`.

The dark-qualified start-window background is changed to the same light background as the base resource. `module.json5` reuses the existing flat MindSpore logo resource for both the start icon and application icon; unused DevEco template layered resources do not need to be rewritten. No new generated asset or alternate splash illustration is needed.

A focused resource guard pins the selected existing flat brand assets so the DevEco template icon cannot silently return.

System status/navigation safe areas remain system-managed. This phase does not add `expandSafeArea()` or manual top/bottom insets.

## Bottom navigation

The current floating white capsule is retained.

Each tab item:

- remains at least 50vp high;
- is one accessibility group with button/tab semantics;
- exposes the localized label and selected state;
- hides the decorative image from separate announcement;
- uses a darker readable brand blue for small selected text;
- keeps the existing pale-blue selected background, so state is not expressed by color alone.

The bar remains 90% wide on narrow phones and is capped at 500vp on wide windows.

## Root-page state preservation

`MainPage` keeps the two public root pages (`ExperiencePage` and `MePage`) mounted in one `Stack`. Selection changes visibility instead of conditionally destroying a page.

The hidden College tab is not mounted because it is not present in `mainTabs`. No route cache, page repository, or second navigation system is introduced.

Expected behavior:

- Experience scroll position survives switching to Me and back.
- Me transient UI state survives switching to Experience and back.
- the hidden page cannot receive touch or accessibility focus.

## Frozen contracts

- `FeatureCatalog.visibleByDefault` remains the only feature-entry visibility source.
- Workflow permission requirements and `requestForWorkflow()` behavior do not change; Dance requests only camera.
- The privacy Web route and stored consent format do not change.
- `mainTabs` continues to expose only Experience and Me.
- The existing floating bottom-bar visual direction remains unchanged.
- Router/system return behavior from feature pages remains unchanged.
- Existing system-managed safe-area behavior remains unchanged.

## Commit boundaries

1. Remove startup permission gating and replace Dance's startup request with camera-only permission.
2. Remove the returning-user countdown.
3. Make first-run privacy consent scrollable, content-driven, and accessible.
4. Lock the light startup theme and reuse the existing flat brand assets.
5. Add bottom-tab semantics, readable selected text, and wide-window cap.
6. Keep Experience and Me root pages mounted across tab switches.

Each boundary receives a focused guard or LocalUnit assertion and one commit.

## Native verification

Use HDC `uitest` touch input and `snapshot_display`; Computer Use is not the primary path.

### Startup and consent

- Clear app data and capture first-run consent at 1.0× and 3.2×.
- Confirm all consent content and both actions are scrollable and clickable.
- Open the privacy Web route and return to the same unresolved consent state.
- Accept and confirm immediate entry without camera/media prompts.
- Relaunch and confirm immediate entry without countdown.
- Decline and confirm the ability terminates.

### Permission timing

- With camera/media denied, relaunch and enter Experience/Me.
- Enter one camera workflow and one gallery workflow; confirm each requests only when used.
- Enter Dance and confirm it requests camera without requesting media.
- Deny and retry through the existing workflow recovery UI.

### Navigation

- Scroll Experience into the advanced section, switch to Me, then back; verify the original scroll position.
- Switch tabs repeatedly at 1.0× and 3.2×; verify one selected item, no click-through, and no rebuild flash.
- Capture narrow portrait and wide/landscape layouts; verify the bar stays centered and no wider than 500vp.

### Theme and accessibility

- Cold-start once with system light and dark appearance; both retain the same light start window and readable system bars.
- Inspect layout JSON for one accessibility node per tab with localized text and selected state.
- Confirm the consent background is excluded from accessibility while the card is active.

## Completion gate

The phase is complete only when:

- focused guards and mutation checks pass;
- LocalUnit passes;
- main and ohosTest HAPs contain `arm64-v8a` and `x86_64`;
- the native verification matrix has screenshot/layout evidence;
- an independent reviewer approves spec compliance and code quality with no Critical or Important findings.
