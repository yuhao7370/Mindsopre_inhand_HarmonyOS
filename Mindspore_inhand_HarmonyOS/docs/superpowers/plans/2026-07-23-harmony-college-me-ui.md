# HarmonyOS 学院与我的页面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将学院和“我的”两个主标签页改成已批准的 HarmonyOS A+C 视觉，同时保持现有路由、学习进度、版本读取和入口可见性。

**Architecture:** 保留 `MainPage` 与底部导航的现有普通纵向布局。学院页和“我的”页各自使用一个原生 `Scroll`；只新增页面级布局常量，不新增通用 Shell、设计系统或业务抽象。

**Tech Stack:** HarmonyOS 6.1 / API 24、ArkTS、ArkUI、Hypium LocalUnit、DevEco Studio 模拟器、PNG 资源。

## Global Constraints

- 页面左右边距 16vp，间距优先使用 8vp 网格。
- 卡片使用白色背景、16vp 圆角、1vp `#E8EDF5` 边框、无常驻阴影。
- 所有可点击目标至少 44vp；标题允许两行，容器使用最小高度和内容驱动布局。
- 正文使用系统字体；默认字号与 3.2× 下不得裁切、重叠或被底部导航遮挡。
- 不改变路由、Web URL、学习进度、版本读取、权限、分享逻辑或 `visibleByDefault`。
- 学院和“我的”分别提交；每个任务完成后由独立子 agent 复核规范与代码质量。
- 不新增第三方依赖，不实现自定义 SafeArea Shell 或完整设计系统。

---

### Task 1: 生成学院与“我的”扁平图标

**Files:**
- Create: `entry/src/main/resources/base/media/college_summary_v2.png`
- Create: `entry/src/main/resources/base/media/college_cloud_v2.png`
- Create: `entry/src/main/resources/base/media/college_quick_v2.png`
- Create: `entry/src/main/resources/base/media/college_faq_v2.png`
- Create: `entry/src/main/resources/base/media/college_forum_v2.png`
- Create: `entry/src/main/resources/base/media/college_train_v2.png`
- Create: `entry/src/main/resources/base/media/college_inference_v2.png`
- Create: `entry/src/main/resources/base/media/college_applications_v2.png`
- Create: `entry/src/main/resources/base/media/college_video_v2.png`
- Create: `entry/src/main/resources/base/media/me_version_v2.png`

**Interfaces:**
- Consumes: 根 `AGENTS.md` 的图标规则；现有 Experience V2 图标的线宽、留白和蓝/青配色。
- Produces: 10 枚独立的 256×256 RGBA 透明 PNG，供 Task 2/3 直接按资源名引用。

- [ ] **Step 1: 运行缺失资源检查并确认 RED**

Run:

```powershell
$names = @(
  'college_summary_v2','college_cloud_v2','college_quick_v2','college_faq_v2','college_forum_v2',
  'college_train_v2','college_inference_v2','college_applications_v2','college_video_v2','me_version_v2'
)
$missing = $names | Where-Object {
  -not (Test-Path "entry/src/main/resources/base/media/$_.png")
}
if ($missing.Count -gt 0) { throw "Missing icons: $($missing -join ', ')" }
```

Expected: FAIL with all 10 missing resource names.

- [ ] **Step 2: 使用 imagegen 分别生成 10 个语义图标**

每个图标使用独立调用，统一提示词骨架：

```text
Create one flat HarmonyOS-style feature icon for <SEMANTIC>.
Pure 2D rounded thin-line illustration, transparent background, blue primary strokes,
small cyan accent, centered with generous padding, readable at 40vp.
No text, no letters, no numbers, no gradient, no shadow, no glass, no 3D, no perspective,
no emoji, no background card.
```

`<SEMANTIC>` 依次为：

```text
MindSpore overview / cloud course / quick start rocket / FAQ help /
developer forum conversation / model training / inference execution /
application grid / learning video / app version information
```

- [ ] **Step 3: 规范化为 256×256 RGBA PNG**

对每个生成结果执行：

```powershell
magick <generated-file> -resize 256x256! -alpha on PNG32:<target-file>
```

Expected: 每个目标文件为 256×256、32-bit RGBA。

- [ ] **Step 4: 验证尺寸、Alpha 和独立性**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem 'entry/src/main/resources/base/media' |
  Where-Object { $_.BaseName -in $names }
