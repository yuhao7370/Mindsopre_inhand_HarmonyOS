# HarmonyOS Experience UI V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将体验中心改为轻量 HarmonyOS 原生风格：紧凑头部自然离场、轻标题栏吸顶、双列浅边框卡片、A 风格扁平图标，并保留现有圆角悬浮底栏。

**Architecture:** `FeatureCatalog.ets` 继续作为功能、路由和可见性的唯一数据源；不修改九个可见入口和四个隐藏入口。`ExperiencePage` 改为单一纵向 `Scroll`，滚动偏移只控制轻标题栏显隐；卡片、头部和图标资源各自保持现有职责。

**Tech Stack:** ArkTS、ArkUI、HarmonyOS media resources、Hypium LocalUnit、内置 ImageGen、Pillow、Hvigor、HDC、DevEco Studio API 24 模拟器。

## Global Constraints

- 必须遵守根目录 `AGENTS.md`。
- 不改变既有路由、推理流程、权限和 `FeatureCatalog.ets` 的 `visibleByDefault`。
- 九个默认功能继续可见；舞蹈工厂、智能古诗、场景检测和自定义模型继续隐藏。
- 保留 `BottomTabBar.ets` 当前圆角悬浮结构和选中态，本计划不修改该文件。
- 不新增运行时依赖或第三方 UI 库。
- 图标必须为圆角细线、纯 2D、无渐变、无阴影、无高光和无透视。
- 每个任务通过独立验证后立即提交。

---

### Task 1: 生成并替换十三枚 A 风格功能图标

**Files:**
- Replace: `entry/src/main/resources/base/media/feature_posenet.png`
- Replace: `entry/src/main/resources/base/media/feature_segmentation.png`
- Replace: `entry/src/main/resources/base/media/feature_classification.png`
- Replace: `entry/src/main/resources/base/media/feature_gesture.png`
- Replace: `entry/src/main/resources/base/media/feature_dance.png`
- Replace: `entry/src/main/resources/base/media/feature_poetry.png`
- Replace: `entry/src/main/resources/base/media/feature_text_extraction.png`
- Replace: `entry/src/main/resources/base/media/feature_translation.png`
- Replace: `entry/src/main/resources/base/media/feature_scene.png`
- Replace: `entry/src/main/resources/base/media/feature_object_photo.png`
- Replace: `entry/src/main/resources/base/media/feature_object_camera.png`
- Replace: `entry/src/main/resources/base/media/feature_style_transfer.png`
- Replace: `entry/src/main/resources/base/media/feature_custom_model.png`

**Interfaces:**
- Consumes: `iconMediaName()` and `iconMediaResource()` in `entry/src/main/ets/common/icons/IconSymbols.ets`; resource names do not change.
- Produces: thirteen 256×256 RGBA PNG resources with transparent corners and unique semantic artwork.

- [ ] **Step 1: 为每个资源调用一次内置 ImageGen**

所有调用共享以下完整提示词，只替换 `<SUBJECT>`：

```text
Use case: ui-mockup
Asset type: HarmonyOS mobile feature icon
Primary request: Create one centered ultra-flat 2D icon for <SUBJECT>.
Style/medium: rounded thin monoline icon with one small solid cyan accent; crisp vector-like raster rendering.
Composition/framing: one icon centered in a square canvas, generous and equal padding on every side, no outer tile or container.
Color palette: dark cobalt #0A3B82 for structural lines, blue #176CE8 for the primary mark, cyan #00A9E8 only for one small accent.
Constraints: consistent 2px visual stroke weight at 48px display size, simple recognizable silhouette, no text, no watermark.
Avoid: gradients, shadows, bevels, gloss, highlights, depth, perspective, isometric view, 3D, emoji style, photorealism.
Create the icon on a perfectly flat solid #00FF00 chroma-key background for background removal. The background must have no texture, shadow, reflection, or lighting variation. Do not use #00FF00 in the icon.
```

使用以下一对一主题映射：

