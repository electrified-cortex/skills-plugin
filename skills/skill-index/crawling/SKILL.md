---
name: crawling
description: Reads an existing skill-index cascade to locate the skill matching an agent's stated need — read-only, no filesystem walking. Triggers - search skill index, find skill in index, locate skill by need, skill lookup, crawl index for skill, crawling.
---

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `root=<path> need=<phrase>`
`<tier>` = `fast-cheap`
`<description>` = `Skill Index Crawl: <phrase>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

`root` (required): absolute path to dir whose `skill.index` is starting node.
`need` (required): agent's stated need as plain phrase.

Returns: `hit: <path>` | `no match` | `ambiguous` | `no index here` | `reference loop` | `subtree-escape` | `unreadable node`.

Related: `building` (`../building`), `auditing` (`../auditing`), `integration` (`../integration`).