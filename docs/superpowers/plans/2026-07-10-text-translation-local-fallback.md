# Text Translation Local Fallback Plan

## Goal

Make Text Translation produce useful offline results for common demo phrases when no HMS/cloud translation runner is injected.

## Constraints

- Do not migrate Android APK update/download behavior.
- Preserve Android text/image input behavior and default target-language rule.
- Keep explicit `TextTranslationRunner` injection ahead of the fallback.
- Keep the fallback honest: translate known phrases, fail unknown text instead of inventing output.
- Document that this is not equivalent to Android HMS cloud translation.

## Steps

1. Add failing tests for local Chinese-to-English and English-to-Chinese fallback translation.
2. Update runtime factory tests so text translation no longer returns platform unsupported by default for known text.
3. Implement a small rule-based `LocalTextTranslationRunner`.
4. Wire the default Harmony text translation service to use it.
5. Update platform-difference docs, then run unit tests, HAP build, whitespace checks, and review.
