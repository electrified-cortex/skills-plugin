# WORDING — Executable Assessment

Assess instruction phrasing, ordering, and structural patterns that
affect how the model interprets and executes the skill.

---

## How to make this assessment

### Step 1 — Scan for guard clause ordering

Find all stop conditions and early exits in `uncompressed.md`. Check:
- Is each stop condition stated before the complex path it guards?
- Example: "If already logged, stop" — does this appear before the
  analysis steps, or after them?

### Step 2 — Check phrasing for determinism

Scan for hedged or conditional prose:
- "you might want to…", "consider whether…", "it may be helpful to…"
- These are implicit judgment calls. Flag and convert to imperatives.

Also scan for passive voice in action steps:
- "The log should be updated" → "Append one row to the log"
- Passive reduces clarity of ownership.

### Step 3 — Check instruction sequencing

For multi-step procedures:
- Is the most common path defined before edge cases?
- Are related concerns grouped?
- Are caveats placed after the action they qualify, not before?

### Step 4 — Check attention positioning

Critical elements (output format, stop conditions, required outputs)
should appear at the beginning or end of each section, not buried
mid-step. Scan Steps 1-6 for any critical requirement that's buried
mid-paragraph.

### Step 5 — Produce finding or confirm clean

```
### WORDING — HIGH | MEDIUM | LOW

**Signal:** <specific lines; what pattern they match>

**Recommendation:** <concrete rewording>
```

---
