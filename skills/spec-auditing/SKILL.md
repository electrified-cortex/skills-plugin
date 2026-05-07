---
name: spec-auditing
description: Audit a spec or companion file for alignment and completeness. Triggers — spec validation, requirements coverage, contradiction detection, specification quality, validate spec, spec audit.
---

Inputs:

`<target-path>` — absolute path to the spec or companion file to audit.
`[--spec <spec-path>]` — explicit spec path (pair-audit mode); context only, not part of the hash key.
`[--fix]` — caller signals fix iteration is in play; executor does not handle this flag.
`[--kind meta|domain]` — force audit kind; default auto-detects from path.

## Inline hash check

- Bash: `bash ../hash-record/hash-record-check/check.sh <target-path> spec-auditing/v1 report.md`
- PS7:  `pwsh ../hash-record/hash-record-check/check.ps1 <target-path> spec-auditing/v1 report.md`

- `HIT: <abs-path>` → emit `PATH: <abs-path>`, stop.
- `MISS: <abs-path>` → bind `<report_path>` = `<abs-path>`, jump to Dispatch.
- `ERROR: <reason>` → surface the error, stop.

## Dispatch

Variables:

`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `<target-path> --report-path <report_path> [--spec <spec-path>] [--kind meta|domain]`
`<tier>` = `fast-cheap`
`<description>` = `Spec Audit: <target-path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Returns: `Pass: <abs-path>` | `Pass with Findings: <abs-path>` | `Fail: <abs-path>` | `ERROR: <reason>`

## Result

If `ERROR:` stop here and return the result to the caller.
Otherwise rerun the inline hash check for `<target-path>`.
If that result is a `MISS: <abs-path>` then something is wrong and report it as: `ERROR: Expected report at <abs-path>. None found.`

If `Pass:`, return the result to the caller and stop here.

To fix, load `../dispatch/SKILL.md` and use the `dispatch` skill (tier: standard) to launch a sub-agent; pass this report as input instructing it to fix all the issues. Then follow this skill again; stop at 3 rounds and surface the report.