$hashes = @()
foreach ($file in $files) {
  $image = [System.Drawing.Bitmap]::FromFile($file.FullName)
  if ($image.Width -ne 256 -or $image.Height -ne 256) {
    throw "$($file.Name) is not 256x256"
  }
  if (($image.PixelFormat.ToString()) -notmatch 'Alpha|Argb') {
    throw "$($file.Name) has no alpha channel"
  }
  $image.Dispose()
  $hashes += (Get-FileHash $file.FullName -Algorithm SHA256).Hash
}
if ($files.Count -ne 10 -or ($hashes | Select-Object -Unique).Count -ne 10) {
  throw 'Expected 10 distinct icons'
}
```

Expected: exit 0; 10 files and 10 distinct hashes.

- [ ] **Step 5: 提交图标**

```bash
git add entry/src/main/resources/base/media/*_v2.png
git commit -m "feat(ui): add flat college and me icons"
```

---

### Task 2: 重设计学院页

**Files:**
- Create: `entry/src/main/ets/common/data/CollegeLayoutSpec.ets`
- Modify: `entry/src/main/ets/pages/CollegePage.ets`
- Modify: `entry/src/main/ets/common/data/CollegeCatalog.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: Task 1 的 9 枚 `college_*_v2.png`；`collegeItems`、`CollegeProgressService`、`openWeb()` 和现有 Summary 文案。
- Produces:
  - `collegePageInsetVp = 16`
  - `collegeHeaderMinHeightVp = 112`
  - `collegeEntryMinHeightVp = 72`
  - `collegeQuickActionMinHeightVp = 64`
  - `collegeCardRadiusVp = 16`
  - `collegeDialogConfirmMinHeightVp = 44`
  - 内容驱动的学院页和可滚动 Summary 对话框。

- [ ] **Step 1: 写学院新布局 RED**

在 `LocalUnit.test.ets` 中导入并增加：

```ts
it('definesHarmonyCollegeLayoutMinimums', 0, () => {
  expect(collegePageInsetVp).assertEqual(16);
  expect(collegeHeaderMinHeightVp).assertEqual(112);
  expect(collegeEntryMinHeightVp).assertEqual(72);
  expect(collegeQuickActionMinHeightVp).assertEqual(64);
  expect(collegeCardRadiusVp).assertEqual(16);
  expect(collegeDialogConfirmMinHeightVp).assertEqual(44);
});
```

删除旧测试：

```text
definesAndroidCollegeTimelineVisuals
definesAndroidCollegeQuickActionVisuals
```

Run:

```powershell
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: FAIL because `CollegeLayoutSpec.ets` and new exports do not exist.

- [ ] **Step 2: 创建最小学院布局常量**

`CollegeLayoutSpec.ets`:

```ts
export const collegePageInsetVp: number = 16;
export const collegeHeaderMinHeightVp: number = 112;
export const collegeEntryMinHeightVp: number = 72;
export const collegeQuickActionMinHeightVp: number = 64;
export const collegeCardRadiusVp: number = 16;
export const collegeDialogConfirmMinHeightVp: number = 44;
```

- [ ] **Step 3: 删除旧 Android 时间线视觉数据**

从 `CollegeCatalog.ets` 删除：

```text
CollegeMediaName
CollegeTimelineVisual
CollegeQuickActionVisual
collegeTimelineCheckedColor
collegeTimelineUncheckedColor
collegeQuickActionUncheckedBorderColor
collegeTimelineTextColor
collegeTimelineIconNamesForItem()
collegeQuickActionIconNames()
isLastCollegeTimelineItem()
collegeTimelineVisualForItem()
collegeQuickActionVisual()
```

保留 `CollegeItem`、`CollegeQuickAction`、`collegeItems` 和 `isCollegeItemUrlNavigable()`。

- [ ] **Step 4: 用单列入口卡和两列 Quick Start 重写学院页**

页面必须使用以下骨架：

```ts
Scroll() {
  Column() {
    this.collegeHeader()
    Text(appString('mindspore_college_title'))
    ForEach(collegeItems, (item: CollegeItem) => {
      if (item.type === 'quickStart') {
        this.quickStartCard(item)
      } else if (item.type === 'footer') {
        this.collegeFooter(item)
      } else {
        this.collegeEntryCard(item)
      }
    }, (item: CollegeItem) => item.id)
  }
  .padding({ left: collegePageInsetVp, right: collegePageInsetVp, bottom: 28 })
}
.scrollBar(BarState.Off)
```

约束：

```text
header: minHeight 112, left aligned 28fp title + 14fp subtitle
entry card: minHeight 72, radius 16, border #E8EDF5, no shadow
entry icon: 40vp; title: 16fp, maxLines 2
quick action: two-column Grid, minHeight 64, icon 30vp, title maxLines 2
completed state: college_checked text plus blue emphasis; not color-only
only summary/url entries receive onClick
```

图标按 `item.id` / `action.id` 映射到 Task 1 资源；不再引用旧 checked/uncheck PNG。

- [ ] **Step 5: 将 Summary 对话框改为可滚动内容**

保持现有 `CustomDialogController`，对话框要求：

```text
width 86%
white background
radius 20
content Scroll with constraintSize({ maxHeight: '72%' })
confirm Button constraintSize({ minHeight: 44 })
original title/content/logo/close behavior unchanged
```

- [ ] **Step 6: 运行完整 LocalUnit**

Run:

```powershell
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: `BUILD SUCCESSFUL`, exit 0, no failure markers.

- [ ] **Step 7: 模拟器验收学院页**

安装当前 main HAP 后验证：

```text
default font: top / Quick Start / bottom
3.2x app font: top / Summary dialog / bottom
summary, cloud, train, inference, applications, video, FAQ, forum: open and return
checked progress persists after returning and reopening College
BottomTabBar remains visible and does not cover footer
```

证据保存到：

```text
.superpowers/sdd/college-ui-evidence/
```

- [ ] **Step 8: 提交学院页**

```bash
git add entry/src/main/ets/pages/CollegePage.ets \
  entry/src/main/ets/common/data/CollegeCatalog.ets \
  entry/src/main/ets/common/data/CollegeLayoutSpec.ets \
  entry/src/test/LocalUnit.test.ets
git commit -m "feat(ui): redesign college page"
```

---

### Task 3: 重设计“我的”页

**Files:**
- Modify: `entry/src/main/ets/pages/MePage.ets`
- Modify: `entry/src/main/ets/common/data/MeLayoutSpec.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: Task 1 的 `me_version_v2.png`；`visibleMeItems`、`AppVersionService` 和现有分享/路由方法。
- Produces:
  - `mePageInsetVp = 16`
  - `meTitleMinHeightVp = 72`
  - `meInfoCardMinHeightVp = 88`
  - `meInfoCardRadiusVp = 16`
  - `meLogoSizeVp = 56`
  - 无渐变、无假点击的版本信息页。

- [ ] **Step 1: 写“我的”新布局 RED**

替换旧 `MeLayoutSpec` 测试为：

```ts
it('definesHarmonyMeLayoutMinimums', 0, () => {
  expect(mePageInsetVp).assertEqual(16);
  expect(meTitleMinHeightVp).assertEqual(72);
  expect(meInfoCardMinHeightVp).assertEqual(88);
  expect(meInfoCardRadiusVp).assertEqual(16);
  expect(meLogoSizeVp).assertEqual(56);
  expect(visibleMeItems.length).assertEqual(1);
  expect(visibleMeItems[0].id).assertEqual('version');
  expect(isMeItemUrlNavigable(visibleMeItems[0])).assertFalse();
  expect(isMeItemPageNavigable(visibleMeItems[0])).assertFalse();
});
```

Run:

```powershell
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: FAIL because new `MeLayoutSpec` exports do not exist.

- [ ] **Step 2: 用最小高度常量替换旧固定布局常量**

`MeLayoutSpec.ets`:

```ts
export const mePageInsetVp: number = 16;
export const meTitleMinHeightVp: number = 72;
export const meInfoCardMinHeightVp: number = 88;
export const meInfoCardRadiusVp: number = 16;
export const meLogoSizeVp: number = 56;
```

- [ ] **Step 3: 重写“我的”页面**

页面骨架：

```ts
Scroll() {
  Column() {
    Text(appString('me_head_title'))
      .fontSize(28)
      .fontWeight(FontWeight.Bold)
      .constraintSize({ minHeight: meTitleMinHeightVp })
    this.versionCard()
    if (this.statusKey !== 'empty') {
      Text(appString(this.statusKey))
    }
  }
  .padding({ left: mePageInsetVp, right: mePageInsetVp, bottom: 28 })
}
.scrollBar(BarState.Off)
```

`versionCard()` 要求：

```text
Image(me_version_v2) 56vp
app name: EntryAbility_label, 17fp Bold, maxLines 2
version title/value: 14fp/13fp, wrap allowed
minHeight 88, radius 16, border #E8EDF5, no shadow
no onClick, no chevron, no pressed state
```

删除渐变标题、1vp 横条、字母圆形 fallback 和 Version 行上的无效点击。

保留 `openItem()`、`shareApp()` 等现有方法，以便未来条目重新可见；不要改变 `MeCatalog.ets`。

- [ ] **Step 4: 运行完整 LocalUnit**

Run:

```powershell
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: `BUILD SUCCESSFUL`, exit 0, no failure markers.

- [ ] **Step 5: 模拟器验收“我的”页**

验证：

```text
default font: title and version card complete
3.2x app font: title, app name and version wrap without clipping
only version is visible
version card has no false click feedback or chevron
BottomTabBar remains clear of content
reported version equals AppVersionService output
```

证据保存到：

```text
.superpowers/sdd/me-ui-evidence/
```

- [ ] **Step 6: 提交“我的”页**

```bash
git add entry/src/main/ets/pages/MePage.ets \
  entry/src/main/ets/common/data/MeLayoutSpec.ets \
  entry/src/test/LocalUnit.test.ets
git commit -m "feat(ui): redesign me page"
```

---

## Final Verification

完成三个任务和逐任务 review 后：

```powershell
& .\scripts\build-ai-runtime-acceptance.ps1
```

Expected:

```text
main and ohosTest BUILD SUCCESSFUL
abis=arm64-v8a,x86_64
```

在 API 24 x86_64 模拟器依次检查 Experience、College、Me 三个标签切换，确认底部导航样式未回归。然后生成 `merge-base..HEAD` review package，交给独立高级子 agent 做整阶段最终审查。
