---
name: skill-auditing
description: Audit a skill for quality, classification, cost, and compliance with the skill-writing spec. Triggers — audit this skill, check skill quality, review skill compliance, validate skill structure, skill needs review, skill audit.
---

Input:
`<skill_dir>` — repo-relative path to skill folder being audited.

Inline result check:
Run `result` tool (this folder) per runtime. DON'T READ script source — before, during, or after. Run it, branch on stdout, move on.
Bash: `bash result.sh <skill_dir>`; PS7: `pwsh result.ps1 <skill_dir>`

If stdout is `MISS: <abs-path>` -> bind `<report_path>` = `<abs-path>`, continue to Preparation.
Otherwise -> emit stdout verbatim, stop.

Inspect:
Variables:
`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `skill_dir=<skill_dir> --report-path <report_path>`
`<tier>` = `fast-cheap` — first pass. Subsequent passes use `standard`.
`<description>` = `Auditing skill: <skill_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.
Should return: `CLEAN: <path>` | `PASS: <path>` | `NEEDS_REVISION: <path>` | `FAIL: <path>` | `ERROR: <reason>`
If returns `ERROR: <reason>` -> stop, surface reason.

Inline result check (post-execute):
Host runs `result` again directly — DON'T dispatch it.
Same invocation as first Inline result check.
Branch on stdout (last line):

`CLEAN: <report_path>` -> audit clean — no findings; done.
`PASS: <report_path>` -> `done.`
`ERROR: <reason>` -> surface stdout, stop.
`MISS: <abs-path>` -> executor failed to write report; surface `ERROR: executor did not write report at <report_path>`, stop.
`FAIL: <report_path>` or `NEEDS_REVISION: <report_path>` -> surface stdout, append:

   ```text

   To fix, load `../dispatch/SKILL.md` and use the `dispatch` skill to launch a standard-tier sub-agent; pass this report as input instructing it to fix all the issues. Keep track of revision rounds. Stop at 3 and surface the report.
   ```
