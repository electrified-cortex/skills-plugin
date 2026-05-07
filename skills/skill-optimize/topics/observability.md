# OBSERVABILITY — Executable Assessment

Assess whether the skill produces enough signal to be debuggable and
trustworthy — decision transparency, intermediate state, error context.

---

## How to make this assessment

### Step 1 — Check decision transparency

For every verdict or categorization the skill produces, is there a
rationale trace in the output?

- Finding severity with `**Reasoning:**` field — traceable ✓
- Assessor topic selection — emits `Assessor selected: <SLUG> — <reason>` ✓
- `TOPIC: none` result — what reasoning led to that? (just says "none apply")

### Step 2 — Check intermediate state surfacing

For multi-step skills: does the output surface enough intermediate state?

- Qualifier output is intermediate state. Is it exposed to the caller?
- Step 4 sub-agent output — is it passed through or only the summary?

### Step 3 — Check error context quality

For the error messages in the skill: are they diagnostic or generic?

Review every `ERROR:` message defined in the skill.

### Step 4 — Check audit log sufficiency

Can the optimize-log be used to reconstruct what happened without re-running?

What's in the log: topic, date, model, N findings, status, action. ✓
What's NOT in the log: which source files were read, what the actual
finding text was (those live in `.optimization/`).

### Step 5 — Produce finding or confirm clean

---
