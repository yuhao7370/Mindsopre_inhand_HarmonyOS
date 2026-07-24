# HarmonyOS Feature Runtime UI Implementation Plan

Date: 2026-07-24

Spec:
`docs/superpowers/specs/2026-07-24-harmony-feature-runtime-ui-design.md`

Baseline: `6f50e81`

## Rules for every task

1. Add or strengthen a focused guard and a balanced mutation fixture first;
   record RED.
2. Make the smallest ArkTS/resource/guard change that satisfies the task.
3. Run the focused checks, mutation suite, `git diff --check`, and LocalUnit.
4. Build/install the HAP and use only HDC native touch, layout dumps, and
   screenshots for runtime verification.
5. Request an independent subagent review.
6. Commit only after the task is verified and reviewed; one completed
   workflow per commit. Task 1 is infrastructure only and cannot mark a
   workflow complete.
7. Update `.superpowers/sdd/progress.md` with evidence and commit SHA.

## Guard migration ownership

The following old Android visual assertions must be rewritten in the same
commit as their owning UI, never deleted or weakened first:

- Task 1: `check-toolbar-back-icon.ps1`,
  `check-runtime-header-actions.ps1`, `check-live-camera-switch-icon.ps1`
- Task 2: `check-still-scene-layout-parity.ps1`
- Task 3: `check-posenet-still-layout-parity.ps1`
- Task 4: `check-static-gesture-layout-parity.ps1`
- Task 5: `check-object-photo-layout-parity.ps1`
- Task 6: `check-still-segmentation-layout-parity.ps1`
- Task 15: `check-text-translation-input-parity.ps1`
- Task 16: `check-style-transfer-layout-parity.ps1`
- Task 17: `check-custom-model-layout-parity.ps1`

`check-runtime-layout-closure.ps1`, view-ID checks, fixed-camera-route checks,
segmentation/portrait save-readiness checks, translation input-mode checks,
runtime contract/debug checks, model/ABI/native-boundary checks remain strict
throughout the phase.

## Exact verification and evidence contract

Each task owns one production guard and one mutation runner:

| Task | Production guard | Mutation runner |
| --- | --- | --- |
| 1 | `check-runtime-shared-ui.ps1` plus the three migrated header/switch guards | `test-runtime-shared-ui-guard.ps1`, `test-runtime-ui-evidence-guard.ps1` |
| 2 | `check-still-scene-layout-parity.ps1` | `test-still-scene-layout-parity-guard.ps1` |
| 3 | `check-posenet-still-layout-parity.ps1` | `test-posenet-still-layout-guard.ps1` |
| 4 | `check-static-gesture-layout-parity.ps1` | `test-static-gesture-layout-guard.ps1` |
| 5 | `check-object-photo-layout-parity.ps1` | `test-object-photo-layout-parity-guard.ps1` |
| 6 | `check-still-segmentation-layout-parity.ps1` | `test-still-segmentation-layout-parity-guard.ps1` |
| 7 | `check-ocr-runtime-ui.ps1` | `test-ocr-runtime-ui-guard.ps1` |
| 8 | `check-live-classification-runtime-ui.ps1` | `test-live-classification-runtime-ui-guard.ps1` |
| 9 | `check-live-object-runtime-ui.ps1` | `test-live-object-runtime-ui-guard.ps1` |
| 10 | `check-live-segmentation-runtime-ui.ps1` | `test-live-segmentation-runtime-ui-guard.ps1` |
| 11 | `check-live-gesture-runtime-ui.ps1` | `test-live-gesture-runtime-ui-guard.ps1` |
| 12 | `check-live-scene-runtime-ui.ps1` | `test-live-scene-runtime-ui-guard.ps1` |
| 13 | `check-live-skeleton-runtime-ui.ps1` | `test-live-skeleton-runtime-ui-guard.ps1` |
| 14 | `check-portrait-runtime-ui.ps1`, `check-feature-runtime-view-ids.ps1`, `check-portrait-composite-save-readiness.ps1` | `test-portrait-runtime-ui-guard.ps1`, `test-feature-runtime-view-ids.ps1` |
| 15 | `check-text-translation-input-parity.ps1`, `check-text-translation-input-mode.ps1` | `test-text-translation-layout-guard.ps1` |
| 16 | `check-style-transfer-layout-parity.ps1` | `test-style-transfer-layout-parity-guard.ps1` |
| 17 | `check-custom-model-layout-parity.ps1`, `check-runtime-hidden-model-ui.ps1` | `test-custom-model-layout-guard.ps1`, `test-runtime-hidden-model-ui-guard.ps1` |

