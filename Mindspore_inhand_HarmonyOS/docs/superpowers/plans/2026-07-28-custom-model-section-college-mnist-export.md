# Custom Model Section and College MNIST Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Custom Model into its own Experience section, replace the College quick start with the supplied MNIST tutorial, and let users export the complete local tutorial ZIP.

**Architecture:** Keep Experience grouping declarative in `FeatureCatalog.ets`. Keep College chapter rendering static and native by updating `CollegeLocalQuickStart.ets` from the supplied Markdown; add one small exporter with injected async functions so file selection, byte reading, exact writing, and cancellation can be tested without platform mocks. Package the supplied ZIP unchanged as a rawfile and verify its hash and entries at build time.

**Tech Stack:** HarmonyOS 6.1 / API 24, ArkTS, ArkUI, CoreFileKit `DocumentViewPicker` and `fileIo`, Hypium LocalUnit, PowerShell integrity guards, Hvigor, HDC native touch and screenshots.

## Global Constraints

- Follow `AGENTS.md`: native HarmonyOS components, 16vp page inset, 8vp spacing rhythm, light borders, no new third-party UI dependency, and no WebView.
- Keep Custom Model route, icon, visibility, package contract, and inference behavior unchanged.
- Keep the broken remote Quick Start and FAQ catalog rows hidden.
- The app must not parse Markdown or unpack the tutorial archive at runtime.
- The College tutorial displayed in the app must contain no HTTP link and no “参考视频”.
- Export archive bytes must match size `11095055` and SHA-256 `9D556E96FE27357B90FDC3814C5AB707FCEF8EED314981A6552B2A11B8C7DE42`.
- Preserve unrelated user changes and stage only the exact paths listed by each task.
- Use HDC native touch and screenshots rather than Computer Use for emulator verification.

---

### Task 1: Separate Custom Model from Advanced Vision

**Files:**
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `entry/src/main/ets/common/data/FeatureCatalog.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`

**Interfaces:**
- Produces: `FeatureCategory` member `custom-models`.
- Produces: string keys `experience_group_custom` and `experience_category_model_tools`.
- Produces: fourth visible section whose only item has ID `custom`.

- [ ] **Step 1: Write the failing catalog tests**

Update `groupsExperienceCatalogLikeAndroidVisionFragment` and add a focused test:

```ts
it('placesCustomModelInItsOwnModelToolsSection', 0, () => {
  const advanced = visibleExperienceSections.find((section: FeatureSection) => {
    return section.id === 'advanced-vision';
  });
  const custom = visibleExperienceSections.find((section: FeatureSection) => {
    return section.id === 'custom-models';
  });
  expect(advanced?.items.some((item: FeatureItem) => item.id === 'custom')).assertFalse();
  expect(custom?.groupTitleKey).assertEqual('experience_group_custom');
  expect(custom?.titleKey).assertEqual('experience_category_model_tools');
  expect(custom?.items.map((item: FeatureItem) => item.id).join(',')).assertEqual('custom');
  expect(visibleExperienceSections.findIndex((section: FeatureSection) => section.id === 'custom-models'))
    .assertEqual(visibleExperienceSections.findIndex((section: FeatureSection) => section.id === 'advanced-vision') + 1);
});
```

- [ ] **Step 2: Run LocalUnit and verify RED**

Run:

```powershell
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default -p buildMode=test `
  -p coverage=false -p testType=LocalUnit test --no-daemon
```

Expected: compilation or assertion failure because `custom-models` and its string keys do not exist.

- [ ] **Step 3: Implement the minimum catalog and i18n change**

Extend the category union:

```ts
export type FeatureCategory =
  'experience-vision' |
  'experience-speech' |
  'advanced-vision' |
  'advanced-speech' |
  'custom-models';
