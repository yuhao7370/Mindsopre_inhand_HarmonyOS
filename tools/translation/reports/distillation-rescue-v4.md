# English-to-Chinese distillation rescue v4

Status: `COMPLETE_BASELINE_RETAINED_NO_PROMOTION`

## Immutable inputs

- Teacher: `Helsinki-NLP/opus-mt-en-zh@408d9bc410a388e1d9aef112a2daba955b945255`, Apache-2.0.
- Teacher weights: 312,087,009 bytes, SHA-256 `69a1d6ec829cee349360b3b677ac0aa99a7d88822d1a6578370029efffdca3f5`.
- Exact language prefix: `>>cmn_Hans<<`, token ID `[5]`.
- Student baseline: optimizer step 16,878, model SHA-256 `a7603325361de12f35ebc660c861c648a1f7293b31174280b32bbea34d9f491a`.
- Source: the approved T2 `en-zh.train.jsonl` only, 90,000 rows, 36,670,761 bytes, SHA-256 `20b908acd71a734f8252c383c5cd2f0bf476214809d0f64cfcc50c1cb5e5670e`.
- No validation, test, manual-audit, or FLORES row is used for distillation or training.

## Deterministic generation contract

Generation uses FP16, four beams, no sampling, renormalized logits, and a maximum of 128 output tokens. Each fixed 512-row chunk is sorted by teacher source-token length and original row ID for inference, then restored to original ID order before its canonical JSONL is atomically persisted. Batch size is fixed to 64 for the initial run and every resume; the runner rejects a different batch because batch 64 and 128 produced different token rows during the probe.

The 512-row throughput probe measured:

| Batch | Rows/s | Peak CUDA memory | Teacher | Original fallback | Hard fail |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 6.9262 | 1.848 GB | 456 | 56 | 0 |
| 128 | 6.1169 | 3.546 GB | 456 | 56 | 0 |

Batch 64 was 13.23% faster and is the immutable selected batch. FP16 and FP32 returned identical token rows for 118/128 precision-probe inputs; this is diagnostic evidence rather than a claim of cross-precision identity.

The eight retained probe timers total 390.515 seconds exactly: initial FP32 batch 64, two FP16/FP32 precision runs, FP16 capacity batch 256, the corrected FP16/FP32 precision pair, and sorted FP16 batches 64/128. Retained teacher loading, warmup, and failed-retry process wall adds 287.385 observed seconds. The immutable actual probe/load ledger is therefore 677.9 seconds; no throughput estimate replaces this actual value in the budget gate.

## Target provenance policy

Teacher targets must pass the student structural/length contract and the conservative source-target number and URL gate. A rejected teacher target falls back to the exact original approved T2 target only if that original target passes the structural/length contract. The original fallback is intentionally not rejected by the source-target regex gate: the strict regex can falsely reject valid dates and Chinese-number translations.

Every fallback receives a canonical sidecar entry containing its row ID, source hash, and `originalPreservationWarnings`. Number and URL differences are audit-only warnings. They do not alter the source, target, target origin, or row order. The final manifest pins the sidecar hash and records `fallbackWithPreservationWarnings`, `number`, and `url` totals. Offline verification recomputes every warning and requires byte-identical sidecar and manifest statistics.

A hard failure means both the generated teacher target failed its applicable validation and the exact original target failed the structural/length target contract. Hard failures stop generation and are never silently omitted.

## Bounded rescue contract

The rescue starts from the exact step-16,878 student weights with a reset AdamW optimizer. It keeps the original 90,000-row Chinese-to-English view and replaces only the English-to-Chinese training targets with the distilled/fallback view, preserving deterministic 1:1 alternation. Training uses FP16, logical and physical batch 32, accumulation 4, learning rate `1e-5`, weight decay `0.01`, label smoothing `0.1`, and 100 warmup optimizer steps. Rescue validation occurs at steps 500, 1,000, and the epoch-one final step. A rescue checkpoint replaces the baseline only on strictly lower combined validation loss.

The cumulative ceiling is 43,200 GPU seconds and includes the prior 13,924.157-second baseline, the 677.9-second actual probe/load ledger, actual teacher generation, and rescue training/evaluation. Before every generation chunk, the runner requires baseline + probe/load actual + generation actual + the 2,400-second rescue reserve to remain at or below the ceiling. Epoch two is permitted only if epoch-one manual evaluation reaches at least 33/50 English-to-Chinese passes with at most two fatal rows and retains at least 32/50 Chinese-to-English passes. Promotion thresholds remain unchanged.

## Retained distillation result

