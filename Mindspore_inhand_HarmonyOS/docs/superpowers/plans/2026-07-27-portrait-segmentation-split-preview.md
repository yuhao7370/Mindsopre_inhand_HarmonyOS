# 人像分割双区预览 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将人像分割页改为保持 4:3 比例的上下双预览，并提供原背景、四套内置背景和自定义相册切换。

**Architecture:** 复用现有相机 Surface、分割前景 PixelMap、保存和重试状态，只调整 `FeatureRuntimePage.ets` 的人像分割布局。背景目录保留五项：动态“原背景”加现有 `portrait2`–`portrait5` 四个 rawfile；背景切换只改合成层 URI，不调用推理。

**Tech Stack:** HarmonyOS 6.1 / API 24、ArkTS、ArkUI、Hypium LocalUnit、PowerShell source guard、ImageGen、Hvigor、HDC。

## Global Constraints

- 两个预览使用相同 4:3 容器和 `ImageFit.Cover`，不得拉伸。
- 前置摄像头镜像只应用一次，上下预览方向和裁切一致。
- 不更换模型、不改变入口、不增加第三方依赖或通用组件层。
- 保存只保存下方合成结果；加载、失败、重试和最近有效结果保留。
- 四张生成背景必须无人物、无文字、无标志。

---

## File Map

- `entry/src/main/ets/pages/FeatureRuntimePage.ets`: 双区布局、动态原背景、背景缩略图和合成显示。
- `entry/src/main/ets/features/runtime/PortraitSegmentationBackgroundCatalog.ets`: 原背景与四套 rawfile 目录。
- `entry/src/main/ets/common/i18n/AppStrings.ets`: 新增双区标题键，复用现有背景键。
- `entry/src/main/resources/{base,zh_CN,en_US}/element/string.json`: 双区标题和语义化背景名称。
- `entry/src/main/resources/rawfile/portrait/portrait2.jpg`–`portrait5.jpg`: 四张生成背景。
- `entry/src/test/LocalUnit.test.ets`: 原背景默认状态和目录回归。
- `scripts/check-portrait-runtime-ui.ps1`: 双区、比例、Cover、保存和背景切换契约。
- `scripts/test-portrait-runtime-ui-guard.ps1`: 新契约的负向变异。

### Task 1: 建立会失败的双区与原背景契约

**Files:**
- Modify: `scripts/check-portrait-runtime-ui.ps1`
- Modify: `scripts/test-portrait-runtime-ui-guard.ps1`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `portraitSegmentationAndroidLayout()`、`portraitSegmentationComposite()`、`selectPortraitBackgroundPreset()`
- Produces: 对双区顺序、4:3、Cover、原背景默认状态和无重复推理的可执行契约

- [ ] **Step 1: 先修改 LocalUnit 期望**

将人像背景测试改为：

```ts
expect(portraitSegmentationBackgroundPresets.length).assertEqual(5);
expect(portraitSegmentationBackgroundPresets[0].id).assertEqual('original');
expect(defaultPortraitSegmentationBackgroundPreset.id).assertEqual('original');
expect(defaultPortraitSegmentationBackgroundUri()).assertEqual('');
expect(initialPortraitSegmentationBackgroundState(
  AppRoute.PORTRAIT_SEGMENTATION.name, '', ''
).selectedPresetId).assertEqual('original');
```

- [ ] **Step 2: 扩展 source guard**

在 `check-portrait-runtime-ui.ps1` 中提取新的 `portraitSegmentationCameraPreview()` 与 `portraitSegmentationResultPreview()` section，并断言：

```powershell
Assert-Contains $portraitLayout 'this.portraitSegmentationCameraPreview()' 'portrait camera preview is missing.'
Assert-Contains $portraitLayout 'this.portraitSegmentationResultPreview()' 'portrait result preview is missing.'
Assert-Contains $portraitLayout 'Scroll() {' 'portrait split previews must remain reachable on compact screens.'
Assert-Count $portraitLayout '.aspectRatio(4 / 3)' 2 'portrait previews must share 4:3 containers.'
Assert-Excludes $portraitLayout "this.liveCameraSurfaceContent()`n        this.portraitSegmentationComposite()" `
  'camera and composite must not share one overlay stack.'
