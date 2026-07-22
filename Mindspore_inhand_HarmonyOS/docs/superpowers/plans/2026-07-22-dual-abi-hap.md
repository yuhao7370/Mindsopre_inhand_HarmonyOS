# Dual-ABI HAP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce one reproducible HarmonyOS HAP that contains the complete `arm64-v8a` and `x86_64` native runtime sets and runs unchanged on the API24 x86_64 emulator.

**Architecture:** Keep the existing ABI-driven CMake and HAP verifier. Add the second ABI to the module profile, version the pinned x86_64 MNN/XZ inputs with per-ABI manifests, and make the existing build gates reject a missing, extra, wrong-architecture, or byte-mismatched native payload for either ABI.

**Tech Stack:** DevEco Studio 6.1.1 SDK/API24, Hvigor, OHOS CMake/Clang, PowerShell guards, ZIP/HAP payload verification, HDC.

## Global Constraints

- The deliverable is one HAP, not separate arm64 and x86 HAPs.
- The HAP must contain all eight production native libraries under both `libs/arm64-v8a/` and `libs/x86_64/`.
- Do not add dependencies or a generic build framework; extend the current scripts.
- Every checked-in prebuilt must have pinned source/toolchain/license, size, SHA-256, ELF class/machine, and dynamic dependency evidence.
- Test HAP isolation remains exact: no AI models or production AI native libraries may leak into the ohosTest HAP.
- Use TDD, keep the final tracked profile dual-ABI, and make one implementation commit: `build(hap): package arm64 and x86 runtimes`.

---

### Task 1: Package and verify the complete ABI matrix

**Files:**
- Modify: `.gitignore`
- Modify: `.gitattributes`
- Modify: `entry/build-profile.json5`
- Create: `entry/src/main/cpp/MNN_BUILD_MANIFEST.x86_64.json`
- Create: `entry/src/main/cpp/translation_xz/XZ_BUILD_MANIFEST.x86_64.json`
- Modify: `entry/src/main/cpp/translation_xz/XZ_BUILD_MANIFEST.json`
- Modify: `entry/src/main/cpp/translation_xz/third_party/xz/COPYING`
- Add: `entry/libs/x86_64/libMNN.so`
- Add: `entry/libs/x86_64/libtranslation_archive.so`
- Add: `entry/src/main/cpp/translation_xz/third_party/xz/lib/x86_64/liblzma.a`
- Create: `scripts/build-translation-xz-ohos.ps1`
- Create: `scripts/test-build-translation-xz-ohos-guard.ps1`
- Modify: `scripts/test-native-abi-matrix.ps1`
- Modify: `scripts/build-hap.ps1`
- Modify: `scripts/build-ai-runtime-acceptance.ps1`
- Modify: `scripts/verify-ai-runtime-haps.ps1`
- Modify: `scripts/test-verify-ai-runtime-haps.ps1`
- Modify: `docs/repair-status.md`
- Modify: `../tools/translation/manifests/final-package-v1.json`
- Modify: `../tools/translation/verify_translation_package.py`
- Modify: `../tools/translation/build_xz_ohos.ps1`
- Modify: `../.superpowers/sdd/progress.md` (ignored live ledger; do not stage)

**Interfaces:**
- Consumes: module `abiFilters`, `${OHOS_ARCH}` CMake paths, `scripts/build-mnn-ohos.ps1 -Abi x86_64`, and the current exact HAP verifier.
- Produces: a dual-ABI `entry-default-unsigned.hap`; `build-translation-xz-ohos.ps1 -Abi <arm64-v8a|x86_64> [-VerifyOnly]`; per-ABI manifests accepted by the baseline gates.

- [x] **Step 1: Add failing ABI-matrix and HAP fixture expectations**

Make `scripts/test-native-abi-matrix.ps1` require exactly the two supported ABIs and validate each ABI-specific input manifest before building:

```powershell
$expectedAbis = @('arm64-v8a', 'x86_64')
if (($abis -join ',') -cne ($expectedAbis -join ',')) {
  throw "abiFilters must be arm64-v8a,x86_64; got $($abis -join ',')"
}
foreach ($abi in $expectedAbis) {
  $mnnManifest = if ($abi -ceq 'arm64-v8a') { 'MNN_BUILD_MANIFEST.json' } else { "MNN_BUILD_MANIFEST.$abi.json" }
  $xzManifest = if ($abi -ceq 'arm64-v8a') { 'XZ_BUILD_MANIFEST.json' } else { "XZ_BUILD_MANIFEST.$abi.json" }
  $mnn = Get-Content (Join-Path $projectRoot "entry/src/main/cpp/$mnnManifest") -Raw | ConvertFrom-Json
  $xz = Get-Content (Join-Path $projectRoot "entry/src/main/cpp/translation_xz/$xzManifest") -Raw | ConvertFrom-Json
  $mnnPath = Join-Path $projectRoot "entry/libs/$abi/libMNN.so"
  $lzmaPath = Join-Path $projectRoot "entry/src/main/cpp/translation_xz/third_party/xz/lib/$abi/liblzma.a"
  $wrapperPath = Join-Path $projectRoot "entry/libs/$abi/libtranslation_archive.so"
  if ($mnn.toolchain.abi -cne $abi -or $xz.toolchain.abi -cne $abi) { throw "Manifest ABI mismatch: $abi" }
  if ((Get-FileHash $mnnPath -Algorithm SHA256).Hash -cne $mnn.artifact.sha256) { throw "MNN hash mismatch: $abi" }
  if ((Get-FileHash $lzmaPath -Algorithm SHA256).Hash -cne $xz.artifacts.liblzma.sha256) { throw "liblzma hash mismatch: $abi" }
  if ((Get-FileHash $wrapperPath -Algorithm SHA256).Hash -cne $xz.artifacts.napi.sha256) { throw "translation wrapper hash mismatch: $abi" }
}
```

