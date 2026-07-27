# HarmonyOS 普通功能页 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Web、二维码和诗词海报页重做为已批准的 HarmonyOS 原生轻量 UI，同时保持现有路由、授权、保存、分享和 JavaScript bridge 契约。

**Architecture:** 新增一个只负责标题、返回和可选更多操作的 `NativePageTitleBar`；三个页面继续各自持有业务状态。Web 只增加页面级失败判断，二维码继续复用现有 reducer 和 `SaveButton`，海报只增加单一 action gate 和响应式视觉常量。

**Tech Stack:** HarmonyOS 6.1 / API 24、ArkTS、ArkUI `SymbolGlyph` / `bindSheet` / `SaveButton`、ArkWeb、Hypium LocalUnit、PowerShell source guards、Hvigor、DevEco Studio 模拟器。

## Global Constraints

- 使用白色或浅灰背景、左对齐标题、品牌蓝操作；卡片只允许 `1vp #E8EDF5` 淡边框，不使用常驻阴影。
- 使用系统 `SymbolGlyph`，不新增图片资源，不再使用 Web/二维码/诗词页的 Android 返回位图。
- 所有操作目标至少 `44vp`；标题栏操作和主按钮使用 `48vp`。
- 标题和内容使用 `minHeight` 或内容驱动布局，支持最大 `3.2×` 系统字体。
- 不新增页面 Shell、导航框架、设计系统或通用异步状态机。
- 保持 Web 参数/URL/bridge、二维码 `SaveButton` 授权与 sheet reducer、海报 snapshot/PixelMap/JPEG/ShareKit 契约。
- 每个 Task 独立提交，完成后必须由独立子 agent 做规范和代码质量复核。

---

### Task 1: 原生轻量标题栏与构建守卫

**Files:**
- Create: `entry/src/main/ets/common/components/NativePageTitleBar.ets`
- Create: `scripts/check-native-page-title-bar.ps1`
- Create: `scripts/test-native-page-ui-guard.ps1`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `scripts/build-hap.ps1`
- Modify: `scripts/check-toolbar-back-icon.ps1`
- Delete: `scripts/check-poetry-back-icon.ps1`

**Interfaces:**
- Consumes: `AppColor`, `appString('action_back' | 'action_more')`, system symbols `chevron_backward` and `more`.
- Produces:

```ts
@Component
export struct NativePageTitleBar {
  title: string = '';
  showMore: boolean = false;
  onBack: () => void = () => {};
  onMore: () => void = () => {};
}
```

- [ ] **Step 1: 写入失败的标题栏 source guard**

创建 `scripts/check-native-page-title-bar.ps1`，检查目标文件存在。用普通清理视图定位组件形状，用保留字符串字面量的同偏移视图核对系统资源名，要求：

```powershell
$requiredPatterns = @(
  "SymbolGlyph\(\`$r\('sys\.symbol\.chevron_backward'\)\)",
  "SymbolGlyph\(\`$r\('sys\.symbol\.more'\)\)",
  '\.width\(48\)',
  '\.height\(48\)',
  '\.maxLines\(2\)',
  "appString\('action_back'\)",
  "appString\('action_more'\)"
)
```

同时拒绝 `app.media.icon_back`、`app.media.back`、固定标题栏 `.height(56)`。脚本读取并复用 `scripts/arkts-source-guard.ps1` 的注释/字符串清理函数，避免注释伪装。把检查实现为 `Assert-NativePageTitleBarContract([string]$Source)`，按 `build()` slice 关联验证每个 symbol、它自己的 `48×48vp` 容器、可访问性名称和点击回调。

创建 `scripts/test-native-page-ui-guard.ps1`，用内存 fixture 验证：

- 当前正确组件接受；
- 返回热区改成 `40vp` 拒绝；
- 删除 `onBack()` 拒绝；
- 删除更多操作的 `onMore()` 拒绝；
- 注释或字符串中的正确代码不能满足守卫。

