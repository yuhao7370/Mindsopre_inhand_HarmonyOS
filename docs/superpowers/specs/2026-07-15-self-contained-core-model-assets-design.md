# Self-Contained Core MindSpore Model Assets Design

## Context

The HarmonyOS app uses five core MindSpore Lite models for image
classification, scene detection, object detection, and style transfer. They are
present in the current workspace and HAP, but `.gitignore` excludes every
`rawfile/model/*.ms`. A clean clone therefore runs four network download scripts
from `build-hap.ps1`, and four of the five assets are accepted using only a
minimum-size check. The HAP payload guard currently verifies gesture and
translation models but not these five core models.

That makes a clean private-repository checkout non-deterministic: upstream
availability/content can affect the build, and a HAP could omit or substitute a
core runtime model without the current package guard rejecting it.

## Goal

Make normal host builds self-contained and byte-deterministic by tracking all
five core models, removing implicit build-time networking, pinning exact size
and SHA-256 checks, and verifying their exact bytes inside the main HAP.

## Asset Contract

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `mobilenetv2.ms` | 14,014,408 | `F88C8C410D1148F5614994038680C245E1788C80E578D093E536572D08ECC514` |
| `resnet18-place365.ms` | 45,448,504 | `286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9` |
| `ssd.ms` | 17,515,528 | `0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553` |
| `style_predict_quant.ms` | 3,022,576 | `6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC` |
| `style_transfer_quant.ms` | 256,864 | `AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682` |

These values were measured from the exact assets already used by the accepted
main HAP. The models are stored as ordinary Git binary files, matching the
repository's existing gesture and translation model precedent. The largest
single file is below 50 MB, so no LFS dependency is introduced unless the
actual private remote later requires it.

## Repository and Build Behavior

- Stop ignoring `model/*.ms`; continue ignoring only partial
  `*.ms.download*` files.
- Mark the five model paths `-text -diff` in
  `Mindspore_inhand_HarmonyOS/.gitattributes`, where patterns are relative to
  the HarmonyOS project directory.
- Track all five exact files in the private repository.
- `ensure-mindspore-models.ps1` becomes verification-only. Normal build and
  acceptance paths never call a downloader.
- Keep the four downloader scripts as explicit manual recovery tools. Each
  downloader writes a request-private same-directory temporary file, validates
  exact size and SHA-256, then publishes with `File.Replace` when a stable file
  exists or same-directory `File.Move` when it does not. Download, validation,
  or publication failure cleans only private temporary/backup files and never
  deletes or truncates the last stable model.
- Model-specific verifier scripts reject missing, wrong-size, or wrong-hash
  assets. The already strict scene verifier remains the reference behavior.

## Package Integrity

Add all five `resources/rawfile/model/*.ms` entries plus the model license and
NOTICE to `verify-ai-runtime-haps.ps1`. Its existing exact-entry and SHA
comparison then proves each payload appears exactly once and has the same bytes
as the tracked source file. Extend the existing fixture test with a valid
five-model package and a tampered app-model rejection.

## Provenance and Scope

The license preflight is part of the commit gate, not a later caveat:

- The three official MindSpore Model Zoo sources are covered by the repository's
  Apache-2.0 license and its model README limits trained models to
  non-commercial research and educational use.
- The pinned HarmonyOS `MSLiteSceneRecognition` commit contains an Apache-2.0
  `LICENSE`, copyright Huawei Device Co., Ltd., and no additional `NOTICE`.
- The project's stated private local-learning use fits the narrower Model Zoo
  research/education boundary.

Ship a full Apache-2.0 license copy plus a model NOTICE/provenance record beside
the tracked models. The record contains source URLs/commit, ownership,
purposes, exact bytes/hashes, the Model Zoo restriction, and the fact that no
upstream NOTICE file was present. If implementation inspection contradicts any
of those facts, binary submission is blocked until resolved.

## Verification

- A source/asset guard enforces the tracked-asset ignore/attribute policy,
  verification-only build wiring, strict verifier/downloader hashes,
  failure-safe same-directory publication, license/NOTICE files, and HAP entry
  wiring.
- All five real files pass exact size/SHA verification.
- HAP verifier fixtures accept the complete package and reject a tampered core
  model.
- Fresh Hypium and unified AI runtime acceptance remain green.
- No device functionality, inference quality, performance, installation, or
  signing claim is made.