New script names above are created only when no focused semantic guard exists.
Every new production guard accepts `-SourceRoot`, every mutation runner builds
a minimal valid fixture in a GUID-named temporary directory, applies each
required replacement exactly once, invokes the production guard against the
mutated `-SourceRoot`, and fails unless the guard rejects it. Fixtures also put
the required marker in comments/strings/sibling builders to prove decoy
resistance. Safe cleanup verifies that the resolved temporary path remains
under the system temp directory.

Run the exact production/mutation filenames from the table for the active task.
This executable map avoids filename placeholders; set only `$taskNumber`:

```powershell
$taskNumber = 1
$taskScripts = @{
  1 = @('check-runtime-shared-ui.ps1', 'check-toolbar-back-icon.ps1', 'check-runtime-header-actions.ps1', 'check-live-camera-switch-icon.ps1', 'test-runtime-shared-ui-guard.ps1', 'test-runtime-ui-evidence-guard.ps1')
  2 = @('check-still-scene-layout-parity.ps1', 'test-still-scene-layout-parity-guard.ps1')
  3 = @('check-posenet-still-layout-parity.ps1', 'test-posenet-still-layout-guard.ps1')
  4 = @('check-static-gesture-layout-parity.ps1', 'test-static-gesture-layout-guard.ps1')
  5 = @('check-object-photo-layout-parity.ps1', 'test-object-photo-layout-parity-guard.ps1')
  6 = @('check-still-segmentation-layout-parity.ps1', 'test-still-segmentation-layout-parity-guard.ps1')
  7 = @('check-ocr-runtime-ui.ps1', 'test-ocr-runtime-ui-guard.ps1')
  8 = @('check-live-classification-runtime-ui.ps1', 'test-live-classification-runtime-ui-guard.ps1')
  9 = @('check-live-object-runtime-ui.ps1', 'test-live-object-runtime-ui-guard.ps1')
  10 = @('check-live-segmentation-runtime-ui.ps1', 'test-live-segmentation-runtime-ui-guard.ps1')
  11 = @('check-live-gesture-runtime-ui.ps1', 'test-live-gesture-runtime-ui-guard.ps1')
  12 = @('check-live-scene-runtime-ui.ps1', 'test-live-scene-runtime-ui-guard.ps1')
  13 = @('check-live-skeleton-runtime-ui.ps1', 'test-live-skeleton-runtime-ui-guard.ps1')
  14 = @('check-portrait-runtime-ui.ps1', 'check-feature-runtime-view-ids.ps1', 'check-portrait-composite-save-readiness.ps1', 'test-portrait-runtime-ui-guard.ps1', 'test-feature-runtime-view-ids.ps1')
  15 = @('check-text-translation-input-parity.ps1', 'check-text-translation-input-mode.ps1', 'test-text-translation-layout-guard.ps1')
  16 = @('check-style-transfer-layout-parity.ps1', 'test-style-transfer-layout-parity-guard.ps1')
  17 = @('check-custom-model-layout-parity.ps1', 'check-runtime-hidden-model-ui.ps1', 'test-custom-model-layout-guard.ps1', 'test-runtime-hidden-model-ui-guard.ps1')
}
$taskScripts[$taskNumber] | ForEach-Object { & (Join-Path '.\scripts' $_) }
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& .\scripts\build-hap.ps1
git diff --check
```