- [ ] **Step 2: 运行 guard，确认 RED**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
```

Expected: 非零退出，消息包含 `Missing NativePageTitleBar.ets`。

- [ ] **Step 3: 增加文案和最小标题栏**

在 base/zh_CN 增加：

```json
{ "name": "action_more", "value": "更多" }
```

en_US 使用 `{ "name": "action_more", "value": "More" }`。

在 `AppStrings.ets` 的 union、key array 和 switch 中加入 `action_more`。

`NativePageTitleBar.ets` 使用以下结构，不增加 BuilderParam 或配置对象：

```ts
import { appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

@Component
export struct NativePageTitleBar {
  title: string = '';
  showMore: boolean = false;
  onBack: () => void = () => {};
  onMore: () => void = () => {};

  build() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(24)
          .fontColor([AppColor.textPrimary])
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .accessibilityText(appString('action_back'))
      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)
      .onClick(() => this.onBack())

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(2)

      if (this.showMore) {
        Row() {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize(24)
            .fontColor([AppColor.textPrimary])
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .accessibilityText(appString('action_more'))
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => this.onMore())
      } else {
        Blank().width(48)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .backgroundColor(AppColor.cardBackground)
  }
}
```

- [ ] **Step 4: 更新旧守卫与 build wiring**

- `check-toolbar-back-icon.ps1` 只保留尚未重做的 `FeatureRuntimePage` 旧图标检查，不再检查 Web/QR。
- 删除 `check-poetry-back-icon.ps1` 及其 `build-hap.ps1` 调用。
- 在 `build-hap.ps1` 中调用 `test-native-page-ui-guard.ps1` 和 `check-native-page-title-bar.ps1`。

- [ ] **Step 5: 运行 GREEN 和完整 LocalUnit**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& .\scripts\check-toolbar-back-icon.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: 标题栏 guard、mutation self-test 和 runtime toolbar guard 成功；LocalUnit 输出 `BUILD SUCCESSFUL` 且无 assertion failure。

- [ ] **Step 6: 提交**

```powershell
git add -- `
  entry/src/main/ets/common/components/NativePageTitleBar.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  scripts/build-hap.ps1 `
  scripts/check-native-page-title-bar.ps1 `
  scripts/test-native-page-ui-guard.ps1 `
  scripts/check-toolbar-back-icon.ps1 `
  scripts/check-poetry-back-icon.ps1
git commit -m "feat(ui): add native page title bar"
```

---

### Task 2: WebPage 原生标题、稳定进度和失败重试

**Files:**
- Create: `entry/src/main/ets/features/web/WebPageLoadState.ets`
- Modify: `entry/src/main/ets/pages/WebPage.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `scripts/check-native-page-title-bar.ps1`
- Modify: `scripts/test-native-page-ui-guard.ps1`

**Interfaces:**
- Consumes: `NativePageTitleBar`, existing `WebDestination`, `PoetryJavascriptBridge`, `WebviewController.refresh()`.
- Produces:

```ts
export function webPageFailedAfterRequest(currentFailed: boolean, isMainFrame: boolean): boolean;
```

- [ ] **Step 1: 写失败的纯状态测试和页面 guard**

在 `LocalUnit.test.ets` 导入 `webPageFailedAfterRequest` 并增加：

```ts
it('webPageOnlyTreatsMainDocumentErrorsAsPageFailure', 0, () => {
  expect(webPageFailedAfterRequest(false, false)).assertFalse();
  expect(webPageFailedAfterRequest(false, true)).assertTrue();
  expect(webPageFailedAfterRequest(true, false)).assertTrue();
});
```

扩展 `check-native-page-title-bar.ps1`，用 `WebPage.build()` 和 `webContent()` method slice 要求 `NativePageTitleBar`、`router.back()`、固定存在的 `Progress` 槽、`onErrorReceive`、`isMainFrame()` 和 `webController.refresh()`，并拒绝 `app.media.icon_back`、`app.media.back`。

扩展 mutation self-test：删除 Web 的真实标题栏调用、把 Progress 放回条件分支、删除 `isMainFrame()` 或 `refresh()` 时均须拒绝；注释中的同名调用不能满足守卫。

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: guard 因 Web 仍使用旧标题栏失败；LocalUnit 因缺少导出失败。

- [ ] **Step 3: 实现页面级失败判断**

创建 `WebPageLoadState.ets`：

```ts
export function webPageFailedAfterRequest(currentFailed: boolean, isMainFrame: boolean): boolean {
  return currentFailed || isMainFrame;
}
```

新增文案：

```json
{ "name": "web_load_failed", "value": "页面加载失败" },
{ "name": "web_retry", "value": "重试" }
```

en_US 对应 `Page failed to load`、`Retry`；三份 locale 同步后再更新 `AppStrings.ets`。

并同步 `AppStrings.ets`。

- [ ] **Step 4: 最小改造 WebPage**

增加：

```ts
@State loadFailed: boolean = false;

private handleWebError(event: OnErrorReceiveEvent): void {
  this.loadFailed = webPageFailedAfterRequest(this.loadFailed, event.request.isMainFrame());
}

