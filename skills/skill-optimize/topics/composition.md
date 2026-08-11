# COMPOSITION — Executable Assessment

Assess whether the skill is structured at the right granularity — not too
monolithic, not over-split. Focus on whether any single invocation loads more
context than it needs, or whether related operations should be grouped.

---

## How to make this assessment

### Step 1 — Map the invocation paths

Read the skill inputs and steps. How many distinct paths can a caller take?

- Path A: `<topic>` provided — skip assessor, go direct to Step 4
- Path B: no topic — assessor pass (Steps 3a-3b), then Step 4
- Path C: `assess-only` mode — Steps 1-3b only, stop

Each path loads the full instruction file regardless. Note what each path
actually needs vs. what it's forced to load.

### Step 2 — Check for sub-procedure bundling

Does the skill combine multiple independently invokable operations that
share no state between them? Signals:

- Multiple modes (e.g., `assess-only` vs. full analysis) that could be
  separate entry points
- Long topic index table that all paths must scan even when a topic is
  pre-selected
- Sub-agent prompt templates that the host reads and passes through but
  doesn't execute itself

### Step 3 — Check for routing layer opportunity

If the skill has grown a large index (many topics, long descriptions), a
routing layer could let callers load only the relevant topic procedure
rather than the full menu.

Current structure: `uncompressed.md` embeds the full topic index as a
fallback heuristic table AND embeds the sub-agent prompts AND contains the
host orchestration logic — all in one file.

### Step 4 — Apply context efficiency test

For each invocation path, estimate: what fraction of `uncompressed.md` is
actually used?

- Direct topic invocation: Steps 1, 2, 4, 5, 6 + the topic spec. The
  assessor block (Step 3), fallback heuristic table, and topic index are
  loaded but not used.
- Assessor path: everything is potentially relevant, but the topic index
  is only scanned once, not iterated.

If a significant section is loaded but never used on the most common path,
that's a partitioning opportunity.

### Step 5 — Produce finding or confirm clean

**Finding format:**

```md
### COMPOSITION — HIGH | MEDIUM | LOW

**Signal:** <what is bundled; which paths load unused content>

**Reasoning:** <context efficiency impact; E = I₀/C estimate>

**Recommendation:** <specific partitioning or routing change>
```

**Severity:**

- HIGH — most invocations load <30% relevant content; clear split available
- MEDIUM — common path loads 40-60% relevant content; split would help
- LOW — most content is relevant to most paths; minor restructuring only

---
