# CHAIN OF THOUGHT — Executable Assessment

Assess whether the skill needs explicit reasoning elicitation to produce
correct verdict quality, and whether the current form provides it.

---

## How to make this assessment

### Step 1 — Identify judgment calls in the skill

Read the topic procedure files and `uncompressed.md`. List every place
where the skill produces a verdict that requires weighing evidence:

- Severity ratings (HIGH / MEDIUM / LOW / CLEAN)
- `applicable: yes | maybe` qualification decision
- Assessor pick (best topic from qualifier results)
- Finding text: does it require multi-signal synthesis?

### Step 2 — Check for existing reasoning elicitation

For each judgment call: does the instruction explicitly ask the model to
reason before concluding?

Signals that reasoning is elicited:

- "Reason through the evidence before producing the finding"
- "Consider X, Y, Z then determine..."
- A structured evidence block before the verdict template

Signals that reasoning is NOT elicited:

- "Produce finding in this format:" — direct output with no reasoning step
- Template with verdict field but no reasoning field
- The self-critique step added in SELF CRITIQUE covers review, but not
  reasoning-before-conclusion

### Step 3 — Assess minimum viable form needed

For each judgment call: what's the minimum reasoning form?

- **Inline justification** in the finding (`**Reasoning:** ...`) —
  already present in the finding template. This IS a form of reasoning
  elicitation: requiring a `**Reasoning:**` field forces the model to
  produce justification inline.
- **Pre-verdict scratchpad**: only if inline reasoning is insufficient.
- **Separate analysis pass**: only if multi-signal synthesis is too
  complex for inline justification.

### Step 4 — Produce finding or confirm clean

---
