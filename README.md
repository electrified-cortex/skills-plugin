# electrified-cortex-skills (plugin host)

Thin Claude Code plugin host for the [electrified-cortex/skills](https://github.com/electrified-cortex/skills) library.

## Structure

```
.claude-plugin/plugin.json   <- plugin manifest
skills/                       <- git submodule -> electrified-cortex/skills
```

## Local test

```bash
git submodule update --init
cc --plugin-dir .
```

## Versioning

Bump the `skills/` submodule pointer to advance the distributed skill set. Tag a new plugin version when published.

## Rollback

- Local `--plugin-dir` testing: stop passing the flag.
- Installed via `/plugin install`: `/plugin uninstall electrified-cortex-skills`.