private retryWebPage(): void {
  this.loadFailed = false;
  this.progress = 0;
  this.webController.refresh();
}
```

三个现有 `Web` 分支都保留，移除只适用于 `Column` 的 `.layoutWeight(1)`，统一改为 `.height('100%')`，并给每个分支追加相同的：

```ts
.onPageBegin(() => {
  this.loadFailed = false;
})
.onErrorReceive((event: OnErrorReceiveEvent) => {
  this.handleWebError(event);
})
```

页面结构改为：

```ts
Column() {
  NativePageTitleBar({
    title: appString(this.titleKey),
    onBack: () => router.back()
  })

  Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
    .width('100%')
    .height(2)
    .color(AppColor.accent)
    .backgroundColor(Color.Transparent)
    .opacity(this.progress > 0 && this.progress < 100 && !this.loadFailed ? 1 : 0)

  Stack() {
    this.webContent()
    if (this.loadFailed) {
      Column() {
        Text(appString('web_load_failed'))
        Button(appString('web_retry'))
          .height(48)
          .onClick(() => this.retryWebPage())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppColor.pageBackground)
    }
  }
  .layoutWeight(1)
  .width('100%')
}
```

- [ ] **Step 5: 运行 GREEN**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: guard 和 mutation self-test 通过；LocalUnit `BUILD SUCCESSFUL`。

- [ ] **Step 6: 提交**

```powershell
git add -- `
  entry/src/main/ets/features/web/WebPageLoadState.ets `
  entry/src/main/ets/pages/WebPage.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/test/LocalUnit.test.ets `
  scripts/check-native-page-title-bar.ps1 `
  scripts/test-native-page-ui-guard.ps1
git commit -m "feat(ui): redesign native web page"
```

---

### Task 3: QrCodePage 原生 sheet 和可见保存状态

**Files:**
- Modify: `entry/src/main/ets/pages/QrCodePage.ets`
- Modify: `entry/src/main/ets/features/qrcode/QrCodeActionSheetState.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `scripts/check-native-page-title-bar.ps1`
- Modify: `scripts/test-native-page-ui-guard.ps1`

**Interfaces:**
- Consumes: `NativePageTitleBar(showMore: true)`、`QrCodeActionSheetState`、`SaveButton`、`QrCodeSaveService`。
- Produces:

```ts
export function qrCodeSheetActionForNativeDismiss(pressedBack: boolean): QrCodeSaveSheetAction;
```

以及原 reducer 语义不变的原生 `bindSheet` UI。

- [ ] **Step 1: 扩展失败 guard**

要求 `QrCodePage.ets` 包含：

```powershell
'NativePageTitleBar\s*\('
'showMore\s*:\s*true'
'\.bindSheet\s*\('
'SheetSize\.FIT_CONTENT'
'SaveButton\s*\('
'\.enabled\(\s*!this\.saveInFlight\s*\)'
'qrCodeSheetActionForNativeDismiss\s*\('
'DismissReason\.PRESS_BACK'
'\.constraintSize\(\{\s*maxWidth:\s*300'
'appString\(''image_save_failed''\)'
```

并拒绝旧 `Text('...')`、全屏 `#66000000` 遮罩和 `app.media.icon_back`。

在 `LocalUnit.test.ets` 增加：

```ts
it('qrCodeMapsNativeSheetDismissReasonsToExistingReducerActions', 0, () => {
  expect(qrCodeSheetActionForNativeDismiss(true)).assertEqual('back');
  expect(qrCodeSheetActionForNativeDismiss(false)).assertEqual('backdrop');
});
```

mutation self-test 增加：删除 QR 的真实标题栏调用、删除 `onMore`、把 `SaveButton` 的 enabled 绑定改为常量、删除 dismiss reason 映射时均须拒绝。

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: guard 因 QR 仍使用旧标题栏和自绘 sheet 失败；LocalUnit 因缺少 dismiss 映射导出失败。

- [ ] **Step 3: 增加进行中文案**

base/zh_CN 和 `AppStrings.ets` 增加：

```json
{ "name": "qr_save_in_progress", "value": "正在保存二维码…" }
```

en_US 使用 `Saving QR code…`。

在 `QrCodeActionSheetState.ets` 增加：

```ts
export function qrCodeSheetActionForNativeDismiss(pressedBack: boolean): QrCodeSaveSheetAction {
  return pressedBack ? 'back' : 'backdrop';
}
```

- [ ] **Step 4: 用 bindSheet 替换全屏遮罩**

标题栏：

```ts
NativePageTitleBar({
  title: appString(this.titleKey),
  showMore: true,
  onBack: () => router.back(),
  onMore: () => this.applySaveSheetAction('open')
})
```

二维码区域：

