# OUTPUT FORMAT — Executable Assessment

Assess whether the skill specifies its output format explicitly enough to
produce consistent, parseable results. Two outputs to check: the primary
return line and the secondary findings content (if any).

---

## How to make this assessment

### Step 1 — Identify all outputs

Read `uncompressed.md`. List every output the skill produces:

1. **Primary return** — the final stdout line the caller receives
2. **Secondary outputs** — files written, records created, log entries
3. **Sub-agent outputs** — if the skill dispatches, what does the
   sub-agent return and how does the host use it?

### Step 2 — Check primary return format

Is the primary return format:

- Explicitly templated in the instructions? (e.g., `` `TOPIC: X | FINDINGS: N | LOG: path` ``)
- Or described in prose ("return a line describing the topic and count")?

Template → pass. Prose → finding.

### Step 3 — Check secondary output formats

For each file the skill writes:

- Is the write operation described with enough detail that the model
  would produce the same structure on every invocation?
- Is the path deterministic (not dependent on runtime state the model
  might format differently)?

### Step 4 — Check sub-agent output contract

If the skill dispatches sub-agents, ask:

- What format does the sub-agent return?
- Is that format specified in the dispatch prompt (not just in the sub-agent)?
- How does the host consume the sub-agent response? Is there a parsing step?

A sub-agent returning free-form text that the host is supposed to structure
is a variance risk. The dispatch prompt should specify the return format.

### Step 5 — Check for spec/instructions alignment

Does the spec's "Output" section match what the instructions actually
produce? Stale spec output descriptions are a common drift point.

### Step 6 — Produce finding or confirm clean

**Finding format:**

```
### OUTPUT FORMAT — HIGH | MEDIUM | LOW

**Signal:** <which output is unspecified or misaligned>

**Reasoning:** <what variance this causes>

**Recommendation:** <specific template or alignment fix>
```

**Severity:**

- HIGH — primary return format unspecified; downstream parsers will break
- MEDIUM — secondary output format unspecified or spec/instructions misalign
- LOW — sub-agent return format under-specified; risk is low because output
  is consumed by a model, not code

---
