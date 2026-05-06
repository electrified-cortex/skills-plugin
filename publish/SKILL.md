---
name: publish
description: Cut a new tagged release of skills-plugin. Bumps plugin.json version, rebuilds skills/ dist via build.ps1, updates CHANGELOG, commits, tags, pushes. Triggers - publish skills-plugin, cut new release, bump plugin version, tag release, release skills plugin, ship plugin update.
---

`<instructions>` = `instructions.txt` (this folder; NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `version_bump=<version_bump> release_notes=<release_notes> [source_root=<source_root>] [dry_run=<dry_run>]`
`<tier>` = `standard`
`<description>` = `Publish: <version_bump>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../skills/dispatch/SKILL.md`.

Inputs:

`<version_bump>` — patch/minor/major
`<release_notes>` — changelog entry text
`<source_root>` (optional) — override repo root
`<dry_run>` (optional) — if true, skip commit/tag/push, return dry-run plan

Returns: status report (prev version, new version, files changed, build report, push result) on success | dry-run plan if `dry_run=true` | `ERROR: <status>` on failure