```ts
Column() {
  Image($r('app.media.my_qr_code'))
    .width('100%')
    .aspectRatio(1)
    .objectFit(ImageFit.Contain)
    .accessibilityText(appString(this.titleKey))
}
.width('78%')
.constraintSize({ maxWidth: 300 })
.padding(16)
.backgroundColor(AppColor.cardBackground)
.border({ width: 1, color: '#E8EDF5', radius: 12 })
```

sheet Builder 只包含 `SaveButton`、进行中/失败文案和取消按钮。`SaveButton` 必须绑定 `.enabled(!this.saveInFlight)`；失败时重新启用并继续显示，成功时现有 reducer 关闭：

```ts
if (this.saveInFlight) {
  Text(appString('qr_save_in_progress'))
} else if (this.statusKey === 'image_save_failed') {
  Text(appString('image_save_failed'))
}
```

在根 `Column` 上绑定：

```ts
.bindSheet(this.showSaveSheet, this.saveActionSheet(), {
  height: SheetSize.FIT_CONTENT,
  showClose: false,
  onWillDismiss: (action: DismissSheetAction) => {
    this.applySaveSheetAction(
      qrCodeSheetActionForNativeDismiss(action.reason === DismissReason.PRESS_BACK)
    );
    action.dismiss();
  },
  onDisappear: () => {
    this.showSaveSheet = false;
  }
})
```

删除页面级 `onBackPress()` 覆盖，避免它与原生 sheet 的 dismiss 回调重复消费系统返回。`DismissReason.PRESS_BACK` 映射到 reducer 的 `back`，触摸遮罩、下滑和其他交互关闭映射到 `backdrop`；取消按钮仍显式发送 `cancel`。

- [ ] **Step 5: 运行 reducer 测试、guard 和完整 LocalUnit**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: guard 通过；现有 `qrCodeSaveSheetMatchesAndroidMoreSaveCancelFlow`、`qrCodeSaveStartsOnlyWhenNoSaveIsAlreadyInFlight` 和完整 LocalUnit 通过。

- [ ] **Step 6: 提交**

```powershell
git add -- `
  entry/src/main/ets/pages/QrCodePage.ets `
  entry/src/main/ets/features/qrcode/QrCodeActionSheetState.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/test/LocalUnit.test.ets `
  scripts/check-native-page-title-bar.ps1 `
  scripts/test-native-page-ui-guard.ps1
git commit -m "feat(ui): redesign native qr code page"
```

---

### Task 4: PoetryPosterPage 响应式海报和单次操作

**Files:**
- Modify: `entry/src/main/ets/pages/PoetryPosterPage.ets`
- Modify: `entry/src/main/ets/services/poetry/PoetryPosterService.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `scripts/check-native-page-title-bar.ps1`
- Modify: `scripts/test-native-page-ui-guard.ps1`

**Interfaces:**
- Consumes: `NativePageTitleBar`、现有 snapshot/save/share 服务。
- Produces:

```ts
export function shouldStartPoetryPosterAction(actionInFlight: boolean): boolean;
```

以及更新后的：

```ts
poetryPosterVisualSpec.poemTextPaddingVp === 20
poetryPosterVisualSpec.posterMinHeightVp === 520
poetryPosterVisualSpec.posterMaxWidthVp === 420
```

- [ ] **Step 1: 写失败测试与 guard**

在 `LocalUnit.test.ets` 增加：

```ts
it('poetryPosterStartsOnlyOneSaveOrShareAction', 0, () => {
  expect(shouldStartPoetryPosterAction(false)).assertTrue();
  expect(shouldStartPoetryPosterAction(true)).assertFalse();
});
```

把旧视觉断言更新为：

```ts
expect(poetryPosterVisualSpec.poemTextPaddingVp).assertEqual(20);
expect(poetryPosterVisualSpec.posterMinHeightVp).assertEqual(520);
expect(poetryPosterVisualSpec.posterMaxWidthVp).assertEqual(420);
```

扩展 guard，按 `posterCard()`、`posterPixelMap()`、`savePoster()`、`sharePoster()` 和 `build()` method slice 验证：

- 共享标题栏；
- `poem_frame` 与 `poem_bg` 都使用 `ImageSize.Cover`，并拒绝 `ImageSize.FILL`；
- 无 `.lineHeight(28)`；
- 单列按钮且两个按钮最小 `48vp`；
- `savePoster()` 和 `sharePoster()` 都先检查 `shouldStartPoetryPosterAction`，并在各自 `.finally()` 中恢复 `this.actionInFlight = false`；
- `posterCard()` 内包含唯一的 `.id(poetryPosterComponentId)`，且不包含 `SaveButton`、分享按钮或状态文案；
- `posterPixelMap()` 保留 `componentSnapshot.get(poetryPosterComponentId, { waitUntilRenderFinished: true })`；
- 保存路径保留 `withCallerOwnedPixelMap`；
- 拒绝 `app.media.back` 和并排 `width('48%')`。

mutation self-test 增加：把任一 `ImageSize.Cover` 改回 `ImageSize.FILL`、把 snapshot id 移到操作区、把保存/分享按钮移入 `posterCard()`、删除 `waitUntilRenderFinished`、删除任一 action 方法的 `.finally()` 释放时均须拒绝。

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
```

