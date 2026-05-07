# VERIFICATION STRATEGY — Executable Assessment

Assess whether the skill defines what counts as correct — what it treats
as ground truth, how it checks claims, and what confidence level attaches
to different outputs.

---

## How to make this assessment

### Step 1 — Identify must-verify vs. can-assume

For each claim the skill produces:
- **Must verify** — finding severity, action recommendation, finding text
- **Can assume** — that the skill files exist (checked at Step 1), that
  the log format is valid (written by the skill itself)

Does the skill distinguish these, or does it treat all outputs equally?

### Step 2 — Check primary source usage

For every finding: does the analysis read the actual skill files, or
does it rely on summaries or cached state?

- Sub-agent in Step 4 receives all source files directly ✓ or ✗?
- Qualifier in Step 3a receives "one-line descriptions only" ✗

### Step 3 — Check confidence labeling

When the skill is uncertain, does it surface the uncertainty?
Signals: `APPLICABLE: yes | maybe` in qualifier output is a confidence
indicator. Does the downstream flow treat `maybe` differently?

### Step 4 — Produce finding or confirm clean

---
