# Handwritten Digit Experience and Scene Top Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to execute this plan task-by-task.

**Goal:** Add one handwritten digit card to Experience with gallery, still-camera, and real-time camera inference, and align the static Scene Detection content to the top like Gesture Recognition.

**Architecture:** Reuse `FeatureRuntimePage`, the existing picker, inline-camera fallback, and live inference loop. Add one digit-specific preprocessor/service because MNIST has a different tensor contract and needs top-three results. Convert the bundled College MindIR once to a checked `.ms` rawfile; the app never trains or converts at runtime.

**Tech Stack:** HarmonyOS 6.1 / API 24, ArkTS, ArkUI, MindSpore Lite, Hypium LocalUnit, PowerShell integrity guards, Hvigor, HDC native touch and screenshots.

## Global Constraints

- Follow `AGENTS.md`: native components, 16vp page inset, 8vp spacing, light card edges, 44vp touch targets, flat unique icon, no WebView or third-party UI kit.
- Keep unrelated dirty files untouched and stage only the paths named by each task.
- Use the same digit preprocessor for gallery, still camera, and live frames.
- Fail visibly on missing model, unreadable input, empty foreground, invalid tensor shape, or non-finite output; never synthesize a result.
- Use HDC touch, layout dump, and screenshots instead of Computer Use.
- Make one commit after each completed task.

---

### Task 1: Convert and Lock the Bundled MNIST Model

**Files:**
- Add: `entry/src/main/resources/rawfile/model/lenet_mnist.ms`
- Add: `entry/src/main/resources/rawfile/model/lenet_mnist.NOTICE.md`
- Add: `scripts/convert-mnist-mindir.ps1`
- Add: `scripts/test-mnist-model-guard.ps1`
- Modify: `entry/src/main/resources/rawfile/model/NOTICE.md`

**Contract:**
- Source: `docs/tutorials/college-hap/college-hap.zip!/artifacts/lenet_mnist.mindir`
- Input: float32 `[1, 1, 28, 28]`
- Output: float32 `[1, 10]`
- Output classes: digits `0` through `9`

- [ ] Write the guard first so it fails while the `.ms` file and locked hash are absent.
- [ ] Extract the MindIR to a temporary ignored directory and convert it with an official MindSpore Lite converter.
- [ ] Record converter version, source SHA-256, `.ms` length/SHA-256, tensor contract, license, and provenance.
- [ ] Run the guard and inspect the converted model with the available MindSpore Lite tooling.
- [ ] Commit:

```powershell
git add -- entry/src/main/resources/rawfile/model/lenet_mnist.ms `
  entry/src/main/resources/rawfile/model/lenet_mnist.NOTICE.md `
  entry/src/main/resources/rawfile/model/NOTICE.md `
  scripts/convert-mnist-mindir.ps1 scripts/test-mnist-model-guard.ps1
git commit -m "build(ai): package MNIST digit model"
```

---

### Task 2: Add Tested Digit Preprocessing and Result Decoding

**Files:**
- Add: `entry/src/main/ets/services/ai/HandwrittenDigitPreprocess.ets`
- Add: `entry/src/main/ets/services/ai/HandwrittenDigitService.ets`
- Add: `entry/src/test/HandwrittenDigitUnit.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- `handwrittenDigitInputFromRgba(rgba, width, height): ArrayBuffer`
- `topHandwrittenDigitResults(logits, limit): Array<HandwrittenDigitPrediction>`
- `HandwrittenDigitService.recognizeDigit(imageUri)`

- [ ] Add failing tests for black-on-white, white-on-black, off-centre input, blank/low-contrast rejection, stable softmax, top-three ordering, invalid shape, and non-finite logits.
- [ ] Run LocalUnit and confirm RED:

```powershell
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default -p buildMode=test `
  -p coverage=false -p testType=LocalUnit test --no-daemon
