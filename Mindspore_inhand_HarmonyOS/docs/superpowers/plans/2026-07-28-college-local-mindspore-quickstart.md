# College Local MindSpore Quick Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken College quick-start and FAQ rows with a complete, locally readable MindSpore handwritten-digit tutorial backed by a real local training run.

**Architecture:** Keep the legacy catalog unchanged and derive a filtered visible list. Store the five tutorial chapters and the one-open-at-a-time state transition in one data module; `CollegePage.ets` only renders the accordion. Preserve the reproducible Python script and terminal record under `docs/tutorials`.

**Tech Stack:** ArkTS/ArkUI, Hypium LocalUnit, Python 3.11, MindSpore 2.5.0 CPU, scikit-learn bundled digits dataset.

## Global Constraints

- Do not add dependencies, network permissions, WebView, or a new route.
- Keep legacy `quick` and `faq` catalog data, but do not render either row.
- Do not render URLs or a “参考视频” section in the local tutorial.
- Use the existing single page `Scroll`; add no nested scrolling container.
- Use a single-column native HarmonyOS layout with 16vp radius, 1vp `#E8EDF5` borders, white cards, and no permanent shadow.
- State the dataset truthfully as sklearn bundled digits resized from 8×8 to 28×28, not real MNIST.
- State that the exported NCHW `[1,1,28,28]` MindIR cannot be loaded by the existing NHWC `[1,224,224,3]` custom-model page and that `.ms` conversion was not run because converter_lite is unavailable.

---

### Task 1: Preserve the reproducible local experiment

**Files:**
- Create: `docs/tutorials/mindspore-digits-lenet.py`
- Create: `docs/tutorials/mindspore-digits-lenet-run.md`

**Interfaces:**
- Consumes: Python 3.11, MindSpore 2.5.0, NumPy, Pillow, scikit-learn 1.3.2.
- Produces: a runnable CPU training/export script and a factual record used by the in-app chapter copy.

- [ ] **Step 1: Copy the proven script into the repository**

Use the already executed `.tmp-college-tutorial/mindspore_digits_lenet.py` unchanged except for a documentation header. It must keep:

```python
bundle = load_digits()
images = resize_digits(bundle.images)
train_x, test_x, train_y, test_y = train_test_split(
    images, labels, test_size=0.2, random_state=42, stratify=labels
)
ms.export(
    network,
    Tensor(np.zeros((1, 1, 28, 28), dtype=np.float32)),
    file_name=str(mindir_stem),
    file_format="MINDIR",
)
```

- [ ] **Step 2: Re-run the script from its tracked location**

Run:

```powershell
python docs/tutorials/mindspore-digits-lenet.py --output-dir .tmp-college-tutorial/verified-artifacts
```

Expected: exit 0; `run_summary.json` reports 1,437 training samples, 360 test samples, a best accuracy above 0.95, and identical eager/MindIR predictions.

- [ ] **Step 3: Write the experiment record**

Record the exact environment, command, architecture, preprocessing, per-run summary, artifact sizes, input/output contract, and the converter/custom-page limitations. Include the actual verified numbers from `run_summary.json`; do not copy temporary absolute paths into user-facing app text.

- [ ] **Step 4: Commit**

```powershell
git add -- docs/tutorials/mindspore-digits-lenet.py docs/tutorials/mindspore-digits-lenet-run.md
git commit -m "docs(college): record local MindSpore digits tutorial"
```

### Task 2: Add the tutorial behavior with TDD

**Files:**
- Create: `entry/src/main/ets/common/data/CollegeLocalQuickStart.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `CollegeItem` and `collegeItems` from `CollegeCatalog.ets`.
- Produces:
  - `visibleCollegeItems: CollegeItem[]`
  - `collegeLocalQuickStartSections: CollegeLocalQuickStartSection[]`
  - `nextCollegeQuickStartExpandedId(currentId: string, selectedId: string): string`

- [ ] **Step 1: Write failing visibility and accordion tests**

Add imports for the three exports above, then add:

```typescript
it('hidesBrokenCollegeRowsWithoutDeletingTheirCatalogData', 0, () => {
  expect(collegeItems.find((item: CollegeItem) => item.id === 'quick') === undefined).assertFalse();
  expect(collegeItems.find((item: CollegeItem) => item.id === 'faq') === undefined).assertFalse();
  expect(visibleCollegeItems.map((item: CollegeItem) => item.id).join(','))
    .assertEqual('summary,cloud,forum,footer');
});

