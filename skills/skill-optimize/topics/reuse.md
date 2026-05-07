# REUSE — Executable Assessment

Assess whether the skill contains procedure blocks that could be extracted
as sub-skills, converted to tools, or replaced with existing primitives.

---

## How to make this assessment

### Step 1 — Read skill as a program

Read `uncompressed.md` and identify discrete procedure blocks. For each:
- What are its inputs and outputs?
- Is it self-contained (no dependency on surrounding state)?
- Does it appear in other skills or is it likely to?

### Step 2 — Check for extraction candidates

For each multi-step block:
- Does the same block appear in 2+ skills, or will it?
- Is it long enough that duplication adds overhead? (>5 lines = likely yes)
- Is it stable enough to be a shared dependency without versioning pain?

### Step 3 — Check for tool conversion candidates

For each LLM step:
- Is the output fully determined by the input (no judgment required)?
- Is it scriptable (file hash, line count, format check)?
- Would a tool be faster, cheaper, and more reliable?

### Step 4 — Check for dispatch adoption

Does the skill spawn sub-agents without using the `dispatch` skill?
If yes: finding — adopt dispatch as the spawning primitive.

### Step 5 — Produce finding or confirm clean

```
### REUSE — HIGH | MEDIUM | LOW

**Signal:** <which block; where it appears or will appear>

**Recommendation:** <extract/convert/adopt or defer with rationale>
```

---
