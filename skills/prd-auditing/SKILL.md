---
name: prd-auditing
description: Audit a Product Requirements Document for structure, content discipline, and scope boundary against the PRD auditing spec. Triggers — audit this PRD, review the PRD, check PRD quality, validate product requirements document, PRD needs review, PRD audit.
---

Input:
`<prd_path>` — absolute path to PRD file being audited (markdown).

Inspect:
Variables:
`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `prd_path=<prd_path>`
`<tier>` = `fast-cheap` — first pass. Subsequent passes use `standard`.
`<description>` = `Auditing PRD: <prd_path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../dispatch/SKILL.md`.
Should return: `CLEAN: <path>` | `PASS: <path>` | `NEEDS_REVISION: <path>` | `FAIL: <path>` | `ERROR: <reason>`
If returns `ERROR: <reason>` -> stop, surface reason.

On Result:
`CLEAN: <report_path>` -> audit clean, no findings; done.
`PASS: <report_path>` -> non-blocking findings only; done.
`NEEDS_REVISION: <report_path>` or `FAIL: <report_path>` -> surface report path, append:

   ```text

   To fix, dispatch a sub-agent with this report as input instructing it
   to fix all the issues. Keep track of revision rounds. If it has been
   3, stop here and surface the report.
   ```

`ERROR: <reason>` -> surface, stop.

Related:
`prd-writing` — companion skill for authoring PRD that passes this audit.
`dispatch` — dispatch mechanics.
