---
name: publish
description: Cut a new tagged release of skills-plugin. Builds dist, bumps version, updates CHANGELOG, commits, tags, pushes. Triggers - publish skills-plugin, cut new release, bump plugin version, tag release, release skills plugin, ship plugin update, update plugin to latest.
---

Run `tools/publish.ps1`. Provide `-Bump` and `-Notes`. Script handles everything else.

## Inputs

- `-Bump` — required: `patch | minor | major`
- `-Notes` — required: release notes string (becomes CHANGELOG entry)
- `-DryRun` — optional: rehearse without committing
- `-Force` — optional: publish even when manifest shows no changes

## Invocation

```pwsh
cd <plugin-root>
pwsh tools/publish.ps1 -Bump patch -Notes "description of what changed"
```

## What the script does

1. Pre-flight: dirty tree, branch == main, source exists
2. Change check: compares source hashes against `.hash-record/publish/last-manifest.txt` — exits early if nothing changed (skip with `-Force`)
3. Build dist: clears `skills/`, mirrors source with deny-list applied, cross-folder refs resolved
4. Bump `plugin.json` version + `built` date
5. Prepend CHANGELOG entry
6. `git add plugin.json CHANGELOG.md skills/` → `git commit -m "release: v<new>"`
7. `git tag -a v<new> -m "v<new>"`
8. Save new manifest to `.hash-record/publish/last-manifest.txt`
9. `git push origin main && git push origin v<new>`

## Companion tools

- `tools/plan.ps1 --check` — inspect what would change before committing to a release
- `tools/plan.ps1 --save` — manually snapshot current state as baseline
- `tools/bump.ps1 minor` — bump version only (no build, no push)
