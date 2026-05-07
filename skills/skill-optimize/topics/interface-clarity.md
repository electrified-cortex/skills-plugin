# INTERFACE CLARITY — Executable Assessment

Assess whether the skill clearly documents its invocation contract: what
inputs it requires, what it returns on success and failure, and what its
preconditions are. A skill with a missing or implicit contract forces
callers to read the full procedure to understand how to use it.

---

## How to make this assessment

### Step 1 — Find the interface documentation

Look in order:

1. `SKILL.md` — the primary invocation surface. Check the `description`
   field and any explicit Inputs / Outputs sections.
2. `uncompressed.md` — the entry step should describe required inputs.
3. `spec.md` — check Requirements and Constraints for input/output specs.

### Step 2 — Assess input specification

For each required input, ask:

| Question | Pass | Fail |
| -------- | ---- | ---- |
| Is it named? | Yes, explicitly | Not named or only implied |
| Is the format specified? | Path format, schema, or type given | Caller must infer |
| Is it validated at entry? | Entry step checks presence | Assumed present |

**Required inputs to look for in skill-optimize:**

- The skill being analyzed (path to skill directory)
- Model tier (caller-provided or default?)
- Topic selection (caller-specified or assessor-driven?)

### Step 3 — Assess output specification

| Output | Pass | Fail |
| ------ | ---- | ---- |
| Success return | Exact format documented (e.g., `TOPIC: X | FINDINGS: N | LOG: path`) | No output format defined |
| Error return | `ERROR: <reason>` as final line | Error format unspecified |
| Side effects | optimize-log write documented | Side effects implied but not stated |

### Step 4 — Assess preconditions

Check if the skill documents:

- What must exist before it can run (skill source files, directory structure)
- What it does when preconditions are not met

### Step 5 — Produce finding or confirm clean

**Finding format:**

```
### INTERFACE CLARITY — HIGH | MEDIUM | LOW

**Signal:** <what is missing or ambiguous in the contract>

**Reasoning:** <why this causes caller friction>

**Recommendation:** <specific addition — e.g., add `## Inputs` section
to SKILL.md describing required path format>
```

**Severity:**

- HIGH — no contract documented; callers must read full procedure
- MEDIUM — partial contract; some inputs/outputs specified but gaps exist
- LOW — contract mostly complete; minor ambiguity

**Confirm clean when:** Inputs, outputs, and preconditions are all
documented with enough specificity for a caller to invoke the skill
without reading `uncompressed.md`.

---
