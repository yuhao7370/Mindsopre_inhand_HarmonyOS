# Local Translation Runtime Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce practical corruption from the existing offline Chinese-English model by normalizing OCR letter spacing and preserving URLs, emails, and code identifiers without changing model assets.

**Architecture:** A pure policy module segments normalized input into ordered `model` and `protected` spans. A pinned Python A/B evaluator must prove the policy decreases automatic fatal corruption before the same contract is integrated into the ArkTS MindSpore Lite runner.

**Tech Stack:** Python 3.9.7, `unittest`, pinned PyTorch/Transformers/SentencePiece evaluation environment, ArkTS, Hypium, MindSpore Lite.

## Global Constraints

- Keep translation fully offline; add no server, network fallback, or dictionary fallback.
- Keep the existing V5 model, tokenizer, graph archive, and package hashes unchanged.
- Protect only URLs, emails, and code-like identifiers; do not heuristically protect plain numbers, dates, names, or ordinary hyphenated words.
- Collapse OCR spacing only for runs of at least three single ASCII letters separated by one space; two or more spaces remain word boundaries.
- Do not train on the fixed manual evaluation set.
- Do not claim production quality or real-device performance.

---

### Task 1: Define And Test The Host Input Policy

**Files:**
- Create: `tools/translation/runtime_input_policy.py`
- Create: `tools/translation/test_runtime_input_policy.py`

**Interfaces:**
- Produces: `TranslationSegment(kind: Literal["model", "protected"], text: str)`.
- Produces: `normalize_ocr_letter_spacing(text: str) -> str`.
- Produces: `prepare_translation_segments(text: str) -> list[TranslationSegment]`.
- Produces: `translate_with_policy(text: str, translate: Callable[[list[str]], list[str]]) -> str`.

- [ ] **Step 1: Write failing OCR normalization tests**

```python
class RuntimeInputPolicyTest(unittest.TestCase):
    def test_collapses_only_three_or_more_single_ascii_letters(self):
        self.assertEqual(
            normalize_ocr_letter_spacing("P L E A S E   K E E P   C L E A R"),
            "PLEASE KEEP CLEAR",
        )
        self.assertEqual(normalize_ocr_letter_spacing("A B test"), "A B test")
        self.assertEqual(normalize_ocr_letter_spacing("中文 A B C"), "中文 ABC")

    def test_preserves_newlines_and_wide_word_boundaries(self):
        self.assertEqual(
            normalize_ocr_letter_spacing("I N V O I C E\r\nN O.  B-3017"),
            "INVOICE\r\nN O.  B-3017",
        )
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
python -m unittest tools.translation.test_runtime_input_policy -v
```

Expected: import failure because `runtime_input_policy.py` does not exist.

- [ ] **Step 3: Implement the minimal OCR normalizer**

```python
import re

_OCR_LETTER_RUN = re.compile(r"(?<![A-Za-z])(?:[A-Za-z] ){2,}[A-Za-z](?![A-Za-z])")


def normalize_ocr_letter_spacing(text: str) -> str:
    if not isinstance(text, str):
        raise TypeError("translation input must be a string")
    return _OCR_LETTER_RUN.sub(lambda match: match.group(0).replace(" ", ""), text)
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: both OCR tests pass.

- [ ] **Step 5: Write failing protected-span and composition tests**

```python
    def test_protects_only_exact_data_spans(self):
        segments = prepare_translation_segments(
            "Open https://example.com/help, mail a.b+1@example.org, then use report_v5 or B-3017."
        )
        self.assertEqual(
            [(item.kind, item.text) for item in segments],
            [
                ("model", "Open "),
                ("protected", "https://example.com/help"),
                ("model", ", mail "),
                ("protected", "a.b+1@example.org"),
                ("model", ", then use "),
                ("protected", "report_v5"),
                ("model", " or "),
                ("protected", "B-3017"),
                ("model", "."),
            ],
        )

    def test_does_not_protect_dates_names_or_words(self):
        text = "OpenAI met Alice on 2025-12-09 for state-of-the-art work."
        self.assertEqual(prepare_translation_segments(text), [TranslationSegment("model", text)])

    def test_translates_model_spans_and_copies_protected_spans(self):
        calls = []
        def translate(values):
            calls.append(values)
            return [value.upper() for value in values]
        self.assertEqual(
            translate_with_policy("open report_v5 at https://example.com/help", translate),
            "OPEN report_v5 AT https://example.com/help",
        )
        self.assertEqual(calls, [["open ", " at "]])

    def test_protected_only_input_does_not_call_model(self):
        self.assertEqual(
            translate_with_policy("https://example.com/help", lambda _: self.fail("called")),
            "https://example.com/help",
        )