| Resource | `<SUBJECT>` |
|---|---|
| `feature_posenet.png` | a human pose skeleton with joint nodes inside four scan-corner marks |
| `feature_segmentation.png` | a head-and-shoulders silhouette split into one solid half and one dashed contour half |
| `feature_classification.png` | a landscape image outline connected to three small classification nodes |
| `feature_gesture.png` | an open hand outline with two short motion arcs |
| `feature_dance.png` | a dancing human pose skeleton with two small rhythm arcs |
| `feature_poetry.png` | a document outline with three short writing lines and a minimal pen nib |
| `feature_text_extraction.png` | a document inside four scan corners with a capital T and two baseline strokes |
| `feature_translation.png` | two text-line panels connected by opposing curved arrows, with no letters or language characters |
| `feature_scene.png` | a landscape frame with sun and mountain connected to two scene-category nodes |
| `feature_object_photo.png` | a still photo outline containing one small rectangular object-detection box |
| `feature_object_camera.png` | a camera outline with four focus-corner marks around its lens |
| `feature_style_transfer.png` | two overlapping image outlines connected by one flowing wave stroke |
| `feature_custom_model.png` | a microchip outline with two input nodes and two output nodes |

内置工具每次生成后，立即把最新的 `output_hint` 对应文件复制到该资源的稳定源文件名。下面是 PoseNet 的完整命令；其余十二个资源使用上表中的确切资源名：

```powershell
New-Item -ItemType Directory -Force 'tmp/imagegen/experience-icons' | Out-Null
$generatedPath = Get-ChildItem 'C:\Users\27377\.codex\generated_images' `
  -Recurse -Filter '*.png' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 -ExpandProperty FullName
Copy-Item -LiteralPath $generatedPath `
  -Destination 'tmp/imagegen/experience-icons/feature_posenet-source.png'
```

顺序执行生成和复制，避免把另一枚图标误配到当前资源。不要先删除已提交的旧资源；Git 是回退路径。

- [ ] **Step 2: 去除色键并生成 256×256 资源**

Run the installed helper for all thirteen sources:

```powershell
$helper = 'C:\Users\27377\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
$names = @(
  'feature_posenet', 'feature_segmentation', 'feature_classification',
  'feature_gesture', 'feature_dance', 'feature_poetry',
  'feature_text_extraction', 'feature_translation', 'feature_scene',
  'feature_object_photo', 'feature_object_camera',
  'feature_style_transfer', 'feature_custom_model'
)
foreach ($name in $names) {
  python $helper `
    --input "tmp/imagegen/experience-icons/$name-source.png" `
    --out "entry/src/main/resources/base/media/$name.png" `
    --auto-key border `
    --soft-matte `
    --transparent-threshold 12 `
    --opaque-threshold 220 `
    --despill
  if ($LASTEXITCODE -ne 0) { throw "Chroma removal failed: $name" }
}
```

Then normalize size and transparent padding:

```powershell
@'
from pathlib import Path
from PIL import Image

