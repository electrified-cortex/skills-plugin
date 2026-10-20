# Scout — Installation

## Claude Code: nothing to install

Installing the electrified-cortex-skills plugin installs the scout agent. It
appears in the agent list as `electrified-cortex-skills:scout`, with its tool
allowlist (Read, Grep, Glob, Bash, WebFetch, WebSearch) and Haiku model pin.

```bash
claude plugin marketplace add https://github.com/electrified-cortex/skills-plugin
claude plugin install electrified-cortex-skills@electrified-cortex
```

Optional override: a project or user agent named `scout` (`.claude/agents/` or
`~/.claude/agents/`) takes priority in the skill. Copy `agents/scout.md` there
only to change its model, tools or rules.

## Without the agent

The skill still runs: it hands the brief to `Explore` or `general-purpose` with
a prompt to read `agents/scout.md` and follow it. Those agents don't carry the
tool allowlist, so the read-only rules rest on the agent body alone.
