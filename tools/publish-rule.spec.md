---
name: publish-rule
version: 1.0.0
---

# Publish Inclusion Rule Specification

## Purpose

Define the deterministic contract for which source files are included in the skills-plugin dist (`skills/`). The rule must prevent working files, session notes, task drafts, audit reports, and other non-functional artifacts from shipping, while ensuring all files the skill needs to operate are present.

## Scope

Applies to the `tools/publish.ps1` build dist phase. Governs all files copied from the source skills tree into `skills/` in the plugin repository. Does not govern the index files (`skill.index`, `skill.index.md`) at the source root — those are always-include.

## Definitions

- **Source root**: the skills repository directory (default: sibling `../skills` relative to the plugin root).
- **Skill folder**: any directory containing a `SKILL.md` file that is not under a dot-prefixed ancestor.
- **Inclusion set**: the set of absolute source file paths authorized to be copied to dist for a given skill folder.
- **Reference**: a file path token found within a scannable file (`.md` or `.txt`) that resolves to an existing file within the source root.
- **Reference chain**: the transitive closure of all references reachable from `SKILL.md` via scannable files.
- **Deny-list**: the set of file names and wildcard patterns defined in `build/deny-list.ps1` that are always excluded regardless of reference.

## Requirements

### R1 — Root

The inclusion set for a skill folder starts with exactly one file: `SKILL.md`. No other file is included by default.

### R2 — Reference walk

The inclusion set is expanded by scanning each included scannable file (`.md` or `.txt`) for references to other files. Each detected reference that passes all guards is added to the inclusion set and queued for scanning if it is itself a scannable file.

### R3 — Reference detection patterns

Two regex patterns detect references:

1. **Backtick-quoted tokens**: `` `<path-or-name>` `` — any text between backtick delimiters that contains at least one `.` followed by 1–8 alphanumeric characters.
2. **Shell command tokens**: `bash`, `pwsh`, `sh`, `source`, or `.` followed by whitespace and a token matching `[\w./\\-]+\.<ext>`.

Both patterns operate on the raw file content. Pattern 1 captures inline code spans; pattern 2 captures direct script invocations in prose or code blocks.

### R4 — Reference resolution

A detected raw token is resolved to an absolute path via `GetFullPath(Join-Path <scanning-file-dir> <raw-token>)`. The scanning file's directory is the base for relative resolution. Path segments with `..` are resolved normally — traversal is bounded by R5, not by pre-filtering.

### R5 — Boundary guard

A resolved reference is only admitted if its absolute path starts with the source root path (case-insensitive on Windows). References that escape the source root are silently dropped.

### R6 — Deny-list guard

A resolved reference is only admitted if `Test-Denied` returns false and `Test-DotFile` returns false for the target file.

### R7 — Dot-ancestor guard

A resolved reference is only admitted if no path segment between the source root and the file begins with `.` (dot-prefixed directories are excluded).

### R8 — Existence guard

A resolved reference is only admitted if the target path resolves to an existing regular file at build time.

### R9 — Scan eligibility

Only files with extensions `.md` or `.txt` are scanned for outbound references. Script files (`.sh`, `.ps1`, `.bash`, `.py`, etc.) are leaf nodes — they are included if referenced but are not themselves scanned for further references.

### R10 — Cycle safety

Each file is scanned at most once per skill's inclusion walk. A per-walk `scanned` set tracks visited files; dequeued files already in `scanned` are skipped.

### R11 — Recursive enumeration

The build copy phase enumerates all files under each skill folder recursively (including subdirectories). Only files whose absolute path is in the inclusion set are copied. All others are either counted as excluded (if they would have passed deny-list) or denied (if deny-listed).

## Constraints

### C1 — No implicit inclusion

No file is included solely because it is co-located with `SKILL.md`. Co-location is not sufficient — a reference chain from `SKILL.md` is required.

### C2 — Template tokens filtered

Raw tokens containing `<`, `>`, `$`, `[`, or `]` are dropped before resolution. These characters indicate template placeholders or shell-expansion syntax, not literal file paths.

### C3 — Glob patterns filtered

Raw tokens beginning with `*` are dropped. Wildcard tokens cannot be resolved to a single file.

### C4 — Absolute Windows paths filtered

Raw tokens beginning with a Windows drive letter (`[A-Za-z]:\`) are dropped. Absolute paths are not portable references.

### C5 — Deny-list is the safety net

The deny-list check applies both during the inclusion walk (R6) and as a final validation pass over the dist. Files that pass the reference walk but are deny-listed are not copied. The reference walk is the primary exclusion mechanism; the deny-list is the secondary safety net.

### C6 — Index files are always-include

`skill.index` and `skill.index.md` at the source root are copied unconditionally and are not subject to reference-chain inclusion. They are not governed by this spec.

## Behavior

1. Collect all skill folders (directories containing `SKILL.md` not under dot-prefixed ancestors).
2. For each skill folder, call `Build-InclusionSet`:
   a. Seed the inclusion set with `SKILL.md`.
   b. Seed the scan queue with `SKILL.md`.
   c. While queue is non-empty: dequeue, skip if already scanned, scan for refs if `.md`/`.txt`, apply guards R4–R8, add admitted refs to inclusion set and queue.
3. For each skill folder, enumerate all files recursively.
4. For each file: if deny-listed → count denied; if in inclusion set → copy to dist (preserving subpath relative to source root); else → count excluded.
5. Copy always-include index files.
6. Run validation pass: any denied files found in dist → build fails.

## Defaults and Assumptions

- Source root is the resolved path of `../skills` relative to the plugin root unless overridden by `-Source`.
- Backtick pattern extension length: 1–8 alphanumeric characters (covers `.md`, `.txt`, `.sh`, `.ps1`, `.bash`, `.json`, `.yaml`).
- Shell command pattern prefix words: `bash`, `pwsh`, `sh`, `source`, `.` (dot sourcing).
- Scan depth is unbounded but bounded by the acyclic file graph (R10 prevents cycles).

## Error Handling

- Unreadable files during scanning: silently skip, do not add to inclusion set.
- Resolved reference does not exist: silently drop (R8).
- Missing `SKILL.md` in a skill folder: return empty inclusion set; skill folder produces no dist files.
- Denied files found in dist during validation: build fails with error listing violating paths.

## Precedence Rules

1. Deny-list overrides inclusion set: a file in the inclusion set that is also deny-listed is NOT copied.
2. Dot-ancestor check overrides reference walk: a referenced file under a dot-prefixed directory is not included even if explicitly referenced.
3. Boundary check overrides reference walk: a referenced file outside the source root is not included even if explicitly referenced.

## Don'ts

- Don't include a file solely because it is in the same directory as `SKILL.md` (no flat-mirror).
- Don't include files referenced only by absolute path tokens — those are filtered per C4.
- Don't include files referenced only by template-token forms (e.g., `<skill-dir>/foo.sh`) — those are filtered per C2.
- Don't scan `.sh`, `.ps1`, or other non-text files for outbound references — those are leaf nodes per R9.
- Don't use glob patterns or wildcard expansion to resolve references — each ref must resolve to a single file.
- Don't bypass the deny-list for files that are in the reference chain — deny-list always wins per Precedence Rule 1.
- Don't apply this rule to `skill.index` / `skill.index.md` at the source root — those are always-include per C6.
