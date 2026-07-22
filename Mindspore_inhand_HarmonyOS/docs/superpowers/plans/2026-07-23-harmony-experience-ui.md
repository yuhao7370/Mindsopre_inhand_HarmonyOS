# HarmonyOS Experience UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the selected C-style HarmonyOS Experience catalog, generated icons, hidden Custom Model entry, and emulator-verified layout.

**Architecture:** Keep `FeatureCatalog` as the visibility source of truth and the existing router untouched. Replace only Experience shell presentation and media mappings; generated PNG assets live in `base/media` and are referenced through `IconSymbols`.

**Tech Stack:** ArkTS/ArkUI, HarmonyOS resources, Hypium LocalUnit, ImageGen PNG assets, Hvigor, HDC emulator.

## Global Constraints

- Preserve all existing routes and feature runtimes.
- Hide, do not delete, Custom Model.
- All thirteen catalog entries receive unique generated icons.
- No new runtime dependencies.
- Commit each independently verified functional change.

---

### Task 1: Generated UI assets

**Files:**
- Create: `entry/src/main/resources/base/media/experience_hero_harmony.png`
- Create: `entry/src/main/resources/base/media/feature_*.png`

**Interfaces:**
- Produces: HarmonyOS `media` resources consumed by `ExperienceHeader` and `IconSymbols`.

- [ ] Generate one blue-violet orbit hero without text or trademarks.
- [ ] Generate thirteen consistent pictographic icons, including hidden features.
- [ ] Validate every PNG opens, has non-zero dimensions, and is distinct.
- [ ] Commit with `feat(ui): add generated experience artwork`.

### Task 2: Catalog visibility and media mapping

**Files:**
- Modify: `entry/src/main/ets/common/data/FeatureCatalog.ets`
- Modify: `entry/src/main/ets/common/icons/IconSymbols.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: generated `feature_*.png` resources.
- Produces: nine visible entries and unique media mappings for all thirteen entries.

- [ ] Change the LocalUnit expectation to nine visible entries, assert Custom Model is hidden, and assert exact unique media names.
- [ ] Run `hvigorw.bat test --no-daemon` and confirm the test fails before implementation.
- [ ] Set Custom Model `visibleByDefault` to `false` and replace media mappings.
- [ ] Rerun LocalUnit and scan the full log for zero failures.
- [ ] Commit with `fix(ui): hide custom model entry`.

### Task 3: Experience catalog layout

**Files:**
- Modify: `entry/src/main/ets/common/data/ExperienceHeaderBranding.ets`
- Modify: `entry/src/main/ets/common/data/ExperienceLayoutSpec.ets`
- Modify: `entry/src/main/ets/common/components/ExperienceHeader.ets`
- Modify: `entry/src/main/ets/common/components/FeatureCard.ets`
- Modify: `entry/src/main/ets/common/components/BottomTabBar.ets`
- Modify: `entry/src/main/ets/pages/ExperiencePage.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `visibleExperienceSections` and generated media.
- Produces: C-style immersive Experience catalog with safe scrolling.

- [ ] Add LocalUnit expectations for the new hero, card, gap, radius, and bottom-clearance constants.
- [ ] Run LocalUnit and confirm the old values fail.
- [ ] Implement the minimum ArkUI layout matching the selected mockup.
- [ ] Rerun LocalUnit and the repository UI guards.
- [ ] Commit with `feat(ui): redesign experience catalog`.

### Task 4: Device verification

**Files:**
- Modify only if a reproducible emulator defect requires it.

**Interfaces:**
- Consumes: main and test HAPs.
- Produces: screenshots and exact dual-ABI verification evidence.

- [ ] Run `scripts/build-ai-runtime-acceptance.ps1` and require exit 0.
- [ ] Install the main HAP and launch `com.yuhaofeng.mih`.
- [ ] Capture top and scrolled screenshots; verify all nine entries, generated icons, hidden Custom Model, and bottom clearance.
- [ ] If a defect is found, add the smallest failing check, fix it, and commit separately.
- [ ] Run final LocalUnit and `git diff --check` before reporting completion.
