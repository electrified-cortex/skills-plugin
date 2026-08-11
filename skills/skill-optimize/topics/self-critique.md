# SELF CRITIQUE — Executable Assessment

Assess whether the skill includes a verification pass for its own judgment
outputs. For assessment-heavy skills, a within-turn self-review reduces
severity miscalibration and premature "clean" calls.

---

## How to make this assessment

### Step 1 — Identify judgment outputs

Read the topic procedure files. What verdicts or ratings does the analysis
step produce?

- Severity rating: HIGH / MEDIUM / LOW / CLEAN
- Finding text: the specific issue identified
- Action recommendation: what to change

These are judgment outputs — they carry risk if wrong.

### Step 2 — Check for existing verification pass

Does any step in `uncompressed.md` or the topic procedure instruct the
model to review its own finding before writing it?

Signals that a review pass exists:
- "Review: does this finding hold under the evidence?"
- "Check: is the severity calibrated correctly?"
- A separate "verify" step after the finding is drafted
- Explicit instruction to reconsider a clean verdict before finalizing

### Step 3 — Assess the cost/benefit tradeoff

Self-critique adds token cost within the same turn. Is this skill's error
cost high enough to justify it?

Consider:
- What happens if a finding is wrong? (unnecessary change, missed issue)
- Is the skill downstream-trusted without independent verification?
- Are the topic criteria explicit enough that a review pass would actually
  catch miscalibration?

### Step 4 — Produce finding or confirm clean

```
### SELF CRITIQUE — HIGH | MEDIUM | LOW

**Signal:** <what outputs lack a review pass>

**Reasoning:** <downstream risk; cost/benefit of adding a review step>

**Recommendation:** <where to add the review instruction>
```

---
