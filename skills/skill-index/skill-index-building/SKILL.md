---
name: skill-index-building
description: Dispatch skill. Creates or updates skill.index and skill.index.md at every indexed directory in a skill tree. Integrity stamp written by auditor after PASS. Triggers - build skill index, create skill index, update skill index, rebuild index, generate skill index.
---

Dispatch skill. Creates or updates two index artifacts at every indexed dir in a skill tree: `skill.index` (raw index) and `skill.index.md` (metadata overlay). Integrity stamp (`skill.index.sha256`) written by auditor after PASS — not builder.

Artifacts:

Every indexed dir gets exactly two files from builder:

| File | Description |
| --- | --- |
| `skill.index` | Plain-text raw index. Three lines per entry (key heading, triggers, path), plus one blank line between entries. Deterministic for mechanical portion. |
| `skill.index.md` | Markdown metadata overlay. H1 + one `## name` section per entry. Trigger-shaped prose: when to load, not what the skill does. |

Absent stamp = unaudited since last build, not needs-rebuild.

## Dispatch

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `root=<path> [--dot-allow <name,...>] [--rebuild]`
`<tier>` = `standard` — generative index writing requires reliable output quality
`<description>` = `Skill Index Build: <path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.
Should return: change manifest (nodes created, updated, unchanged, broken-shortcut, skipped)

Parameters:
`root` (required): absolute path to invocation root.
`--dot-allow` (optional): comma-separated dot-folder bare names to traverse (no globs, no paths). Default: empty.
`--rebuild` (optional): full-rebuild — regenerates all nodes regardless of stored raw index content.

Returns change manifest: nodes created, updated, unchanged, blocked (overlay compression failed), broken-shortcut targets, unreadable dir skips.

Header Output:

The builder emits a header block at the top of each `skill.index` file. Required fields:

`role:` — the agent role this index is scoped to. Builder emits `role:` (not the deprecated `agent:` field). Readers must accept both; builders must emit `role:`.
`built:` — ISO-8601 timestamp of the original build. Set once; not updated on rebuild. If rebuilding an existing index that already has `built:`, preserve its value. Only `updated:` changes on rebuild.
`updated:` — ISO-8601 timestamp of the most recent build or rebuild. Always updated on every run.

If rebuilding an existing index that already has `built:`, preserve its value. Only `updated:` changes on rebuild.

Raw Index Format (`skill.index`):

Each entry is three lines, followed by one blank line before the next entry:

```
## <key> [op|self]
triggers: <phrase> | <phrase> | <phrase>
path: <relative-path-to-SKILL.md>
```

Key line: `## <key> <marker>`. Key is child dir name (no path prefix, no extension). Marker is `[op]` for operator-triggered skills or `[self]` for agent-self-triggered skills. Exactly one marker per entry.
Sub-node marker: when child contains its own `skill.index`, key ends in `/` before the space and marker. Example: `## sub-node/ [op]`.
Self entry: key is `.` when current dir is combo node (manifest present + at least one indexable child). Self entry first, before sorted block.
Sort: byte-lexicographic on full UTF-8 key (excluding marker). `.` always first. Shortcut keys share sort space. `/` (0x2F) compares by byte value. Shorter key first when one is a proper prefix.

Marker Assignment:

To determine the marker for each skill entry at build time:

1. Check the skill's SKILL.md frontmatter for a `trigger-mode: op` or `trigger-mode: self` field. If present, use it.
2. If absent, infer from the skill name and description: skills whose primary invocation is explicit operator request (name contains 'spawn', 'merge', 'review', 'deploy', etc.) default to `[op]`; skills whose primary invocation is agent workflow state (name contains 'scan', 'verify', 'compress', 'crawl', 'audit', etc.) default to `[self]`.
3. When inference is ambiguous, emit `[op]` as the conservative default and add a `# TODO: verify marker` comment in the raw index entry.
4. The calling agent building the index may override the inferred marker via an explicit override list passed to the builder.

