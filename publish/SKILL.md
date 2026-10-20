---
name: publish
description: Cut a new tagged release of skills-plugin. Builds dist, bumps version, commits, tags with release notes, pushes. Triggers - publish skills-plugin, cut new release, bump plugin version, tag release, release skills plugin, ship plugin update, update plugin to latest.
---

Run `tools/publish.ps1`. Provide `-Bump` and `-Notes`. Script handles everything else.

## Inputs

- `-Bump` — required: `patch | minor | major`
- `-Notes` — required: release notes string (becomes the annotated tag body; this repo carries no CHANGELOG)
- `-DryRun` — optional: rehearse without mutating anything
- `-Force` — optional: publish even when manifest shows no changes
- `-BuildOnly` — optional: validate + rebuild the dist tree, then stop (no bump, commit, tag, or push)

## Invocation

```pwsh
cd <plugin-root>
pwsh tools/publish.ps1 -Bump patch -Notes "description of what changed"
```

## What the script does

1. Pre-flight: dirty tree, branch == main, source exists, source tree clean outside ignored/dot dirs (build is pinned to the source HEAD SHA)
2. Publish-ignore: loads `<source>/.publish-ignore` (required — the build fails closed if it is missing); listed top-level dirs never enter the dist
3. Pre-publish validation: `build/pre-publish-check.sh` gates on BOM / frontmatter / Inheritance findings
4. Change check: compares source hashes against `.hash-record/publish/last-manifest.txt` — exits early if nothing changed (skip with `-Force`)
5. Build dist: clears `skills/`, mirrors source with deny-list applied, cross-folder refs resolved (containment-checked to the source root), then asserts no denied or ignored entries landed in the dist. Also rebuilds `agents/` from each skill's `agents/*.md` (Claude Code agents; validated before the bump)
6. Bump `plugin.json` version + `built` date
7. `git add -A -- .claude-plugin/plugin.json skills/ agents/` → `git commit -m "release: v<new>"`
8. `git tag -a v<new>` — tag body carries the release notes and the source commit SHA
9. Save new manifest to `.hash-record/publish/last-manifest.txt`
10. `git push origin main && git push origin v<new>`

## Companion tools

- `tools/plan.ps1 --check` — inspect what would change before committing to a release
- `tools/plan.ps1 --save` — manually snapshot current state as baseline
- `tools/bump.ps1 minor` — bump version only (no build, no push)
