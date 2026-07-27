# College Tutorial Humanized Copy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the complete local MindSpore tutorial read like a developer-written walkthrough and remove every College “✓ 已完成” presentation.

**Architecture:** Keep tutorial structure, code, commands, measurements, and storage compatibility unchanged. Rewrite only human-facing copy in the tutorial data, experiment record, and College labels; delete completion-state reads and rendering from `CollegePage.ets`.

**Tech Stack:** ArkTS/ArkUI, Markdown, Hypium LocalUnit, HDC `uitest`, `humanizer-zh`.

## Global Constraints

- Preserve all versions, numbers, tensor contracts, filenames, commands, code, and logs.
- Keep the explicit statement that sklearn digits is not standard MNIST.
- Keep the MindIR versus MindSpore Lite `.ms` limitation and unavailable `converter_lite`.
- Do not add dependencies, routes, storage migrations, or new tutorial features.
- Keep the five chapter IDs and order: `environment,data,network,training,export`.
- Do not add URLs or “参考视频”.
- Remove “✓ 已完成” and completed-card background styling from College UI.
- Keep `CollegeProgressService`, preference keys, and stored historical values unchanged.

---

### Task 1: Humanize the in-app tutorial and remove completion presentation

**Files:**
- Modify: `entry/src/main/ets/common/data/CollegeLocalQuickStart.ets`
- Modify: `entry/src/main/ets/pages/CollegePage.ets`
- Test: running emulator layout dump

**Interfaces:**
- Consumes: the existing five `CollegeLocalQuickStartSection` records.
- Produces: the same records with natural Chinese copy and a College page with no completion-state presentation.

- [ ] **Step 1: Capture the failing completion-state baseline**

Install the current HAP, open College with HDC native touch, and dump:

```powershell
$hdc = 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc shell uitest dumpLayout -p /data/local/tmp/college-completion-before.json
& $hdc file recv /data/local/tmp/college-completion-before.json '..\.tmp-college-tutorial\college-completion-before.json'
Select-String -Path '..\.tmp-college-tutorial\college-completion-before.json' -Pattern '已完成'
```

Expected RED: at least one visible “已完成” node.

- [ ] **Step 2: Rewrite the app tutorial with the approved two-layer tone**

Use these exact chapter directions:

| Chapter | Natural opening | Required result wording |
| --- | --- | --- |
| 环境 | “这套流程已经在本机跑过一遍：训练、评估和导出都留下了实际结果。” | “环境是 Python 3.11.7、MindSpore 2.5.0，跑在 CPU 上。” |
| 数据 | “先把本地 digits 整理成 LeNet 能吃的格式。” | “原图是 [1797,8,8]，处理后是 [1797,1,28,28]。” |
| 网络 | “结构很经典：两组卷积、激活和池化，后面接三层全连接。” | “输入是 float32 NCHW [N,1,28,28]，输出是 [N,10]。” |
| 训练 | “每轮训练结束后，马上用 360 张测试图算一次准确率。” | “第一次跑到 98.61%；重跑最终 96.94%、最好 98.33%。” |
| 导出 | “训练完成后先存 CKPT，再导出 MindIR，并用同一张图检查回载结果。” | “目前只走到了桌面 MindIR。Lite 转换和 HarmonyOS 端侧运行还没做。” |

Replace report-like phrases:

```text
本教程不是一段概念介绍，而是…… -> 这套流程已经在本机跑过一遍……
为了保持完全离线 -> 为了离线也能跑
不宣称逐层复刻 -> 和 1998 年原版不完全一样
所以本次没有声称完成 -> 这一步还没做
真正接入需要 -> 要接进应用，还得……
明确标注该边界 -> 这里先把限制说清楚
```

Keep the code strings byte-for-byte unchanged.

- [ ] **Step 3: Remove completion-state UI**

Delete from `CollegePage.ets`:

```typescript
const collegeCompletedBackgroundColor: string = '#F4F7FF';
private progressService: CollegeProgressService | undefined = undefined;
@State checkedCollegeItemIds: Array<string> = [];
aboutToAppear()
uiAbilityContext()
collegeProgressService()
refreshCollegeProgress()
isCollegeItemChecked()
markCollegeItemChecked()
collegeItemCompletedStatus()
```

Remove the `CollegeProgressService` imports and these calls:

