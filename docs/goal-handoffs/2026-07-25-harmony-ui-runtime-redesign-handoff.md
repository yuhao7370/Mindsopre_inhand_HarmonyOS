# HarmonyOS 全界面重设计与运行时修复：暂停交接

更新时间：2026-07-25（Asia/Shanghai）

## 1. 暂停快照

- 原 Goal：
  `接下来你需要把每个界面都重新设计。并且多用子agent复核ui做的有没有缺陷。计划也可以都用子agent复核，不需要等待人工审阅。调试尽量不要用computeruse而是用鸿蒙原生触点+截图`
- 原 Goal 线程：`019f7fd1-7f4c-7f23-90a6-5a0604ebdc4f`
- 暂停时 Goal 状态：`usageLimited`
- 主分支：`master`
- 主分支暂停前 HEAD：`5a11db1b8fbfa8eb4b7294c86c99e65254091908`
- UI 工作分支：`ui/harmony-experience-redesign`
- UI 工作分支暂停 HEAD：`8228021c9f7bce698701c812d6f03697f4f219e6`
- UI 工作树：
  `E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS`
- UI 分支当前没有 upstream，尚未推送。
- 暂停时已中断实现子代理；没有继续执行 Task 14。
- UI 工作树在 `8228021` 上 tracked 状态干净。
- 主工作树原本已有 `.hvigor/`、`output/`、`tmp/`、文档等未跟踪用户文件；交接提交不得包含或删除它们。

## 2. 必须继续遵守的用户约束

1. 每个功能修复完成后只保留一个功能提交。
   - 审查修复使用 `git commit --amend`。
   - 不要为了同一功能新增多个“完成”提交。
2. 每项功能由实现子代理完成后，再由新的独立子代理复审。
3. 不等待人工审阅；子代理可以判断普通阻塞是否允许继续，只有很大的卡点才询问用户。
4. 调试优先使用 HarmonyOS 原生 HDC 触点、`dumpLayout`、截图和 Hilog。
5. 尽量不要使用 Computer Use。
6. 可以创建工作树；不要破坏或覆盖用户已有修改。
7. 默认与 3.2 倍字体必须使用彼此独立、不可变的 HAP、receipt 和证据目录。
8. 测试 harness 只能注入路由、输入或可审计的服务状态，不能伪造生产布局或直接把结果状态改成成功。
9. 自定义模型及相关入口当前应保持隐藏，Task 17 只验证隐藏路由。
10. UI 遵守工作分支根目录 `AGENTS.md`：
    - HarmonyOS 原生风格；
    - 扁平线性图标；
    - 轻边界、无重阴影；
    - 安全区和大字体；
    - 明确的 loading、success、failure、retry；
    - 不依赖颜色作为唯一状态表达。

## 3. 已完成的界面阶段

以下修改都位于 `ui/harmony-experience-redesign`，不要在恢复 Goal 后重做。

### 3.1 体验中心

- 已生成并接入鸿蒙风格 hero 图和扁平功能图标。
- 已隐藏自定义模型入口。
- 已按用户选择完成体验中心新布局：
  - hero 保持稳定；
  - 浅色功能卡片；
  - 卡片边缘减淡；
  - 底部导航保持圆角悬浮；
  - 扁平线性图标；
  - 处理大字体和滚动阈值。
- 已把项目级 UI 设计理念写入工作分支 `AGENTS.md`。

### 3.2 学院页和“我的”页

- 已生成并接入新版扁平图标。
- 已完成学院页和“我的”页 HarmonyOS 原生风格重设计。
- 已补齐字体、图标、占位符和构建守卫。

### 3.3 原生壳页面

- 已完成原生标题栏。
- 已重设计 Web、二维码和诗词海报页面。
- 已处理底部安全区、状态可见性、唯一快照 ID 和大字体。

### 3.4 应用壳、启动和导航

- 敏感权限改为按需请求。
- 隐私同意后直接进入应用。
- 修复隐私入口、启动主题和悬浮底栏可访问性。
- 公开 tab 状态可保持。

## 4. 运行时 UI 计划状态

计划文件：

`E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\docs\superpowers\plans\2026-07-24-harmony-feature-runtime-ui.md`

计划台账：

`E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\.superpowers\sdd\2026-07-24-harmony-feature-runtime-ui\progress.md`

