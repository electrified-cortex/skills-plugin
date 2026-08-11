---
name: finding
description: Cache-accelerated skill lookup. Returns file path or URL for a named skill in a single Haiku pass. Cache hit is near-instant. Cache miss invokes crawling and caches result. Triggers - find skill, locate skill, where is skill, get skill path, finding, look up skill, skill lookup.
---

Cache-first skill lookup. Returns path or URL on hit; invokes crawling and caches result on miss. Haiku tier — minimum token cost.

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `query=<text> root=<path>`
`<tier>` = `fast-cheap`
`<description>` = `Skill Finder: <query>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

`query` (required): skill name or purpose description.
`root` (required): absolute path to the directory containing `.skill-index/` (or where it should be created).

Returns: `hit: <path>` | `hit: <url>` | `crawled: <path>` | `stale-updated: <path>` | `not-found: <query>`