```

- [ ] **Step 6: Run the focused test and verify RED**

Expected: failures because segmentation and composition are not implemented.

- [ ] **Step 7: Implement minimal deterministic segmentation**

Use three explicit regular expressions in precedence order: URL, email, then
code token. Trim terminal `.,;!?)]}` from URL matches back into model text.
Accept a code token only when it contains `_`, or contains at least one ASCII
letter, at least one digit, and at least one `-_.\/:` separator. Merge adjacent
segments of the same kind and discard empty segments.

```python
@dataclass(frozen=True)
class TranslationSegment:
    kind: Literal["model", "protected"]
    text: str


def prepare_translation_segments(text: str) -> list[TranslationSegment]:
    normalized = normalize_ocr_letter_spacing(text)
    matches = _non_overlapping_protected_matches(normalized)
    return _segments_from_matches(normalized, matches)


def translate_with_policy(text: str, translate: Callable[[list[str]], list[str]]) -> str:
    segments = prepare_translation_segments(text)
    model_texts = [item.text for item in segments if item.kind == "model"]
    outputs = translate(model_texts) if model_texts else []
    if len(outputs) != len(model_texts) or any(not value for value in outputs):
        raise RuntimeInputPolicyError("model output count differs")
    iterator = iter(outputs)
    return "".join(next(iterator) if item.kind == "model" else item.text for item in segments)
```

- [ ] **Step 8: Run focused and existing Python translation tests**

Run:

```powershell
python -m unittest tools.translation.test_runtime_input_policy -v
python -m unittest discover -s tools/translation -p 'test_*.py'
```

Expected: all tests pass.

- [ ] **Step 9: Commit the host policy**

```powershell
git add -- tools/translation/runtime_input_policy.py tools/translation/test_runtime_input_policy.py
git commit -m "feat: protect local translation data spans"
```

### Task 2: Run A/B Against The Retained Exact V5 Checkpoint

**Files:**
- Create: `tools/translation/evaluate_runtime_input_policy.py`
- Create: `tools/translation/test_evaluate_runtime_input_policy.py`
- Create after successful run: `tools/translation/reports/runtime-input-policy-v1.md`

**Interfaces:**
- Consumes: `prepare_translation_segments()` and `translate_with_policy()` from Task 1.
- Consumes: `load_runtime()`, `translate_texts()`, `load_manual_set()`, and `corruption_reasons()` from `evaluate_translation.py`.
- Produces: canonical `runtime-input-policy-evaluation-v1.json` in a new external artifact directory.
- Produces: `evaluate_gate(baseline_rows, policy_rows) -> dict` with per-direction and total corruption counts.
- Produces: `validate_bound_hashes(checkpoint_sha256, tokenizer_sha256) -> None`.

- [ ] **Step 1: Write failing gate tests with injected outputs**

```python
class RuntimeInputPolicyEvaluationTest(unittest.TestCase):
    def test_gate_requires_strict_total_improvement_without_direction_regression(self):
        baseline = [row("zh-en", ["url"]), row("en-zh", ["proper-name"])]
        improved = [row("zh-en", []), row("en-zh", ["proper-name"])]
        self.assertTrue(evaluate_gate(baseline, improved)["passed"])
        regressed = [row("zh-en", []), row("en-zh", ["proper-name", "url"])]
        self.assertFalse(evaluate_gate(baseline, regressed)["passed"])

    def test_report_rejects_changed_checkpoint_or_tokenizer_hash(self):
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            validate_bound_hashes("0" * 64, EXPECTED_TOKENIZER_SHA256)
```

- [ ] **Step 2: Run the evaluator test and verify RED**

Run:

```powershell
python -m unittest tools.translation.test_evaluate_runtime_input_policy -v
```

Expected: import failure because the evaluator does not exist.

- [ ] **Step 3: Implement the minimal fail-closed evaluator**

The evaluator must:

1. reuse `validate_v5_binding()` to verify the exact V5 terminal, budget, and checkpoint inventory;
2. verify the fixed manual JSONL and baseline raw-result SHA-256;
3. load the model once and generate only policy outputs;
4. call the model in batches grouped by direction and restore protected spans in original order;
5. calculate `corruption_reasons(source, output, reference)` for every row;
6. require no per-direction flag-count increase and at least one total flag decrease;
7. record checkpoint, tokenizer, policy code, input, output, and report hashes in canonical JSON;
8. write only to a new external output directory.

```python
def evaluate_gate(baseline_rows, policy_rows):
    baseline = _flag_counts(baseline_rows)
    policy = _flag_counts(policy_rows)
    direction_safe = all(policy[name] <= baseline[name] for name in ("zh-en", "en-zh"))
    total_improved = sum(policy.values()) < sum(baseline.values())
    return {"passed": direction_safe and total_improved, "baseline": baseline, "policy": policy}
