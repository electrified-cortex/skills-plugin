# PROGRESSIVE OPTIMIZATION — Executable Assessment

Assess whether the skill's topic priority ordering is correct and whether
the current tracking infrastructure captures what it needs to.

---

## How to make this assessment

### Step 1 — Compare tier ranking in the spec vs. the topic index

The draft impact tier ranking (to be validated empirically), high to low: Tier 1 dispatch, model selection, wording, determinism; Tier 2 compressability, less-is-more, composition, chain-of-thought; Tier 3 hash record, output format, examples, self-critique; Tier 4 tool signatures, reuse. Tiers run in order, so a partial run captures the most actionable findings.
The execution order is the priority list in `_index.md`.
Check: are they aligned?

### Step 2 — Check tracking infrastructure

Does the skill's current tracking give enough information to:
- Skip already-analyzed topics? (skip logic)
- Resume after a partial run?
- Identify which tier topics are complete?

### Step 3 — Assess per-topic version tracking

The design proposes tracking which topic file version was used per analysis.
Does the current log track this? If not, is that a gap?

### Step 4 — Produce finding or confirm clean

---
