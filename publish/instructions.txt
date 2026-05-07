# Publish Skill — Instructions

Caller decides WHEN to release. This skill executes the release.

## Definitions

- **source root** — directory tree containing the source skills. Required `source_root` arg.
- **dist root** — `skills/` subdirectory of the plugin repo root. Output of the build step.
- **plugin version** — SemVer string in `plugin.json` `version` field.
- **deny list** — files that must NEVER appear in dist. Operator-locked patterns (embedded below).
- **dry run** — all steps except commit/tag/push; returns planned outcome.
- **release commit** — single commit: bumped `plugin.json`, prepended `CHANGELOG.md`, regenerated `skills/`.

## Deny Patterns (operator-locked — do not load from file)

Deny any file matching ANY of these patterns (case-insensitive, any depth):
- `*spec.md` — spec files (bare `spec.md`, named `foo.spec.md`, hyphenated `canonical-format-spec.md`, etc.)
- `*.sha256` — hash checksums
- `*.uncompressed.md` — uncompressed source files
- Any filename beginning with `.` (dot-files)
- Any directory beginning with `.` (dot-dirs — skip entire subtree)

## Pre-flight (R1-R4) — all mandatory; none skippable

**R1 dirty_working_tree** — if uncommitted changes exist outside `skills/`, `plugin.json`, `CHANGELOG.md`: stop, list offending paths.

**R2 wrong_branch** — if current branch != release branch (default `main`): stop, surface current branch.

**R3 bad_source** — if source root does not exist or contains no `SKILL.md`-bearing directories: stop with `bad_source`.

**R4 bad_prior_version** — if the most recent tag does not parse as SemVer: stop.

## Procedure

### Step 1 — Compute version (R5)

Read `plugin.json` `.version`. Apply `version_bump`:
- `patch` -> increment patch component, reset nothing.
- `minor` -> increment minor, reset patch to 0.
- `major` -> increment major, reset minor and patch to 0.

### Step 2 — Build dist (agent-procedural)

Perform the build yourself — no script invocation.

**2a. Discover skills.** Walk the source root recursively. For each directory containing a `SKILL.md` file:
- Skip any directory or ancestor whose name starts with `.`
- Record the directory as a skill folder.

**2b. Clear dist.** Remove all contents of `skills/` (the dist root). Do not remove the `skills/` directory itself.

**2c. Mirror Stage 1.** For each skill folder discovered:
- Determine the skill's relative path from the source root (e.g., `system/session-logging`).
- Create the matching directory under `skills/` (e.g., `skills/system/session-logging/`).
- Copy `SKILL.md` to `skills/<rel-path>/SKILL.md` — ONLY if it does not match any deny pattern.

**2d. Stage 2 — Reference resolution.** For each copied `SKILL.md`:
- Parse it for backtick file references: any `` `path/to/file.ext` `` **or bare** `` `file.ext` `` (filename only, no path separator) where the path ends in a file extension (2–6 chars).
- Skip patterns beginning with `*/` (wildcard deny markers).
- Skip cross-skill refs beginning with `../` — log a warning, do not follow.
- For template paths (containing `<...>`): find all files in the source skill directory matching the leaf filename; include each (recursively resolve their refs too, depth cap 4).
- For direct paths (including bare filenames with no `/`): resolve relative to the source skill directory. The resolved absolute path must be within the source skill directory (no escaping). Copy the file to the mirrored location in dist if not already there. Recursively resolve its backtick refs (depth cap 4).
- Apply deny patterns at every copy step — never copy a denied file.

**2e. Copy skill.index files.** If `skill.index` exists in the source root, copy to `skills/skill.index`. If `skill.index.md` exists, copy to `skills/skill.index.md`.

**2f. Validation.** After all copies are done, scan `skills/` recursively. If ANY file matches a deny pattern -> stop with `build_validation_failed`, list offending paths.

**2g. Build report.** Record: skills mirrored count, total files copied, total files denied/skipped.

### Step 3 — Update plugin.json (R7)

Set `version` to new SemVer. Set `built` to today's UTC date `YYYY-MM-DD`.

### Step 4 — Update CHANGELOG.md (R8)

Prepend:

```markdown
## [<new-version>] - <YYYY-MM-DD>

<release_notes>
```

Preserve all prior entries verbatim.

### Step 5 — Stage + commit (R9)

Stage exactly: `plugin.json`, `CHANGELOG.md`, `skills/` (full tree). No `git add -A`. Commit message: `release: v<new-version>`.

### Step 6 — Tag (R10)

Annotated tag: `git tag -a v<new-version> -m "v<new-version>"`

### Step 7 — Dry-run gate (R11)

If `dry_run=true` -> stop; return dry-run report. No push.

### Step 8 — Push (R11, R12)

Push branch and tag. Force-push forbidden. Push failure -> stop `push_failed`, leave local commit+tag intact.

## Outputs

- Release commit: bumped `plugin.json`, prepended `CHANGELOG.md`, rebuilt `skills/`.
- Annotated tag `v<new-version>`.
- Status report: prev version, new version, build report, push result.

## Bailout

| Status | Trigger | State |
|---|---|---|
| `dirty_working_tree` | R1 | No mutations |
| `wrong_branch` | R2 | No mutations |
| `bad_source` | R3 | No mutations |
| `bad_prior_version` | R4 | No mutations |
| `build_validation_failed` | Step 2f | No commit |
| `push_failed` | Step 8 | Local commit+tag intact |

## Constraints

- Must NOT invoke any external build script.
- Must NOT decide whether to release.
- Must NOT auto-generate `release_notes`.
- Must NOT modify `skills/` by hand outside of Step 2.
- Must NOT skip R1-R4 on caller request.
- Must NOT force-push.

## Dependencies

- Source root exists with SKILL.md-bearing directories.
- `plugin.json` exists with valid SemVer `version` field.
- Agent has file system read/write access (no external tools required).
