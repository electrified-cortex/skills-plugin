# ITERATION SAFETY — Executable Assessment

Assess whether the skill's loops have hard caps, state tracking, and
explicit stopping criteria to prevent runaway token spend.

---

## How to make this assessment

### Step 1 — Enumerate all loops in the skill

Read `uncompressed.md`. Identify every iterative pattern:
- Explicit loops (repeat N times, while-condition)
- Implicit loops (re-invoke instructions, "repeat for each topic")
- Convergence loops (run until stable)
- The outer loop: the operator re-invokes the skill across sessions

### Step 2 — Check for hard iteration caps

For each loop: is there an explicit maximum N?
- "Repeat up to 3 times" — explicit cap. ✓
- "Repeat until stable" — no cap. ✗ Flag.
- "For each topic" — bounded by the topic list length. Effectively capped.

### Step 3 — Check for state tracking

Does each loop track what it changed in previous iterations?
- If the loop can revisit the same finding, can it detect and avoid it?
- If the loop re-runs the qualifier, does it skip already-analyzed topics?

### Step 4 — Check for oscillation guard

Is there any mechanism to detect if the loop is cycling between two states?

### Step 5 — Produce finding or confirm clean

---
