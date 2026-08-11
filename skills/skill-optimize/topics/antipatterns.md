# ANTI-PATTERNS — Executable Assessment

Assess whether systemic failures are present — ones no primary topic fully
owns, or ones emerging from topic interaction. Primary topics own their
domains; this topic catches what falls through.

**Activation gate:** Only produce findings for systemic anti-patterns.
Cross-topic tensions and per-topic foot guns below are reference material —
they do not generate findings on their own.

---

## How to make this assessment

### Step 1 — Check for required context

Before running, confirm available context:

- Topic set being applied to this skill ✓
- Prior findings / changelog ✓ (`.optimization/.log.md`)
- Any prior optimize log ✓

Without all three, this topic cannot meaningfully run.

### Step 2 — Review the cross-topic tension set for systemic patterns

Read the prior findings in `.optimization/.log.md`. Look for:

1. **LESS IS MORE vs. EXAMPLES oscillation** — Did the log show LESS IS
   MORE removing content that EXAMPLES would require?
2. **COMPRESSIBILITY vs. OUTPUT FORMAT** — Did either conflict with the
   other in their recommendations?
3. **REUSE vs. LESS IS MORE** — Did REUSE recommend extraction while LESS
   IS MORE would inline the same block?
4. **Topic interaction producing a regression** — Any finding where acting
   on Topic A created a condition that Topic B would now flag?

### Step 3 — Check for validation theater

Does any finding in the log recommend a self-check without external
observable criteria? This is validation theater (IACDM antipattern 1).
Flag if found.

### Step 4 — Produce finding or confirm clean

Only produce a finding if a systemic pattern is present that no primary
topic addressed.

---
