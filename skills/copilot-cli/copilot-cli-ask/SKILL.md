---
name: copilot-cli-ask
description: General query or advice operation via the standalone Copilot CLI binary. Returns Copilot's plain text answer. Triggers - ask copilot, copilot question, get advice from copilot, query copilot, copilot answer.
---

Dispatch skill. Full procedure in `instructions.txt`.

Input: `<question>` (required) `[<context>]` (optional) `[<model>]` (optional)

Variables:
`<instructions>` = `instructions.txt` (NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `question=<question> [context=<context>] [model=<model>]`
`<tier>` = `fast-cheap`
`<description>` = `copilot-cli-ask: <question>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.

Expected output:

```text
Status: OK | ERROR | UNAVAILABLE
Answer: <Copilot's plain text response>
```

Related: `copilot-cli` (router), `copilot-cli-review`, `copilot-cli-explain`
