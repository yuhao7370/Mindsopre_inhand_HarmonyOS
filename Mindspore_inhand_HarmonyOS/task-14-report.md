# Task 14 — Portrait segmentation runtime

## Result

Portrait segmentation now uses the HarmonyOS runtime page, starts with the
front camera, preserves the selected camera and background across a retry, and
keeps the last valid composite visible while a transient inference failure is
reported. Preset and custom-background selection, picker cancellation, save
readiness, single-flight saving, localized feedback, and route re-entry are
covered.

The public live-segmentation route remains the production entry. The hidden
portrait route is still absent from `FeatureCatalog`; Task 14 did not expose a
previously hidden feature.

## Product commits

- `3c75b78` — production portrait runtime and HarmonyOS UI.
- `0540620`, `948bc64` — semantic and signed runtime-evidence contract.
- `bbb38ab`, `c7ef9ee`, `fc7a496` — physical HDC scroll calibration,
  restoration binding, and recovery-state validation.

## Accepted runtime evidence

Only these two signed runs are accepted:

| Matrix | Run | Signed root SHA-256 | HAP SHA-256 |
| --- | --- | --- | --- |
| 1.0× | `default-9bbacab5d52f4d34af12788558dc861f` | `ad26936b810d6e5f8da65652f0f9757a72272378652590cddbd92c06380e7cce` | `907078d3f08b81e9ce99ab5b584e4f1c09f2652b4905acb454bcb01ffbf1caaa` |
| 3.2× | `font32-353ac003607a4633957996cce8a1ab29` | `985074ef2590862b2f1e744376263401bbbb697bd38be7a9b00cfe8ef207dffd` | `0fb701d55fd237f14730b15ae9af3f97faa10c53f752ec2a42063dc8f45c5a45` |

The manifests live under
`.worktrees/harmony-ui-redesign/.superpowers/sdd/2026-07-24-harmony-feature-runtime-ui/task-14-final-2026-07-27`.
Both HAPs contain `arm64-v8a` and `x86_64`. The signing-key fingerprint is
`8cf68478e1fcb46745e3c7b8a18235caca42c3607eff84d96e8e74dd33f979e6`.

Earlier Task 14 evidence directories are failed or superseded attempts and are
not acceptance evidence.

## Evidence boundary

The two portrait runs use a narrow, disclosed route/state harness. The harness
may select auditable input and service states, but it cannot replace production
layout code or claim production inference success. Each manifest binds the
working-tree diff, build receipt, immutable HAP, trusted capture runner,
per-state HDC actions, screenshots, accessibility dumps, service events,
fingerprints, media traversal, and run-root signature.

The checker rejects a public-route claim, a production-success claim, a
mismatched source, an unbound diff or HAP, stale screenshots, missing state
transitions, altered retry order, broken restore direction, and unrelated
screenshot reuse. The only allowed duplicate screenshot pairs are exact
no-visual-change transitions; failure/success events and content fingerprints
remain independently required.

## Verification

- Both accepted signed manifests pass
  `scripts/check-runtime-ui-evidence.ps1` at `fc7a496`.
- Positive signed fixtures and the complete Task 14 core mutation suite pass.
- The PowerShell parser and `git diff --check` pass.
- Independent final review: PASS, with no Critical or Important findings.
- Physical interaction was performed through HDC touch, accessibility dumps,
  screenshots, and device logs; Computer Use was not used.

The harness worktrees intentionally retain the exact signed candidate diff.
Cleaning them would invalidate the manifests, so they are evidence fixtures,
not product worktrees.