```

- [ ] Implement the minimum pure ArkTS pipeline: grayscale, border background estimate, optional inversion, foreground bounds, square padding, 20px body resize, centre-of-mass translation to 28×28, and `(x - 0.1307) / 0.3081`.
- [ ] Implement stable softmax and validated top-three decoding.
- [ ] Re-run LocalUnit and confirm GREEN.
- [ ] Commit:

```powershell
git add -- entry/src/main/ets/services/ai/HandwrittenDigitPreprocess.ets `
  entry/src/main/ets/services/ai/HandwrittenDigitService.ets `
  entry/src/test/HandwrittenDigitUnit.test.ets entry/src/test/List.test.ets
git commit -m "feat(ai): preprocess and decode handwritten digits"
```

---

### Task 3: Decode HarmonyOS Images and Run the `.ms` Model

**Files:**
- Add: `entry/src/main/ets/services/ai/HarmonyHandwrittenDigitInputPreprocessor.ets`
- Modify: `entry/src/main/ets/services/ai/HandwrittenDigitService.ets`
- Modify: `entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Decode with EXIF orientation into RGBA without distorting aspect ratio.
- Use `MindSporeLiteModelRunner` with `model/lenet_mnist.ms`.
- Cache the digit service by route through the existing `RuntimeAiServiceSession`.

- [ ] Add failing service/factory tests with injected preprocessor and tensor runner.
- [ ] Implement image decoding and model runner wiring.
- [ ] Verify a missing/corrupt model and invalid output return a typed failure.
- [ ] Run LocalUnit and `scripts/test-mnist-model-guard.ps1`.
- [ ] Commit:

```powershell
git add -- entry/src/main/ets/services/ai/HarmonyHandwrittenDigitInputPreprocessor.ets `
  entry/src/main/ets/services/ai/HandwrittenDigitService.ets `
  entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets `
  entry/src/test/LocalUnit.test.ets
git commit -m "feat(ai): run handwritten digit model on device"
```

---

### Task 4: Add the Experience Card, Routes, Workflow, Icon, and Strings

**Files:**
- Modify: `entry/src/main/ets/app/AppRoutes.ets`
- Modify: `entry/src/main/ets/common/data/FeatureCatalog.ets`
- Modify: `entry/src/main/ets/common/icons/IconSymbols.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Add: `entry/src/main/resources/base/media/feature_digit.png`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Routes:**
- Static route: photo + still camera, linked to live route.
- Live route: camera only, `liveMode: true`.
- Both use AI method `recognizeDigit`.

- [ ] Add failing catalog, route, workflow, icon uniqueness, and i18n assertions.
- [ ] Generate one flat 2D digit icon matching the current Experience icon family and copy it into the project.
- [ ] Add the card immediately after Image Classification and wire both routes to `FeatureRuntimePage`.
- [ ] Add localized titles, actions, statuses, error messages, predicted digit, confidence, and candidate labels.
- [ ] Run LocalUnit and all catalog/i18n/icon guards.
- [ ] Commit:

```powershell
git add -- entry/src/main/ets/app/AppRoutes.ets `
  entry/src/main/ets/common/data/FeatureCatalog.ets `
  entry/src/main/ets/common/icons/IconSymbols.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/main/resources/base/media/feature_digit.png `
  entry/src/test/LocalUnit.test.ets
git commit -m "feat(experience): add handwritten digit entry"
```

---

### Task 5: Reuse the Gesture UI for Static and Live Digit Recognition

**Files:**
- Modify: `entry/src/main/ets/services/ai/AiService.ets`
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Add: `scripts/test-handwritten-digit-runtime-ui-guard.ps1`

**Behavior:**
- Static page: 4:3 preview, status card, gallery/camera/live/run buttons, result card.
- Live page: existing camera preview, switch-camera control, serial inference loop, current digit/confidence.
- API 24 camera-picker failure: use the existing inline-camera single-frame fallback.

- [ ] Add failing tests for result-row projection, route-specific UI selection, fallback eligibility, live interval, and loop cleanup.
- [ ] Add `recognizeDigit` dispatch/result data to `DefaultAiService`.
- [ ] Reuse the Gesture static/live builders with digit-specific labels and rows; do not copy the entire page.
- [ ] Keep the current image selected after inference failure.
- [ ] Run LocalUnit and the new runtime UI guard.
- [ ] Commit:

```powershell
git add -- entry/src/main/ets/services/ai/AiService.ets `
  entry/src/main/ets/pages/FeatureRuntimePage.ets `
  entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets `
  entry/src/test/LocalUnit.test.ets `
  scripts/test-handwritten-digit-runtime-ui-guard.ps1
