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

## Set me up in VS Code (GitHub Copilot)

Skills use the [Agent Skills open standard](https://agentskills.io),
natively compatible with GitHub Copilot Chat in VS Code.

**Project install** — copy any skill directory into `.github/skills/`:

```bash
cp -r .claude-plugins/ec-skills/skills/<skill-name> .github/skills/
```

**User-level install** — cross-project personal access:

```bash
# Linux / macOS
cp -r .claude-plugins/ec-skills/skills/<skill-name> ~/.copilot/skills/

# Windows (PowerShell)
Copy-Item -Recurse .claude-plugins\ec-skills\skills\<skill-name> $HOME\.copilot\skills\
```

After copying, type `/skills` in Copilot Chat to confirm the skill appears.

## Install (submodule)

```bash
git submodule add https://github.com/electrified-cortex/skills-plugin .claude-plugins/ec-skills
git submodule update --init --recursive
```

Then reference in your Claude Code project config.

## Agent reference pattern

Skills are available at:

```text
<submodule>/skills/<skill-name>/SKILL.md
```

Example: `.claude-plugins/ec-skills/skills/compression/SKILL.md`

## Consumer notes

- No build step needed. The `skills/` tree is pre-built and ready to reference.
- To update: `git submodule update --remote .claude-plugins/ec-skills`
- Rollback: revert the submodule pointer to the previous commit.

## Structure

```text
skills-plugin/
  .claude-plugin/
    plugin.json    # plugin manifest: name, version, description (the manifest Claude Code reads)
  build/           # build tooling (deny-list, blob-hash)
  tools/           # publish toolchain (bump, plan, publish)
  skills/          # distributed output tree (build output — never edit by hand)
  CHANGELOG.md
  README.md
  spec.md          # full contract: inputs, outputs, invariants
```

## Versioning

`.claude-plugin/plugin.json` carries a single `version` field — the plugin is
the unit of release. Pin by git tag (`v<version>`) or submodule commit. No
per-skill versioning.
