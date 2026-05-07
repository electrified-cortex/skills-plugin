# EXAMPLES — Executable Assessment

Assess whether the skill's output format or judgment calibration would
benefit materially from 1-3 targeted concrete examples.

---

## How to make this assessment

### Step 1 — Identify format-sensitive outputs

Read the topic procedure files and `uncompressed.md`. What does the skill
produce that has a specific shape?

- Finding format block (`### TOPIC — SEVERITY`)
- Log row format (`| TOPIC | date | model | N | status | action |`)
- Report file format (`.optimization/<slug>.md`)
- Qualifier output format (`TOPIC: / APPLICABLE: / REASON:`)

For each: is the format described only in prose/template, or is there a
concrete filled-in example showing real content?

### Step 2 — Identify judgment-calibration outputs

Where does the skill make a categorization that isn't fully determined
by explicit rules?

- Severity (HIGH / MEDIUM / LOW / CLEAN) — is the boundary between
  categories shown by example, or only described abstractly?
- `applicable: yes | maybe` — is the distinction shown by example?
- Status values (`acted` / `deferred` / etc.) — are real-usage examples
  in the log sufficient, or are new callers likely to miscategorize?

### Step 3 — Assess whether examples would close a real gap

For each format or judgment point identified:
- Would a concrete filled-in example make the output more consistent?
- Is there currently anything a caller could look at as a reference?

Note: the optimize-log itself serves as a calibration reference for
severity/status — real entries are examples of prior outputs. If the
log is populated and visible to the sub-agent, it partly fills the
example gap.

### Step 4 — Produce finding or confirm clean

```
### EXAMPLES — HIGH | MEDIUM | LOW

**Signal:** <which output lacks an example; what ambiguity results>

**Recommendation:** <what a short example should show>
```

---