```

- [ ] **Step 4: Run evaluator tests and verify GREEN**

Run the command from Step 2.

Expected: all evaluator tests pass.

- [ ] **Step 5: Run the pinned V5 A/B evaluation**

Use the retained Python 3.9 environment and artifacts:

```powershell
$root = Join-Path $env:LOCALAPPDATA 'Temp\translation-t3-marian'
$python = Join-Path $root 'venv\Scripts\python.exe'
& $python -m tools.translation.evaluate_runtime_input_policy `
  --v5-terminal (Join-Path $root 'v5-original-bist-epoch13-v2\v5-terminal-v1.json') `
  --budget-terminal (Join-Path $root 'v5-original-bist-epoch13-v2\budget-terminal-v1.json') `
  --manual tools/translation/manual-eval-v1.jsonl `
  --baseline-results (Join-Path $root 'v5-candidate-quality-eval-v1\manual-results-raw-v5-candidate-v1.jsonl') `
  --output-root (Join-Path $root 'runtime-input-policy-eval-v1')
```

Expected: exit `0`, `gate.passed=true`, no direction regresses, and the total automatic corruption count decreases.

- [ ] **Step 6: Stop if the A/B gate fails**

If the command exits non-zero or the gate is false, do not touch ArkTS. Record
the exact failure in the report and return to design; do not weaken patterns,
change thresholds, train on the manual set, or claim improvement.

- [ ] **Step 7: Record the successful evidence summary**

Write `runtime-input-policy-v1.md` with exact artifact hashes, baseline and
policy counts per direction, changed row IDs, unchanged model/tokenizer hashes,
and the explicit local-learning/device limitations.

- [ ] **Step 8: Run all Python translation tests and commit**

```powershell
python -m unittest discover -s tools/translation -p 'test_*.py'
git add -- tools/translation/evaluate_runtime_input_policy.py tools/translation/test_evaluate_runtime_input_policy.py tools/translation/reports/runtime-input-policy-v1.md
git commit -m "test: qualify local translation input policy"
```

### Task 3: Port The Approved Policy To ArkTS

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationInputPolicy.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`

**Interfaces:**
- Produces: `TranslationInputSegmentKind = 'model' | 'protected'`.
- Produces: `TranslationInputSegment { readonly kind; readonly text; }`.
- Produces: `normalizeOcrLetterSpacing(text: string): string`.
- Produces: `prepareTranslationInput(text: string): Array<TranslationInputSegment>`.
- Consumes: existing `encodeTranslationText()` and `decodeChunk()` without changing tensor or tokenizer contracts.

- [ ] **Step 1: Add failing pure ArkTS policy tests**

Add tests equivalent to every Task 1 fixture, plus:

```typescript
it('preservesProtectedInputOrderAroundNewlines', 0, () => {
  const segments = prepareTranslationInput('Open report_v5\nhttps://example.com/help');
  expect(serializedSegments(segments)).assertEqual(
    'model:Open |protected:report_v5|model:\n|protected:https://example.com/help'
  );
});

it('keepsPlainDatesNamesAndHyphenatedWordsInModelContext', 0, () => {
  const text = 'OpenAI met Alice on 2025-12-09 for state-of-the-art work.';
  expect(serializedSegments(prepareTranslationInput(text))).assertEqual(`model:${text}`);
});
```

- [ ] **Step 2: Run Hypium and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon'
```