| Task | 功能 | 状态 | 提交 |
|---|---|---|---|
| 0 | 冻结并复审计划 | 完成、复审 clean | `9d004c4` |
| 1 | 共享原生运行时框架 | 完成、复审 clean | `f91214b..fd15c1e` |
| 2 | 静态场景检测 | 完成、复审 clean | `e9ae2b1..7689b0c` |
| 3 | 静态姿态检测 | 完成、复审 clean | `04eca40` |
| 4 | 静态手势检测 | 完成、复审 clean | `42f9aec` |
| 5 | 图片对象检测 | 完成、复审 clean | `f00d234` |
| 6 | 静态人像分割 | 完成、复审 clean | `e00f8b6` |
| 7 | 文本识别 | 完成、复审 clean | `edb04a6` |
| 8 | 实时图像分类 | 完成、复审 clean | `9f18634` |
| 9 | 实时对象检测 | 完成、复审 clean | `0c36a8f` |
| 10 | 实时人像分割 | 完成、1 项物理输入证据 parked | `2dc5da2` |
| 11 | 实时手势识别 | 完成、复审 clean | `ff4a872` |
| 12 | 实时场景检测 | 完成、复审 clean | `1755f90` |
| 13 | 实时骨架检测 | 完成、复审 clean | `48e413c` |
| 14 | 人像分割/背景替换 | 代码已 amend；证据和复审未完成 | `8228021` |
| 15 | 文本翻译 | 未开始 | — |
| 16 | 风格迁移 | 未开始 | — |
| 17 | 隐藏的自定义模型路由 | 未开始 | — |
| 18 | 集成运行时验证 | 未开始 | — |

Task 10 parked 项：

- 产品代码、守卫、默认/3.2 确定性证据、权限、切换、双 ABI 和复审修复均通过。
- 宿主 UVC 画面没有可见人物，所以真实 person-mask/front-rear 对齐证据暂缺。
- 不允许通过改变推理语义伪造这项证据。

## 5. Task 14 当前精确状态

### 5.1 当前提交

- HEAD：`8228021c9f7bce698701c812d6f03697f4f219e6`
- 提交主题：`fix(portrait): modernize segmentation runtime`
- 这是 Task 14 唯一功能提交，后续修复继续 amend，不新增第二个 Task 14 提交。

### 5.2 已实现的产品行为

- 合成前景和背景使用 `ImageFit.Contain`，避免拉伸。
- 背景预设卡有勾选图标，状态不只依赖颜色。
- 自定义背景取消保持原输入。
- 默认前摄、摄像头切换和按路由记忆。
- 独立的状态/重试区域。
- 失败时保留 foreground、background 和 camera input。
- 唯一合成组件 ID。
- 保存 readiness、single-flight、成功/失败反馈。
- 背景列表高度由 144vp 修复为 184vp。
- 3.2 倍字体下背景 1–4 和状态文本已证明不裁切；背景 4 横滑后完整可见。
- production workflow 只请求 CAMERA，不在启动时请求媒体权限。

### 5.3 本轮发现并修复的真实运行时缺陷

生产入口真实执行曾持续显示“人像分割失败”。

原始根因：

- 相机帧和 256×256 PixelMap 转换成功；
- `ImageDecodeOrientation.ts` 调用 `getImageProperty` 时传入了不兼容的 PropertyOptions；
- 设备日志出现：
  - `ImageSourceNapi: PropertyOptions mismatch`
  - `ArkCompiler: Throw error: async context unwrap failed`
  - 栈定位到 `imageRotationDegreesFromImageSource`。

`8228021` 中的修复：

- `imageSource.getImageProperty(image.PropertyKey.ORIENTATION)` 不再传错误 options。
- 修复后真实 HAP 不再出现上述异常。
- 分割结果区分：
  - `noSubject`
  - `runtimeException`
- `noSubject` 映射为本地化生产提示：
  `未检测到人物，请将人物置于取景框内。`
- `noSubject` 仍可通过真实 Retry 重启推理。
- 已补 AppString、base/en_US/zh_CN 资源、LocalUnit 和 mutation guards。
- 删除了 `FeatureWorkflowCatalog` 中 Task 14 引入的不可达 portrait fallback。
- portrait guard 已增加 template-literal decoy，以及“移除真实实现只留 decoy”负例。
- 因新 noSubject Retry 契约改变，实时分割旧守卫也已同步并 amend 到 `8228021`。

