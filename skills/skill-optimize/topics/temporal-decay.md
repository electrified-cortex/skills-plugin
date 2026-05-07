# TEMPORAL DECAY — Executable Assessment

Assess whether the skill contains content that will become stale as
external versions, model behaviors, or conventions change.

---

## How to make this assessment

### Step 1 — Scan for version-pinned references

Read `uncompressed.md` and `spec.md`. List every:
- Model name or version (e.g., `claude-sonnet-4-6`, `Haiku`, `Sonnet`)
- Tool version or platform requirement
- File paths that assume a specific directory structure
- API endpoint references

### Step 2 — Check for model behavior assumptions

Does any instruction rely on a specific model behaving a certain way?
Example: "this model always returns JSON when..." or "Haiku will
short-circuit on the first match."

### Step 3 — Check environmental assumptions

Does the skill assume specific paths, tool availability, or platform
conventions that could change?

### Step 4 — Produce finding or confirm clean

---
