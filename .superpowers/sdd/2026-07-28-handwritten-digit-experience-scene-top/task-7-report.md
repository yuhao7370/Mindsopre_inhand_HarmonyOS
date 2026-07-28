# Task 7 report — handwritten digit fixtures

Completed 2026-07-28.

- Copied the three supplied ImageGen files unchanged into `Mindspore_inhand_HarmonyOS/test-assets/handwritten-digits/`; none is under `entry/` or a HAP resource path.
- Added `validate-mnist-test-assets.py`. It extracts only `artifacts/lenet_mnist.mindir` from the College tutorial ZIP to a temporary directory, runs installed desktop MindSpore, and mirrors the ArkTS image pipeline: border background, relative foreground, threshold, square crop with 10% padding, 20 px resize, bounded center-of-mass translation, and `(x - 0.1307) / 0.3081` normalization.
- Added the asset guard, including a mutation check that changes a manifest expected label and confirms rejection.
- TDD evidence: the new guard first failed because the validator was absent; it now passes after the validator, immutable assets, and manifest were added.

| Fixture | SHA-256 | Desktop MindIR result |
| --- | --- | --- |
| `digit-2.png` | `16A2868156CA7D0F9DF72C6C8A412C621BD8634F29F651DCCE5532C9B3E16622` | 2, 0.970998 |
| `digit-7.png` | `6F6B137F81272AFDFCEF5942AFD43D8D605F93A14556DA3E05C825C42BFEA393` | 7, 0.822432 |
| `digit-9.png` | `9A4B32923B0ACA332A59183FCBF2A2354BBC36F23DE3A4CB2E9F9FDB8864CFCD` | 9, 0.992624 |

Verification run:

```powershell
python .\scripts\validate-mnist-test-assets.py
.\scripts\test-mnist-test-assets-guard.ps1
git diff --check
```

All commands passed. No regeneration is required.

## Review fix round 1

- The guard now requires the manifest file list to have exactly three unique entries and to sort exactly to `digit-2.png`, `digit-7.png`, and `digit-9.png`; it then verifies each file's expected digit, dimensions, and SHA-256.
- A second mutation replaces all three manifest records with otherwise valid `digit-2.png` records. The guard rejects it, in addition to the existing expected-label mutation.
- The desktop mirror now performs the same RGBA trust-boundary validation as ArkTS and counts each border pixel exactly once for 1×N/N×1 images. `--self-test` covers both thin-image border cases, invalid pixel length, and over-limit dimensions; the guard runs it.

Round-1 verification passed: `python .\\scripts\\validate-mnist-test-assets.py --self-test`, the full validator (2→2, 7→7, 9→9), the guard with both mutations, and `git diff --check`.