`triggers:` line: pipe-separated natural-language trigger phrases. Single space after `triggers:`. ` | ` (space-pipe-space) between phrases.
R21: At least three phrases per entry.
R22: No phrase may duplicate the entry key verbatim (paraphrases, synonyms, and related phrases required).
R23: No phrase set consisting solely of single-word entries (at least one phrase must be multi-word).
R24: At least one phrase per entry must contain two or more words.
Phrases are lower-case; no trailing period. Phrases describe when an operator or agent invokes the skill — not the skill's internal mechanics.

`path:` line: relative path from the index file's directory to the skill's `SKILL.md`. Forward slashes. No anchor fragments.

Example entries:

```
## spawn-worker [op]
triggers: spawn a worker | no workers available | queue is backed up | add capacity | fleet is empty | worker is dead or stuck
path: ../../skills/- fleet/spawn-worker/SKILL.md

## scan-tasks [self]
triggers: idle cycle start | before verification pass | any tasks done | what is pending | check queue depth
path: ../../skills/task-engine/scan-tasks/SKILL.md
```

Metadata Overlay Format (`skill.index.md`):

H1: dir's identifying title plus " — skill index" suffix. Example: `# Overseer — skill index`.
Optional preamble (at most two sentences) between H1 and first section. Preferred phrasing: "Match the operator's words (or your current situation) to an entry below, then load that skill." Do not describe index mechanics.
One `## name [marker]` section per entry key in same order as raw index. Self entry's section uses dir's own name, not `.`. Marker (`[op]` or `[self]`) must appear on every section heading.
Each section: one to three trigger-shaped sentences. No lists. No code blocks.

R29: Every overlay section must be trigger-shaped — it must express when to load the skill (operator phrasing or agent-observed situation), not describe what the skill does.
Non-conformant (description-shaped): "This skill dispatches a new worker process."
Conformant (trigger-shaped, operator): "When the operator says 'spawn a worker', 'no workers available', or 'queue is backed up'."
Conformant (trigger-shaped, agent-self): "At the start of every idle cycle and before any verification pass."

R30: The `[op]` or `[self]` marker must appear in each section heading. Operator-triggered sections (`[op]`) lead with operator-quoted phrases in double quotes. Agent-self-triggered sections (`[self]`) lead with plain imperatives.
Mustn't describe trailing slashes, dot entries, nav mechanics, or index artifact internals.
Must pass full compression pass before builder writes. Compression fails → builder aborts node (blocked), leaves prior artifacts unchanged, continues with siblings.

Build Logic:

Incremental Mode (default):

For each node:

1. Compute mechanical portion: self entry (combo node — manifest + at least one indexable child) + direct-child entries.
2. Merge with preserved shortcut entries from existing `skill.index`.
3. Sort combined list per sort rule.
4. Serialize as three lines per entry plus blank-line separator.
5. Compute SHA-256 of serialized content.
6. Compare against SHA-256 of stored `skill.index` bytes. `skill.index.sha256` stamp not consulted — auditor's artifact, not builder freshness marker.
7. Hashes match: no writes. Record unchanged.
8. Hashes differ (or no stored `skill.index`): generate overlay in memory → compression check → on success, write strict order: `skill.index` first, then `skill.index.md`. Don't terminate normally between two writes of single node.

Full-Rebuild Mode (`--rebuild`):

Regenerates all nodes regardless of stored raw index content. Same write order and compression gate as incremental.

Write Order (strict):

1. `skill.index`
2. `skill.index.md`

Don't terminate normally between these two writes for single node.

Traversal Rules:

Walk downward from invocation root.
Skip dot-prefixed dirs by default; only traverse dot-folders named in `--dot-allow`.
Don't follow symlinks.
Dir has indexable children: write artifacts and descend.
Dir has no indexable children, no skill manifest: write empty `skill.index` (zero bytes) and overlay with only H1, no sections.
Dir has no indexable children but has skill manifest (pure leaf): don't write `skill.index`. Parent's index already references leaf as plain entry; leaf's manifest describes it.

