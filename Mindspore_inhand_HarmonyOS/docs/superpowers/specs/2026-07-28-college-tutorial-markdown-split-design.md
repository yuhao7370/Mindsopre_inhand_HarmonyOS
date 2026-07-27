# 学院教程 Markdown 拆分规格

## 目标

把 HAP 学院页“本地快速入门”的五个章节拆成五篇可独立编辑的 Markdown。用户修改完成后，可以按章节一一回填到 `CollegeLocalQuickStart.ets`，不需要猜测内容归属。

本次只创建本地文档，不修改 ArkTS、页面布局或 HAP。

## 文件结构

文档放在 `docs/tutorials/college-hap/`：

- `01-environment.md`
- `02-data.md`
- `03-network.md`
- `04-training.md`
- `05-export.md`

文件顺序、章节 ID 和当前 HAP 保持一致。

## 单篇格式

每篇文档使用同一结构：

1. YAML 头信息：`id`、`step`、`title`
2. `## 这一节要做什么`
3. `## 正文`
4. 一个或多个带标题的代码块
5. `## 跑出来的结果`

正文段落和代码块顺序必须与当前 ArkTS 数据一致。代码内容原样复制，不改命令、缩进或数值。

## 回填规则

后续同步到 HAP 时，按 `id` 找到对应章节：

- YAML `title` 回填 `title`
- “这一节要做什么”回填 `objective`
- “正文”中的自然段依次回填 `paragraphs`
- 带标题代码块依次回填 `codeBlocks`
- “跑出来的结果”回填 `measuredResult`

Markdown 标题和说明文字只是编辑边界，不进入 HAP 正文。

## 验收

- 五个 ArkTS 章节各有且只有一篇 Markdown。
- 章节 ID、序号和标题一一对应。
- 所有正文、代码块和实测结果均已覆盖。
- 代码块与当前 ArkTS 完全一致。
- 文件为 UTF-8，可直接编辑。
- 本次提交不包含 ArkTS 或 HAP 改动。
