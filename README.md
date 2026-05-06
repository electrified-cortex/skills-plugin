# skills-plugin

Distributes the [electrified-cortex/skills](https://github.com/electrified-cortex/skills) library as a Claude Code plugin. Consumers get all skills available in-context with no build step required.

## Install

```bash
git submodule add https://github.com/electrified-cortex/skills-plugin .claude-plugins/ec-skills
git submodule update --init --recursive
```

Then reference in your Claude Code project config.

## Agent reference pattern

Skills are available at:

```
<submodule>/skills/<skill-name>/SKILL.md
```

Example: `.claude-plugins/ec-skills/skills/compression/SKILL.md`

## Consumer notes

- No build step needed. The `skills/` tree in this repo is the distributed output — pre-built and ready to reference.
- To update skills: `git submodule update --remote .claude-plugins/ec-skills`
- Rollback: revert the submodule pointer to the previous commit.

## Structure

```
skills-plugin/
  publish/        # meta-skill: how to publish a new plugin release (T10)
  build/          # build tooling (sibling/url crawler — T2)
    build.ps1
    config.yaml
  skills/         # git submodule -> electrified-cortex/skills (distributed output)
  plugin.json     # version registry (mono semver)
  CHANGELOG.md
  README.md
```

## Versioning

`plugin.json` carries a single `version` field — the plugin is the unit of release. No per-skill versioning. Bump and tag when publishing a new release.