git commit -m "feat(experience): support three digit input modes"
```

---

### Task 6: Align Static Scene Detection to the Top

**Files:**
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `scripts/test-still-scene-layout-parity-guard.ps1`

- [ ] Make the guard fail unless the static Scene `Scroll` uses `Alignment.TopStart`, matching Gesture.
- [ ] Add the one missing alignment call; do not change Scene inference or spacing.
- [ ] Run the focused guard and LocalUnit.
- [ ] Commit:

```powershell
git add -- entry/src/main/ets/pages/FeatureRuntimePage.ets `
  scripts/test-still-scene-layout-parity-guard.ps1
git commit -m "fix(scene): align static content to top"
```

---

### Task 7: Generate and Validate Digit Test Images

**Files:**
- Add: `test-assets/handwritten-digits/digit-2.png`
- Add: `test-assets/handwritten-digits/digit-7.png`
- Add: `test-assets/handwritten-digits/digit-9.png`
- Add: `test-assets/handwritten-digits/README.md`
- Add: `scripts/validate-mnist-test-assets.py`
- Add: `scripts/test-mnist-test-assets-guard.ps1`

- [ ] Use built-in ImageGen in three separate calls: one black handwritten digit on near-white paper per image, no text/watermark/decoration.
- [ ] Copy each generated image into `test-assets/handwritten-digits/`.
- [ ] Validate all three with the desktop MindIR and the same preprocessing constants; reject and regenerate any wrong prediction.
- [ ] Record prompts, expected labels, dimensions, SHA-256, and validation result.
- [ ] Run the asset guard.
- [ ] Commit:

```powershell
git add -- test-assets/handwritten-digits `
  scripts/validate-mnist-test-assets.py scripts/test-mnist-test-assets-guard.ps1
git commit -m "test(ai): add handwritten digit fixtures"
```

---

### Task 8: Build, Install, and Verify All Three Modes

**Files:**
- Add evidence under the existing ignored verification/output location only.

- [ ] Run LocalUnit plus:

```powershell
powershell -NoProfile -File scripts/test-mnist-model-guard.ps1
powershell -NoProfile -File scripts/test-mnist-test-assets-guard.ps1
powershell -NoProfile -File scripts/test-handwritten-digit-runtime-ui-guard.ps1
powershell -NoProfile -File scripts/test-still-scene-layout-parity-guard.ps1
powershell -NoProfile -File scripts/test-native-abi-matrix.ps1
```

- [ ] Build the main HAP and ohosTest HAP and verify both contain `arm64-v8a` and `x86_64`.
- [ ] Install the main HAP on the running emulator.
- [ ] Push the three digit images into a media-visible emulator location.
- [ ] Verify with HDC native touch/dump/screenshots:
  - card order and flat icon;
  - gallery recognition for 2, 7, and 9;
  - still-camera inline fallback;
  - live camera continuously produces non-empty results and stops on exit;
  - camera switch preserves correct orientation/aspect ratio;
  - Scene static preview starts at the same top spacing as Gesture.
- [ ] Record the final HAP absolute path, SHA-256, ABI list, and verification evidence.
- [ ] Commit only any verification guard corrections required by real-device findings.

---

### Task 9: Review and Integrate

- [ ] Run `git diff --check`, full LocalUnit, focused guards, main build, and ohosTest build from a clean feature worktree.
- [ ] Request a code review focused on correctness, model contract, lifecycle cleanup, and hidden regressions.
- [ ] Fix review findings in scoped commits and repeat verification.
- [ ] Merge the feature branch into `master` without overwriting the unrelated dirty files in the primary checkout.
- [ ] Push `master`, verify the remote commit, and remove the feature worktree/branch.

