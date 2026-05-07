---
name: copilot-cli-review
description: Code review operation via the standalone Copilot CLI binary. Runs adversarial review of a change set and returns structured findings. Triggers - copilot review, review these changes, adversarial review, copilot code review, review this diff.
---

Dispatch skill. Full procedure in `instructions.txt`.

Input: `<diff>` or `<file-content>` (required) `<working_dir>` (required) `[<model>]` (optional)

Variables:
`<instructions>` = `instructions.txt` (NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `diff=<diff> working_dir=<working_dir> [model=<model>]`
`<tier>` = `standard`
`<description>` = `copilot-cli-review: <working_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Expected output:

```text
Status: CLEAN | FINDINGS | UNAVAILABLE | ERROR
Findings:
  - severity: blocker | major | minor | nit
    file: <path>
    line: <number or range>
    description: <one sentence>
Raw: <Copilot's full response>
```

Related: `copilot-cli` (router), `copilot-cli-ask`, `copilot-cli-explain`
