# skills-plugin

Distributes the [electrified-cortex/skills](https://github.com/electrified-cortex/skills)
library as a Claude Code plugin. The `skills/` tree is pre-built — consumers
get all skills available in-context with no build step required.

For full contract, build inputs, and invariants, see [spec.md](spec.md).

## Install

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
  publish/        # meta-skill: version-bump, changelog, tag, push
  build/          # build tooling (Stage 1 crawler)
  skills/         # distributed output tree (build output — never edit by hand)
  plugin.json     # version: mono SemVer
  CHANGELOG.md
  README.md
  spec.md         # full contract: inputs, outputs, invariants
```

## Versioning

`plugin.json` carries a single `version` field — the plugin is the unit of release.
Pin by git tag (`v<version>`) or submodule commit. No per-skill versioning.
