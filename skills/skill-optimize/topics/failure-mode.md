# FAILURE MODE — Executable Assessment

Assess whether the skill documents and handles the ways it can silently
produce wrong output — not runtime errors, but semantic failures.

---

## How to make this assessment

### Step 1 — Identify semantic failure conditions

Read `uncompressed.md`. What could cause the skill to execute without
error but produce a wrong, incomplete, or not-useful result?

Common failure modes to check:
- Insufficient input quality (skill files are too sparse to analyze)
- Conflicting instructions from multiple sources
- Missing tool access (no sub-agent dispatch available)
- Low-confidence judgment producing over-confident output
- Partial completion producing an apparently-complete result

### Step 2 — Check for existing confidence labeling

Does the skill label outputs as uncertain when conditions for certainty
aren't met? Look for:
- "I could not determine" / "insufficient evidence"
- `maybe` vs. `yes` distinction in qualifier
- Any "low confidence" flag in finding output

### Step 3 — Produce finding or confirm clean

---