Combo Nodes:

Combo node: dir with own skill manifest + at least one manifest-bearing child.
Emits `.` self entry in own `skill.index`. Emits sub-node-marked entry (key ending in `/`) in parent's `skill.index`. Manifest-bearing subdirs traversed normally.

Curator-Added Shortcut Entries:

Shortcut entries: multi-segment keys (e.g. `tools/compression/`). Curator-added; never mechanically generated.

When existing `skill.index` at node contains shortcut entries:
Preserve verbatim: same key, same triggers line, same path line, same character sequence.
Merge with freshly generated mechanical portion.
Sort combined list per sort rule. Self entry (if any) remains first.
Preserved shortcut target missing from filesystem: record as `broken-shortcut` in change manifest; emit entry unchanged. Don't repair or remove — curator decision.
Don't evaluate shortcut structural legality (subtree containment or acyclicity). Auditor's responsibility.
Curator trigger lists inside preserved shortcuts are authoritative even if non-conformant; treat as opaque text for that entry.

Error Handling:

Unreadable dir: skip, record as skipped in change manifest, continue with siblings.
Overlay compression failure: record as `blocked`, leave prior artifacts unchanged, continue.
Partial-write protection: don't terminate normally between two writes of single node.
Change manifest not producible: emit non-zero exit; don't silently succeed.

Footguns:

F1: Stamp consulted for change detection.
Mitigation: Builder never reads `skill.index.sha256` for change detection. Compare SHA-256 of recomputed raw content against SHA-256 of stored `skill.index` bytes. Stamp is auditor's artifact.

F2: Builder writes stamp.
Mitigation: Write order is `skill.index` → `skill.index.md`. No stamp write. Auditor writes stamp on PASS.

F3: Combo node treated as pure leaf.
Mitigation: Emit self entry AND enumerate manifest-bearing subdirs. Traversal not suppressed.

F4: Dot-folder allow-list used as path expression.
Mitigation: Allow-list entries: bare names only — no globs, paths, regexes.

F5: Builder erases curated shortcuts on rebuild.
Mitigation: Preserve shortcut entries verbatim across all runs.

F6: Overlay section describes what a skill does instead of when to load it.
Mitigation: Every section must answer "when does the agent reach for this skill?" not "what does this skill do?" Rewrite description-shaped sections before writing. Examples:
  Non-conformant: "Compress markdown sessions, notes, or docs to reduce token budget."
  Conformant: "Before writing any overlay, or when a document has grown past the context budget."

F7: Entry heading omits [op]/[self] marker.
Mitigation: Every entry in both `skill.index` (key line) and `skill.index.md` (section heading) must carry exactly one marker. Reject entries without markers as malformed.

Don'ts:

Doesn't author skill content.
Doesn't validate or audit skills.
Doesn't decide which dot-folders to traverse — supplied via `--dot-allow`.
Doesn't emit `skill.index` with `.md` extension.
Doesn't embed nav or mechanical explanation in overlay sections.
Doesn't write description-shaped overlay sections.
Doesn't write `skill.index.sha256`. Stamp-writing is auditor's responsibility; only after PASS.
Doesn't consult network.
Doesn't modify files outside two artifact classes (raw index and overlay).

Backward Compatibility:

Indexes built with the previous format (single `agent:` field, comma-separated keywords, no markers, single timestamp) remain readable but are considered legacy. The builder, when invoked on a directory containing a legacy index:

1. Detects legacy format by absence of `triggers:` lines or presence of `agent:` instead of `role:`.
2. Rebuilds fully in the new format.
3. Logs a `[rebuilt from legacy]` notice in the header comment.
The old `key: keyword, keyword` format is not valid in new indexes.

Related:

`skill-index` — root spec and toolkit overview.
`skill-index-auditing` — validates cascade, writes stamp; run after building.
`skill-index-crawling` — consumes artifacts produced here.
`compression` — required for overlay compression pass before write.