Extend `scripts/test-verify-ai-runtime-haps.ps1` so its valid main fixture includes the eight existing runtime filenames for both ABIs, and add mutations that remove one x86 library and add an unexpected third-ABI library. The expected failures must contain `missing` and `unexpected` respectively.

- [x] **Step 2: Run the new guards and record RED**

Run:

```powershell
powershell.exe -NoProfile -File scripts/test-native-abi-matrix.ps1
powershell.exe -NoProfile -File scripts/test-verify-ai-runtime-haps.ps1
```

Expected: fail because the tracked profile is arm64-only and the tracked x86 manifests/payloads do not yet exist.

- [x] **Step 3: Generate and pin the x86 native inputs**

Run the existing MNN builder against the pinned MNN commit:

```powershell
powershell.exe -NoProfile -File scripts/build-mnn-ohos.ps1 -Abi x86_64
```

Implement `scripts/build-translation-xz-ohos.ps1` with the same pinned XZ 5.8.3 URL, source SHA-256, API24 SDK discovery, decoder-only flags, and `${Abi}` output paths recorded in the arm64 manifest. Its public parameters must be:

```powershell
param(
  [ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a',
  [string]$DevEcoSdkRoot = '',
  [string]$CacheRoot = '',
  [switch]$VerifyOnly
)
```

The script must build `liblzma.a`, build the existing `translation_xz` wrapper with the matching OHOS architecture, copy the two outputs into the existing ABI paths, write `XZ_BUILD_MANIFEST.<abi>.json` for x86_64, and in `-VerifyOnly` mode compare size/hash/ELF machine/dynamic dependencies without downloading or rewriting files.

Run:

```powershell
powershell.exe -NoProfile -File scripts/build-translation-xz-ohos.ps1 -Abi x86_64
powershell.exe -NoProfile -File scripts/build-mnn-ohos.ps1 -Abi x86_64 -VerifyOnly
powershell.exe -NoProfile -File scripts/build-translation-xz-ohos.ps1 -Abi x86_64 -VerifyOnly
```

Expected: all three commands exit 0, and the x86 manifests describe the exact tracked bytes and `Advanced Micro Devices X86-64` ELF machine.

- [x] **Step 4: Enable one dual-ABI product**

Change `entry/build-profile.json5` to:

```json5
"abiFilters": [
  "arm64-v8a",
  "x86_64"
]
```

Remove the production `nativeLib.filter.excludes` entry for `**/x86_64/*.so`. Remove only the two x86 ignore rules from `.gitignore`; retain all unrelated ignore rules.

- [x] **Step 5: Wire per-ABI provenance into the baseline gate**

In `scripts/build-hap.ps1`, run both MNN and XZ `-VerifyOnly` checks for each configured ABI before Hvigor. In `scripts/build-ai-runtime-acceptance.ps1`, retain the existing loop over `abiFilters` and verify the stripped `libtranslation_archive.so` plus every MNN-backed wrapper for each ABI.

Keep `scripts/verify-ai-runtime-haps.ps1` profile-driven. Its expected main entries must be exactly:

```powershell
foreach ($abi in $targetAbis) {
  foreach ($library in @(
    'libgesture_mnn.so', 'libMNN.so', 'libtranslation_archive.so',
    'libsegmentation_mnn.so', 'libobject_detection_mnn.so',
    'libocr_mnn.so', 'libstyle_transfer_mnn.so', 'libc++_shared.so'
  )) { "libs/$abi/$library" }
}
```

Continue hashing every HAP native entry against `entry/build/default/intermediates/stripped_native_libs/default/<abi>/`; do not accept name-only verification.

- [x] **Step 6: Run the complete GREEN build gate**

Run:

```powershell
powershell.exe -NoProfile -File scripts/test-build-translation-xz-ohos-guard.ps1
powershell.exe -NoProfile -File scripts/test-native-abi-matrix.ps1
powershell.exe -NoProfile -File scripts/test-verify-ai-runtime-haps.ps1
powershell.exe -NoProfile -File scripts/build-ai-runtime-acceptance.ps1
powershell.exe -NoProfile -File scripts/build-hap.ps1
```

Expected: every command exits 0. The exact HAP verifier reports both target ABIs; main HAP contains exactly sixteen production native entries; ohosTest contains no production AI native entry for either ABI.

- [x] **Step 7: Install the same HAP on the x86_64 emulator**

Run:

```powershell
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' install -r '.\entry\build\default\outputs\default\entry-default-unsigned.hap'
& 'F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' shell param get const.product.cpu.abilist
```

Expected: target `127.0.0.1:5555` is online, install exits 0, and the device ABI list includes `x86_64`. This project has no `signingConfigs`, so DevEco emits an unsigned HAP that the API24 emulator accepts; do not claim a signed artifact. Run the focused Gesture native suite once from the same dual-ABI build and require 1/1 pass to prove the loader selected the x86 payload.

- [x] **Step 8: Update evidence and commit once**

Update `docs/repair-status.md` and the ignored live ledger with both HAP ABI entry counts, exact verifier output, emulator install result, focused native result, and the arm64 non-device boundary. Then run:

```powershell
git diff --check
git status --short
git add -A -- .gitignore entry docs scripts
git commit -m "build(hap): package arm64 and x86 runtimes"
git status --short
```

Expected: one implementation commit and a clean tracked worktree. The ignored progress ledger remains uncommitted.
