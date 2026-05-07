# LESS IS MORE — Executable Assessment

Assess whether the skill's instruction file (`uncompressed.md`, `SKILL.md`,
`instructions.txt`) contains non-load-bearing content — sentences, sections,
or rules the model doesn't need to produce correct output.

---

## How to make this assessment

### Step 1 — Identify the instruction file(s)

Separate instruction files from spec files:

- `spec.md` — spec; may be verbose; NOT a target for this topic
- `uncompressed.md` or `instructions.txt` — instruction file; primary target
- `SKILL.md` — compressed instruction surface; secondary target

Apply this topic only to instruction files.

### Step 2 — Run the subtraction test

For each sentence in the instruction file, ask:

> If this sentence were removed, would a capable model still execute the
> skill correctly?

**Yes → load-bearing. Keep.**
**No → overhead. Candidate for removal.**

Overhead patterns:

- Restating the obvious: "you are analyzing a skill file"
- Hedging: "try to ensure that...", "when possible..."
- Motivational framing: "this is important because..."
- Meta-commentary: "the following section is critical"
- Redundant restatement: same constraint said twice in different words

Do NOT remove:

- Negative constraints ("do not modify skill files")
- Branching conditions with real decision points
- Output format specifications
- Precondition checks
- Unique information not derivable from context

### Step 3 — Check for complexity inflation

Look for clusters of 3+ rules that address the same underlying behavior.
Signals:

- Three bullet points all saying "don't do X" in slightly different ways
- Multiple rules that are all compensating for one unclear upstream instruction
- Rules added to "reinforce" a point already made

If found, trace the root cause: what is the one instruction that, if
written more precisely, collapses all three rules into nothing?

### Step 4 — Check for spec content in instruction file

Signal: the instruction file contains "why" explanations, design rationale,
or criteria descriptions that a model doesn't need to follow the procedure.

Specs belong in `spec.md`. Instructions belong in `uncompressed.md`.

### Step 5 — Produce finding or confirm clean

Only produce a finding when the issue is **significant** — not for single
sentences. The overhead should be meaningful relative to file size.

**Finding format:**

```md
### LESS IS MORE — HIGH | MEDIUM | LOW

**Signal:** <what was found — section name, pattern>

**Reasoning:** <why it's overhead, not load-bearing>

**Recommendation:** <specific removal or consolidation>
```

**Severity:**

- HIGH — instruction file has grown substantially; significant non-load-
  bearing sections; model must wade through overhead on every invocation
- MEDIUM — notable overhead in a specific section; or 3+ redundant rules
- LOW — single section with minor overhead; or spec content leaking into
  one paragraph of instructions

**Confirm clean when:** every sentence in the instruction file is load-
bearing — removing it would cause a model to produce wrong output.

---
