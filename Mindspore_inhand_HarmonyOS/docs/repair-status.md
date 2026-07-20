# Runtime Feature Repair Status

Updated: 2026-07-20

`pending -> coding -> auto_pass -> emulator_pass -> device_pass -> done`; failures use `blocked` with evidence. `done` requires real-input effect verification and a feature commit.

| Feature | Phase | Commit | Depends on | Model source / license / SHA-256 | API24 + tensor contract | Automatic evidence | Emulator evidence | Device evidence | Last error / blocker |
|---|---|---|---|---|---|---|---|---|---|
| Image Classification | pending | — | Camera | Existing MobileNet / audit pending | pending | baseline static checks pass | camera start failed | pending | `cameraInfo is null`; model not reached |
| PoseNet | pending | — | Camera | CoreVision or licensed local model | pending | baseline static checks pass | CoreVision module missing | pending | `@hms:ai.vision.skeletonDetection` unavailable |
| Portrait Segmentation | pending | — | Camera | CoreVision or licensed local model | pending | baseline static checks pass | not proven | pending | CoreVision availability unproven |
| Gesture Recognition | pending | — | Camera | Existing bundled MNN model | manifest present; runtime recheck pending | native contract exists | still result inconclusive | pending | labeled positive fixture needed |
| Text Extraction | pending | — | Camera | CoreVision or licensed two-stage OCR | pending | baseline static checks pass | CoreVision module missing | pending | `@hms:ai.ocr.textRecognition` unavailable |
| Text Translation | pending | — | Text Extraction for image input | Existing local model package / audit pending | package verification blocked | unit checks pass | blank result; UI stall observed | pending | Python `sentencepiece` missing; runtime empty output |
| Object Detection (Photo) | pending | — | API24 model pipeline | Existing SSD license/schema audit pending | incompatible model observed | model file guard passes | `Invalid mslite model` | pending | legacy model rejected by API24 runtime |
| Object Detection (Real-time) | pending | — | Camera + Photo detection | Same as photo detection | pending | route checks pass | camera/model blocked | pending | upstream dependencies |
| Style Transfer | pending | — | API24 model pipeline | Existing style models license/schema audit pending | incompatible models observed | model file guard passes | `Invalid mslite model` | pending | legacy models rejected by API24 runtime |
| Custom Model | pending | — | Picker + API24 runtime | User-selected model | first-output contract missing | orchestration tests pass | picker preflight only | pending | compatible `.ms` fixture and output validation needed |

Baseline build: blocked in `scripts/verify-translation-model.ps1` because the selected Python lacks `sentencepiece`. Worktree was clean before this status document.