Expected: guard 因旧页面失败；LocalUnit 因缺少 action gate/新字段失败。

- [ ] **Step 3: 更新最小视觉常量和 action gate**

`PoetryPosterVisualSpec` 增加 `posterMinHeightVp`、`posterMaxWidthVp`，并设置：

```ts
poemTextPaddingVp: 20,
posterMinHeightVp: 520,
posterMaxWidthVp: 420
```

增加：

```ts
export function shouldStartPoetryPosterAction(actionInFlight: boolean): boolean {
  return !actionInFlight;
}
```

新增文案：

```json
{ "name": "poem_save_in_progress", "value": "正在保存海报…" },
{ "name": "poem_share_in_progress", "value": "正在准备分享…" }
```

en_US 对应 `Saving poster…`、`Preparing share…`。

- [ ] **Step 4: 改造海报布局和操作状态**

页面增加：

```ts
@State actionInFlight: boolean = false;
```

`savePoster()` 和 `sharePoster()` 都先检查 `shouldStartPoetryPosterAction`，开始时设 `actionInFlight = true` 和相应进行中文案，Promise 结束在 `.finally()` 中恢复 `false`。

海报：

- 删除固定 `.lineHeight(28)`；
- `poem_frame` 和 `poem_bg` 使用 `ImageSize.Cover`；
- 使用 `poetryPosterVisualSpec.poemTextPaddingVp`；
- 根海报 `.constraintSize({ minHeight: 520, maxWidth: 420 })` 并居中；
- 署名颜色从 `textMuted` 改为 `textSecondary`；
- `poetryPosterComponentId` 仍只包住海报，不包含按钮和状态。

操作区改为：

```ts
Column({ space: AppSpacing.md }) {
  SaveButton(...)
    .width('100%')
    .height(48)
    .enabled(!this.actionInFlight)
  Button(appString('poem_share_poster'))
    .width('100%')
    .height(48)
    .enabled(!this.actionInFlight)
  if (this.statusKey !== 'empty') {
    Text(appString(this.statusKey))
  }
}
```

- [ ] **Step 5: 运行 GREEN、HAP 和 diff check**

Run:

```powershell
& .\scripts\check-native-page-title-bar.ps1
& .\scripts\test-native-page-ui-guard.ps1
& cmd.exe /d /c '"F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default --no-daemon'
& .\scripts\build-hap.ps1
git diff --check
```

Expected: guard、LocalUnit 和 HAP 构建成功；主 HAP 校验 `arm64-v8a,x86_64`；无 whitespace error。

- [ ] **Step 6: 提交**

```powershell
git add -- `
  entry/src/main/ets/pages/PoetryPosterPage.ets `
  entry/src/main/ets/services/poetry/PoetryPosterService.ets `
  entry/src/main/ets/common/i18n/AppStrings.ets `
  entry/src/main/resources/base/element/string.json `
  entry/src/main/resources/en_US/element/string.json `
  entry/src/main/resources/zh_CN/element/string.json `
  entry/src/test/LocalUnit.test.ets `
  scripts/check-native-page-title-bar.ps1 `
  scripts/test-native-page-ui-guard.ps1
git commit -m "feat(ui): redesign native poetry poster"
```

---

## 阶段验收

四个 Task 全部通过独立复核后：

1. 运行完整 LocalUnit、`scripts/build-hap.ps1` 和 `scripts/build-ai-runtime-acceptance.ps1`。
2. 确认 main 与 ohosTest HAP 都包含 `arm64-v8a,x86_64`。
3. 在 DevEco 模拟器以默认字体和 `3.2×` 验证 Web、二维码、海报。
4. Web 验证本地/远端/失败重试/诗词 bridge；二维码验证原生 sheet、失败重试与单次保存；海报验证长短诗、snapshot 边界、单次保存/分享。
5. 生成整阶段 review package，由独立子 agent 做最终 UI、业务契约和代码质量复核。
