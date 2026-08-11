# Dispatch — Installation

The dispatch skill requires a companion agent file installed in your project's agent directory.

## Agent Files

Source: `dispatch/agents/`
See `dispatch/agents/README.md` for agent file descriptions and install path details.

| File | Environment | Install path |
| --- | --- | --- |
| `claude-dispatch.agent.md` | Claude Code CLI | `.claude/agents/dispatch.agent.md` |
| `vscode-dispatch.agent.md` | VS Code (GitHub Copilot) | `.github/agents/dispatch.agent.md` |

Copy the appropriate file. The agent name is `Dispatch` in both environments.

## If Not Installed

The dispatch primitive works without the agent file — it omits `subagent_type` / `agentName` and dispatches using the default subagent type. Behavior is identical to when the agent is installed; the agent file adds context isolation and consistent performance. Install is strongly recommended for production use. Notify the host after completion if the agent file is absent.
