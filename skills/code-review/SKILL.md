---
name: code-review
description: Tiered code review on a change set. Read-only — never modifies code. Triggers — security, correctness, code-quality, change-review, architectural-risk.
---

## Goal

Adversarial code review on a change set. Two first-class modes: tiered (smoke+substantive) for comprehensive coverage, single-adversary for fast targeted passes. Read-only — never modifies code.

## When to Use

- Reviewing a PR diff, file list, or git range for correctness, security, or quality issues.
- Need sign-off before merge (tiered mode) or a quick adversarial pass (single-adversary mode).
- Triggers: security, correctness, code-quality, change-review, architectural-risk.

## Review Modes

| Mode | When to use | Cost/time profile | Model |
| --- | --- | --- | --- |
| **Swarm** | Comprehensive review: multiple model passes, consensus | High cost, high quality, ~3-5x longer | All available models (see `swarm` skill) |
| **Tiered** | Standard review: smoke pass then substantive sign-off | Medium cost, medium time, two passes | Haiku (smoke) + Sonnet (substantive) |
| **Single-adversary** | Quick targeted review: one pass, focused finding list | Low cost, fast, single model | One model (see capability-cache for selection) |

Worker chooses mode based on time/token budget. All modes are first-class.

## Inputs

`change_set` (required): inline unified diff, absolute file path list, or git ref/range (refs require shell access in dispatched agent).
`tier` (tiered mode only, required): `smoke` or `substantive`.
`prior_findings` (substantive pass only, required): all prior-pass findings forwarded unmodified.
`focus` (optional): comma-separated focus areas (e.g. `security,concurrency`). Reorders priority; doesn't reduce depth — `blocker` and `major` outside focus must still surface.
`context_pointer` (optional): path to CLAUDE.md, README, or style guide for local conventions.

## Procedure

### Tiered Mode

`<instructions>` = `instructions.txt` (this folder; NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`

Smoke pass (`tier=smoke`):
`<input-args>` = `change_set=<form> tier=smoke [focus=<csv>] [context_pointer=<path>]`
`<tier>` = `fast-cheap`
`<description>` = `Code Review Smoke: <change_set>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Substantive pass (`tier=substantive`):
`<input-args>` = `change_set=<form> tier=substantive prior_findings=<json> [focus=<csv>] [context_pointer=<path>]`
`<tier>` = `standard`
`<description>` = `Code Review Substantive: <change_set>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Orchestration:

1. Dispatch smoke pass (Haiku/fast-cheap). Receive per-pass result.
2. Dispatch substantive pass (Sonnet/standard). Forward all smoke findings unmodified as `prior_findings`.
3. Collect both per-pass results. Build aggregated result.

Caller obligations:
Smoke is not sign-off. Always dispatch substantive before acting on results.
Forward `prior_findings` to substantive unmodified — no filtering, no summarizing.
Tier substitution is prohibited: smoke must use fast-cheap, substantive must use standard.

### Single-Adversary Mode

#### When to choose
- Time/token budget is limited.
- Reviewer needs a quick adversarial pass on a specific file or PR (not full coverage).
- Swarm-grade thoroughness is not required.

#### Interface
Input:
- `file_path` OR `pr_number` — target of the review.
- `model` — which model to use. If omitted, read capability-cache for available models and use the first listed, or fall back to the host model.
- `focus` — optional. Specific concern to focus on (e.g., "security", "logic errors", "API surface").

Output:
- Finding list: each finding as `{file, line_or_range, severity, description}`.
- Summary: 1-3 sentences: top concern + overall verdict.

#### Procedure
1. Check capability cache (see `capability-cache` skill) to determine available models.
2. If `model` specified -> use it. If not -> use first available from cache (fall back to host model if cache MISS or unavailable).
3. Read the target (file contents or PR diff).
4. Produce ONE adversarial review pass: assume the author is wrong and look for problems.
5. Return finding list + summary.

## Outputs

### Tiered Mode

Per-pass result: `{tier, pass_index, verdict, findings[]}`. Verdict: `clean`, `findings`, `error`. Severity: `blocker`, `major`, `minor`, `nit`.

Aggregated result (caller builds after both passes complete):

| Field | Description |
| --- | --- |
| `passes` | Array of per-pass results, ordered by `pass_index`. |
| `sign_off_pass_index` | Index of most recent successful standard pass (authoritative sign-off). `null` if no successful standard pass yet. |
| `severity_aggregate` | Count of findings by severity (`blocker`, `major`, `minor`, `nit`) from sign-off pass only. |
| `verdict` | Sign-off pass verdict propagated (`clean`, `findings`, or `error` if no successful standard pass). |
| `preserved_contradictions` | Findings where smoke and substantive disagree — surface as-is, do not resolve. |

### Single-Adversary Mode

Finding list: each item as `{file, line_or_range, severity, description}`. Severity: `critical | high | medium | low | info`.
Summary: 1-3 sentences — top concern + overall verdict.

## Constraints

- Read-only: never modifies code, never commits.
- Smoke is not sign-off — always dispatch substantive before acting on tiered results.
- MUST NOT run multiple passes in single-adversary mode (that is tiered/swarm mode).
- MUST check capability-cache before dispatching to any non-host model.
- When time/token budget is tight: use single-adversary mode.
- When comprehensive coverage is required: use tiered or swarm mode.
- Both tiered and single-adversary modes MUST check capability-cache before using non-host models.
- Finding severity in tiered mode: `blocker`, `major`, `minor`, `nit`. In single-adversary mode: `critical`, `high`, `medium`, `low`, `info`.

## Error Handling

- Smoke pass fails (dispatch error) -> abort; do not proceed to substantive. Return `{verdict: "error", passes: [{tier: "smoke", verdict: "error", ...}]}`.
- Substantive pass fails -> return partial aggregated result with `verdict: "error"` and `sign_off_pass_index: null`.
- Single-adversary: capability cache MISS or unavailable -> fall back to host model; note in summary.
- Single-adversary: target file/PR not found -> return `{verdict: "error", summary: "Target not found: <path/pr>"}`.

## Dependencies

- `capability-cache` skill
- `dispatch` skill
- `swarm` skill (for swarm mode)
- `spec-auditing`, `skill-auditing`, `compression` (related skills)
