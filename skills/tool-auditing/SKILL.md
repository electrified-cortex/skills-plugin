---
name: tool-auditing
description: Audit a tool script for companion spec, conventions, and error handling. Triggers — audit tool, check tool script, review tool conventions, tool compliance, tool script audit, tool auditing.
---

## Input

`<tool_path>` — absolute path to ANY member of the **tool trio**: `<stem>.sh`, `<stem>.ps1`, or `<stem>.spec.md`. The audit covers the trio together: ALL three (`<stem>.sh`, `<stem>.ps1`, `<stem>.spec.md`) MUST exist; any missing member causes audit FAIL on Check 1.

## Inline result check (pre-inspect)

Run the `result` tool (in this folder), whichever your runtime has. DON'T READ the trio source at any point — before, during, or after invocation. Run it, branch on stdout, move on.

- Bash: `bash result.sh <tool_path>`
- PS7: `pwsh result.ps1 <tool_path>`

If stdout is `MISS: <abs-path>` -> bind `<report_path>` = `<abs-path>`, continue to Inspect.
Otherwise -> emit stdout verbatim, stop.

## Inspect

Variables:

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `tool_path=<tool_path> --report-path <report_path>`
`<tier>` = `standard`
`<description>` = `Auditing tool: <tool_path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.
Should return: `PASS: <path>` | `PASS_WITH_FINDINGS: <path>` | `FAIL: <path>` | `ERROR: <reason>`
If returns `ERROR: <reason>` -> stop, surface reason.

## Inline result check (post-execute)

You (the host) run `result` again directly — do NOT dispatch it.
Same invocation as the first Inline result check (pre-inspect).
Branch on stdout (last line):

- `PASS: <report_path>` -> done.
- `PASS_WITH_FINDINGS: <report_path>` -> non-blocking warnings; surface verdict and stop.
- `FAIL: <report_path>` -> blocking; surface verdict and stop.
- `ERROR: <reason>` -> stop, surface reason.
- `MISS: <abs-path>` -> executor failed to write report; surface `ERROR: executor did not write report at <report_path>`, stop.
