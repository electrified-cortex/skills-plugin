# skills-plugin

Distributes the [electrified-cortex/skills](https://github.com/electrified-cortex/skills) library as a Claude Code plugin. Consumers get all skills available in-context with no build step required.: scaffold skills-plugin repo structure)

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
