### Task 7: Generate and Validate Digit Test Images

**Files:**
- Add: `test-assets/handwritten-digits/digit-2.png`
- Add: `test-assets/handwritten-digits/digit-7.png`
- Add: `test-assets/handwritten-digits/digit-9.png`
- Add: `test-assets/handwritten-digits/README.md`
- Add: `scripts/validate-mnist-test-assets.py`
- Add: `scripts/test-mnist-test-assets-guard.ps1`

- [ ] Use built-in ImageGen in three separate calls: one black handwritten digit on near-white paper per image, no text/watermark/decoration.
- [ ] Copy each generated image into `test-assets/handwritten-digits/`.
- [ ] Validate all three with the desktop MindIR and the same preprocessing constants; reject and regenerate any wrong prediction.
- [ ] Record prompts, expected labels, dimensions, SHA-256, and validation result.
- [ ] Run the asset guard.
- [ ] Commit:

```powershell
git add -- test-assets/handwritten-digits `
  scripts/validate-mnist-test-assets.py scripts/test-mnist-test-assets-guard.ps1
git commit -m "test(ai): add handwritten digit fixtures"
```

---
