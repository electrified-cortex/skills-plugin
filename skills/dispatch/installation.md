# Dispatch — Installation

## Claude Code: nothing to install

Installing the electrified-cortex-skills plugin installs the Dispatch agent.
It appears in the agent list as `electrified-cortex-skills:dispatch`.

```bash
claude plugin marketplace add https://github.com/electrified-cortex/skills-plugin
claude plugin install electrified-cortex-skills@electrified-cortex
```

Optional override: a project or user agent named `Dispatch`
(`.claude/agents/` or `~/.claude/agents/`) takes priority in the `dispatch`
skill. Copy `agents/dispatch.md` there only to change its model or tools.

## VS Code (GitHub Copilot): manual copy

VS Code does not read Claude Code plugin agents. Copy the agent into the host
project:

| Source | Install path |
| --- | --- |
| `agents/vscode/dispatch.agent.md` | `.github/agents/dispatch.agent.md` |

The agent name is `Dispatch`. See `setup/SKILL.md` for frontmatter rules.

## If no Dispatch agent is available

The dispatch primitive still works: omit `subagent_type` / `agentName` and the
host uses its default sub-agent type. The agent adds context isolation and
consistent performance. Notify the host after completion.
