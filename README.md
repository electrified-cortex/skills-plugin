# skills-plugin

Distributes the [electrified-cortex/skills](https://github.com/electrified-cortex/skills)
library as a Claude Code plugin. The `skills/` tree is pre-built — consumers
get all skills available in-context with no build step required.

For full contract, build inputs, and invariants, see [spec.md](spec.md).

## Set me up in Claude Code

If you've been told "set me up in Claude Code" with this repo URL, run these two commands. No further input required:

```bash
claude plugin marketplace add https://github.com/electrified-cortex/skills-plugin
claude plugin install electrified-cortex-skills@electrified-cortex
```

This also installs the plugin's agents, such as `electrified-cortex-skills:dispatch`.
No agent files need copying.

## Update in Claude Code

To move an existing install to the latest release, refresh the marketplace,
update the plugin, then restart Claude Code:

```bash
claude plugin marketplace update electrified-cortex
claude plugin update electrified-cortex-skills@electrified-cortex
```

Installed at more than one scope (for example user and project)? Add
`--scope user`, `--scope project` or `--scope local` and run the update once
per scope. `claude plugin list` shows the installed version and scope.

## Set me up in VS Code (GitHub Copilot)

Skills use the [Agent Skills open standard](https://agentskills.io),
natively compatible with GitHub Copilot Chat in VS Code.

Clone this repo somewhere outside your project, then copy the skill
directories you want:

```bash
git clone https://github.com/electrified-cortex/skills-plugin
```

**Project install** — copy any skill directory into `.github/skills/`:

```bash
cp -r skills-plugin/skills/<skill-name> .github/skills/
```

**User-level install** — cross-project personal access:

```bash
# Linux / macOS
cp -r skills-plugin/skills/<skill-name> ~/.copilot/skills/

# Windows (PowerShell)
Copy-Item -Recurse skills-plugin\skills\<skill-name> $HOME\.copilot\skills\
```

After copying, type `/skills` in Copilot Chat to confirm the skill appears.

To update, pull the clone and copy again.

## Consumer notes

- No build step needed. The `skills/` tree is pre-built and ready to use.

## Structure

```text
skills-plugin/
  publish/        # meta-skill: version-bump, tag, push
  build/          # deny-list + pre-publish validation gate
  tools/          # publish.ps1 release pipeline + helpers
  skills/         # distributed output tree (build output — never edit by hand)
  agents/         # Claude Code agents hoisted from <skill>/agents/ (build output)
  .claude-plugin/ # plugin.json (version: mono SemVer) + marketplace.json
  README.md
  spec.md         # full contract: inputs, outputs, invariants
```

Release notes live in each version's annotated git tag — there is no CHANGELOG
file.

## Versioning

`plugin.json` carries a single `version` field — the plugin is the unit of release.
Releases are git tags (`v<version>`). No per-skill versioning.
