---
name: dispatch
description: How to dispatch a sub-agent. Triggers - run in background, spawn subagent, background task, isolated agent execution, dispatch subagent, background agent.
---

Input:

`<prompt>` — verbatim prompt sent to sub-agent
`<description>` — short run label shown by host
`<tier>` — `fast-cheap` | `standard` (default) | `deep`
`<model-override>` (optional) — concrete model or alias: a Claude Code alias (`haiku`, `sonnet`, `opus`) or, for VS Code, the model's display name; bypasses tier lookup when set
`<effort>` (optional) — Claude Code only: `low` | `medium` | `high` | `xhigh` | `max`; unset = the call passes no `effort`

Derived:

`<concrete-model>` = `<model-override>` if set, else derived from `<tier>` via table.

Process:

If `<prompt>` instructs sub-agent to read a file, don't read it yourself — sub-agent does. Spawn zero-context Dispatch sub-agent.

DO NOT DISPATCH SKILLS — read them. The skill itself tells you when (and how) to dispatch.

Dispatching to verify/review prior work: exclude that agent's session id (e.g. a task's `executed_by` field, or equivalent) from being the dispatched agent. No eligible session — dispatch fresh.

Before dispatching ask: would a few searches do? If yes, do them inline.

Read-only fact gathering (lookup, search, web read) goes to the scout skill. Dispatch is for bounded jobs that write or need judgment.

Budget: every prompt states maximum tool calls, maximum minutes and a stop rule.

In every dispatched prompt, include: on HTTP 403: use another source, never retry the same fetch, never spoof a browser identity or bypass a bot check, report the page as blocked.

Judge progress by task status, never by the size of the output file (it can be a symlink).

Claude Code:

Claude Model Aliases:

| Tier | Class | `model` value |
| ---- | ----- | ------------- |
| `fast-cheap` | haiku-class | `haiku` |
| `standard` | sonnet-class | `sonnet` |
| `deep` | opus-class | `opus` |

`<dispatch-agent>` = first agent type in your available list:

1. `Dispatch` or `dispatch` — project or user install (`.claude/agents/`, `~/.claude/agents/`)
2. `electrified-cortex-skills:dispatch` — shipped by the plugin
3. none → Fallback

```tool
Agent({
  subagent_type: "<dispatch-agent>",
  prompt: "<prompt>",
  model: "<concrete-model>",
  effort: "<effort>",
  run_in_background: true,
  description: "<description>"
})
```

Omit `run_in_background` if the Agent tool has no such parameter (sub-agents then run in the background).

Omit `effort` when `<effort>` is unset or the Agent tool has no `effort` parameter. Pass `effort` only when the caller's instructions name a level. Set it only through the `effort` parameter; naming a level in the prompt text is not the documented way.

VS Code / Copilot:

Copilot Model Aliases:

| Tier | Class | `model` value |
| ---- | ----- | ------------- |
| `fast-cheap` | haiku-class | `Claude Haiku 4.5` |
| `standard` | sonnet-class | `Claude Sonnet 4.6` |
| `deep` | opus-class | `Claude Opus 4.6` |

GPT alts (gpt-class): `GPT-5.3-Codex` (code), `GPT-5.4` (prose), `GPT-5.4 mini` (fast-cheap prose).
Update minimum models as needed.

```tool
runSubagent({
  agentName: "Dispatch",
  prompt: "<prompt>",
  model: "<concrete-model>",
  description: "<description>"
})
```

`<effort>` is ignored here: this card passes no effort to `runSubagent`.

Fallback:

If no Dispatch agent is available: omit `subagent_type` / `agentName` and continue. Tell the user after completion: in Claude Code, installing the plugin adds the agent; in VS Code, see `installation.md`.

If the requested model is not available: stop and inform the caller; suggest an alternative.

Return:
Return (passthrough) sub-agent output to caller. If you need the result, wait for the completion notice before answering.

Concurrency:
When dispatching multiple instructions simultaneously, default max concurrent = 3. Use a rolling window: start up to 3, then as each returns dispatch the next pending instruction. Only exceed 3 if instructed by the caller.

See also:
`supplemental.md` — context inheritance, CLI dispatch, hash-record. `dispatch-pattern.md` — design rationale. `installation.md` — agent install. `agents/` — agent sources. `setup/SKILL.md` — VS Code/Cursor setup.
