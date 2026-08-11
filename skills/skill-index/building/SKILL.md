---
name: building
description: Creates or updates skill.index and skill.index.md at every indexed directory in a skill tree. Integrity stamp written by auditor after PASS. Triggers - build skill index, create skill index, update skill index, rebuild index, generate skill index, building.
---

Creates/updates `skill.index` and `skill.index.md` at every indexed dir. Integrity stamp written by auditor after PASS — not builder.

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `root=<path> [--dot-allow <name,...>] [--rebuild]`
`<tier>` = `standard`
`<description>` = `Skill Index Build: <path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

`root` (required): absolute path to invocation root.
`--dot-allow` (optional): comma-separated dot-folder bare names (no globs, no paths). Default: empty.
`--rebuild` (optional): regenerate all nodes regardless of stored content.

Returns: change manifest — nodes created, updated, unchanged, blocked, broken-shortcut, skipped.