Assert-Contains $portraitComposite '.objectFit(ImageFit.Cover)' 'portrait composite must preserve aspect ratio.'
Assert-Excludes $selectPreset 'this.runWorkflow()' 'background selection must not rerun segmentation.'
```

- [ ] **Step 3: 增加 guard 负向变异**

在 `test-portrait-runtime-ui-guard.ps1` 中增加三项 mutation：删除结果预览、把第二个 `.aspectRatio(4 / 3)` 改为 `.height('100%')`、把 `ImageFit.Cover` 改为 `ImageFit.Fill`。每项都必须被 guard 拒绝。

- [ ] **Step 4: 运行 RED**

```powershell
& .\scripts\check-portrait-runtime-ui.ps1
& .\scripts\test-portrait-runtime-ui-guard.ps1
```

Expected: 当前单 Stack 布局缺少双区 builder，至少第一条命令失败。

- [ ] **Step 5: 提交 RED 契约**

```powershell
git add scripts/check-portrait-runtime-ui.ps1 scripts/test-portrait-runtime-ui-guard.ps1 entry/src/test/LocalUnit.test.ets
git commit -m "test(portrait): require split previews"
```

### Task 2: 实现最小双区布局与原背景

**Files:**
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `entry/src/main/ets/features/runtime/PortraitSegmentationBackgroundCatalog.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`

**Interfaces:**
- Produces: `portraitSegmentationCameraPreview()`、`portraitSegmentationResultPreview()`；目录首项 `id: 'original'`
- Consumes: `segmentationImageUri` 作为原背景、`segmentationForegroundPixelMap` 作为前景

- [ ] **Step 1: 将目录首项改为动态原背景**

首项使用：

```ts
{
  id: 'original',
  titleKey: 'feature_runtime_portrait_background_1',
  mediaName: 'original',
  rawfilePath: ''
}
```

`portraitSegmentationBackgroundUri()` 对 `original` 返回空字符串；`initialPortraitSegmentationBackgroundState()` 在 `selectedPresetId` 已存在时不重复初始化。

- [ ] **Step 2: 让选择原背景复用当前源帧**

在 `FeatureRuntimePage.ets` 中以一个表达式解析背景：

```ts
private portraitCompositeBackgroundUri(): string {
  return this.selectedPortraitBackgroundPresetId === 'original' ?
    this.segmentationImageUri : this.backgroundImageUri;
}
```

`portraitSegmentationComposite()` 使用该 URI；选择 `original` 时只更新选择状态和元数据，不调用 `runWorkflow()`。

- [ ] **Step 3: 拆出两个预览 builder**

```ts
@Builder
portraitSegmentationCameraPreview() {
  Stack({ alignContent: Alignment.Center }) {
    this.liveCameraSurfaceContent()
  }
  .width('100%')
  .aspectRatio(4 / 3)
  .clip(true)
  .backgroundColor('#111827')
  .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
}

