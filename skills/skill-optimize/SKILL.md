---
name: skill-optimize
description: Analyzes single skill for architectural and structural improvement. Dispatches topic analysis to sub-agents, records findings in optimize-log. NEVER modifies source files. Triggers — optimize skill, skill review, architectural review, skill improvement, find skill issues, analyze skill structure.
---

Prerequisite: audit the target skill using `../skill-auditing/SKILL.md`

Inputs:

Required: `<skill-path>` — path to the **target skill being analyzed** (not this skill's own directory). Contains SKILL.md, spec.md, uncompressed.md, etc.

Optional:
`<topic>` — slug; provided → skip assessor, analyze directly.
`<mode>` — `assess-only` (pick only) | default (assess + analyze)

Step 1 — Read Source Files:

Read all from `<skill-path>` in order; don't analyze yet.

1. `spec.md`
2. `uncompressed.md`
3. `SKILL.md`
4. `instructions.txt`
5. `instructions.uncompressed.md`

None found → `ERROR: no skill source files found at <skill-path>`.

Allowed write targets (inside the **target skill's** directory): `<skill-path>/.optimization/.log.md` (5a), `<skill-path>/.optimization/<slug>.md` (5b). Read scope: `<skill-path>` and `<skill-optimize-root>/topics/` only.

Step 2 — Check Optimize Log:

Log: `<skill-path>/.optimization/.log.md`. Read if exists. Exclude from 3a: any topic with status `qualified` (no), `clean`, `acted`, `deferred`, `rejected`, or `audit-candidate`. Topics with no log entry are candidates. `yes`/`maybe` results are never logged — those topics re-enter the pool each pass. No log → first pass.

```markdown
(H1) Optimize Log: <skill-name>

## Topics Analyzed

| Topic | Date | Model | Findings | Status | Action |
| DISPATCH | 2026-04-29 | Sonnet | 1 | pending | — |
| CACHING  | 2026-04-29 | Sonnet | 0 | clean   | No change. |
```

File location: `<skill-path>/.optimization/.log.md`

Status: `qualified` (verdict in Action) | `pending` | `acted` | `deferred` | `rejected` | `clean`

Action for `qualified` rows: `yes — <reason>` / `maybe — <what tips it>` / `no — <reason>`

Step 2a — Pre-flight Audit Check:

Run `pwsh result.ps1 <skill-path>` from `skill-auditing/` dir. Note verdict; proceed regardless.

Step 2b — Explicit Topic Guard:

If `<topic>` provided AND log exists AND `<topic>` row status is `clean`, `acted`, or `rejected` → emit `SKIP: <topic> already <status> — pass --force to re-analyze` and stop. (Bypass with `--force` flag.)

Step 3 — Assessor Pass:

Pick best next topic. Skip if `<topic>` provided — verify `topics/<topic>.md` exists; missing → `ERROR: topic file not found at topics/<topic>.md`. Go to Step 4.

3a — Candidate Selection (Host, mechanical):

1. Read `topics/_index.md` — fixed priority-ordered list
2. Remove any topic already in the optimize-log (any status, including `qualified`)
3. Take top 3 remaining in order

None remaining → `No unqualified topics remaining — all topics logged.`

3b — Qualifier (Haiku-class, one call):

Pass: source files (Step 1), the 3 candidates from 3a, one-line descriptions.

```text
For each topic, assess whether it applies to this skill.
Format: TOPIC: <SLUG> | APPLICABLE: yes | no | maybe | REASON: <one sentence>
For `maybe`: reason must explain what would tip it yes or no.
Return a result for every topic.
```

Log all 3 results immediately as `qualified` rows (Step 5a).

3c — Assessor Decision (Sonnet-class host):

Read all `qualified: yes/maybe` rows. Pick topic most likely to yield HIGH finding.

No yes/maybe rows → `No applicable topics found — all qualified topics returned no.`

Tie-breaking: 1. `yes` > `maybe` 2. Structural > stylistic 3. Shorter spec

Emit: `Assessor selected: <TOPIC-SLUG> — <one-line reason>`. `assess-only` → stop.

Fallback (no dispatch): Skip 3b. Read `topics/_index.md` for priority order. Assess top 3 candidates inline. Log as `qualified`. Proceed to 3c.

Step 4 — Topic Analysis (Dispatched):

Dispatch Sonnet-class sub-agent. Pass: source files (Step 1), `topics/<slug>.spec.md`, `topics/<slug>.md` (if exists).

```md
You are a skill optimizer running a focused topic analysis.

Topic: <SLUG>

Skill files: <attach all>
Topic spec: <attach spec>
Topic assessment guide (if exists): <attach .md>

Apply assessment. Return findings or CLEAN:

### <CATEGORY> — HIGH | MEDIUM | LOW

**Reasoning:** <grounded in skill content>

**Recommendation:** <concrete, actionable>

HIGH = clear benefit, direct evidence. MEDIUM = likely, context-dependent. LOW = minor.
CLEAN if none apply. Universal findings: `audit-candidate: <description>`
Verify severity before output. All paths repo-relative.
```

CLEAN → `clean`. Findings → record. Missing `### CATEGORY` or `**Reasoning:**` → `ERROR: unexpected analysis format`, stop.

Step 5 — Record Results:

After 3b: append `qualified` rows **for `no` results only** (Haiku-class, Action: `no — <reason>`). `yes`/`maybe` held in memory, not logged until analyzer completes.
After 4: append final row for analyzed topic.

5a: Append to `<skill-path>/.optimization/.log.md`: `| <TOPIC> | <date> | <model> | <N> | <status> | <action> |`

Status: `qualified` | `acted` | `deferred` | `rejected` | `clean` | `audit-candidate`. No log → create `.optimization/` dir if needed, create `.log.md` with Step 2 header.

5b: Write `<skill-path>/.optimization/<slug>.md`:

```md
# <TOPIC> — <date>

**Severity:** HIGH | MEDIUM | LOW
**Finding:** <observed>
**Action taken:** <changed or "No change.">
```

Multiple findings: use `## Findings` section header before the list, not `---` separators.
Clean → single-line body under `# <TOPIC>`: `CLEAN — no findings.`

5c: Apply findings before advancing.

For each finding in the just-written report:
- If the recommendation is **concrete and safe** (a targeted edit to the skill source files with no operator judgment required): apply it now, update `**Action taken:**` in the report, update log status to `acted`.
- If it requires operator judgment (structural redesign, breaking change, ambiguous tradeoff): leave `pending`, set `**Action taken:**` to `pending — <why skipped>`.

Apply only to files in `<skill-path>` (uncompressed.md, instructions.uncompressed.md, spec.md, SKILL.md). Never apply to the skill-optimize files themselves.

**Do not advance to the next pass until 5c is complete.** Later analyses must run against the updated source files.

Step 6 — Output:

```text
TOPIC: <TOPIC-SLUG> | FINDINGS: <N> | LOG: <repo-relative path>
```

Tier-1+2 all `clean`/`acted`/`deferred` → also emit:

```text
CONVERGENCE: tier-1+2 topics complete — <N acted>, <M clean>, <K deferred>
Next: re-run with higher model tier to verify.
```

Stop. Caller re-runs if needed.

Topic slugs: `dispatch` `caching` `determinism` `composition` `model-selection` `compressability` `wording` `less-is-more` `reuse` `output-format` `examples` `chain-of-thought` `tool-signatures` `self-critique` `convergence` `iteration-safety` `progressive-optimization` `antipatterns` `error-handling` `interface-clarity` `observability` `temporal-decay` `context-sensitivity` `autonomy-level` `activation-discipline` `context-budget` `failure-mode` `verification-strategy` `evaluation-harness`

Context budget: prefer shorter specs (DISPATCH, CACHING, DETERMINISM lean). One topic vs. thin coverage.

Related: skill-auditing (conformance auditing), hash-stamping (caching pattern), compression (compress uncompressed.md → SKILL.md after changes).