Pre-commit runtime evidence is stored under
`.superpowers/sdd/emulator-evidence/runtime-ui/task-<N>-hap-<hap-sha12>/`.
That directory records the full HAP SHA-256, candidate diff hash, `aa dump`,
and paired JSON/JPEG states. After the verified commit is created, append its
commit SHA to the evidence manifest; the directory name does not depend on a
commit that does not yet exist.
The native command shape is:

```powershell
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.yuhaofeng.mih
hdc shell uitest uiInput click <x> <y>
hdc shell uitest uiInput swipe <x1> <y1> <x2> <y2> 600
hdc shell uitest uiInput keyEvent Back
hdc shell uitest dumpLayout -p /data/local/tmp/<state>.json
hdc shell snapshot_display -f /data/local/tmp/<state>.jpeg
hdc file recv /data/local/tmp/<state>.json <evidence-directory>
hdc file recv /data/local/tmp/<state>.jpeg <evidence-directory>
hdc shell aa dump -a
```

Task 1 creates `scripts/check-runtime-ui-evidence.ps1`. Every later task runs:

```powershell
& .\scripts\check-runtime-ui-evidence.ps1 -ManifestPath C:\absolute\path\manifest.json
```

The manifest is UTF-8 JSON with this fixed schema:

```json
{
  "task": 1,
  "candidateDiffSha256": "<64 hex>",
  "hapPath": "<absolute HAP path>",
  "hapSha256": "<64 hex>",
  "commitSha": "",
  "routeName": "<exact AppRoute name>",
  "fontScale": 1.0,
  "source": "production",
  "density": 3.5,
  "permissionBefore": { "camera": -1, "media": -1 },
  "permissionAfter": { "camera": 0, "media": -1 },
  "aaDumpPath": "<absolute text path>",
  "states": [
    {
      "name": "initial",
      "layout": "<absolute JSON path>",
      "screenshot": "<absolute JPEG path>",
      "pagePath": "pages/FeatureRuntimePage",
      "scrollableCount": 1,
      "requiredTexts": [],
      "forbiddenTexts": [],
      "requiredClickableTexts": [],
      "minTargetVp": 44,
      "minPrimaryTargetVp": 48,
      "bottomInsetPx": 98,
      "preservedBoundsHashFrom": ""
    }
  ]
}
```

The checker rejects missing files, a mismatched HAP hash, invalid enums,
missing foreground `aa dump`, wrong page/route, wrong scroll count,
absent/forbidden texts, non-clickable required controls, undersized targets,
visible bounds outside the application area, overlapping action bounds, hidden
labels, fixed-route camera switches, missing state labels, and mismatched
preservation hashes. `test-runtime-ui-evidence-guard.ps1` builds one valid tiny
dump/manifest and mutates every field above, including comment/text decoys, to
prove rejection.

Font, direct-route, state, and permission setup is deterministic:

- User-reachable initial and success evidence at default font comes from the
  current production HAP. Hidden routes and deterministic injected states may
  use the isolated 1.0x/3.2x Runtime harness because production intentionally
  has no hidden entry or state-injection surface.
- 3.2x evidence uses the isolated Runtime harness worktree. Its
  `EntryAbility.ets` calls
  `this.context.getApplicationContext().setFontSizeScale(3.2)` before loading
  the production page. After capture, restore that exact file with
  `git restore --source=HEAD -- <file>` and require an empty harness
  `git status --short`.
- Hidden/direct routes use the harness-only `RuntimeHarnessPage` route
  parameter. Running/success/failure fixtures may use only harness-local
  adapters around existing service interfaces; record the harness diff, never
  copy it into the product worktree, and restore every touched path to HEAD.
- Reset first-use state and permissions with
  `hdc shell bm clean -n com.yuhaofeng.mih -d`; verify camera/media state with
  `hdc shell atm dump -t -b com.yuhaofeng.mih` before and after the flow.
- After every harness run, reinstall the current production HAP, start
  `EntryAbility`, capture a production layout/screenshot, and record its HAP
  SHA-256.
- Computer Use is not part of this matrix.

Every paired dump is machine-checked, not judged from the JPEG alone:

- the root `pagePath`/route matches the task;
- each intended action is visible, enabled as expected, and clickable;
- icon/action bounds measure at least 44vp, with primary/header controls at
  least 48vp after dividing pixels by the captured device density;
- static/text/custom pages expose one top-level scrollable content region;
- no visible text/action bounds overlap or cross the application bottom inset;
- fixed-camera routes contain no switch action; switchable routes contain one
  localized semantic action;
- hidden model/catalog labels are absent from the production dump;
- loading/success/failure/retry text and selected-state semantics exist in the
  owning builder's dump;
- before/after hashes confirm cancel/failure keeps the input or last-valid
  result required by that workflow.

Each mutation runner must prove these concrete RED cases (plus comment/string/
decoy resistance):

| Task | Required rejected mutations |
| --- | --- |
| 1 | restore 56vp/fixed title chrome; shrink a semantic target below 48vp; remove the full scrim; swap Retry/Settings handlers; expose a switch on a fixed-camera route |
| 2 | restore `Fill`/fixed preview or 37vp row; remove status/retry; change scene failure mapping |
| 3 | restore a fixed single-row action area; auto-run the bundled sample; break picker preservation or overlay/orientation wiring |
| 4 | restore the duplicate divider or fixed row; remove failure feedback/retry; change live-link handler |
| 5 | re-expose Select Model; remove optional/cache contract; restore `Fill`; clear current preview/boxes on failure |
| 6 | restore the 37vp four-action row; loosen save readiness/single flight; clear input/result on failure |
| 7 | restore fixed OCR/result heights; remove status/retry or copy feedback; clear input on picker cancellation |
| 8 | restore the 100vp blocking panel; expose camera switch; remove retry or last-valid classification |
| 9 | expose camera/model switch; remove optional/cache contract; permit unbounded labels; clear last-valid boxes |
| 10 | force rear/no-switch; remove per-route memory, retry, or last-valid foreground |
| 11 | remove front mirroring or per-route memory; restore one-line labels; clear last-valid gesture overlay |
| 12 | force rear/no-switch; restore fixed scene overlay; clear last-valid labels |
| 13 | force front/no-memory; remove pose template/status/retry; clear last-valid pose overlay |
| 14 | duplicate/move the composite View ID; loosen save gate; make selection color-only; clear last-valid composite |
| 15 | restore competing nested weights/scrolls or 37vp actions; enable Copy without a result; clear source/result on failure |
| 16 | restore 256vp/four-column locks or model buttons; make selection color-only; loosen save gate; clear last-valid result |
| 17 | re-expose the hidden Custom Model catalog entry or the public Object/Style model selectors (the direct Custom Model route's required model picker remains); restore `Fill`/fixed action heights; remove the single Scroll or status/retry; clear valid input/output |

## Task 0 — Freeze plan and review it

Files:

- this plan and its design spec
- `.superpowers/sdd/runtime-phase-plan-audit.md`
- `.superpowers/sdd/runtime-phase-plan-review.md`

Verify the 16-workflow/13-family map, old guard migration list, functional
freeze, and commit boundaries. Commit:

`docs(ui): plan Harmony feature runtime redesign`

## Task 1 — Shared native runtime chrome

Scope:

- `runtimeActionToolbar`
- `portraitSegmentationToolbar`
- `runtimePermissionRecoveryOverlay`
- shared status/action builders already inside `FeatureRuntimePage.ets`
- the route-neutral geometry of `simpleAndroidLiveLayout`
- toolbar/header/recovery guards and mutations
- `check-runtime-ui-evidence.ps1` and its mutation-tested manifest/dump checker

Acceptance:

- content-driven title bars, two-line title, 48vp semantic actions;
- full scrim and blocking recovery card;
- content-driven retry/settings actions;
- responsive live-camera canvas/status geometry without claiming any of its
  four route-specific workflows complete;
- no route/handler/order changes;
- default and 3.2x direct-route HDC evidence.

Commit:

`fix(runtime): make shared chrome responsive`

## Task 2 — Still scene detection

Scope: `stillSceneAndroidLayout`, status feedback, image fit, wrapping action
grid, scene result presentation, and its old visual guard migration.

Acceptance: production catalog confirms the entry remains hidden; an isolated
direct-route harness verifies photo/camera/cancel, run, success, failure/retry,
linked live route, input preservation, unchanged scene-result preservation,
and default/3.2x layout.

Commit:

`fix(scene): modernize still detection runtime`

## Task 3 — Still pose detection

Scope: `poseNetStillAndroidLayout`, sample/input preview, pose overlay, action
grid, result text, and PoseNet contract guards.

Acceptance: sample, picker, camera, run, pose success/failure, linked live route,
picker cancellation preserves the previous input, bundled sample still does not
auto-run, EXIF orientation remains paired with pose coordinates, and
default/3.2x evidence passes.

Commit:

`fix(pose): modernize still detection runtime`

## Task 4 — Still gesture detection

Scope: `gestureStillAndroidLayout`, input preview, label/result state, duplicate
divider removal, wrapping action grid, and focused guards.

Acceptance: photo/camera/cancel, gesture success/failure, linked live route,
picker cancellation preserves the previous input, overlay orientation remains
paired with gesture coordinates, default/3.2x evidence.

Commit:

`fix(gesture): modernize still detection runtime`

## Task 5 — Photo object detection

Scope: `objectPhotoAndroidLayout`, preview/result overlays, status/retry,
wrapping actions, and hidden model selector.

Acceptance: public model-file control absent; optional model/cache behavior still
covered by unit tests; the initial automatic picker cancellation still leaves
the route, later cancellation does not clear valid input, EXIF/box coordinates
remain paired, failure/retry retains the current valid preview, and default/
3.2x evidence passes.

Commit:

`fix(objects): modernize photo detection runtime`

## Task 6 — Still segmentation

Scope: `stillSegmentationAndroidLayout`, preview/result aspect ratio, wrapping
actions, status/retry, save readiness, single-flight state, and parity guard
migration.

Acceptance: photo/camera/cancel/run/save, failed inference preserves input,
save disabled/running/success/failure, picker cancellation preserves the
previous input, EXIF/mask coordinates remain paired, atomic result replacement
is unchanged, and default/3.2x evidence passes.

Commit:

`fix(segmentation): modernize still runtime`

## Task 7 — Text recognition

Scope: `textRecognitionAndroidLayout`, input image, recognized-text card,
status/retry, copy feedback, wrapping actions, and focused guards.

Acceptance: photo/camera/cancel/run/copy; long OCR text scrolls; empty and
failed copy state visible; picker cancellation preserves the previous input;
EXIF display orientation remains correct; default/3.2x evidence.

Commit:

`fix(ocr): modernize text recognition runtime`

## Task 8 — Live image classification

Scope: `imageClassificationAndroidLiveLayout`, compact classification overlay,
camera/inference status and retry, explicit absence of a camera switch, and
switch/header guard migration.

Acceptance: fixed rear camera with no switch action, preparation/success/failure,
last valid classification remains visible across transient failure, no 100vp
blocking result panel, long label at 3.2x, default/3.2x evidence.

Commit:

`fix(classification): modernize live runtime`

## Task 9 — Live object detection

Scope: `objectDetectionAndroidLiveLayout`, explicit absence of a camera switch,
detection labels/bounds, status/retry, and hidden model selector.

Acceptance: public model-file control absent; fixed rear camera with no switch
action; optional model input, cached-model restoration, and inference parameter
tests remain green; multiple and edge detections are bounded; transient failure
preserves the last valid boxes; long labels are readable; default/3.2x evidence.

Commit:

`fix(objects): modernize live detection runtime`

## Task 10 — Live segmentation

Scope: route-specific segmentation mask/overlay state inside the shared live
canvas.

Acceptance: camera permission timing, default front camera, allowed front/rear
switching with per-route memory, running/result/failure, mask alignment, retry,
last valid foreground preservation, default/3.2x evidence.

Commit:

`fix(segmentation): verify live runtime states`

## Task 11 — Live gesture

Scope: route-specific gesture overlay and camera position behavior.

Acceptance: default rear camera, allowed front/rear switching with per-route
memory, mirrored front-camera overlay, gesture label, failure/retry, long result
at 3.2x, transient failure preserves the last valid overlay and camera input,
default/3.2x evidence.

Commit:

`fix(gesture): verify live runtime states`

## Task 12 — Live scene detection

Scope: route-specific scene labels and compact result overlay.

Acceptance: default front camera, allowed front/rear switching with per-route
memory, multiple labels, no canvas occlusion, failure/retry, long result at
3.2x, transient failure preserves the last valid labels and camera input,
default/3.2x evidence.

Commit:

`fix(scene): verify live runtime states`

## Task 13 — Live skeleton

Scope: route-specific pose points/template overlay.

Acceptance: default rear camera, allowed front/rear switching with per-route
memory, template visibility, pose alignment, status/retry, default/3.2x
evidence, and transient failure preserves the last valid pose overlay and
camera input.

Commit:

`fix(pose): verify live skeleton runtime`

## Task 14 — Portrait segmentation

Scope: `portraitSegmentationAndroidLayout`, composite image fit, background
choices/selected state, camera switch, status/retry, save feedback, unique view
ID, and save-readiness guards.

Acceptance: preset/custom background/cancel, default front camera with allowed
front/rear switching and per-route memory, selected state not color-only,
composite save readiness and single flight, transient failure preserves the
last valid foreground/background/input, default/3.2x evidence.

Commit:

`fix(portrait): modernize segmentation runtime`

## Task 15 — Text translation

Scope: `textTranslationAndroidLayout`, one top-level scroll, keyboard-safe text
input, primary action, result card, image/camera/copy actions, status/retry, and
translation guard migration.

Acceptance: empty/short/long text; keyboard open/closed; translate
running/success/failure/retry; image/camera cancellation restores editor; long
result and copy feedback; typed source, selected image mode, and the last valid
translation remain visible across failure/retry; default/3.2x evidence.

Commit:

`fix(translation): modernize text runtime`

## Task 16 — Style transfer

Scope: `styleTransferAndroidLayout`, aspect-correct preview, style grid,
non-color selected state, status/retry/save, hidden model-file buttons, and
parity guard migration.

Acceptance: content/style selection and cancellation, all built-in/custom
styles, model buttons absent while optional input/cache tests pass, running /
success/failure, selected content/style and the last valid result remain visible
across failure, save readiness, default/3.2x evidence.

Commit:

`fix(style): modernize transfer runtime`

## Task 17 — Hidden custom-model route

Scope: `customModelAndroidLayout` and exact visibility guards. The direct route
uses one top-level Scroll, content-driven cards, a wrapping 48vp input/action
area, and visible input/running/success/failure/retry status.

Acceptance: no public catalog entry; direct route remains usable for smoke
testing; model/photo/camera/run/output/error semantics remain intact; picker
cancellation preserves valid input; failure preserves selected inputs and the
last valid output; default/3.2x actions remain reachable; no new capability or
route exposure.

Commit:

`fix(models): keep custom runtime hidden and accessible`

## Task 18 — Integrated runtime verification

Run:

- every updated focused guard and mutation suite;
- `check-runtime-layout-closure.ps1` and its guard test;
- route mapping, camera policy, view ID, save readiness, input restoration,
  model cache, and visibility LocalUnit coverage;
- full LocalUnit;
- `assembleHap`;
- full AI runtime acceptance and main/ohosTest `arm64-v8a,x86_64` verifier.

Native HDC matrix:

- all user-reachable workflows at default and 3.2x;
- initial, success, non-permission failure, and successful retry for every
  user-reachable workflow;
- permission-denied plus recovery for every workflow that requests camera or
  media;
- keyboard translation;
- image aspect/orientation and overlay samples;
- tab/back/input-state preservation;
- direct hidden Scene Still, Scene Live, and Custom Model smoke at default and
  3.2x, including their initial/success/failure/retry states;
- final production HAP restoration.

Request a final whole-phase independent review. Record evidence only; fix any
new defect in a dedicated feature commit before approval.
