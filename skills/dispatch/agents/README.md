# Dispatch Agent Files

Canonical Dispatch agent definitions. This folder is the source of truth.

| File | Environment | Role |
| --- | --- | --- |
| `dispatch.md` | Claude Code | Minimal executor — reads a file and follows it |
| `orchestrator.md` | Claude Code | Dispatch-first orchestrator, run as the main session agent |
| `vscode/dispatch.agent.md` | VS Code (GitHub Copilot) | Minimal executor — reads a file and follows it |
| `vscode/orchestrator.agent.md` | VS Code (GitHub Copilot) | Dispatch-first orchestrator — delegates to Dispatch |
| `vscode/orchestration.txt` | VS Code (GitHub Copilot) | Ultra-compressed how-to for the orchestrator |

## Claude Code: shipped by the plugin

The `*.md` files directly in this folder (not `README.md`, not `vscode/`) are
Claude Code agents. The skills-plugin publish script copies them to the
plugin's root `agents/` folder, where Claude Code registers them on install.
They load under the plugin's scoped names:

- `electrified-cortex-skills:dispatch`
- `electrified-cortex-skills:orchestrator`

No copy step is needed. A project (`.claude/agents/`) or user (`~/.claude/agents/`)
agent named `Dispatch` still works and is preferred when present.

Plugin agents ignore `hooks`, `mcpServers` and `permissionMode` in frontmatter.
Keep those out of these files.

## VS Code: manual install

VS Code reads agents from `.github/agents/` in the host project. Copy
`vscode/dispatch.agent.md` to `.github/agents/dispatch.agent.md`. For the
orchestrator mode, also copy `vscode/orchestrator.agent.md` and
`vscode/orchestration.txt` into the same folder. See `../setup/SKILL.md`.

## Executor (Dispatch)

Intentionally minimal — carries no context of its own. All behavior comes from
the file it reads. General-purpose runner for any skill that defines its own procedure.

## Orchestrator

A main-session agent, not a sub-agent. In VS Code, select it from the chat
panel agent picker. In Claude Code, start a session with
`claude --agent electrified-cortex-skills:orchestrator`.

VS Code does not support nested sub-agents by default. Orchestrator is always
the host. It dispatches to Dispatch one level down — that's the full depth.