@Builder
portraitSegmentationResultPreview() {
  Stack({ alignContent: Alignment.Center }) {
    this.portraitSegmentationComposite()
  }
  .width('100%')
  .aspectRatio(4 / 3)
  .clip(true)
  .backgroundColor('#111827')
  .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
}
```

- [ ] **Step 4: 改为可滚动双区**

导航栏下使用 `Scroll()`，内部按“相机原画”、相机预览、“分割效果”、结果预览、状态、背景条排列。为标题新增 `feature_runtime_portrait_camera_original` 与 `feature_runtime_portrait_segmentation_result` 资源键，中英文分别为“相机原画 / 分割效果”和“Camera / Segmentation result”。

- [ ] **Step 5: 调整合成 fit**

背景与前景都改为：

```ts
.width('100%')
.height('100%')
.objectFit(ImageFit.Cover)
```

保留现有 `segmentationForegroundMirrorScaleX()`，不增加第二次旋转或镜像。

- [ ] **Step 6: 运行 GREEN**

```powershell
& .\scripts\check-portrait-runtime-ui.ps1
& .\scripts\test-portrait-runtime-ui-guard.ps1
```

Expected: 两个脚本通过并输出 portrait contract / negative fixtures passed。

- [ ] **Step 7: 提交布局修复**

```powershell
git add entry/src/main/ets/pages/FeatureRuntimePage.ets entry/src/main/ets/features/runtime/PortraitSegmentationBackgroundCatalog.ets entry/src/main/ets/common/i18n/AppStrings.ets entry/src/main/resources/base/element/string.json entry/src/main/resources/zh_CN/element/string.json entry/src/main/resources/en_US/element/string.json
git commit -m "fix(portrait): split camera and result previews"
```

### Task 3: 生成并接入四套背景

**Files:**
- Modify: `entry/src/main/resources/rawfile/portrait/portrait2.jpg`
- Modify: `entry/src/main/resources/rawfile/portrait/portrait3.jpg`
- Modify: `entry/src/main/resources/rawfile/portrait/portrait4.jpg`
- Modify: `entry/src/main/resources/rawfile/portrait/portrait5.jpg`
- Modify: `entry/src/main/resources/{base,zh_CN,en_US}/element/string.json`

**Interfaces:**
- Produces: 四张 4:3 内置背景，沿用现有 rawfile 路径，避免增加目录和资源映射

- [ ] **Step 1: 用 ImageGen 生成四张 4:3 背景**

一次请求生成四张可独立裁切的背景：冷蓝科技影棚、暖色现代室内、柔和自然庭院、蓝白极简渐变；全部无人物、无文字、无 logo，主体区域保持低细节以便前景可读。

- [ ] **Step 2: 检查并复制素材**

逐张目视确认无人物、文字和标志，统一转换为 1536×1152 JPEG，分别覆盖 `portrait2.jpg`–`portrait5.jpg`。不修改 `portrait1.jpg`，因为设备原生分割测试使用它作为无人负样本。

- [ ] **Step 3: 更新背景名称**

将背景 1–5 的资源文案改为：

```text
原背景 / 冷蓝影棚 / 暖色室内 / 自然庭院 / 极简渐变
Original / Blue studio / Warm interior / Garden / Minimal gradient
```

- [ ] **Step 4: 运行资源与契约检查**

```powershell
& .\scripts\check-portrait-runtime-ui.ps1
& .\scripts\test-portrait-runtime-ui-guard.ps1
git diff --check
```

Expected: 全部通过，四张 JPEG 存在且尺寸为 1536×1152。

- [ ] **Step 5: 提交背景素材**

```powershell
git add entry/src/main/resources/rawfile/portrait/portrait2.jpg entry/src/main/resources/rawfile/portrait/portrait3.jpg entry/src/main/resources/rawfile/portrait/portrait4.jpg entry/src/main/resources/rawfile/portrait/portrait5.jpg entry/src/main/resources/base/element/string.json entry/src/main/resources/zh_CN/element/string.json entry/src/main/resources/en_US/element/string.json
git commit -m "feat(portrait): add background presets"
```

### Task 4: 构建与模拟器验收

**Files:**
- Modify only if a reproduced defect needs a focused failing check first

**Interfaces:**
- Consumes: 已通过守卫的双区页面和四张背景
- Produces: 可安装 HAP 与 HDC 截图证据

- [ ] **Step 1: 运行完整 LocalUnit 并扫描失败标记**

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon' 2>&1 |
  Tee-Object -FilePath .\portrait-localunit.log
if (Select-String .\portrait-localunit.log -Pattern 'AssertException|FAILED|ERROR') { throw 'LocalUnit failure marker found' }
```

- [ ] **Step 2: 构建 HAP**

```powershell
& .\scripts\build-hap.ps1
```

Expected: guard、LocalUnit 相关检查和 Hvigor 构建成功。

- [ ] **Step 3: 安装并启动**

使用 `hdc list targets` 找到已启动模拟器，以 `hdc install -r <hap>` 安装最新 HAP，并启动应用的人像分割路由。

- [ ] **Step 4: 用原生触点验收**

用 HDC `uitest` 点击人像分割入口、切换前后摄像头、依次选择五个预设和自定义相册；使用 `snapshot_display` 截取顶部、结果和背景条。确认上下画面不拉伸、方向与镜像一致、背景切换不出现新的推理加载状态、保存可用。

- [ ] **Step 5: 验收大字体**

将系统字体调到 3.2 倍后重新进入页面并截图；确认 Scroll 可到达重试与背景条，标题和状态不遮挡。验收后恢复原字体。

- [ ] **Step 6: 最终复核**

```powershell
git diff --check master...HEAD
git status --short
git log --oneline master..HEAD
```

Expected: 工作树无未提交修改，提交按契约、布局、素材分离。
