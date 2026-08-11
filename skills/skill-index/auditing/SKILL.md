---
name: auditing
description: Validator for a skill-index cascade. Triggers - validate skill index, audit skill index, check if index is stale, skill index health, verify index cascade, auditing.
---

Validates an existing cascade. Write-only on audit report — never modifies index files. See `instructions.txt` for full check rules (dispatched agent reads that, not this).

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `root=<path> result_file=<path> [--dot-allow <name,...>]`
`<tier>` = `standard`
`<description>` = `Skill Index Audit: <path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

`root` (required): abs path to cascade's invocation root.
`result_file` (required): abs path for audit report.
`--dot-allow` (optional): comma-separated bare dot-folder names. Default: empty.

Returns: audit report at `result_file` with verdict `ok` | `rebuild-needed` | `inconclusive`.