### 5.4 已通过的验证

- Task 14 快速契约守卫通过。
- Task 14 mutation fixtures 通过。
- 相关 still/live segmentation 守卫通过。
- DevEco LocalUnit 通过。
- `git diff --check` 通过。
- UI 工作树 tracked 状态干净。

### 5.5 暂停时未能确认的验证

- 从 `8228021` 启动了新的完整 `scripts/build-hap.ps1`。
- 用户要求暂停时实现代理被中断；该次完整构建没有取得可引用的最终退出码。
- 恢复后必须从 `8228021` 重新跑一次完整构建，不能把这次视为通过。

## 6. Task 14 独立复审历史

首次独立复审基线：

- base：`48e413c861a59e9deab247e948a88ee76506a0ce`
- 当时 head：`8b96167569725eeb0a77822d8544bca29494bc7e`
- diff：
  `E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\.superpowers\sdd\2026-07-24-harmony-feature-runtime-ui\review-48e413c..8b96167.diff`

复审结果：

- 生产代码主体通过。
- Spec 未批准，有 3 个 Important 和 2 个 Minor。

Important：

1. 默认成功态来自 harness，而不是用户可达的 production HAP。
2. custom cancel、Retry、rear/reentry、save failure 没有全部被 manifest/checker 强绑定。
3. HAP/receipt 指向可变 build 输出、`commitSha` 为空，两个 evidence worktree 未恢复干净。

Minor：

1. 缺 template-literal 和“只留 decoy”mutation。
2. `FeatureWorkflowCatalog` 有不可达 portrait fallback。

当前处理情况：

- 两个 Minor 已在 `8228021` 修复。
- production 相机授权、前后摄像头、真实运行时异常定位均已用 HDC 执行。
- Important 1 的真实 runtime exception 已修复。
- 当前物理输入仍没有人物，所以 production success 证据只能暂时 parked，不能用 harness success 冒充。
- Important 2、3 的最终 manifest、immutable freeze 和 worktree cleanup 尚未完成。
- 必须生成新的 review package，并让新的独立 reviewer 针对 `48e413c..最终 Task14 HEAD` 复审。

## 7. 物理相机/OBS 尝试

为避免伪造 production success，曾尝试用标准 Windows OBS Virtual Camera 给 DevEco 提供仓库人物 fixture。

- OBS 只在任务专属 portable 副本运行。
- 没有读取或修改用户 OBS 配置。
- 唯一输入：
  `entry\src\ohosTest\resources\rawfile\fixtures\segmentation\person.jpg`
- DevEco 仍只枚举：
  - `lcam002`
  - `lcam001`
- 两路都是物理 UVC 的天花板/墙面，没有枚举 Windows Virtual Camera。
- 因此无法取得真实人物成功态。
- OBS 任务进程已经停止。
- 必要日志和截图已复制到：
  `E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\.superpowers\sdd\emulator-evidence\runtime-ui\task-14-final-pending`
- 隔离副本：
  `E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\.superpowers\sdd\task14-obs-portable\obs-studio`
- 对该精确路径做过 prefix/non-root 安全校验，但宿主策略在执行前阻止递归删除。
- 不要绕过安全策略；恢复时可在获得允许后清理，或把它明确列为临时资源。

## 8. 已作废、不得复用的 Task 14 证据

以下冻结哈希来自旧 harness/旧提交或指向可变 build 输出，复审已判定不合格：

- default：`8e8a42e297ce971c3605e97846d28645a8ff69152ec14a9d2c8fd2d915545822`
- 3.2x：`e6aeb0765246425518561d58c8197f29b8fb527bb605302b82e79ee46c1f3568`

不得把它们改名后继续使用。必须从最终 Task 14 committed HEAD 重新构建和冻结。

## 9. 当前 evidence worktree 状态

以下两个 detached evidence worktree 仍有 harness 修改，复审要求最终恢复干净：

- `E:\Mindsopre_inhand_HarmonyOS\.worktrees\task14-portrait-evidence-default\Mindspore_inhand_HarmonyOS`
- `E:\Mindsopre_inhand_HarmonyOS\.worktrees\task14-portrait-evidence-font32\Mindspore_inhand_HarmonyOS`