```

Remove the `custom` item from `advanced-vision` and append this section after it:

```ts
{
  id: 'custom-models',
  title: 'Model Tools',
  titleKey: 'experience_category_model_tools',
  groupTitleKey: 'experience_group_custom',
  items: [
    {
      id: 'custom',
      title: 'Custom Model',
      titleKey: 'title_custom_model',
      icon: 'model',
      routeName: AppRoute.CUSTOM_MODEL.name,
      visibleByDefault: true
    }
  ]
}
```

Add localized values:

```text
experience_group_custom: base/zh_CN “自定义能力”; en_US “Custom Capabilities”
experience_category_model_tools: base/zh_CN “模型工具”; en_US “Model Tools”
```

- [ ] **Step 4: Run focused and full checks**

Run LocalUnit again and:

```powershell
powershell -NoProfile -File scripts/check-i18n-strings.ps1
powershell -NoProfile -File scripts/check-runtime-shared-ui.ps1
```

Expected: all pass; visible feature count remains 11 and all feature icon mappings remain unique.

- [ ] **Step 5: Commit**

```powershell
git add -- entry/src/test/LocalUnit.test.ets `
  entry/src/main/ets/common/data/FeatureCatalog.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/main/resources/en_US/element/string.json
git commit -m "feat(ui): separate custom model tools"
```

---

### Task 2: Replace the College Tutorial with the Supplied MNIST Chapters

**Files:**
- Restore/replace: `docs/tutorials/college-hap/01-environment.md`
- Restore/replace: `docs/tutorials/college-hap/02-data.md`
- Restore/replace: `docs/tutorials/college-hap/03-network.md`
- Restore/replace: `docs/tutorials/college-hap/04-training.md`
- Restore/replace: `docs/tutorials/college-hap/05-export.md`
- Add: `docs/tutorials/college-hap/college-hap.zip`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `entry/src/main/ets/common/data/CollegeLocalQuickStart.ets`

**Interfaces:**
- Keeps: `CollegeLocalQuickStartSection` and `collegeLocalQuickStartSections`.
- Produces: five MNIST chapters with IDs `environment,data,network,training,export`.

- [ ] **Step 1: Write failing MNIST content assertions**

Extend `providesFiveCompleteOfflineMindSporeTutorialChapters`:

```ts
const tutorial = JSON.stringify(collegeLocalQuickStartSections);
expect(tutorial.indexOf('MindSpore 2.9.0') >= 0).assertTrue();
expect(tutorial.indexOf('60,000') >= 0).assertTrue();
expect(tutorial.indexOf('10,000') >= 0).assertTrue();
expect(tutorial.indexOf('batch size 32') >= 0).assertTrue();
expect(tutorial.indexOf('98.82%') >= 0).assertTrue();
expect(tutorial.indexOf('98.87%') >= 0).assertTrue();
expect(tutorial.indexOf('46.035') >= 0).assertTrue();
expect(tutorial.indexOf('lenet_mnist.mindir') >= 0).assertTrue();
expect(tutorial.indexOf('http')).assertEqual(-1);
expect(tutorial.indexOf('digits')).assertEqual(-1);
```

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command.

Expected: assertions fail because the current chapters describe MindSpore 2.5.0 and scikit-learn digits.

- [ ] **Step 3: Restore the five source Markdown files**

Restore each Markdown path with the exact UTF-8 content of the matching entry in the supplied `college-hap.zip`. Preserve its frontmatter:

```yaml
---
id: environment
step: "01"
title: 准备环境和数据集
---
```

Use the corresponding IDs, steps, and titles for the other four chapters. Keep the supplied archive unchanged and do not extract `data/`, `artifacts/`, or `mnist-lenet.py` into the repository.

- [ ] **Step 4: Replace the ArkTS chapter data**

Use the supplied Markdown as the source of truth, with these local-app adaptations:

```text
Environment: Python 3.11.15, MindSpore 2.9.0 CPU; data is included in the export package.
Data: 60,000 train, 10,000 test, Normalize(0.1307, 0.3081), HWC2CHW, batch 32.
Network: LeNet-5 style, 44,404 trainable parameters, Momentum(0.01, 0.9).
Training: 5 epochs, final 98.82%, best 98.87%, total 46.035 seconds.
Export: lenet_mnist.ckpt 177,956 B, lenet_mnist.mindir 189,495 B,
        label/prediction 7, max absolute logits difference 0.0.
```

