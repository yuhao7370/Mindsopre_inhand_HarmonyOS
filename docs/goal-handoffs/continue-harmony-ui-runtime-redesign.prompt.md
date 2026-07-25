# 可直接粘贴到新 `/goal` 的续作 Prompt

```text
继续 HarmonyOS 全界面重设计与运行时功能修复 Goal。

开始执行前，先完整读取主分支交接文档：
E:\Mindsopre_inhand_HarmonyOS\docs\goal-handoffs\2026-07-25-harmony-ui-runtime-redesign-handoff.md

然后进入现有 UI 工作树：
E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS

必须完整读取该工作树的 AGENTS.md、计划：
docs\superpowers\plans\2026-07-24-harmony-feature-runtime-ui.md
以及 Task 14 brief：
E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\.superpowers\sdd\2026-07-24-harmony-feature-runtime-ui\task-14-brief.md

不要从头重做。当前分支应为 ui/harmony-experience-redesign，暂停提交为
8228021c9f7bce698701c812d6f03697f4f219e6
（fix(portrait): modernize segmentation runtime）。

已完成：
- 体验中心、学院页、我的页、原生 Web/二维码/诗词页、应用壳和导航重设计；
- runtime Task 0–13，均已独立复审；Task 10 有 1 项真实人物物理输入证据 parked。

当前进行中：
- Task 14 人像分割。
- 产品代码已修复真实 ImageSource PropertyOptions/async context unwrap 异常；
- 已加入 noSubject/runtimeException 区分和“未检测到人物，请将人物置于取景框内。”状态；
- 快速 guards、mutation、LocalUnit 已通过；
- 用户暂停时，从 8228021 启动的最终 full build 没有取得可引用退出码，必须重跑。

Task 14 仍需完成：
1. 从 committed HEAD 重跑 full build、LocalUnit、双 ABI 和 HAP receipt。
2. 使用 production HAP + HDC 重采 CAMERA 授权、默认前摄、noSubject、Retry、rear、同进程 re-entry、真实 custom picker cancel、save failure。
3. manifest 强绑定所有状态；cancel 前后绑定 composite hash。
4. HAP/receipt 必须复制到 evidence 目录内并不可变，commitSha 必须是最终 Task 14 HEAD。
5. 重新构建独立 3.2x HAP并验证文本完整、背景4横滑和无 overlap。
6. 两个 task14 evidence worktree 必须恢复 clean；不要用 git reset --hard。
7. 安装并恢复 canonical production HAP，clean bundle data，EntryAbility 前台。
8. 重新生成 review package，让新的独立子代理复审。
9. 同一 Task 14 只保留一个提交；修复使用 git commit --amend，不新增第二个功能提交。

当前物理阻塞：
- DevEco 只枚举 lcam001/lcam002，两路都是天花板/墙面，没有人物。
- 已用隔离 OBS portable + repo person fixture 尝试标准 Windows Virtual Camera，但 DevEco 不枚举。
- 不允许用 harness 或直接状态注入伪造 production success。
- 若仍没有人物，按 Task 10 先例保留 1 项 parked；如果我能把人物放到摄像头画面，再补真实成功证据。

Task 14 独立复审 clean 后，再按计划依次完成：
- Task 15 文本翻译
- Task 16 风格迁移
- Task 17 隐藏的自定义模型路由
- Task 18 集成运行时验证

继续遵守：
- 每项功能一个提交；
- 每项功能由实现子代理完成，再由新的独立子代理复审；
- 优先使用 HarmonyOS 原生 HDC 触点、dumpLayout、截图、Hilog；
- 尽量不用 Computer Use；
- 默认和 3.2x 使用独立冻结 HAP/receipt/manifest；
- 不伪造成功态；
- 未经我明确要求，不要提前合并到 master 或 push。

从交接文档“恢复 Goal 后的执行顺序”第 1 步开始继续，并先报告当前 branch、HEAD、status 和是否仍有构建进程。
```