The completed run retained all 90,000 source rows in their original order. The teacher supplied 83,433 targets and the approved original target fallback supplied 6,567 targets; there were zero hard failures. Teacher acceptance was 92.7033%. The fallback sidecar contains 6,567 rows, including 3,641 rows with preservation warnings (3,639 number warnings and 15 URL warnings; warning categories may overlap).

- Audit JSONL: 51,459,349 bytes, SHA-256 `c7068610825807422f156d98306c4a7768bc4985331865cc3ae282ec7e36a83c`.
- Distillation manifest: SHA-256 `49a706e0047c18cddd6e9f773e5f3e28c2a06d8767692f7128d043fd27817ed9`.
- Fallback sidecar: SHA-256 `847099c0fdda3d0481cfb93a108b9100cff02881e97a0111fdedeb09a3c2fa53`.
- Materialized rescue view: 90,000 rows, 36,012,858 bytes, SHA-256 `f6a067cd9112ade1dfae1f42f190a04072a41d8abe167a819eee267b51bcc6a9`.
- Training-view manifest: SHA-256 `a6a8a211bb3f7ddee78b1c9db9fc4086f3126582bf83ef1c642372c73fd07dda`.
- Measured teacher generation time: 11,715.989 seconds.

Two separate offline-verification invocations ran with `HF_HUB_OFFLINE=1` and `TRANSFORMERS_OFFLINE=1`. Their receipts were stored at distinct paths, were byte-identical, and both have SHA-256 `e57bd01b65211ab0a09246d57e6bd57b4df6f373b83cbbba447b816cdc03636e`. Each receipt records zero network calls and binds the tokenizer, audit, manifest, and sidecar hashes above.

## Retained rescue result

The first epoch initially reached optimizer step 414 before a Windows file-replacement access race terminated the old process. No model checkpoint existed at that old cadence. Recovery therefore used the explicit deterministic `replay-from-baseline` path, not an unaccounted restart. The immutable replay receipt binds the old 414-step progress and its 241.391-second elapsed floor; its SHA-256 is `e2c9cf23522d63071874325645987ceda082003b7e2080ffd5c6e19578bcafae`. The recovered run emitted its first model/optimizer/RNG checkpoint at replay step 100 and completed all 1,406 optimizer steps.

Combined validation loss did not strictly improve over the selected baseline:

| Checkpoint | Combined validation loss |
| ---: | ---: |
| Baseline step 16,878 | 3.7039039318084717 |
| Rescue step 500 | 3.7263651744842528 |
| Rescue step 1,000 | 3.7316759941101076 |
| Rescue step 1,406 | 3.7347549407958986 |

Consequently `best_rescue_step`, `candidate_checkpoint`, and `candidate` are all null. The strict-best policy retained the original step-16,878 baseline. No epoch-two authorization, manual/FLORES candidate gate, export, or promotion was attempted because there is no eligible rescue candidate.

The canonical training report is `training-v1.json`, SHA-256 `0696ea9986c10c2a814632dec20a1da3bb12846081c83087e20f60431749a636`. Rescue training/evaluation consumed 1,020.531 cumulative seconds, including the inherited failed-run floor and deterministic replay. The final ledger is 13,924.157 baseline + 677.9 probe/load + 11,715.989 teacher generation + 1,020.531 rescue = 27,338.577 actual GPU seconds, leaving 15,861.423 seconds beneath the 43,200-second ceiling. Peak allocated CUDA memory recorded by the training report is 2,385,506,816 bytes.

## Rejected final-weight diagnostics

For diagnosis only, the final step-1,406 resume state was materialized under `diagnostic-epoch1-final`, outside every candidate directory. Its model SHA-256 is `c28e7f7f8af8009d634795d2fd012a891695bf59dc134ddf7e50516da9831237`. The canonical provenance has SHA-256 `5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5`, status `REJECTED_NOT_PROMOTABLE`, and `gate_eligible=false`. Gate code rejects this exact model hash after directory renaming, and every export profile rejects the known diagnostic hash before prototype allowlist or final approval processing. Final export additionally continues to require a canonical successful quality gate bound to the exact candidate hash.

The original step-16,878 baseline and rejected diagnostic weights were evaluated with the same tokenizer, pinned BiST revision, 5,000 validation and 5,000 test rows per direction, greedy decode, and 100-row manual asset. A no-GPU reconciliation under `diagnostic-reconcile-v2` verified every referenced model, tokenizer, dataset-manifest, six-dataset, manual, raw-output, and receipt file against its byte count and SHA-256, then recomputed BLEU and chrF2 from the retained 10,000-row raw BiST output of each checkpoint. The canonical baseline report SHA-256 is `d46a7f3a71132e17ae068e9a43b72ef033c7f469010c0033c5f21a476ef30c65`; the canonical diagnostic report SHA-256 is `7aba3fb4d45ba141ed1040f4648c49f5e57923fa97ee1ea19067276b5ea83e58`; and the canonical comparison SHA-256 is `10284aaec8bfc3859a618915b30f2f769cbcbab2797e404f2e1fba9a9ef3f960`. A second no-GPU reconciliation rebuilt the comparison and matched all 1,478 bytes exactly.

