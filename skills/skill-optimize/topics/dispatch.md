# DISPATCH — Executable Assessment

Assess whether the skill uses the right execution pattern: dispatch (isolated
sub-agent context) or inline (runs in the host agent's context). Wrong
choice in either direction is a structural defect — harder to fix than most
other categories.

---

## How to make this assessment

### Step 1 — Identify the execution pattern

Read `SKILL.md` and `uncompressed.md`. Determine:

- Does the skill invoke a sub-agent (Dispatch pattern) or run inline in
  the host context?
- If dispatched: who dispatches it, and what is the sub-agent's scope?
- If inline: does it run entirely in the host, or does it dispatch sub-steps?

Look for these specific indicators:

| Indicator | Implies |
| --------- | ------- |
| `runSubagent(...)` or equivalent in instructions | Dispatch pattern |
| SKILL.md names itself a "dispatch skill" | Dispatch pattern (intended) |
| Instructions are a procedure the host executes directly | Inline |
| Instructions contain `dispatch` skill or sub-skill reference | Dispatch |
| Instructions modify shared session state (memory, operator comms) | Inline required |

### Step 2 — Check for pattern/implementation mismatch

A skill can claim to be a dispatch skill (in its spec or SKILL.md) but
implement its steps inline. This is a mismatch.

Signals of mismatch:

- SKILL.md or spec.md says "dispatch skill" but `uncompressed.md` describes
  steps the host executes directly
- The skill dispatches sub-steps but the primary analysis still runs inline
  in the host context — partial dispatch, full context pollution
- The skill has no SKILL.md dispatch invocation but the spec intends dispatch

### Step 3 — Assess whether the current pattern is correct

**For inline skills — ask: should this be dispatched?**

Fire a DISPATCH finding if ALL of the following are true:

- The procedure has 5+ distinct steps with intermediate state (findings,
  file reads, analysis results) that accumulate in context
- The work is context-independent — no shared session state needed
- The instruction file is large (>50 lines) and loads fully on every call

Do NOT fire if:

- The skill is brief (< 5 steps, < 20 lines of instructions)
- The skill must write to or read from shared session state
- Dispatch overhead would dominate the actual work

**For dispatch skills — ask: is the dispatch scope correct?**

Fire a DISPATCH finding if:

- The skill claims dispatch but does significant work inline before the
  dispatch call (pre-filtering, state building, context accumulation)
- The dispatch boundary is wrong — too coarse (one giant sub-agent doing
  everything) or too fine (dispatching trivial single-step operations)
- The fallback for unavailable dispatch is missing

### Step 4 — Check dispatch implementation quality (for dispatch skills)

If the skill uses dispatch, inspect how it invokes the dispatch pattern:

**Canonical form** (from `markdown-hygiene/analysis/SKILL.md` as golden reference):

```
`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = <the specific inputs>
`<tier>` = `fast-cheap` | `standard` | `deep`  — <reason>
`<description>` = <short run label>
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `<path>/dispatch/SKILL.md`.
Should return: <expected output contract>
```

Fire a MEDIUM finding for any of these:

1. **Old inline form** — skill uses `"Read and follow instructions.txt..."` embedded
   directly (e.g. `Dispatch agent (zero context): "..."`) instead of named variables.
   This makes the dispatch fragile and non-uniform across skills.

2. **Missing `Should return:`** — the expected output contract is not declared
   after the dispatch call. Callers must guess what to handle.

3. **Missing tier or tier unjustified** — `<tier>` not set, or set without any
   comment. For non-obvious choices (e.g. using `standard` for what looks simple,
   or `fast-cheap` for complex work) a parenthetical reason is expected.

Do NOT fire if the skill is inline-only (no dispatch at all).

### Step 5 — Check tool call vs. text substitution opportunities

Scan the instructions for tool calls. For each one, ask:

1. Does the tool interact with external state (filesystem, network, time)?
   If yes → keep it.
2. Does the tool compute something the model can derive inline from
   context? If yes → candidate for replacement.
3. Is the tool call reused across many skills, centralizing logic to
   prevent drift? If yes → keep it.

Fire a LOW finding (tool call replacement) when a tool call's behavior
could be replaced by a 2-3 line inline instruction with no loss of
reliability or correctness.

### Step 6 — Produce finding or confirm clean

**Finding format:**

```md
### DISPATCH — HIGH | MEDIUM | LOW

**Signal:** <what you observed in the skill>

**Reasoning:** <why the current pattern is wrong>

**Recommendation:** <specific change — e.g., "Wrap Steps 4-6 in a
dispatched sub-agent. Pass [list] as inputs. Return findings record.">
```

**Severity:**

- HIGH — pattern mismatch that causes context pollution every invocation
  or blocks architectural evolution
- MEDIUM — partial mismatch or tool call replacement with moderate gain
- LOW — tool call replacement with minor gain, or pattern is fine but
  could be marginally improved

**Confirm clean** (emit no finding) when:

- The skill is inline and brief — dispatch overhead would be wasteful
- The skill is dispatched with the correct scope
- All tool calls interact with external state or centralize shared logic

---
