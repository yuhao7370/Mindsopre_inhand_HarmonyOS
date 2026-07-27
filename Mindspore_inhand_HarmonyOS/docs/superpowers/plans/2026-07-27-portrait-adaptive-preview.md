# Portrait Adaptive Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make portrait segmentation previews compact for vertical cameras, full-width for horizontal cameras, and remove the visible result scrollbar.

**Architecture:** Derive preview width from the existing oriented camera aspect ratio in `LiveCameraService.ets`. Reuse that value for both preview builders while retaining the existing aspect ratio and inference rotation paths.

**Tech Stack:** ArkTS, HarmonyOS ArkUI, Hypium, PowerShell contract guards

## Global Constraints

- Vertical camera: `3:4` preview at `78%` width.
- Horizontal camera: `4:3` preview at `100%` width.
- Camera and segmentation result use identical dimensions.
- Scrolling remains available with `BarState.Off`.
- Do not change inference, image rotation, saving, or background replacement.

---

### Task 1: Adaptive portrait preview layout

**Files:**
- Modify: `entry/src/main/ets/services/camera/LiveCameraService.ets`
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `scripts/check-portrait-runtime-ui.ps1`
- Modify: `scripts/test-portrait-runtime-ui-guard.ps1`
- Modify: `docs/superpowers/specs/2026-07-27-portrait-adaptive-preview-design.md`
- Create: `docs/superpowers/specs/assets/portrait-segmentation-layout-concept-v2.png`

**Interfaces:**
- Produces: `livePreviewWidthForAspectRatio(aspectRatio: number): string`
- Consumes: `liveCameraPreviewAspectRatio`

- [x] **Step 1: Write failing regressions**

Add Hypium expectations:

```typescript
expect(livePreviewWidthForAspectRatio(3 / 4)).assertEqual('78%');
expect(livePreviewWidthForAspectRatio(4 / 3)).assertEqual('100%');
expect(livePreviewWidthForAspectRatio(Number.NaN)).assertEqual('100%');
```

Require both preview builders to use the helper and the result `Scroll` to use `BarState.Off`; add mutations restoring fixed full width and `BarState.Auto`.

- [x] **Step 2: Verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-portrait-runtime-ui.ps1
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: guard fails because adaptive width and hidden scrollbar are absent; ArkTS test compilation fails because `livePreviewWidthForAspectRatio` is absent.

- [x] **Step 3: Implement the minimum**

```typescript
export function livePreviewWidthForAspectRatio(aspectRatio: number): string {
  return Number.isFinite(aspectRatio) && aspectRatio > 0 && aspectRatio < 1 ? '78%' : '100%';
}
```

Use `.width(livePreviewWidthForAspectRatio(this.liveCameraPreviewAspectRatio))` on both previews and change only the portrait result scroll to `.scrollBar(BarState.Off)`.

- [x] **Step 4: Verify GREEN**

Run the focused guard, mutation guard, complete Hypium suite, clean HAP build, install through HDC, and capture top and scrolled screenshots.

- [x] **Step 5: Commit**

```powershell
git add entry/src/main/ets/services/camera/LiveCameraService.ets entry/src/main/ets/pages/FeatureRuntimePage.ets entry/src/test/LocalUnit.test.ets scripts/check-portrait-runtime-ui.ps1 scripts/test-portrait-runtime-ui-guard.ps1 docs/superpowers
git commit -m "fix(portrait): adapt preview layout to camera direction"
```
