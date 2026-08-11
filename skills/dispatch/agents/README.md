# Dispatch Agent Files

Canonical Dispatch agent definitions, one per runtime environment.
Each file lives at its install path — no separate copy step required.

| File | Environment | Role |
| --- | --- | --- |
| [.claude/agents/dispatch.agent.md](../../.claude/agents/dispatch.agent.md) | Claude Code CLI | Minimal executor — reads a file and follows it |
| [.github/agents/dispatch.agent.md](../../.github/agents/dispatch.agent.md) | VS Code (GitHub Copilot) | Minimal executor — reads a file and follows it |
| [.github/agents/orchestrator.agent.md](../../.github/agents/orchestrator.agent.md) | VS Code (GitHub Copilot) | Dispatch-first orchestrator — delegates to Dispatch |
| [.github/agents/orchestration.txt](../../.github/agents/orchestration.txt) | VS Code (GitHub Copilot) | ultra-compressed how-to for the orchestrator |

## Executor (Dispatch)

Intentionally minimal — carries no context of its own. All behavior comes from
the file it reads. General-purpose runner for any skill that defines its own procedure.

Canonical path (Claude Code): `.claude/agents/dispatch.agent.md`
Canonical path (VS Code): `.github/agents/dispatch.agent.md`

## Orchestrator

A first-class VS Code agent mode — not a sub-agent. Select it from the VS Code
chat panel agent picker just like any other mode. It handles all dispatch
for you so your VS Code session requires no other wiring.

VS Code does not support nested sub-agents by default. Orchestrator is always
the host. It dispatches to Dispatch one level down — that's the full depth.

Companion `vscode-orchestration.txt` (same folder) — ultra-compressed how-to.

Canonical path: `.github/agents/orchestrator.agent.md`

Requires: Dispatch agent also installed at `.github/agents/dispatch.agent.md`

## Source

These files live at their canonical paths in `.claude/agents/` and `.github/agents/`.
To use in a host project, copy the appropriate file to the matching path in that project.