Expected: ArkTS compile failure because `TranslationInputPolicy.ets` is missing.

- [ ] **Step 3: Implement the smallest pure ArkTS policy**

Use explicit character predicates and linear scans rather than a platform regex
dependency. Match the same URL, email, and code-token boundaries and the same
OCR threshold as the approved Python policy. Merge adjacent same-kind segments.

```typescript
export type TranslationInputSegmentKind = 'model' | 'protected';

export interface TranslationInputSegment {
  readonly kind: TranslationInputSegmentKind;
  readonly text: string;
}

export function prepareTranslationInput(text: string): Array<TranslationInputSegment> {
  const normalized = normalizeOcrLetterSpacing(text);
  return segmentsFromProtectedRanges(normalized, protectedRanges(normalized));
}
```

- [ ] **Step 4: Run Hypium and verify the pure tests GREEN**

Expected: all tests pass, including the previous 473 cases plus the new policy cases.

- [ ] **Step 5: Add failing runner integration tests**

Use the existing deterministic fake translation bundle/session. Require that:

- protected-only text returns unchanged and performs no inference;
- mixed text infers only `model` spans and preserves protected spans exactly;
- a failed model span fails the whole request;
- `sourceText` remains the original unnormalized input;
- CRLF/LF order remains exact.

- [ ] **Step 6: Run the integration tests and verify RED**

Expected: mixed/protected-only assertions fail because the runner still sends the complete source to the model.

- [ ] **Step 7: Integrate the policy without changing tensor code**

Replace the single `encodeTranslationText(text, targetLanguage)` call with
`prepareTranslationInput(text)`. Inside the existing serialized request queue,
append protected text directly and run the unchanged encode/decode loop for
each model segment. Keep original input in success and failure results.

```typescript
for (let index = 0; index < segments.length; index++) {
  const segment = segments[index];
  if (segment.kind === 'protected') {
    translatedText += segment.text;
    continue;
  }
  const chunks = encodeTranslationText(segment.text, targetLanguage);
  translatedText += await translateChunksToText(bundle, chunks);
}
```

- [ ] **Step 8: Run focused and full Hypium tests**

Run the command from Step 2.

Expected: zero failures and errors; record the new total test count.

- [ ] **Step 9: Commit the ArkTS integration**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationInputPolicy.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets
git commit -m "feat: preserve exact spans in local translation"
```

### Task 4: Document And Verify The Unchanged Package Boundary

**Files:**
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: successful A/B report and ArkTS integration from Tasks 2–3.
- Produces: final evidence that runtime quality improved while model assets stayed byte-identical.

- [ ] **Step 1: Update the translation platform note**

Document OCR letter normalization, exact protected spans, protected-only
behavior, the measured host A/B delta, unchanged model/package hashes, and the
remaining semantic/manual-quality and device limitations.

- [ ] **Step 2: Run focused guards**

```powershell
python -m unittest tools.translation.test_runtime_input_policy tools.translation.test_evaluate_runtime_input_policy -v
powershell -ExecutionPolicy Bypass -File .\Mindspore_inhand_HarmonyOS\scripts\check-text-translation-input-parity.ps1
powershell -ExecutionPolicy Bypass -File .\Mindspore_inhand_HarmonyOS\scripts\verify-translation-model.ps1 -ReleaseEvidencePath .\tools\translation\manifests\local-learning-authorization-v1.json
```

Expected: all commands exit `0` and the package verifier reports the existing archive SHA-256.

- [ ] **Step 3: Run full host verification**

```powershell
python -m unittest discover -s tools/translation -p 'test_*.py'
Set-Location Mindspore_inhand_HarmonyOS
cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon'
Set-Location ..
git diff --check
git status --short
```

Expected: Python and Hypium suites pass, `git diff --check` is silent, and only the intended documentation change is uncommitted.

- [ ] **Step 4: Commit documentation**

```powershell
git add -- docs/harmonyos-platform-differences.md
git commit -m "docs: record local translation quality policy"
```

- [ ] **Step 5: Run final branch verification**

Repeat Task 4 Steps 2–3 after the commit and confirm the worktree is clean.
