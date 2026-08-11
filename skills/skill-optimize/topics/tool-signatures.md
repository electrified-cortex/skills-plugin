# TOOL SIGNATURES — Executable Assessment

Assess whether the tool calls, sub-skill names, and parameter descriptions
used in this skill are precise enough to avoid selection errors at runtime.

---

## How to make this assessment

### Step 1 — Enumerate all tool/sub-skill references

Read `uncompressed.md`. List every:
- Named tool or function called by the skill
- Sub-skill dispatched by name
- Parameter passed to a dispatched call

### Step 2 — Check name precision

For each name: is it semantically precise? Could a routing agent confuse it
with something else?

Generic red flags: "run", "process", "handle", "analyze", "check", "do"
without a direct object.

### Step 3 — Check parameter documentation

For each dispatched call: are inputs documented with types, constraints, and
examples? Or are they described with "the path", "the topic", "the result"?

### Step 4 — Check for disambiguation

If multiple sub-skills are dispatched, can the host clearly distinguish when
to use each? Does the dispatch logic name the criteria?

### Step 5 — Produce finding or confirm clean

```
### TOOL SIGNATURES — HIGH | MEDIUM | LOW

**Signal:** <which names/descriptions are weak>

**Reasoning:** <what selection error could occur>

**Recommendation:** <specific wording improvement>
```

---
