# EVALUATION HARNESS — Executable Assessment

Assess whether the skill has a mechanism to verify that optimizations
actually improve it and don't introduce regressions.

---

## How to make this assessment

### Step 1 — Check for benchmark inputs

Does the skill or its repo have any defined test cases — known-good skills
to produce CLEAN verdicts, known-bad skills to produce specific findings?

### Step 2 — Check for regression guard

Is there any mechanism to detect if a recent change caused the skill
to produce worse output on a previously-passing case?

### Step 3 — Assess evaluatability

Is the skill's output structured enough to score automatically?
The optimize-log + `.optimization/` report format is structured. But
scoring "is this finding correct" is itself a judgment call, not a
deterministic check.

### Step 4 — Produce finding or confirm clean

---