root = Path("entry/src/main/resources/base/media")
names = [
    "feature_posenet", "feature_segmentation", "feature_classification",
    "feature_gesture", "feature_dance", "feature_poetry",
    "feature_text_extraction", "feature_translation", "feature_scene",
    "feature_object_photo", "feature_object_camera",
    "feature_style_transfer", "feature_custom_model",
]
for name in names:
    path = root / f"{name}.png"
    image = Image.open(path).convert("RGBA")
    image.thumbnail((208, 208), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((256 - image.width) // 2, (256 - image.height) // 2))
    canvas.save(path, optimize=True)
'@ | python -
```

- [ ] **Step 3: 验证尺寸、透明度、内容和唯一性**

```powershell
@'
from hashlib import sha256
from pathlib import Path
from PIL import Image

root = Path("entry/src/main/resources/base/media")
paths = sorted(root.glob("feature_*.png"))
assert len(paths) == 13, len(paths)
hashes = []
for path in paths:
    raw = path.read_bytes()
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    assert image.size == (256, 256), (path, image.size)
    assert alpha.getbbox() is not None, f"{path}: empty alpha"
    assert all(alpha.getpixel(point) == 0 for point in ((0, 0), (255, 0), (0, 255), (255, 255))), f"{path}: opaque corner"
    hashes.append(sha256(raw).hexdigest())
assert len(set(hashes)) == 13, "duplicate icon bytes"
print("validated 13 flat feature icons")
'@ | python -
```

Expected: `validated 13 flat feature icons`.

- [ ] **Step 4: 构建资源并确认映射仍完整**

```powershell
$deveco = 'F:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $deveco 'sdk'
$env:PATH = (Join-Path $deveco 'tools\node') + ';' + (Join-Path $deveco 'jbr\bin') + ';' + $env:PATH
& (Join-Path $deveco 'tools\hvigor\bin\hvigorw.bat') test --no-daemon 2>&1 |
  Tee-Object -FilePath '.superpowers/experience-icons-localunit.log'
if ($LASTEXITCODE -ne 0) { throw 'Hvigor LocalUnit failed' }
if (Select-String -Path '.superpowers/experience-icons-localunit.log' -Pattern 'AssertException|FAILED|ERROR') {
  throw 'LocalUnit output contains a failure marker'
}
```

Expected: output contains `BUILD SUCCESSFUL`; `mapsExperienceFeaturesToGeneratedMedia` passes.

- [ ] **Step 5: 提交图标**

```powershell
git add entry/src/main/resources/base/media/feature_*.png
git diff --cached --check
git commit -m "feat(ui): replace feature icons with flat line set"
```

---

### Task 2: 将功能卡片改为浅边框、无常驻阴影

**Files:**
- Modify: `entry/src/main/ets/common/data/ExperienceLayoutSpec.ets`
- Modify: `entry/src/main/ets/common/components/FeatureCard.ets`
- Test: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces: `experienceCardBorderWidthVp: number`, `experienceCardBorderColor: string`, and `experienceCardPressedScale: number`.
- Consumes: existing `FeatureItem`, `iconMediaResource()`, and `experienceGridCardHeightVp`.

- [ ] **Step 1: 写入失败的卡片视觉契约测试**

Add these imports from `ExperienceLayoutSpec.ets`:

```typescript
experienceCardBorderColor,
experienceCardBorderWidthVp,
experienceCardPressedScale,
```

Add these expectations inside `usesHarmonyExperienceCardGeometry`:

```typescript
expect(experienceCardBorderWidthVp).assertEqual(1);
expect(experienceCardBorderColor).assertEqual('#E8EDF5');
expect(experienceCardPressedScale).assertEqual(0.98);
```

- [ ] **Step 2: 运行测试并确认 RED**

```powershell
$deveco = 'F:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $deveco 'sdk'
$env:PATH = (Join-Path $deveco 'tools\node') + ';' + (Join-Path $deveco 'jbr\bin') + ';' + $env:PATH
& (Join-Path $deveco 'tools\hvigor\bin\hvigorw.bat') test --no-daemon
```

Expected: compile failure because the three new exports do not exist.

- [ ] **Step 3: 添加最小视觉常量**

Add to `ExperienceLayoutSpec.ets`:

```typescript
export const experienceCardBorderWidthVp: number = 1;
export const experienceCardBorderColor: string = '#E8EDF5';
export const experienceCardPressedScale: number = 0.98;
```

- [ ] **Step 4: 更新 FeatureCard**

In `FeatureCard.ets`, import the new constants:

```typescript
import {
  experienceCardBorderColor,
  experienceCardBorderWidthVp,
  experienceCardPressedScale,
  experienceCardRadiusVp,
  experienceGridCardHeightVp
} from '../data/ExperienceLayoutSpec';
```

Replace the current card modifier chain from `.backgroundColor` through `.onClick` with:

```typescript
.backgroundColor(Color.White)
.border({
  width: experienceCardBorderWidthVp,
  color: experienceCardBorderColor,
  radius: experienceCardRadiusVp
})
.clickEffect({
  level: ClickEffectLevel.LIGHT,
  scale: experienceCardPressedScale
})
.onClick(() => this.action(this.item))
```

Do not add a `.shadow()` modifier.

- [ ] **Step 5: 运行测试并确认 GREEN**

Run the Step 2 command again and capture the full output. Expected: `BUILD SUCCESSFUL` and no `AssertException|FAILED|ERROR`.

- [ ] **Step 6: 提交卡片改动**

```powershell
git add entry/src/main/ets/common/data/ExperienceLayoutSpec.ets `
  entry/src/main/ets/common/components/FeatureCard.ets `
  entry/src/test/LocalUnit.test.ets
git diff --cached --check
git commit -m "fix(ui): lighten experience feature cards"
```

---

### Task 3: 改为紧凑头部、单一滚动和轻标题栏吸顶

**Files:**
- Modify: `entry/src/main/ets/common/data/ExperienceHeaderBranding.ets`
- Modify: `entry/src/main/ets/common/data/ExperienceLayoutSpec.ets`
- Modify: `entry/src/main/ets/common/components/ExperienceHeader.ets`
- Modify: `entry/src/main/ets/pages/ExperiencePage.ets`
- Test: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces: `experienceStickyTitleHeightVp`, `experienceStickyTitleThresholdVp`, and `experienceStickyTitleVisible(scrollOffsetVp)`.
- Consumes: `visibleExperienceSections`, `ExperienceHeader`, `FeatureCard`, `experienceGridHeightVp()`, and the existing route-opening callback.

- [ ] **Step 1: 写入失败的滚动边界测试**

Replace the old immersive-header and overlap imports with:

```typescript
experienceStickyTitleHeightVp,
experienceStickyTitleThresholdVp,
experienceStickyTitleVisible,
```

Replace `usesImmersiveHarmonyExperienceHeaderHeight` with:

```typescript
it('usesCompactHarmonyExperienceHeaderAndStickyTitle', 0, () => {
  expect(experienceHeaderHeightVp).assertEqual(132);
  expect(experienceStickyTitleHeightVp).assertEqual(56);
  expect(experienceStickyTitleThresholdVp).assertEqual(76);
  expect(experienceStickyTitleVisible(75)).assertFalse();
  expect(experienceStickyTitleVisible(76)).assertTrue();
  expect(experienceStickyTitleVisible(132)).assertTrue();
});
```

Remove these old expectations from `usesHarmonyExperienceCardGeometry`:

```typescript
expect(experienceContentTopRadiusVp).assertEqual(28);
expect(experienceContentOverlapVp).assertEqual(24);
expect(experienceHeaderHeightVp - experienceContentOverlapVp).assertEqual(152);
```

- [ ] **Step 2: 运行测试并确认 RED**

Run the Task 2 Step 2 Hvigor command.

Expected: compile failure for missing sticky-title exports and/or assertion failure because the header is still `176`.

- [ ] **Step 3: 实现可测试的滚动契约**

Replace `ExperienceHeaderBranding.ets` with:

```typescript
export const experienceHeaderHeightVp: number = 132;
```

Remove `experienceContentTopRadiusVp` and `experienceContentOverlapVp` from `ExperienceLayoutSpec.ets`, then add:

```typescript
import { experienceHeaderHeightVp } from './ExperienceHeaderBranding';

export const experienceStickyTitleHeightVp: number = 56;
export const experienceStickyTitleThresholdVp: number =
  experienceHeaderHeightVp - experienceStickyTitleHeightVp;

export function experienceStickyTitleVisible(scrollOffsetVp: number): boolean {
  return scrollOffsetVp >= experienceStickyTitleThresholdVp;
}
```

- [ ] **Step 4: 收紧 ExperienceHeader**

Keep the existing `experience_hero_harmony` resource, but update `ExperienceHeader.build()` to:

```typescript
build() {
  Stack() {
    Image($r('app.media.experience_hero_harmony'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
    Row()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 90,
        colors: [['#D91667E8', 0], ['#A0308DF1', 0.56], ['#7068B8FF', 1]]
      })
    Column() {
      Text(appString('experience_head_title'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
      Text(appString('experience_head_subtitle'))
        .fontSize(13)
        .fontColor('#E6FFFFFF')
        .maxLines(2)
        .margin({ top: 6 })
    }
    .width('62%')
    .alignItems(HorizontalAlign.Start)
    .position({ x: 20, y: 28 })
  }
  .width('100%')
  .height(experienceHeaderHeightVp)
}
```

- [ ] **Step 5: 将 ExperiencePage 改为单一 Scroll**

Add state and imports:

```typescript
@State stickyTitleVisible: boolean = false;
```

```typescript
import {
  experienceContentBottomPaddingVp,
  experienceGridColumnGapVp,
  experienceGridHeightVp,
  experienceGridRowGapVp,
  experienceGridSideInsetVp,
  experienceStickyTitleHeightVp,
  experienceStickyTitleVisible
} from '../common/data/ExperienceLayoutSpec';
```

Remove the now-unused import of `experienceHeaderHeightVp` from `ExperienceHeaderBranding.ets`.

Replace `groupTitle()` with a left-aligned title:

```typescript
@Builder
private groupTitle(titleKey: AppStringKey, topMargin: number) {
  Text(appString(titleKey))
    .width('100%')
    .height(30)
    .fontSize(17)
    .fontWeight(FontWeight.Bold)
    .fontColor(AppColor.textPrimary)
    .padding({ left: experienceGridSideInsetVp, right: experienceGridSideInsetVp })
    .margin({ top: topMargin })
}
```

Keep `sectionTitle()` and `openFeature()` unchanged. Add:

```typescript
@Builder
private stickyTitle() {
  Row() {
    Text(appString('experience_head_title'))
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColor.textPrimary)
  }
  .width('100%')
  .height(experienceStickyTitleHeightVp)
  .padding({ left: experienceGridSideInsetVp, right: experienceGridSideInsetVp })
  .alignItems(VerticalAlign.Center)
  .backgroundColor(Color.White)
  .border({ width: { bottom: 1 }, color: '#EDF0F5' })
}
```

Replace `build()` with:

```typescript
build() {
  Stack({ alignContent: Alignment.Top }) {
    Scroll() {
      Column() {
        ExperienceHeader()
        Column() {
          ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {
            Column() {
              if (section.groupTitleKey !== undefined) {
                this.groupTitle(section.groupTitleKey, sectionIndex === 0 ? 18 : 22)
              }
              this.sectionTitle(section.titleKey)
              Grid() {
                ForEach(section.items, (item: FeatureItem) => {
                  GridItem() {
                    FeatureCard({
                      item: item,
                      action: (clicked: FeatureItem) => this.openFeature(clicked)
                    })
                  }
                }, (item: FeatureItem) => item.id)
              }
              .columnsTemplate('1fr 1fr')
              .columnsGap(experienceGridColumnGapVp)
              .rowsGap(experienceGridRowGapVp)
              .height(experienceGridHeightVp(section.items.length))
              .width('100%')
              .padding({
                left: experienceGridSideInsetVp,
                right: experienceGridSideInsetVp
              })
              .margin({ top: 12 })
              .scrollBar(BarState.Off)
              .enableScrollInteraction(false)
            }
            .width('100%')
          }, (section: FeatureSection) => section.id)
        }
        .width('100%')
        .padding({ bottom: experienceContentBottomPaddingVp })
        .backgroundColor(Color.White)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .onScroll((_xOffset: number, yOffset: number) => {
      const visible = experienceStickyTitleVisible(yOffset);
      if (visible !== this.stickyTitleVisible) {
        this.stickyTitleVisible = visible;
      }
    })

    if (this.stickyTitleVisible) {
      this.stickyTitle()
    }
  }
  .width('100%')
  .height('100%')
  .backgroundColor(Color.White)
}
```

This removes both nested scrolling and the rounded overlapping content surface. Do not modify `BottomTabBar.ets`.

- [ ] **Step 6: 运行 LocalUnit 并扫描完整日志**

```powershell
$deveco = 'F:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $deveco 'sdk'
$env:PATH = (Join-Path $deveco 'tools\node') + ';' + (Join-Path $deveco 'jbr\bin') + ';' + $env:PATH
& (Join-Path $deveco 'tools\hvigor\bin\hvigorw.bat') test --no-daemon 2>&1 |
  Tee-Object -FilePath '.superpowers/experience-v2-localunit.log'
if ($LASTEXITCODE -ne 0) { throw 'Hvigor LocalUnit failed' }
if (Select-String -Path '.superpowers/experience-v2-localunit.log' -Pattern 'AssertException|FAILED|ERROR') {
  throw 'LocalUnit output contains a failure marker'
}
```

Expected: `BUILD SUCCESSFUL`; sticky threshold boundary and all existing catalog/route tests pass.

- [ ] **Step 7: 提交滚动与头部**

```powershell
git add entry/src/main/ets/common/data/ExperienceHeaderBranding.ets `
  entry/src/main/ets/common/data/ExperienceLayoutSpec.ets `
  entry/src/main/ets/common/components/ExperienceHeader.ets `
  entry/src/main/ets/pages/ExperiencePage.ets `
  entry/src/test/LocalUnit.test.ets
git diff --cached --check
git commit -m "feat(ui): simplify experience header and scrolling"
```

---

### Task 4: 构建双 ABI HAP 并在 API 24 模拟器验收

**Files:**
- Verify: `entry/build/default/outputs/default/entry-default-unsigned.hap`
- Verify: `entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap`
- Verify: `entry/src/main/ets/common/components/BottomTabBar.ets` remains unchanged.

**Interfaces:**
- Consumes: the thirteen icons, lightweight cards, compact header, and single-scroll Experience page.
- Produces: fresh LocalUnit, dual-ABI HAP, installed emulator build, top screenshot, and scrolled screenshot.

- [ ] **Step 1: 运行最终 LocalUnit**

Run Task 3 Step 6. Expected: `BUILD SUCCESSFUL` and zero `AssertException|FAILED|ERROR`.

- [ ] **Step 2: 构建并验证双 ABI HAP**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File scripts/build-ai-runtime-acceptance.ps1
```

Expected: exit code `0`; final output includes `Verified AI runtime HAP structure and payload bytes`. The main HAP contains both `arm64-v8a` and `x86_64`.

- [ ] **Step 3: 安装并启动应用**

```powershell
$hdc = 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc list targets
& $hdc install -r '.\entry\build\default\outputs\default\entry-default-unsigned.hap'
if ($LASTEXITCODE -ne 0) { throw 'Main HAP install failed' }
& $hdc shell aa force-stop com.yuhaofeng.mih
& $hdc shell aa start -a EntryAbility -b com.yuhaofeng.mih
if ($LASTEXITCODE -ne 0) { throw 'EntryAbility launch failed' }
```

Expected: one API 24 emulator target, install success, and `EntryAbility` visible.

- [ ] **Step 4: 验证初始状态**

检查：

- 紧凑头部不与内容重叠。
- 首屏显示双列浅边框卡片，卡片无常驻阴影。
- 图标为 A 风格圆角细线，不出现色键残留、外层底座或模糊边缘。
- 现有圆角悬浮底栏、选中胶囊和图标保持不变。
- 可见入口仍为九个；舞蹈、古诗、场景和自定义模型不出现。

Capture:

```powershell
$hdc = 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc shell snapshot_display -f /data/local/tmp/experience-v2-top.png
& $hdc file recv /data/local/tmp/experience-v2-top.png '.superpowers/experience-v2-top.png'
```

- [ ] **Step 5: 验证下滑状态**

Use Computer Use or native touch debugging to swipe the Experience page upward once, then check:

- 头部完整自然离场。
- 只有 56vp 白色轻标题栏吸顶。
- 页面没有圆角形变、双层滚动、跳动或卡片缩放。
- 上下滑回时标题栏只按 76vp 阈值显隐。
- 最后一行卡片不被底部导航遮挡。

Capture:

```powershell
$hdc = 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc shell snapshot_display -f /data/local/tmp/experience-v2-scrolled.png
& $hdc file recv /data/local/tmp/experience-v2-scrolled.png '.superpowers/experience-v2-scrolled.png'
```

- [ ] **Step 6: 逐项点击九个可见入口**

For PoseNet, Portrait Segmentation, Image Classification, Gesture Recognition, Text Extraction, Text Translation, Object Detection (Photo), Object Detection (Real-time), and Style Transfer:

1. Tap the complete card.
2. Confirm the expected feature page opens.
3. Return to Experience.
4. Confirm the list returns without a crash and remains scrollable.

No inference-quality retest is required for this UI-only task; route opening is the regression boundary.

- [ ] **Step 7: 最终仓库检查**

```powershell
git diff --check
git status --short
git diff --name-only 7fa3ae5..HEAD
```

Expected: no whitespace errors; after the `7fa3ae5` design baseline, only the plan, thirteen icon resources, Experience UI files, and `LocalUnit.test.ets` are changed. If emulator-only polish required an additional ArkTS fix, it must have its own failing check and commit:

```powershell
git commit -m "fix(ui): polish experience emulator layout"
```