Omit the four external MNIST URLs from the ArkTS page and replace them with a sentence directing the user to export the bundled tutorial package.

- [ ] **Step 5: Run LocalUnit and verify GREEN**

Run the Task 1 LocalUnit command.

Expected: the five chapter order, completeness, local-only content, and new MNIST facts all pass.

- [ ] **Step 6: Commit**

```powershell
git add -- docs/tutorials/college-hap/01-environment.md `
  docs/tutorials/college-hap/02-data.md `
  docs/tutorials/college-hap/03-network.md `
  docs/tutorials/college-hap/04-training.md `
  docs/tutorials/college-hap/05-export.md `
  docs/tutorials/college-hap/college-hap.zip `
  entry/src/test/LocalUnit.test.ets `
  entry/src/main/ets/common/data/CollegeLocalQuickStart.ets
git commit -m "docs(college): adopt bundled MNIST tutorial"
```

---

### Task 3: Package and Verify the Tutorial Archive

**Files:**
- Add: `entry/src/main/resources/rawfile/college/college-hap.zip`
- Add: `scripts/verify-college-tutorial-package.ps1`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces: rawfile path `college/college-hap.zip`.
- Produces: constants `collegeTutorialRawFileName` and `collegeTutorialExportFileName`.

- [ ] **Step 1: Add failing package constants and integrity guard**

Add LocalUnit expectations:

```ts
expect(collegeTutorialRawFileName).assertEqual('college/college-hap.zip');
expect(collegeTutorialExportFileName).assertEqual('MindSpore-MNIST-入门教程.zip');
```

Create `verify-college-tutorial-package.ps1` to require:

```powershell
$expectedLength = 11095055
$expectedSha256 = '9D556E96FE27357B90FDC3814C5AB707FCEF8EED314981A6552B2A11B8C7DE42'
$requiredEntries = @(
  '01-environment.md', '02-data.md', '03-network.md', '04-training.md', '05-export.md',
  'mnist-lenet.py',
  'artifacts/lenet_mnist.ckpt', 'artifacts/lenet_mnist.mindir',
  'data/MNIST/train-images-idx3-ubyte', 'data/MNIST/train-labels-idx1-ubyte',
  'data/MNIST/t10k-images-idx3-ubyte', 'data/MNIST/t10k-labels-idx1-ubyte'
)
```

The guard must compare both the docs ZIP and rawfile ZIP byte length/hash and inspect ZIP entry names with `System.IO.Compression.ZipFile`.

- [ ] **Step 2: Run checks and verify RED**

Run LocalUnit and:

```powershell
powershell -NoProfile -File scripts/verify-college-tutorial-package.ps1
```

Expected: failure because constants and the packaged rawfile do not exist.

- [ ] **Step 3: Add constants and the exact rawfile copy**

Add to `CollegeLocalQuickStart.ets`:

```ts
export const collegeTutorialRawFileName: string = 'college/college-hap.zip';
export const collegeTutorialExportFileName: string = 'MindSpore-MNIST-入门教程.zip';
```

Copy the supplied ZIP byte-for-byte to `entry/src/main/resources/rawfile/college/college-hap.zip`.

- [ ] **Step 4: Run checks and verify GREEN**

Run LocalUnit and the integrity guard.

Expected: both ZIPs are 11,095,055 bytes, have the locked SHA-256, and contain every required entry.

- [ ] **Step 5: Commit**

```powershell
git add -- entry/src/main/resources/rawfile/college/college-hap.zip `
  entry/src/main/ets/common/data/CollegeLocalQuickStart.ets `
  entry/src/test/LocalUnit.test.ets `
  scripts/verify-college-tutorial-package.ps1
git commit -m "feat(college): package verified MNIST tutorial"
```

---

### Task 4: Implement Exact Local Export