```typescript
this.markCollegeItemChecked(item);
this.collegeItemCompletedStatus(item.id)
```

Make all entry cards use:

```typescript
.backgroundColor(Color.White)
```

Do not edit `CollegeProgressService.ets` or its tests.

- [ ] **Step 4: Build, install, and verify the completion state is gone**

Run `assembleHap`, install, open College, and dump the layout again:

```powershell
Select-String -Path '..\.tmp-college-tutorial\college-completion-after.json' -Pattern '已完成'
```

Expected GREEN: no match. Visually verify white cards and unchanged tutorial expand/collapse controls.

- [ ] **Step 5: Commit**

```powershell
git add -- entry/src/main/ets/common/data/CollegeLocalQuickStart.ets entry/src/main/ets/pages/CollegePage.ets
git commit -m "feat(college): humanize tutorial and remove completion states"
```

### Task 2: Humanize the reproducible experiment record

**Files:**
- Modify: `docs/tutorials/mindspore-digits-lenet-run.md`

**Interfaces:**
- Consumes: the verified experiment record and approved copy design.
- Produces: a developer-written walkthrough with unchanged commands and measurements.

- [ ] **Step 1: Rewrite prose section by section**

Use these exact section intentions:

```text
开头：说明“我在 Windows 11 上把这条链路跑了一遍”，随后直接交代产物。
数据说明：先说本机没有 MNIST IDX，再说明为什么选内置 digits，最后用一句话强调准确率口径。
环境：表格不改，只把 torchvision 错误说明写成排错笔记。
数据准备：用“先、再、最后”描述像素转换，不重复真实性声明。
网络：解释 PyTorch/MindSpore 对应关系，保留 44,404 个参数。
训练：先列设置，再给两次结果；把 CPU 波动写成观察，不写成保证或免责声明。
导出：保留第一次 PYNATIVE_MODE 失败和 GRAPH_MODE 修复。
端侧：直接说“不能直接导入”，再列接入应用还要完成的五步。
```

Keep every fenced code block, table value, command, log line, filename, API name, version, number, and tensor contract unchanged.

- [ ] **Step 2: Run factual text guards**

Run:

```powershell
$record = Get-Content -Raw -Encoding UTF8 'docs/tutorials/mindspore-digits-lenet-run.md'
@(
  'Python | 3.11.7',
  'MindSpore | 2.5.0',
  '1797',
  '1437',
  '360',
  '0.986111',
  '0.969444',
  '4.344',
  '4.497',
  '177,956',
  '188,389',
  '[1,1,28,28]',
  '[1,224,224,3]',
  'converter_lite'
) | ForEach-Object { if (-not $record.Contains($_)) { throw "Missing fact: $_" } }
```

Expected: exit 0.

- [ ] **Step 3: Humanizer self-review**

Score the final prose against `humanizer-zh`:

```text
直接性 >= 9
节奏 >= 9
信任度 >= 9
真实性 >= 9
精炼度 >= 9
总分 >= 45/50
```

If a paragraph still contains “本次没有声称”“明确标注”“为了实现这一目标” or repeated “因此”, rewrite it before committing.

- [ ] **Step 4: Commit**

```powershell
git add -- docs/tutorials/mindspore-digits-lenet-run.md
git commit -m "docs(college): humanize local MindSpore walkthrough"
```

### Task 3: Full verification and delivery

**Files:**
- Verify: `entry/src/test/LocalUnit.test.ets`
- Verify: `entry/build/default/outputs/default/entry-default-unsigned.hap`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: verified HAP, emulator screenshots, and pushed master commits.

- [ ] **Step 1: Run full LocalUnit**

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: exit 0 and `BUILD SUCCESSFUL`.

- [ ] **Step 2: Build the HAP**

```powershell
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: exit 0 and `entry/build/default/outputs/default/entry-default-unsigned.hap`.

- [ ] **Step 3: Verify three emulator states**

Use HDC native touch and screenshots:

1. College top: no “已完成”; first chapter reads naturally.
2. Training chapter: both run results remain visible and accurate.
3. Export chapter/bottom: Lite limitation is conversational but explicit; footer remains above the floating tab bar.

- [ ] **Step 4: Push**

```powershell
git fetch origin master
git rev-list --left-right --count origin/master...master
git push origin master
git ls-remote origin refs/heads/master
```

Expected: no remote-only commits before push and remote master equals local HEAD after push.
