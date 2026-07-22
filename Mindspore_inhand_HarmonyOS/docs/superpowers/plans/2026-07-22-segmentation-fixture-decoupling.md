# Segmentation Fixture Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Portrait Segmentation device test's PoseNet/non-white-pixel oracle with a dedicated, licensed person fixture and an independently authored binary mask.

**Architecture:** Test-only image and mask assets live together under `entry/src/ohosTest/resources/rawfile/fixtures/segmentation/`; production resources and runtime code remain unchanged. `SegmentationNativeTest` reads both assets from the ohosTest module and compares the production foreground alpha to the labelled mask. A PowerShell guard pins provenance, hashes, mask encoding, and HAP isolation.

**Tech Stack:** ArkTS/Hypium, HarmonyOS ResourceManager, PNG/JPEG test assets, PowerShell guards, API24 x86_64 emulator, arm64 HAP acceptance.

## Global Constraints

- Follow RED-GREEN-REFACTOR: observe the coupling guard fail before editing the test.
- The fixture must have an explicit redistribution license and exact SHA-256.
- The mask must be independently authored, binary, same-sized as the fixture, and must not be copied from production model output.
- Main HAP must not receive test fixtures; ohosTest HAP must not receive production models.
- Final tracked ABI is `arm64-v8a`; no physical-device inference claim.
- Create one follow-up commit; do not amend `867d6cc`.

---

### Task 1: Reproduce the invalid oracle

**Files:**
- Create: `scripts/check-segmentation-fixture-contract.ps1`
- Test: `entry/src/ohosTest/ets/test/SegmentationNative.test.ets`

**Interfaces:**
- Consumes: the existing `personFixturePath` and `foregroundIou` implementation.
- Produces: a guard that requires dedicated segmentation image/mask paths and rejects RGB-threshold-derived expected foreground.

- [x] **Step 1: Write the failing guard** requiring `fixtures/segmentation/person.*`, `fixtures/segmentation/person_mask.png`, test-module resource reads, and no `foregroundChannelThreshold`/RGB expected-mask construction.
- [x] **Step 2: Run** `pwsh scripts/check-segmentation-fixture-contract.ps1`; expect failure naming the old `posenet/skeleton_image.JPG` coupling.

### Task 2: Add licensed image and independent mask

**Files:**
- Create: `entry/src/ohosTest/resources/rawfile/fixtures/segmentation/person.*`
- Create: `entry/src/ohosTest/resources/rawfile/fixtures/segmentation/person_mask.png`
- Create: `entry/src/ohosTest/resources/rawfile/fixtures/segmentation/NOTICE.md`
- Modify: `scripts/check-segmentation-fixture-contract.ps1`

**Interfaces:**
- Consumes: canonical upstream image bytes and project-authored mask pixels.
- Produces: exact-size binary mask, pinned hashes, author/license/source attribution.

- [x] **Step 1: Select and download a clearly licensed full-body person image**; preserve upstream bytes and record canonical URL/revision, author, license, dimensions, byte size, and SHA-256.
- [x] **Step 2: Create and visually inspect an independent binary person mask** without consuming production segmentation output; record the authoring method and SHA-256.
- [x] **Step 3: Extend the guard** to decode the assets, verify exact hashes/dimensions, require mask values to be binary with nontrivial foreground/background, and require NOTICE markers.

### Task 3: Switch the device oracle to mask-to-mask IoU

**Files:**
- Modify: `entry/src/ohosTest/ets/test/SegmentationNative.test.ets`

**Interfaces:**
- Consumes: fixture RGBA for inference and labelled-mask RGBA for truth.
- Produces: `foregroundIou(labelMaskRgba, actualForegroundRgba)` based only on labelled-mask alpha/luma versus production foreground alpha.

- [x] **Step 1: Read image and mask from the ohosTest module ResourceManager**, resize both to the production output dimensions, and classify expected foreground from the binary mask only.
- [x] **Step 2: Run** `scripts/check-segmentation-fixture-contract.ps1`; expect GREEN.
- [x] **Step 3: Build/install x86_64 main and ohosTest HAPs and run focused** `SegmentationNativeTest`; expect all focused cases pass and record IoU.

### Task 4: Supply-chain, regression, and release verification

**Files:**
- Modify: `scripts/build-hap.ps1`
- Modify: `scripts/check-core-model-assets.ps1`
- Modify: `scripts/verify-ai-runtime-haps.ps1`
- Modify: `scripts/test-verify-ai-runtime-haps.ps1`
- Modify: `docs/repair-status.md`
- Modify: `docs/task-3-report.md`

**Interfaces:**
- Consumes: dedicated asset guard and built HAPs.
- Produces: automatic guard wiring, exact HAP placement checks, dated status/report evidence.

- [x] **Step 1: Wire the segmentation fixture guard** into normal build/core checks and add HAP positive/negative fixtures that require image/mask only in ohosTest.
- [x] **Step 2: Run fresh LocalUnit and hidden scan**, segmentation guard, core/HAP mutation guards, and full arm64 acceptance.
- [x] **Step 3: Update docs** to date `2026-07-22`, write Pose commit as `867d6cc + follow-up`, and record focused API24 evidence without claiming arm64 physical-device inference.
- [x] **Step 4: Run** `git diff --check`, verify `arm64-v8a`, commit with a new follow-up commit, and confirm tracked worktree cleanliness.