**Files:**
- Add: `entry/src/main/ets/services/college/CollegeTutorialExportService.ets`
- Add: `entry/src/test/CollegeTutorialExportService.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces:

```ts
export type CollegeTutorialExportStatus = 'idle' | 'exporting' | 'done' | 'failed';
export interface CollegeTutorialExportResult {
  readonly ok: boolean;
  readonly cancelled: boolean;
}
export type CollegeDestinationPicker = (defaultName: string) => Promise<string>;
export type CollegePackageReader = () => Promise<Uint8Array>;
export type CollegePackageWriter = (uri: string, bytes: Uint8Array) => Promise<number>;
export class CollegeTutorialExportService {
  constructor(
    pickDestination: CollegeDestinationPicker,
    readPackage: CollegePackageReader,
    writePackage: CollegePackageWriter
  );
  exportPackage(): Promise<CollegeTutorialExportResult>;
}
```

- [ ] **Step 1: Write failing service tests**

Cover these real branches using injected async functions:

```ts
it('exportsEveryPackageByteAfterDestinationSelection', 0, async () => {
  const bytes = new Uint8Array([1, 2, 3, 4]);
  let written = 0;
  const service = new CollegeTutorialExportService(
    async (name: string): Promise<string> => name.endsWith('.zip') ? 'file://target' : '',
    async (): Promise<Uint8Array> => bytes,
    async (_uri: string, value: Uint8Array): Promise<number> => {
      written = value.length;
      return value.length;
    }
  );
  expect((await service.exportPackage()).ok).assertTrue();
  expect(written).assertEqual(4);
});
```

Add separate tests for empty destination returning `{ ok: false, cancelled: true }`, reader failure, writer failure, and short write returning `{ ok: false, cancelled: false }`.

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command.

Expected: compilation fails because `CollegeTutorialExportService.ets` does not exist.

- [ ] **Step 3: Implement the minimum testable exporter**

`exportPackage()` must:

```ts
const destination = await this.pickDestination(collegeTutorialExportFileName);
if (destination.length === 0) {
  return { ok: false, cancelled: true };
}
try {
  const bytes = await this.readPackage();
  const written = await this.writePackage(destination, bytes);
  return { ok: written === bytes.length, cancelled: false };
} catch (_) {
  return { ok: false, cancelled: false };
}
```

Do not expose the destination URI in the result or logs.

- [ ] **Step 4: Run LocalUnit and verify GREEN**

Run the Task 1 LocalUnit command and scan output for `AssertException`, `BUILD FAILED`, and `COMPILE RESULT:FAIL`.

Expected: all exporter branches pass.

- [ ] **Step 5: Commit**

```powershell
git add -- entry/src/main/ets/services/college/CollegeTutorialExportService.ets `
  entry/src/test/CollegeTutorialExportService.test.ets `
  entry/src/test/List.test.ets
git commit -m "feat(college): add exact tutorial exporter"
```

---

### Task 5: Connect the Native Save Picker to the College Page

**Files:**
- Modify: `entry/src/main/ets/pages/CollegePage.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `CollegeTutorialExportService`, archive constants, `DocumentViewPicker.save`, `resourceManager.getRawFileContent`, and `fileIo`.
- Produces: `@State tutorialExportStatus: CollegeTutorialExportStatus`.

- [ ] **Step 1: Write failing UI-state and i18n tests**

Add keys:

```text
college_tutorial_export
college_tutorial_exporting
college_tutorial_export_done
college_tutorial_export_failed
```

Add a pure state mapper in the export service:

```ts
export function collegeTutorialStatusAfterResult(
  result: CollegeTutorialExportResult
): CollegeTutorialExportStatus {
  if (result.cancelled) {
    return 'idle';
  }
  return result.ok ? 'done' : 'failed';
}
```

Test cancelled → idle, success → done, failure → failed, and assert all four i18n keys exist.

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command.

Expected: missing mapper and string keys.

- [ ] **Step 3: Implement the platform adapters**

In `CollegePage.ets`, create the service immediately before export:

```ts
const context = getContext(this) as common.UIAbilityContext;
const service = new CollegeTutorialExportService(
  async (defaultName: string): Promise<string> => {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [defaultName];
    options.fileSuffixChoices = ['ZIP archive|.zip'];
    try {
      const targets = await new picker.DocumentViewPicker(context).save(options);
      return targets.length > 0 ? targets[0] : '';
    } catch (_) {
      return '';
    }
  },
  async (): Promise<Uint8Array> => {
    return await context.resourceManager.getRawFileContent(collegeTutorialRawFileName);
  },
  async (uri: string, bytes: Uint8Array): Promise<number> => {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      let totalWritten = 0;
      while (totalWritten < bytes.byteLength) {
        const remaining = bytes.subarray(totalWritten);
        const written = await fileIo.write(file.fd, remaining.buffer as ArrayBuffer, {
          offset: remaining.byteOffset,
          length: remaining.byteLength
        });
        if (written <= 0) {
          throw new Error('Tutorial package write stopped early.');
        }
        totalWritten += written;
      }
      return totalWritten;
    } finally {
      await fileIo.close(file);
    }
  }
);
```

Set status to `exporting`, await `exportPackage()`, then map the result. Ignore taps while status is `exporting`.

- [ ] **Step 4: Add the native export control**

Place a compact button beside the “本地快速入门” heading. Use the localized label, transparent/light-blue native treatment, 44vp minimum height, and disable it during export. Show a single small status line only when exporting, done, or failed; cancellation returns to idle without a message.

- [ ] **Step 5: Run checks and verify GREEN**

Run LocalUnit, i18n, shared UI, and tutorial package checks.

Expected: all pass and no remote Quick Start/FAQ entry becomes visible.

- [ ] **Step 6: Commit**

```powershell
git add -- entry/src/main/ets/pages/CollegePage.ets `
  entry/src/main/ets/services/college/CollegeTutorialExportService.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/test/LocalUnit.test.ets
git commit -m "feat(college): export the local MNIST tutorial"
```

---

### Task 6: Build and Verify on the Emulator

**Files:**
- Verify only; do not add generated build output.
- Save screenshots outside tracked source under `output/custom-section-college-mnist/`.

**Interfaces:**
- Consumes: finished catalog, College page, exporter, and rawfile.
- Produces: verified dual-ABI HAP and HDC evidence.

- [ ] **Step 1: Run final source checks**

```powershell
powershell -NoProfile -File scripts/verify-college-tutorial-package.ps1
powershell -NoProfile -File scripts/check-i18n-strings.ps1
powershell -NoProfile -File scripts/check-runtime-shared-ui.ps1
git diff --check
```

Expected: all exit `0`.

- [ ] **Step 2: Run full LocalUnit**

Run the Task 1 LocalUnit command and require `BUILD SUCCESSFUL` with no assertion or compile failure marker.

- [ ] **Step 3: Build and verify both HAPs**

```powershell
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p product=default -p module=entry@default --no-daemon
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon
powershell -NoProfile -File scripts/verify-ai-runtime-haps.ps1 `
  -MainHapPath entry/build/default/outputs/default/entry-default-unsigned.hap `
  -OhosTestHapPath entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
```

Expected: both builds succeed and verifier reports `arm64-v8a,x86_64`.

- [ ] **Step 4: Install and verify with HDC**

Install the main HAP on target `127.0.0.1:5555`. Use:

```powershell
hdc -t 127.0.0.1:5555 shell uitest uiInput swipe 650 2200 650 900 600
hdc -t 127.0.0.1:5555 shell uitest dumpLayout
hdc -t 127.0.0.1:5555 shell snapshot_display -f /data/local/tmp/custom-section.jpeg
```

Verify layout text contains `自定义能力`, `模型工具`, and `自定义模型`, and that Custom Model is no longer inside the advanced visual section.

Tap College, expand at least the environment and training chapters, and verify the layout contains `MindSpore 2.9.0`, `60,000`, `98.82%`, and `导出教程包`.

- [ ] **Step 5: Verify the save picker and capture evidence**

Tap `导出教程包` with HDC and confirm the native document save page opens with default ZIP filename. Return without saving and confirm the College page remains usable and does not show a failure state. Capture College top and tutorial-area screenshots.

- [ ] **Step 6: Final commit if verification required no code change**

No commit is needed for generated screenshots or HAP output. If verification exposed a product bug, return to RED with one focused test, fix it, re-run Tasks 5–6, and commit that fix separately.
