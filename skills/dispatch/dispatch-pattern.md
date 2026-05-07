# Dispatch Pattern

Design rationale for the `dispatch` primitive. Canonical envelope is in
`dispatch/SKILL.md` and `dispatch/uncompressed.md` — read those for the
operational spec.

## Why dispatch exists

Agent skills need to run isolated sub-agents without leaking the calling
agent's context. Dispatch provides a single cross-runtime primitive for
spawning a zero-context Dispatch agent with a verbatim prompt.

Before dispatch, each skill embedded platform-specific invocation code
(Claude Code `Agent` tool + VS Code `runSubagent` side-by-side). This
caused:

- Drift: each skill had its own wording and model selection.
- Confusion: callers constructed prompt templates internally, mixing
  "how to spawn" with "what to say."
- Maintenance cost: every model name change touched every skill.

## Variable substitution model

The current pattern requires callers to bind variables — including
`<prompt>` — in their own Variables block before calling dispatch.
Dispatch receives `<prompt>` verbatim and spawns the sub-agent.

This is the "prompt-only" shape. The caller owns prompt construction;
dispatch owns spawning. Separation of concerns.

Example from markdown-hygiene:

```text
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../dispatch/SKILL.md`.
```

## Tier system

Callers declare a tier (`fast-cheap`, `standard`, `deep`) instead of a
model name. Dispatch resolves the tier to a concrete model per runtime.
Model name changes require only one update (in `dispatch/SKILL.md`), not
across every consumer skill.

## Zero-context isolation

Dispatch agents start with no context — only the prompt. The prompt tells
them what file to read and what input to process. This prevents calling
agent state from contaminating the sub-agent's reasoning.

## Install check and fallback

If the "Dispatch" agent is not installed on the host, dispatch falls back:
omit `agentName` and continue, but notify the host after completion. This
makes the primitive resilient across environments with different agent
installations.

## Consumer Pattern

Skills that use dispatch follow a common three-phase pattern:

1. **Pre-dispatch result check**: the consuming skill calls a `result` tool (a script, not a dispatch call). If `HIT`, dispatch is skipped and the cached report is used directly.
2. **Dispatch**: the consuming skill builds a prompt (typically "read and follow `<instructions.txt>`; input: `<args>`") and calls the dispatch skill. The sub-agent reads `instructions.txt` and executes. The host **never** reads `instructions.txt` — that is the sub-agent's operative content.
3. **Post-dispatch result check**: the consuming skill calls `result` again to verify the sub-agent wrote the report. On `MISS`, the consuming skill handles the failure (log, retry up to max iterations, or surface error).

Reference consumers: the `markdown-hygiene` and `skill-auditing` skills.

## Hash-Record Relationship

Dispatch is hash-record-agnostic. The integration belongs to the consuming skill: cache check before dispatch, cache write after dispatch (by the dispatched agent). Dispatch just spawns; caching decisions are upstream.

## Historical note

Prior to the prompt-only refactor, each dispatch skill embedded a verbatim
opener (`Without reading instructions.txt yourself, spawn...`) and closer
(`NEVER READ OR INTERPRET...`). The prompt-only pattern replaced it — consumers now compose
`<prompt>` themselves and delegate all spawning mechanics to `dispatch/SKILL.md`.
