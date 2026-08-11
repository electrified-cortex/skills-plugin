# CACHING (HASH RECORD) — Executable Assessment

Assess whether the skill correctly applies a hash record for caching, and
whether the chosen iteration-tracking approach is sound.

---

## How to make this assessment

### Step 1 — Identify the caching mechanism

Read `uncompressed.md` and `SKILL.md`. Look for:

- Any reference to `.hash-record/` or hash manifest procedure
- Any reference to `.optimization/.log.md` or similar iteration log
- Any "already done" check at entry (cache probe, log read, status check)
- Any output write to a cache path

Classify what you find:

| Observed | Classification |
| -------- | -------------- |
| `.hash-record/<hash>/` path in instructions | Content-addressed cache (hash record) |
| Log file with topic rows and status fields | Iteration log (topic-level tracking) |
| No caching or checking mechanism | No cache |
| Probe + emit PATH on hit | Hash record with correct short-circuit |

### Step 2 — Assess fit for the skill's purpose

A hash record caches the *entire skill output* keyed to input file
contents. It is correct when:

- The skill produces a deterministic, reusable result given the same inputs
- The skill is expensive (multi-LLM, large file sets)
- Callers want to avoid re-running on unchanged inputs

An iteration log tracks *which sub-tasks have been completed*. It is
correct when:

- The skill is stateful across calls (each call advances progress)
- Different topics/sub-tasks are analyzed separately
- The caller wants to resume where it left off, not replay the whole run

Ask: does the skill need a hash record, an iteration log, or both?

- **Both** — if the skill has expensive per-topic analysis AND callers want
  to skip the whole skill when inputs haven't changed
- **Log only** — if per-invocation progress tracking is the core need
- **Hash only** — if the skill produces a single reusable report
- **Neither** — if the skill is cheap and called at most once per session

### Step 3 — Check for conflicts

Look for contradictions between:

- The spec's stated caching requirements (e.g., R5 hash-record mandate)
- The instructions file's actual implementation

A spec that mandates a hash record while the instructions use only a log
is a conflict. A spec that has not been updated to reflect the log approach
is a conflict. Both are findings.

### Step 4 — Assess idempotency

Separate question: if the cache or log were absent, would running the
skill twice on the same inputs cause problems?

Signals of non-idempotency:

- Duplicate log rows appended on every run without deduplication check
- Findings re-emitted even when status is already `acted` or `clean`
- Files written without checking if already written

### Step 5 — Produce finding or confirm clean

**Finding format:**

```md
### HASH RECORD — HIGH | MEDIUM | LOW

**Signal:** <what you observed>

**Reasoning:** <why the current approach is wrong or conflicted>

**Recommendation:** <specific change>
```

**Severity:**

- HIGH — spec/instructions conflict causing incorrect behavior; or no
  caching on an expensive, repeatedly-called skill
- MEDIUM — partial mismatch; spec says one thing, instructions say another,
  but behavior is still reasonable
- LOW — idempotency gap that won't cause errors but could cause duplicates

**Confirm clean when:** caching approach matches the skill's usage pattern,
spec and instructions are aligned, and the skill is idempotent.

---
