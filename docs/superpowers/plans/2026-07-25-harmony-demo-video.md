# HarmonyOS Demo Video Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce an editable ChatCut project and a sub-five-minute 1080p H.264 MP4 that demonstrates the HarmonyOS app's working core features without camera-dependent inference.

**Architecture:** HDC drives the emulator and uploads deterministic gallery fixtures. An isolated OBS portable instance records the emulator window into short source clips. ChatCut keeps those originals on an editable multi-track timeline, adds titles and one music track, verifies composed frames, and performs the final MP4 export.

**Tech Stack:** HarmonyOS HDC, DevEco emulator, OBS Studio portable, ChatCut MCP, ChatCut Motion Graphics, ChatCut music generation, MP4/H.264.

## Global Constraints

- Final canvas is 1920×1080, 16:9, 30fps.
- Final format is H.264 MP4.
- Final duration is under 5 minutes; target is about 4 minutes 20 seconds.
- Use subtitles and instrumental music only; no voiceover.
- Camera-dependent inference is not recorded.
- Use gallery fixtures and only show real successful results.
- All emulator actions use HDC touch, text input, `dumpLayout`, and screenshots.
- Do not use Computer Use.
- Keep the product worktree on `ui/harmony-experience-redesign` unchanged.
- Keep original source clips editable in ChatCut; do not locally flatten the edit.
- Do not expose desktop paths, terminals, private windows, or user media.

---

### Task 1: Preflight the app and demo inputs

**Files:**
- Read: `docs/superpowers/specs/2026-07-25-harmony-demo-video-design.md`
- Read: `.worktrees/harmony-ui-redesign/Mindspore_inhand_HarmonyOS/AGENTS.md`
- Read: `.worktrees/harmony-ui-redesign/Mindspore_inhand_HarmonyOS/entry/build/default/outputs/default/entry-default-unsigned.hap`
- Create outside git: `.superpowers/demo-video/2026-07-25/preflight/`

**Interfaces:**
- Consumes: committed UI worktree `ui/harmony-experience-redesign@8228021`.
- Produces: installed app, uploaded gallery fixtures, deterministic HDC route/action notes, and preflight screenshots.

- [ ] **Step 1: Confirm branch, HAP, emulator, and recording processes**

Run:

```powershell
git -C E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS status --short --branch
git -C E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS log -1 --format="%H%n%s"
Get-FileHash -Algorithm SHA256 E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\entry\build\default\outputs\default\entry-default-unsigned.hap
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
Get-Process obs64 -ErrorAction SilentlyContinue
```

Expected:

- branch is `ui/harmony-experience-redesign`;
- tracked status is empty;
- target `127.0.0.1:5555` is present;
- no stale OBS recording process is running.

- [ ] **Step 2: Verify the HAP receipt matches the paused product commit**

Read:

```powershell
Get-Content -Raw -Encoding UTF8 E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\entry\build\default\outputs\default\entry-default-unsigned.hap.runtime-ui-build.json
```

Accept the existing HAP only if its receipt names the same product HEAD and the file hash matches the receipt. Otherwise run the existing `scripts\build-hap.ps1` once in a hidden background process, retain stdout/stderr/exit code, and use only an exit-0 output.

- [ ] **Step 3: Install and start the app**

Run:

```powershell
$hdc='F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hap='E:\Mindsopre_inhand_HarmonyOS\.worktrees\harmony-ui-redesign\Mindspore_inhand_HarmonyOS\entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc -t 127.0.0.1:5555 install -r $hap
& $hdc -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.yuhaofeng.mih
& $hdc -t 127.0.0.1:5555 shell aa dump -l
```

Expected: `EntryAbility` reaches foreground.

- [ ] **Step 4: Upload gallery fixtures**

Use `hdc file send` for:

```text
classification/grace_hopper.jpg
classification/yellow_labrador.jpg
gesture/four.jpg
segmentation/person.jpg
ocr/chinese_sentence.png
```

Destination:

```text
/storage/media/100/local/files/Docs/Download/
```

Then open the system gallery once with HDC and verify the files appear. If the emulator indexes uploaded images directly into Photos, use that public picker view instead of copying the files again.

- [ ] **Step 5: Build one deterministic HDC sequence per segment**

For each segment, use `dumpLayout` to record clickable bounds and save:

```text
overview.txt
object-or-scene.txt
classification-or-scene.txt
pose.txt
gesture.txt
segmentation.txt
ocr.txt
translation.txt
style-poetry.txt
college-me.txt
```

Each note contains only:

- route entry click;
- gallery choice;
- wait condition text;
- result-state text;
- back-navigation click.

- [ ] **Step 6: Run a no-recording rehearsal**

