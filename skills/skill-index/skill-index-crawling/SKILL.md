---
name: skill-index-crawling
description: Reads an existing skill-index cascade to locate the skill matching an agent's stated need — read-only, no filesystem walking. Triggers - search skill index, find skill in index, locate skill by need, skill lookup, crawl index for skill.
---

Dispatch skill. Reads existing skill-index cascade to locate skill matching agent's stated need. Read-only — no files produced, nothing modified.

Purpose:
Find right skill by reading only index nodes. Never opens skill contents, never walks filesystem, never climbs above working dir.

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `root=<path> need=<phrase>`
`<tier>` = `fast-cheap` — pattern matching against index keywords; no deep judgment needed
`<description>` = `Skill Index Crawl: <phrase>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.
Should return: crawl report with outcome `hit: <path>` | `no match` | `ambiguous` | `no index here` | `reference loop`

Parameters:

- `root` (required): absolute path to dir whose `skill.index` is starting node.
- `need` (required): agent's stated need as plain phrase.

Returns crawl report (see Output).

How the Crawler Works:

1. Open `skill.index` at `root`. Missing → return "no index here", stop.
2. Parse each line as `key: keyword, keyword, keyword`. Split at first colon; keyword list splits on `,`. Malformed lines recorded and skipped.
3. Check stamp: open `skill.index.sha256`; compute SHA-256 of `skill.index` stored bytes; compare. Mismatch or missing stamp → overlay untrusted for this node (still usable for identity; not consulted for disambiguation).
4. Match: case-fold both sides; declare Hit when `need` appears as substring of any entry key or keyword.
5. Rank hits: self entry or plain leaf beats descent-marked. Consult overlay only to break ties among equally ranked hits in raw index (overlay never produces new candidates).
6. Exactly one hit survives ranking → return it.
7. No hits → return "no match", stop.
8. Two or more hits tied after overlay consultation → return "ambiguous".
9. Descent-marked hit → resolve target, open its `skill.index`, re-apply from step 2. Each descent lands on exactly one new node.
10. Track every visited node on resolution path. Descent would land on visited node → return "reference loop" with ordered visited sequence, stop.

Entry Types:

| Key form | Meaning |
| --- | --- |
| `foo` | Leaf skill at `./foo/` |
| `foo/` | Sub-node: descend into `./foo/skill.index` |
| `.` | Self entry: current dir is itself a skill |
| `tools/compression/` | Shortcut entry: walk path from current node; trailing `/` = deeper index exists |
| `tools/compression` | Shortcut entry: no trailing `/` = leaf skill |

Shortcut Entry Resolution:
Shortcut key (multi-segment, e.g. `a/b/c/`). Crawler:

1. Walks each segment from current node's dir.
2. At each step, verify resolved path doesn't ascend above invocation root (no `..`, no absolute paths). Violation → record `subtree-escape`, don't follow; return "subtree-escape".
3. At final segment: trailing `/` → open `skill.index` there (sub-node); no trailing `/` → leaf skill.

Combo Entry Handling:
Combo entry: descent marker AND target emits `.` self entry in its own `skill.index`. Crawler:

1. Treat as leaf first.
2. Leaf produces no hit → descend into sub-node, re-apply.

Stop Conditions:

| Outcome | Condition |
| --- | --- |
| Hit returned | Exactly one hit survives ranking |
| "no index here" | `skill.index` absent at working dir |
| "no match" | Current node produces no hits |
| "ambiguous" | Two or more hits tied after overlay consultation |
| "reference loop" | Descent would revisit node already on current resolution path |
| "subtree-escape" | Shortcut resolution attempts to leave invocation root's subtree |
| "unreadable node" | `skill.index` exists but can't be read |
| "broken descent" | Descent target lacks required file; recorded, treated as absent |

Crawl Report Fields:

- `outcome`: one of outcomes above
- `hit`: matched entry key and resolved path (when outcome is hit)
- `visited`: ordered list of node paths on resolution path
- `inconsistencies`: malformed lines, broken descents, stamp mismatches, subtree-escape attempts

Overlay Trust:
Overlay (`skill.index.md`) trusted for disambiguation only when stamp matches SHA-256 of raw index bytes. Missing or mismatched stamp → overlay untrusted; raw index only. Recorded in crawl report.

Footguns:
F1: Overlay consulted before ranking.
Mitigation: Compute hits against raw index first. Overlay only breaks ties among existing hits.

F2: Stamp mismatch ignored.
Mitigation: Mismatch or missing stamp → downgrade overlay to untrusted for that node.

F3: Crawler climbs outside working dir.
Mitigation: Only open `skill.index` at working dir; descend only via explicit descent markers.

F4: Shortcut entry escapes invocation root's subtree.
Mitigation: Subtree check at every step of every shortcut walk. Record `subtree-escape`; don't follow.

F5: Cycle detection skipped on non-shortcut descents.
Mitigation: Track visited nodes on every descent — direct-child, shortcut, combo sub-node. Halt on revisit.

Don'ts:

- Doesn't produce, author, or update any artifact.
- Doesn't open skill contents.
- Doesn't climb above working dir.
- Doesn't trust overlay when stamp is absent or mismatched.
- Doesn't follow shortcut entry out of invocation root's subtree.

Related:

- `skill-index` — root spec and toolkit overview
- `skill-index-building` — produces artifacts this skill reads
- `skill-index-auditing` — validates cascade before crawling
