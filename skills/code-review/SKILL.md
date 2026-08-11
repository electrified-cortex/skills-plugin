---
name: code-review
description: Tiered code review on a change set. Read-only. Never modifies code. Triggers - code review, security, correctness, code-quality, change-review, architectural-risk. Not for: specs, docs, config-only changes, lockfiles (use spec-auditing or markdown-hygiene).
---

Cache Probe:

Prereq: install and use `hash-record`.

Before dispatching any pass (SKILL.md owns probe + write; dispatched agents don't cache):

1. Invoke `hash-record/manifest` with: `op_kind` = `code-review/vN` (append `/<model>` if `model` input set); `record_filename` = `report.md`; `files` = all `change_set` files + `context_pointer` file (if set) + temp file containing `tier`, `focus` (if set), `prior_findings` hash (if substantive + set).
2. `hash-record/manifest` emits `HIT: <abs-path>` or `MISS: <abs-path>`.
3. HIT → read + return cached report; skip dispatch.
4. MISS → dispatch; after result, write to returned `<abs-path>`.

Dispatch:

`<instructions>` = `<absolute-path>/code-review/instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`

Smoke pass:
`<description>` = `code-review smoke — fast surface scan`
`<input-args>` = `change_set=<form> tier=smoke [focus=<csv>] [context_pointer=<path>]`
`<tier>` = `fast-cheap` (shallow scan; surface-level findings only)
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Follow dispatch skill. See `../dispatch/SKILL.md`
Should return: JSON findings report `{tier, pass_index, verdict, findings[], failure_reason?}`

Substantive pass:
`<description>` = `code-review substantive — full depth pass`
`<input-args>` = `change_set=<form> tier=substantive prior_findings=<json> [focus=<csv>] [context_pointer=<path>]`
`<tier>` = `standard` (full depth; design, correctness, security, architectural risk)
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Follow dispatch skill. See `../dispatch/SKILL.md`
Should return: JSON findings report `{tier, pass_index, verdict, findings[], failure_reason?}`

Inputs:

`change_set` (required): inline unified diff, absolute file path list, or git ref/range (refs require shell access in dispatched agent).
`tier` (required): `smoke` or `substantive`.
`prior_findings` (substantive only, required): `findings[]` array from all prior passes, forwarded unmodified.
`focus` (optional): comma-separated focus areas (e.g. `security,concurrency`). Reorders priority; doesn't reduce depth — `critical` + `high` outside focus must still surface.
`context_pointer` (optional): path to CLAUDE.md, README, or style guide for local conventions.
`model` (optional): model override. Affects cache path subfolder (`.../vN/<model>/report.md`). Applies to all tiers.

Returns:

RESULT: aggregated review result `{passes[], sign_off_pass_index, severity_aggregate, verdict, preserved_contradictions[]}`
ERROR: `<reason>`

Calling agent assembles aggregated result from per-pass reports. Aggregation rules in `instructions.txt`.
SARIF severity map: `critical`/`high` → error, `medium` → warning, `low`/`info` → note.
Severity calibrated: speculative findings `medium` or lower. `critical`/`high` findings require Source/Sink/Missing-guard evidence; incomplete evidence auto-downgraded to `medium`.

Single-Adversary Mode:

`<description>` = `code-review single-adversary — focused adversarial pass`
`<input-args>` = `change_set=<file_path|pr_number> tier=single-adversary [model=<model>] [focus=<csv>] [context_pointer=<path>]`
`<tier>` = `fast-cheap` (focused adversarial pass; catches obvious logic errors)
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Follow dispatch skill. See `../dispatch/SKILL.md`
Should return: JSON findings report `{tier: "single-adversary", pass_index, verdict, findings[{severity, location, snippet, description, recommended_action}], failure_reason?}`
