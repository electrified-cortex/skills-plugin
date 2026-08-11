# CONVERGENCE — Executable Assessment

Assess whether the skill has sufficient multi-pass stopping criteria and
whether the current implementation will reach a stable optimized state
without oscillation or premature convergence.

---

## How to make this assessment

### Step 1 — Check for multi-pass stopping criteria

Does `uncompressed.md` or `spec.md` define when to stop running the
optimizer on a skill?

Look for:

- A hard iteration cap (explicit N)
- A net-new-findings test ("stop when a full pass produces zero new findings")
- A coverage threshold (e.g., "all topics in priority tier 1-2 analyzed")
- An escalation ceiling (Haiku → Sonnet → Opus)

### Step 2 — Check for oscillation risk

Does the topic set contain pairs of topics whose recommendations could
conflict? Pairs to check:

- REUSE (extract) vs. LESS IS MORE (inline — don't add overhead)
- COMPOSITION (split) vs. LESS IS MORE (collapse)
- DISPATCH (dispatch) vs. CONTEXT BUDGET (minimize context)

If conflicting recommendations appear across passes, the skill needs an
explicit deduplication step or a "don't revert prior decisions" guard.

### Step 3 — Check for false convergence risk

Could the optimizer declare convergence while the skill still has real issues?

- Does the log track which topics were analyzed? (If not, duplicates could
  re-surface as "new" findings on later passes.)
- Does the assessor skip already-logged topics?

### Step 4 — Produce finding or confirm clean

---
