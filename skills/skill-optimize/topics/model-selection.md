# MODEL SELECTION — Executable Assessment

Assess whether each execution role in the skill is using the right model
tier, and whether instruction quality is the real barrier preventing a
cheaper tier.

---

## How to make this assessment

### Step 1 — Identify model roles

Read `uncompressed.md`. List every dispatch point and its assigned tier:

- Host agent (orchestrator)
- Qualifier dispatch (topic selection)
- Topic analysis dispatch (finding generation)
- Any other dispatched roles

### Step 2 — Evaluate each role against tier criteria

For each role:

| Role | Current tier | Task type | Judgment required? | Tier justified? |
| ---- | ------------ | --------- | ------------------ | --------------- |

Task types:

- **Deterministic execution** → Haiku-class candidate
- **Structured judgment** (weighing, comparing, assessing) → Sonnet-class
- **Deep multi-constraint reasoning** → Opus-class (rare)

### Step 3 — Apply the instruction-quality lever

For any role at Sonnet+ tier: ask whether the instructions are explicit
enough that a Haiku could follow them if given the same inputs.

Signal that instructions are the barrier (not cognitive demand):

- Steps use prose conditionals ("if it seems like...", "consider whether...")
  instead of explicit decision trees
- The model must infer criteria that aren't stated
- Output format is described loosely rather than templated

If instructions are the barrier: finding. Tighten instructions to enable
downgrade.

### Step 4 — Check for evaluatability

Is the skill's output structured enough to A/B test across tiers? If yes
and no eval exists, flag it.

### Step 5 — Produce finding or confirm clean

```md
### MODEL SELECTION — HIGH | MEDIUM | LOW

**Signal:** <which role; current tier; what the task actually demands>

**Reasoning:** <instruction quality vs. cognitive demand analysis>

**Recommendation:** <specific tier change or instruction tightening>
```

---
