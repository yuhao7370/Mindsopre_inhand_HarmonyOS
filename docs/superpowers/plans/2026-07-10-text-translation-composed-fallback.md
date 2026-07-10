# Text Translation Composed Fallback Plan

## Goal

Improve the existing offline text-translation fallback without pretending to
replace HMS cloud translation.

## Steps

1. Keep exact phrase translation and Android target-language behavior.
2. Add deterministic composition for adjacent known Chinese phrases and
   whitespace-separated known English phrases.
3. Preserve honest failure for any unknown segment.
4. Cover punctuation, mixed known phrases, and unknown-tail failures in unit
   tests.
5. Update platform-differences documentation.