The recursive budget chain is rooted at the diagnostic provenance above. Its failed-attempt receipt SHA-256 is `edda591abc9943f0f0b65eda34487ec6e8abd5a7310a29a5b694da6c38dd639f`, the completed baseline-evaluation receipt SHA-256 is `4dc8803c2f81855224883627dc06f734ed6b48a31c99fe21aa2bc525a0d33bc3`, and the completed diagnostic-evaluation receipt SHA-256 is `2996575f8100857820d92a4874989c561211ac2a68c617b7d287ceff28307675`. Recursive validation requires each actual predecessor file and hash, continuous prior/cumulative seconds, the same root evidence, and the fixed 43,200-second total.

| Direction | Validation loss baseline | Validation loss diagnostic | BLEU baseline | BLEU diagnostic | chrF2 baseline | chrF2 diagnostic |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chinese to English | 3.2650395485 | 3.2580416153 | 24.8850987607 | 25.0255980425 | 51.8996216594 | 52.0700613905 |
| English to Chinese | 4.1427683151 | 4.2114682663 | 30.9933623589 | 30.7518608208 | 28.3749530799 | 28.2081604901 |

The teacher-target rescue therefore produced a small Chinese-to-English improvement while regressing every measured English-to-Chinese metric, the direction it was intended to rescue. It is not a case where sequence metrics improved globally while NLL regressed.

An independent row-by-row semantic audit preserved every source field and automatic corruption marker. Baseline results were 34/50 passed with six fatal rows for Chinese-to-English and 24/50 passed with seven fatal rows for English-to-Chinese. Diagnostic results fell to 33/50 with six fatal rows and 23/50 with six fatal rows respectively. Audited JSONL SHA-256 values are `cc7abf715bdfcecaf151f35d5695b25078cfb181ab5c5f075ede7613322c33ab` (baseline) and `2d0c6c0469e8744095db7617039bc40f43d4c64596106fd2284c3646b0bbdafb` (diagnostic); the audit comparison SHA-256 is `83da948576d41a9bf20fb840bf52469606d7e8d3ff00b82ea1cf10aceef4c539`. Pass status changed only for IDs 39, 64, 76, and 95; only ID 76 improved while the other three regressed.

The failed first diagnostic attempt consumed an observed 21.7490849 seconds, baseline evaluation consumed 251.829 seconds, and diagnostic evaluation consumed 293.359 seconds. All are retained in the translation ledger: 27,338.577 + 566.9370849 = 27,905.5140849 cumulative seconds, leaving 15,294.4859151 seconds. No ONNX export, HarmonyOS packaging, promotion, or second rescue epoch was performed from the rejected weights.

## Minimal v5 design: resume original BiST training

The smallest evidence-backed next experiment is not another teacher-target rescue. It is one additional bounded epoch of the original 1:1 BiST objectives from the exact step-16,878 training state. The retained `resume.pt` is 206,519,930 bytes with SHA-256 `f9b78ef7f07476881d76ff724188558ed461b9b026113d2ed3de692c8ba29a6d`; it records optimizer step 16,878, epoch index 11, plan cursor 5,626, the 149-entry AdamW state, GradScaler state, Python/Torch/CUDA RNG states, and 13,924.157 seconds. All 155 model tensors are byte-value equal to the selected step-16,878 checkpoint.

Before launch, a v5 continuation contract must test and bind that resume hash/cursor, the original pinned BiST manifest and six artifacts, the original tokenizer/config, the selected model hash, validation history, and the reconciled 27,905.5140849-second budget root. Execution must occur in a new artifact directory and restore model, optimizer, scaler, RNG, epoch, and plan cursor without resetting any of them. It must use the original `zh-en.train.jsonl` and `en-zh.train.jsonl`; the distilled teacher view is forbidden.

The proposed ceiling is one additional epoch only (global final step 18,284), at most 2,400 additional GPU seconds, with validation at global steps 17,000, 18,000, and the final step. Each validation must record both directional losses. A checkpoint is eligible only if English-to-Chinese validation loss is strictly below 4.1427683151 and Chinese-to-English validation loss is strictly below 3.2650395485; two consecutive checks without a jointly improving checkpoint stop the run. Test BLEU/chrF2 and the 100-row manual audit run only once on a validation-eligible strict best, never for checkpoint selection. Even then, export remains blocked until the existing manual and FLORES promotion gate passes. No v5 GPU job starts until these contracts and their fail-closed tests pass.