it('keepsOnlyOneLocalQuickStartChapterExpanded', 0, () => {
  expect(nextCollegeQuickStartExpandedId('environment', 'data')).assertEqual('data');
  expect(nextCollegeQuickStartExpandedId('data', 'data')).assertEqual('');
});
```

Run LocalUnit and confirm failure because `CollegeLocalQuickStart.ets` does not exist.

- [ ] **Step 2: Implement the minimal visible list and state transition**

```typescript
export const visibleCollegeItems: CollegeItem[] =
  collegeItems.filter((item: CollegeItem) => item.id !== 'quick' && item.id !== 'faq');

export function nextCollegeQuickStartExpandedId(currentId: string, selectedId: string): string {
  return currentId === selectedId ? '' : selectedId;
}
```

Run LocalUnit and confirm the two tests pass.

- [ ] **Step 3: Write a failing chapter-contract test**

```typescript
it('providesFiveCompleteOfflineMindSporeTutorialChapters', 0, () => {
  expect(collegeLocalQuickStartSections.map((section: CollegeLocalQuickStartSection) => section.id).join(','))
    .assertEqual('environment,data,network,training,export');
  collegeLocalQuickStartSections.forEach((section: CollegeLocalQuickStartSection) => {
    expect(section.objective.length > 0).assertTrue();
    expect(section.paragraphs.length > 0).assertTrue();
    expect(section.codeBlocks.length > 0).assertTrue();
    expect(section.measuredResult.length > 0).assertTrue();
    const text = JSON.stringify(section);
    expect(text.indexOf('http')).assertEqual(-1);
    expect(text.indexOf('参考视频')).assertEqual(-1);
  });
});
```

Run LocalUnit and confirm failure because the chapter array is empty or missing.

- [ ] **Step 4: Add the five complete chapter records**

Define:

```typescript
export interface CollegeTutorialCodeBlock {
  readonly title: string;
  readonly code: string;
}

export interface CollegeLocalQuickStartSection {
  readonly id: string;
  readonly step: string;
  readonly title: string;
  readonly objective: string;
  readonly paragraphs: string[];
  readonly codeBlocks: CollegeTutorialCodeBlock[];
  readonly measuredResult: string;
}
```

Populate all five sections from `docs/tutorials/mindspore-digits-lenet-run.md`. The training result must report 20 epochs, 98.61% final/best accuracy for the recorded run, and about 4.34 seconds of training. The export section must report CKPT and MindIR sizes and the exact NCHW input contract.

- [ ] **Step 5: Run LocalUnit and commit**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: exit 0.

```powershell
git add -- entry/src/main/ets/common/data/CollegeLocalQuickStart.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat(college): add offline MindSpore tutorial data"
```

### Task 3: Render the native inline tutorial

**Files:**
- Modify: `entry/src/main/ets/pages/CollegePage.ets`

**Interfaces:**
- Consumes: `visibleCollegeItems`, `collegeLocalQuickStartSections`, and `nextCollegeQuickStartExpandedId`.
- Produces: an inline single-open accordion shown between the section title and the retained college rows.

- [ ] **Step 1: Switch the page to the filtered list**

Import `visibleCollegeItems` and use it in both progress refresh and `ForEach`. Delete the unreachable quick-action rendering builders and imports from this page; keep the underlying catalog and progress service untouched.

- [ ] **Step 2: Add the minimal accordion state and builders**

Initialize:

```typescript
@State expandedQuickStartSectionId: string = collegeLocalQuickStartSections[0].id;
```

Render a heading, then each section as one bordered white card. The closed row shows `section.step`, `section.title`, and `展开`; the open row shows `收起`, objective, paragraphs, wrapped monospace code blocks, and the measured result. The row click must use:

```typescript
this.expandedQuickStartSectionId = nextCollegeQuickStartExpandedId(
  this.expandedQuickStartSectionId,
  section.id
);
```

Do not add `Scroll`, `List`, `Grid`, `Web`, or URL handlers inside the tutorial.

- [ ] **Step 3: Run unit tests and build the HAP**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: both commands exit 0 and produce `entry/build/default/outputs/default/entry-default-unsigned.hap`.

- [ ] **Step 4: Verify on the running emulator**

Use:

```powershell
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' install -r entry/build/default/outputs/default/entry-default-unsigned.hap
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' shell aa start -a EntryAbility -b com.yuhaofeng.mih
```

Use HDC native touch and screenshots to verify: the old quick/FAQ rows are absent; the first chapter opens by default; selecting another chapter closes the previous one; long content scrolls in the page without inner scrollbars; the bottom content stays above the floating navigation.

- [ ] **Step 5: Commit and push**

```powershell
git add -- entry/src/main/ets/pages/CollegePage.ets
git commit -m "feat(college): render local MindSpore quick start"
git push origin master
```
