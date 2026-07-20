# Runtime Feature Repair Status

Updated: 2026-07-21

`pending -> coding -> auto_pass -> emulator_pass -> device_pass -> done`; failures use `blocked` with evidence. `done` requires real-input effect verification and a feature commit.

| Feature | Phase | Commit | Depends on | Model source / license / SHA-256 | API24 + tensor contract | Automatic evidence | Emulator evidence | Device evidence | Last error / blocker |
|---|---|---|---|---|---|---|---|---|---|
| Image Classification | emulator_pass | `3f7f905` + follow-up | Camera | Official MindSpore quick-start `mobilenetv2.ms` MSL2; private local learning, non-commercial research/education; `5A7CCD53BF92D8B294A703A1302D4230A311B2D19A8D212EEDD65FF6838CFA84` | float32 NHWC `[1,224,224,3]`; float32 `[1,1001]`, discard background index 0 and map `scores[i+1]` to label `i` | camera device/profile guard + asset/hash/HAP guards pass | API24 x86_64 emulator: installed HAP, live Image Classification route showed a current preview and non-empty result (`百叶窗`); CameraService logged `lcam001`/`OnFrame`/`ReceiveBuffer status:0`; fixtures: `military_uniform` rank 4 and `Labrador_retriever` rank 1 | Not run: no arm64 physical-device evidence is claimed or required for emulator acceptance | resolved for emulator: legacy MSL1 model rejected by API24 `GetInputs`; pinned MSL2 contract now verified |
| PoseNet | pending | — | Camera | CoreVision or licensed local model | pending | baseline static checks pass | CoreVision module missing | pending | `@hms:ai.vision.skeletonDetection` unavailable |
| Portrait Segmentation | pending | — | Camera | CoreVision or licensed local model | pending | baseline static checks pass | not proven | pending | CoreVision availability unproven |
| Gesture Recognition | pending | — | Camera | Existing bundled MNN model | manifest present; runtime recheck pending | native contract exists | still result inconclusive | pending | labeled positive fixture needed |
| Text Extraction | pending | — | Camera | CoreVision or licensed two-stage OCR | pending | baseline static checks pass | CoreVision module missing | pending | `@hms:ai.ocr.textRecognition` unavailable |
| Text Translation | pending | — | Text Extraction for image input | Existing local model package / audit pending | package verification blocked | unit checks pass | blank result; UI stall observed | pending | Python `sentencepiece` missing; runtime empty output |
| Object Detection (Photo) | pending | — | API24 model pipeline | Existing SSD license/schema audit pending | incompatible model observed | model file guard passes | `Invalid mslite model` | pending | legacy model rejected by API24 runtime |
| Object Detection (Real-time) | pending | — | Camera + Photo detection | Same as photo detection | pending | route checks pass | camera/model blocked | pending | upstream dependencies |
| Style Transfer | pending | — | API24 model pipeline | Existing style models license/schema audit pending | incompatible models observed | model file guard passes | `Invalid mslite model` | pending | legacy models rejected by API24 runtime |
| Custom Model | pending | — | Picker + API24 runtime | User-selected model | first-output contract missing | orchestration tests pass | picker preflight only | pending | compatible `.ms` fixture and output validation needed |

Baseline build: `scripts/build-hap.ps1` passed for Image Classification after the camera/model repair. The other feature rows retain their prior independent evidence.
