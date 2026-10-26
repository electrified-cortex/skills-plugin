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
`<tier>` = `fast-cheap`
Caller may override `<tier>` or set `<model-override>`.
`<effort>` = `ultra` `low`; `full` `medium`; `lite`/`none` unset; never `high`
`<description>` = `Compressing: <file-path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Before dispatch, run `wc -c` on `--source` file if given, else `<file-path>` (in-place mode overwrites it): that is `<before>`.
Import the `dispatch` skill from `../dispatch/SKILL.md`. Use the `dispatch` skill to launch the sub-agent.
After return, unless `REJECTED`, run `wc -c` on file written (`<file-path>` if `<mode>` is `in-place`, else file `<mode>` names): that is `<after>`. `<N>` = (`<before>` - `<after>`) * 100 / `<before>`, rounded to nearest integer. Use these three in Returns, not sub-agent's counts.
Returns: `<before>-><after> bytes | <N>% reduction | <tier> | <mode> | hygiene: clean|fixed N|N warning(s)`
Lint-fix (full, ultra only; skip on REJECTED): `<written-file>` = file `<after>` measured on; `<compression-tier>` = `--tier` value, `ultra` if `--tier` omitted (not dispatch `<tier>`; `lite`/`none` not linted). Run `bash lint.sh <written-file> <compression-tier>` (PS7: `pwsh lint.ps1 <written-file> <compression-tier>`; scripts not executable, name the interpreter). Only exit 1 starts fix: `<findings>` = its output, `<found>` = its line count. Exit 0: clean, skip to last line. Exit 2 or any code not 0/1 (126, 127 too): lint could not run; stop (no fix pass, no re-lint, no `.fixed` file), last line = `lint: error (<message>)`, `<message>` = lint's own message, or `lint exited <code>` if none.
Fix pass: dispatch once more via `dispatch` skill, one pass only: `<tier>` = `fast-cheap`, `<effort>` = `medium`, `<description>` = `Fixing lint: <written-file>`, `<prompt>` = `fix.txt` (this folder) with `<SRC>` = `<written-file>`, `<DST>` = `<written-file>.fixed`, `<findings>` replacing placeholder line `<LINT OUTPUT, ...>` (line 4) under `Violations to fix:`, then budget line: max 6 tool calls, max 3 minutes, stop once `<DST>` written.
Check: run `bash lint.sh --check <written-file> <written-file>.fixed <compression-tier>` (PS7: `pwsh lint.ps1 --check`, same arguments). Accept fix only if every changed line was flagged, line count equal, no tag added. Exit 0: move `<written-file>.fixed` over `<written-file>`. Else (exit 1, 2 or other): keep `<written-file>`, delete `<written-file>.fixed`, fix rejected; `<reason>` never empty: exit 1 first `reject:` line, other exit what failed in few words (e.g. `fixed file missing`) or first line of check's message.
Re-lint: run `bash lint.sh <written-file> <compression-tier>` once more, no second fix pass; `<left>` = its line count, `<remaining>` = its output; exit 2 or other non-0/1 = `error (<message>)`, never `clean` or count. If fix accepted, run `wc -c` on `<written-file>` again: final `<after>`; recompute `<N>`. Returns line uses final values.
Then second output line: `lint: clean|fixed N|N remaining (<line>: <rule> ...)|fix rejected (<reason>); N remaining|error (<message>)`. `clean`: first lint found nothing. `fixed N`: fix accepted, nothing left, N = `<found>` - `<left>`. `N remaining`: fix accepted, N = `<left>` left, each listed from `<remaining>` as `<line>: <rule>`. `fix rejected`: N = `<found>`. `error`: first lint or re-lint exited 2 or other non-0/1; `<message>` = its first line.
