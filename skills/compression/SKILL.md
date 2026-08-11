---
name: compression
description: Compress .md and text files via subagent dispatch. Triggers — compress this file, reduce tokens, shrink instructions, caveman compress, ultra/full/lite compress.
---

Never compress spec files (`*.spec.md` — token cost acceptable; meaning loss isn't).

Input:

`<file-path>` — path to target file
Flags: `--tier <none|lite|full|ultra>` (default `ultra`); `--source <src> --target <dst>` — source-to-target mode (source untouched, no git check)

In-place mode: target must be git-tracked and clean before modification.

Preserves: code blocks, URLs, technical terms, logic words (not/must/only), actors, normative language. No exceptions at any tier.

When target is `SKILL.md` and source H1 matches frontmatter `name:`, H1 is stripped from target (A-FM-3 compliance).

Dispatch:

Variables:

`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `<file-path> [--tier <none|lite|full|ultra>] [--source <src> --target <dst>]`
`<tier>` = `standard`
`<description>` = `Compressing: <file-path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.
Returns: `<before>-><after> bytes | <N>% reduction | <tier> | <mode> | hygiene: clean|fixed N|N warning(s)`