Execute every sequence once. Save a screenshot of each result with:

```powershell
& $hdc -t 127.0.0.1:5555 shell snapshot_display -f /data/local/tmp/demo-check.jpeg
$segment='overview'
& $hdc -t 127.0.0.1:5555 file recv /data/local/tmp/demo-check.jpeg "E:\Mindsopre_inhand_HarmonyOS\.superpowers\demo-video\2026-07-25\preflight\$segment.jpeg"
```

Expected: all selected segments show real success results and no error dialog. If image classification is camera-only, replace it with gallery scene detection as specified.

### Task 2: Record clean source clips with isolated OBS

**Files:**
- Reuse outside git: `.worktrees/harmony-ui-redesign/Mindspore_inhand_HarmonyOS/.superpowers/sdd/task14-obs-portable/obs-studio/`
- Create outside git: `.superpowers/demo-video/2026-07-25/raw/`
- Create outside git: `.superpowers/demo-video/2026-07-25/obs-logs/`

**Interfaces:**
- Consumes: deterministic HDC sequences and installed app from Task 1.
- Produces: one original video per storyboard segment, with no editorial pre-render.

- [ ] **Step 1: Verify OBS isolation**

Start only the portable copy and verify its log includes `Portable mode: true`. Use a new profile `HarmonyDemo` and collection `HarmonyDemoCapture`. Do not read or modify `%APPDATA%\obs-studio`.

- [ ] **Step 2: Configure the capture source**

Use one OBS window-capture source targeting the DevEco emulator window. Set:

```text
Canvas: 1320×2868 or the emulator viewport's exact native bounds
Output: same as canvas
FPS: 30
Recording directory: E:\Mindsopre_inhand_HarmonyOS\.superpowers\demo-video\2026-07-25\raw
Audio tracks: none
```

Crop window chrome so the recorded pixels contain only the device viewport.

- [ ] **Step 3: Verify a five-second capture**

Record five seconds of the experience center, stop recording cleanly, and inspect three source frames locally. Expected:

- no desktop or terminal pixels;
- full phone viewport;
- readable UI;
- no cursor;
- 30fps source.

Delete only this named test clip after its exact path is verified to remain inside the `raw` directory.

- [ ] **Step 4: Record the ten storyboard segments**

Record these files separately:

```text
01-overview
02-object-or-scene
03-classification-or-scene
04-pose
05-gesture
06-segmentation
07-ocr
08-translation
09-style-poetry
10-college-me
```

For each file:

1. navigate to its clean start state;
2. start OBS recording;
3. run the HDC sequence;
4. hold the successful result for 2–3 seconds;
5. stop OBS recording cleanly;
6. record the filename, duration, route, fixture, and result text.

- [ ] **Step 5: Inspect source clips**

Use local source-frame inspection only. Check the first, middle, and last frame of every clip. Re-record a clip if it contains:

- a system error;
- picker search or irrelevant gallery browsing;
- a wrong result;
- a private desktop region;
- an unreadable transient state.

### Task 3: Create ChatCut project and import originals

**Files:**
- Read: all videos in `.superpowers/demo-video/2026-07-25/raw/`
- Use ChatCut project: `MindSpore掌中宝 HarmonyOS 作品演示`

**Interfaces:**
- Consumes: the ten original OBS source clips.
- Produces: a targeted ChatCut project with cloud-readable original assets and a 1920×1080/30fps timeline.

- [ ] **Step 1: Create and target a fresh ChatCut project**

Call ChatCut `create_project` with:

```text
MindSpore掌中宝 HarmonyOS 作品演示
```

Open the returned Chinese-localized editor URL in the in-app browser and retain the returned `projectId`.

- [ ] **Step 2: Import source clips in batches of at most four**

For each batch:

1. call `import_media` with `action=create_session`;
2. run the plugin-provided `upload-media.mjs` once with the returned token, endpoint, bundled Node path, and up to four exact local paths;
3. retain each returned `assetId`;
4. wait for upload readiness before cloud rendering.

Do not call local FFmpeg to pre-trim, concatenate, caption, or flatten the clips.

- [ ] **Step 3: Create the timeline**

Create or configure one timeline:

```text
Name: 作品演示成片
Width: 1920
Height: 1080
FPS: 30
```

- [ ] **Step 4: Verify imported assets**

Use staged `read_project` asset discovery and targeted asset reads. Expected: all ten original clips are present, video-typed, and cloud-readable.

### Task 4: Assemble the review cut

**Files:**
- Modify: ChatCut timeline `作品演示成片`

**Interfaces:**
- Consumes: imported asset IDs and storyboard timing.
- Produces: a silent structural cut under 4 minutes 40 seconds.

- [ ] **Step 1: Add clips in storyboard order**

