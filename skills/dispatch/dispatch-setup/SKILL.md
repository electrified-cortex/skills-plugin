---
name: dispatch-setup
description: Configure the dispatch skill agent file correctly in VS Code and Cursor. Triggers — dispatch setup, configure dispatch, runSubagent not working, agent not found, VS Code dispatch, Cursor dispatch setup.
---

Claude Code CLI has no known setup issues.
This skill applies to VS Code (GitHub Copilot) and Cursor only.

## Agent File Location

| Environment | Path |
| --- | --- |
| VS Code / Cursor | `.github/agents/dispatch.agent.md` |
| Claude Code CLI | `.claude/agents/dispatch.agent.md` |

VS Code can read `.claude/agents/` but tends to get permissions wrong and is generally true in reverse with `.github/agents/`
The right thing to do is simply copy these to the correct location.

## Required Frontmatter

All four fields are mandatory:

```yaml
---
name: Dispatch
description: Minimal agent that reads a target file and follows its instructions. No extra context.
model: Claude Sonnet 4.6
tools: [read, edit, search, execute, web/fetch, websearch]
---
```

`name` — must match `agentName` in `runSubagent`. Canonical: `Dispatch`.
`description` — non-empty string.
`model` — human-readable name with spaces (see below).
`tools` — list every tool the sub-agent needs. Missing → silent failure.

## Model Name Format

Use the human-readable form with spaces. Slugs are invalid.

| Valid | Invalid |
| --- | --- |
| `Claude Sonnet 4.6` | `claude-sonnet-4-6` |
| `Claude Haiku 4.5` | `claude-haiku-4-5` |
| `Claude Opus 4.6` | `claude-opus-4-6` |

Slug in `model` field → silent fallback or error. Failure not always surfaced in the UI.

## Host vs Sub-Agent

The host's model setting does not control the dispatched agent's model. The sub-agent model comes from the agent file's `model` field (or the optional `model` arg at call time). These are independent.

## Context — Hand-Feed Everything

Project context (CLAUDE.md, memory) is unverified as inherited in VS Code. Treat as NOT inherited. Every dispatch prompt must include:

- Goal (one sentence)
- All needed file paths (absolute)
- Prior decisions, preferences, findings
- Output shape and constraints

## Dispatch Primitive

`runSubagent(agentName: "Dispatch", prompt: "...", description: "...")` — always synchronous (blocking). No background dispatch. "Background dispatch" from the parent skill does not apply here.

## Cursor

Assumed similar to VS Code: same path, frontmatter rules, model name format. No confirmed differences. Treat all Cursor guidance as "assumed similar."

## Pitfalls

| Symptom | Cause |
| --- | --- |
| Wrong model silently | Slug in `model` field |
| Sub-agent can't use tools | `tools` field missing or incomplete |
| Sub-agent lacks task context | Context not inherited; hand-feed it |
| Dispatch hangs or appears parallel | No — `runSubagent` serializes; re-evaluate for blocking cost |
