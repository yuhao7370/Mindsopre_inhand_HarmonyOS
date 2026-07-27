# College Tutorial Markdown Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create five editable Markdown files that map one-to-one to the five local quick-start chapters currently rendered in the HAP.

**Architecture:** `CollegeLocalQuickStart.ets` remains the source for this initial export. Each ArkTS section becomes one UTF-8 Markdown file with fixed YAML metadata and headings, so a later pass can map edited text back to the same section without changing order or meaning.

**Tech Stack:** Markdown, YAML front matter, ArkTS source data, PowerShell validation

## Global Constraints

- Create files only under `docs/tutorials/college-hap/`.
- Do not modify ArkTS, page layout, build output, or HAP behavior.
- Use exactly five files named `01-environment.md` through `05-export.md`.
- Preserve every current paragraph, code block, code-block title, and measured result.
- Preserve code content, indentation, commands, and numeric values exactly.
- Save all files as UTF-8.

---

### Task 1: Export the five HAP tutorial chapters

**Files:**
- Read: `entry/src/main/ets/common/data/CollegeLocalQuickStart.ets`
- Create: `docs/tutorials/college-hap/01-environment.md`
- Create: `docs/tutorials/college-hap/02-data.md`
- Create: `docs/tutorials/college-hap/03-network.md`
- Create: `docs/tutorials/college-hap/04-training.md`
- Create: `docs/tutorials/college-hap/05-export.md`

**Interfaces:**
- Consumes: `collegeLocalQuickStartSections` entries with `id`, `step`, `title`, `objective`, `paragraphs`, `codeBlocks`, and `measuredResult`.
- Produces: five Markdown files whose YAML `id` and `step` identify the ArkTS section to update later.

- [ ] **Step 1: Create the target directory and five files**

Use this exact structure in every file. The example shows the first chapter; for the other four files, substitute the mapped metadata and the corresponding ArkTS fields:

````markdown
---
id: environment
step: "01"
title: 先看任务和环境
---

# 先看任务和环境

## 这一节要做什么

先确认这台电脑能跑什么，再用 MindSpore 做一遍经典的手写数字识别。

## 正文

Write every string from the section's `paragraphs` array as a separate Markdown paragraph, preserving source order.

For every item in `codeBlocks`, write its `title` as a level-three heading and its `code` in a fenced `text` block:

```text
python --version
```

## 跑出来的结果

Write the section's complete `measuredResult` value as one paragraph.
````

Use this exact file-to-section mapping:

| File | id | step | title |
| --- | --- | --- | --- |
| `01-environment.md` | `environment` | `01` | `先看任务和环境` |
| `02-data.md` | `data` | `02` | `准备本地数据` |
| `03-network.md` | `network` | `03` | `搭好 LeNet 网络` |
| `04-training.md` | `training` | `04` | `跑训练，看结果` |
| `05-export.md` | `export` | `05` | `导出模型，认清边界` |

- [ ] **Step 2: Check the exported files**

Run:

```powershell
$files = Get-ChildItem 'docs/tutorials/college-hap' -Filter '*.md'
if ($files.Count -ne 5) { throw "Expected 5 Markdown files, found $($files.Count)" }
foreach ($file in $files) {
  $text = Get-Content -Raw -Encoding UTF8 $file.FullName
  foreach ($heading in '# ', '## 这一节要做什么', '## 正文', '## 跑出来的结果') {
    if (-not $text.Contains($heading)) { throw "$($file.Name) is missing $heading" }
  }
}
```

Expected: command exits successfully with no output.

- [ ] **Step 3: Commit the exported chapters**

```powershell
git add -- docs/tutorials/college-hap
git commit -m "docs(college): export editable HAP tutorial chapters"
```

### Task 2: Verify reversible chapter mapping

**Files:**
- Read: `entry/src/main/ets/common/data/CollegeLocalQuickStart.ets`
- Test: `docs/tutorials/college-hap/*.md`

**Interfaces:**
- Consumes: the five Markdown files from Task 1.
- Produces: evidence that every HAP chapter has one editable document and no application source was changed.

- [ ] **Step 1: Validate unique metadata and order**

Run:

```powershell
$expected = @(
  @{ File='01-environment.md'; Id='environment'; Step='01' },
  @{ File='02-data.md'; Id='data'; Step='02' },
  @{ File='03-network.md'; Id='network'; Step='03' },
  @{ File='04-training.md'; Id='training'; Step='04' },
  @{ File='05-export.md'; Id='export'; Step='05' }
)
foreach ($item in $expected) {
  $text = Get-Content -Raw -Encoding UTF8 "docs/tutorials/college-hap/$($item.File)"
  if ($text -notmatch "(?m)^id: $([regex]::Escape($item.Id))$") { throw "Wrong id in $($item.File)" }
  if ($text -notmatch "(?m)^step: `"$($item.Step)`"$") { throw "Wrong step in $($item.File)" }
}
```

Expected: command exits successfully with no output.

- [ ] **Step 2: Confirm the change is documentation-only**

Run:

```powershell
git diff HEAD^ --name-only
```

Expected: only paths under `docs/tutorials/college-hap/` are listed for the export commit.

- [ ] **Step 3: Confirm a clean document diff**

Run:

```powershell
git diff --check HEAD^..HEAD
git status --short
```

Expected: `git diff --check` has no output. Existing unrelated workspace changes may remain, but none are staged by this work.