Place the ten clips sequentially on one main video track. Use source trims to remove:

- OBS startup/stop frames;
- repeated picker waiting;
- redundant back navigation;
- model waits longer than needed to prove execution.

Keep at least one visible input action and one visible result state per function.

- [ ] **Step 2: Fit the portrait emulator into the landscape canvas**

Keep the source aspect ratio. Center the device vertically and horizontally within its designated central column. Do not stretch the phone capture.

- [ ] **Step 3: Adjust segment durations**

Target:

```text
overview: 23s
object + classification/scene: 35s
pose + gesture: 35s
segmentation: 30s
OCR: 35s
translation: 30s
style + poetry: 30s
college + me: 18s
```

Reserve about 24 seconds for opening and closing graphics. Keep the total structural cut under 4 minutes 40 seconds.

- [ ] **Step 4: Verify structure**

Use `read_project` timeline and track views. Expected:

- no same-track overlap;
- no black gaps;
- correct clip order;
- each item references an original asset;
- duration is under 280 seconds.

### Task 5: Add titles, subtitles, and music

**Files:**
- Modify: ChatCut timeline
- Create in ChatCut: title/subtitle Motion Graphics assets
- Create in ChatCut: one instrumental music asset

**Interfaces:**
- Consumes: structural cut from Task 4.
- Produces: final editable cut with Harmony-style text and mixed music.

- [ ] **Step 1: Add opening and closing graphics**

Opening text:

```text
MindSpore 掌中宝
HarmonyOS 原生端侧 AI 体验
```

Closing text:

```text
原生 HarmonyOS UI
端侧 AI · 相册推理 · 多 ABI
```

Use blue/white flat graphics, no 3D, no heavy shadow.

- [ ] **Step 2: Add concise segment subtitles**

Use these factual captions:

```text
对象检测：从相册选择图片并标注识别结果
图像分类 / 场景检测：端侧模型输出类别与置信度
骨架检测：在人物图片上生成关键点和骨架
手势识别：识别相册中的手势类别
人像分割：提取人物前景并保留原图比例
文本提取：识别图片中的中文内容
文本翻译：支持中英文本输入与本地推理
风格迁移与诗词：展示端侧视觉和文本创作能力
学院与我的：统一的 HarmonyOS 原生设计
```

Place text in the side area. Never cover the phone's result, status, or main buttons.

- [ ] **Step 3: Add one instrumental track**

Generate or select one lyric-free light electronic track:

```text
105–115 BPM
clean technology mood
no dramatic drops
duration at least the final cut
```

Place it on one audio track, trim to picture duration, and use short fades at both ends. Do not add sound effects.

- [ ] **Step 4: Add restrained transitions**

Use only short fades between major sections. Do not add a transition between every tap or picker action.

- [ ] **Step 5: Verify key composed frames**

Render and inspect frames from:

```text
opening
overview
object/scene
pose/gesture
segmentation
OCR
translation
style/poetry
college/me
closing
```

Expected:

- phone is not stretched;
- titles are readable;
- subtitles do not cover results;
- no black frame;
- visual style is consistent.

### Task 6: Final verification and MP4 export

**Files:**
- Export to: `%USERPROFILE%\Downloads\MindSpore掌中宝-HarmonyOS作品演示.mp4`

**Interfaces:**
- Consumes: verified ChatCut timeline.
- Produces: final downloadable MP4 and retained editable ChatCut project.

- [ ] **Step 1: Verify project structure**

Refresh ChatCut project state and confirm:

- active timeline is `作品演示成片`;
- all source assets are cloud-readable;
- video, title, and music tracks are aligned;
- final duration is below 300 seconds.

- [ ] **Step 2: Submit export**

Call:

```json
{
  "format": "video",
  "codec": "h264",
  "resolution": "1080p",
  "fps": 30,
  "name": "MindSpore掌中宝-HarmonyOS作品演示"
}
```

- [ ] **Step 3: Track export**

Use `track_export` with the returned `renderId` until the job completes. Record the render ID and final download URL.

- [ ] **Step 4: Download without overwriting**

Download into `%USERPROFILE%\Downloads`. If the target exists, use a numbered filename. Do not overwrite an older export.

- [ ] **Step 5: Verify the downloaded MP4**

Confirm:

- extension `.mp4`;
- H.264 video;
- 1920×1080;
- 30fps;
- duration below 300 seconds;
- file size is nonzero;
- opening, middle, and closing frames render.

- [ ] **Step 6: Deliver**

Report:

- absolute local path;
- file size;
- resolution;
- fps;
- duration;
- ChatCut editor URL;
- render ID.

Show the final MP4 inline in Codex and leave the editable ChatCut project available.