两者暂停时均包含：

- modified `EntryAbility.ets`
- modified `FeatureWorkflowCatalog.ets`
- added `RuntimeHarnessState.ets`
- modified `FeatureRuntimePage.ets`
- added `RuntimeHarnessPage.ets`
- modified `main_pages.json`
- modified `LocalUnit.test.ets`
- modified `build-hap.ps1`
- modified `test-live-segmentation-runtime-ui-guard.ps1`

恢复时：

1. 先把 harness diff 和必要证据归档。
2. 不使用 `git reset --hard`。
3. 用精确文件列表恢复 tracked 文件，并删除明确的两个新增 harness 文件。
4. 证明两个 worktree `git status --short` 为空。

## 10. 恢复 Goal 后的执行顺序

1. 切到：
   `E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS`
2. 完整读取：
   - 工作分支 `AGENTS.md`
   - runtime plan
   - Task 14 brief
   - 本交接文档
3. 确认：
   - branch 是 `ui/harmony-experience-redesign`
   - HEAD 是 `8228021` 或其后续 Task 14 amend
   - tracked status 干净
4. 从 committed HEAD 重新运行完整 `scripts/build-hap.ps1`，保留真实退出码。
5. 校验 production HAP：
   - arm64-v8a
   - x86_64
   - receipt 绑定精确 committed HEAD
6. 把 HAP 和 receipt 复制进最终 evidence 目录，manifest 只能引用 evidence 目录内 immutable 文件。
7. 用 production HAP 和原生 HDC 重采并强校验：
   - clean bundle data
   - 首次隐私同意
   - CAMERA 系统授权
   - 默认前摄
   - `noSubject` 明确状态
   - 真实 Retry
   - 切到后摄
   - 同一进程返回并 re-entry 后保持后摄
   - custom picker 打开并 cancel
   - cancel 前后 composite bounds/hash 保持
   - save failure
   - production restore、EntryAbility FOCUSED/FOREGROUND
8. production success：
   - 如果用户可以把人物放到 UVC 画面中，立即补真实成功证据。
   - 如果仍没有人物，按 Task 10 先例保留 1 项 parked。
   - 不允许用直接状态注入或 harness success 冒充。
9. 重新构建独立 3.2x HAP，验证：
   - status 完整
   - 背景 1–4 完整
   - 背景 4 横滑后 `bounds == origBounds`
   - clickable 无重叠
10. manifest 必须：
    - `source=production` 用于 production 状态；
    - `commitSha` 是最终 Task 14 HEAD；
    - HAP/receipt 是 evidence 目录内 immutable 路径；
    - states 包含 rear、re-entry、cancel、retry、save-failure；
    - parked 项有明确物理输入证据。
11. 恢复两个 harness worktree 并证明 clean。
12. 安装 canonical production HAP、clean bundle data、启动 EntryAbility，并记录最终 SHA/status。
13. 如果 tracked 代码需要修复，只 amend Task 14 提交；任何 amend 都使旧 HAP/证据作废。
14. 生成新的 review package，启动新的独立 reviewer。
15. reviewer Critical/Important/Minor 全 clean 后：
    - 在 progress ledger 追加 Task 14 complete；
    - 再进入 Task 15。
16. 顺序完成 Task 15、16、17、18。
17. 最后执行集成回归、双 ABI HAP 和独立复审。
18. 未经用户明确要求，不要提前把 UI 分支合并到 master 或推送。

## 11. DevEco/HDC 环境

- DevEco Studio：
  `F:\Program Files\Huawei\DevEco Studio`
- HDC：
  `F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`
- 模拟器 target：
  `127.0.0.1:5555`
- full build 通常需要 3–6 分钟。
- 避免前台 wrapper 超时：
  - 用隐藏后台进程运行同一 build；
  - stdout、stderr、exit code 写任务专属文件；
  - 只轮询同一 PID；
  - 不因工具 60/120 秒超时重复启动构建。

## 12. 暂停后的分支策略

- 本交接文档保存在 `master`，只用于让新 Goal 恢复上下文。
- 产品/UI 修改仍只在 `ui/harmony-experience-redesign`。
- 不要把交接提交误当成 UI 分支已合并。
- 恢复 Goal 时先进入现有工作树，不要从 master 重新实现。
