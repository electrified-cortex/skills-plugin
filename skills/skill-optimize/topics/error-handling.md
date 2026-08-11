# ERROR HANDLING — Executable Assessment

Assess whether the skill explicitly addresses error paths — missing inputs,
malformed data, unexpected states, and out-of-scope inputs.

---

## How to make this assessment

### Step 1 — Check precondition handling

Read `uncompressed.md` Steps 1-2. Does the skill check for required
inputs before proceeding?

Required inputs for skill-optimize:

- `<skill-path>` — the path to the skill being analyzed
- Skill source files: at least `uncompressed.md` or `SKILL.md`

Does Step 1 specify what to do if the skill path doesn't exist or the
source files are absent?

### Step 2 — Check sub-agent error handling

Steps 3a and 4 dispatch sub-agents. What happens if:

- The qualifier returns `TOPIC: none`?
- The qualifier returns a malformed response?
- The Sonnet analysis sub-agent returns an unexpected format?

### Step 3 — Check out-of-scope handling

If the input is not a skill (e.g., a random directory), does the skill
detect and reject it, or does it attempt analysis anyway?

### Step 4 — Produce finding or confirm clean

---
