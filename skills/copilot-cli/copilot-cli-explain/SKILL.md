---
name: copilot-cli-explain
description: Explain operation via the standalone Copilot CLI binary. Returns an explanatory markdown description of a code region or file. Triggers - explain this code, copilot explain, what does this do, explain this file, describe this function.
---

Dispatch skill. Full procedure in `instructions.txt`.

Input: `<code-content>` (required) `<working_dir>` (required) `[<model>]` (optional)

Variables:
`<instructions>` = `instructions.txt` (NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `code_content=<code-content> working_dir=<working_dir> [model=<model>]`
`<tier>` = `fast-cheap`
`<description>` = `copilot-cli-explain: <working_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Expected output:

```text
Status: OK | ERROR | UNAVAILABLE
Explanation: <Copilot's markdown explanation>
```

Related: `copilot-cli` (router), `copilot-cli-review`, `copilot-cli-ask`
