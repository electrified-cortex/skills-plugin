# COMPRESSIBILITY — Executable Assessment

Assess whether the skill's instruction file is tighter than it needs to
be. Match instruction style to the actual cognitive demand of the task.

---

## How to make this assessment

### Step 1 — Identify cognitive demand type

Read the skill's purpose and steps. Classify each step:

- **Deterministic** — file reads, log writes, format checks, rule
  application. Optimal form: tables, decision trees, minimal prose.
- **Probabilistic / judgment** — assessments, ranking, scoring. Optimal
  form: criteria with why-context. Some prose load-bearing.
- **Creative** — generation, synthesis. Optimal form: intent + examples.
  Why-context may matter more than steps.

Mismatch between cognitive demand and instruction style = finding.

### Step 2 — Scan for prose in deterministic steps

For each step that is deterministic (rule application, file I/O, log
writing), count the prose-to-rule ratio. If the step has paragraphs of
explanation for a mechanical operation, that's overhead.

Signals:

- "The log records which topics have been analyzed, when, and what was
  found. Use it to: (three-item bulleted list)" — this is background
  context the model doesn't need to parse a log. A one-line format spec
  does the same job.
- Multiple nested conditions described in prose when a table would suffice.

### Step 3 — Check for duplicate format specifications

If the same format (log header, output schema, field list) appears more
than once in the instruction file, that's duplication overhead.

Every format spec should appear once — in the most authoritative location
— and be referenced elsewhere rather than repeated.

### Step 4 — Check for SKILL.md existence

The SKILL.md surface is the compressed runtime version of the instructions.
Without it, every invocation must load the full verbose file.

If SKILL.md doesn't exist, this is a compressibility finding —
the compression work hasn't been done yet. The finding recommends
creating SKILL.md by stripping orientation prose, collapsing inline
sub-agent prompts to references, and condensing the topic index.

### Step 5 — Check for partitioning opportunity

If the instructions cover multiple distinct sub-procedures (e.g.,
assessment path + topic analysis path), could they be separate sub-skills
that are dispatched independently? If so, each invocation only loads the
relevant sub-skill's context.

### Step 6 — Produce finding or confirm clean

**Finding format:**

```md
### COMPRESSIBILITY — HIGH | MEDIUM | LOW

**Signal:** <where the overhead is — section name, pattern>

**Reasoning:** <what cognitive demand is present; why prose is overhead
vs. load-bearing>

**Recommendation:** <specific compression strategy>
```

**Severity:**

- HIGH — most of the instruction file is prose overhead; decision trees
  or tables would replace it; SKILL.md doesn't exist for a complex skill
- MEDIUM — one significant section is over-specified relative to its
  cognitive demand; OR duplicate format specs; OR SKILL.md missing for a
  moderately complex skill
- LOW — minor prose overhead in one or two steps; SKILL.md missing for
  a simple skill

---
