# hash-record-rekey — Usage Guide

## When to use

Use `hash-record-rekey` when:

- A file's byte content was changed by a formatting or hygiene pass (lint,
  whitespace normalisation, markdown-hygiene, trailing-newline fix, etc.).
- The file has an existing hash-record entry (from a prior audit or code-review).
- You need the old hash-record entry to remain accessible under the new hash,
  without re-running the audit.

Do NOT use this to refresh a record after substantive content changes — those
invalidate the audit result and require a full re-audit.

## Typical caller context

The sealing-strategy Phase 4A (re-sign path):

1. A lint pass changed a file (e.g. trailing newline added by markdown-hygiene).
2. `hash-record-check` returns MISS for the new hash.
3. Check whether the old record exists by running `hash-record-rekey`.
4. If REKEYED: the old audit result is now discoverable at the new hash. Proceed.
5. If NOT_FOUND: no old record; a full audit pass is required.
6. If CURRENT: file content was not actually changed; continue normally.
7. If AMBIGUOUS: stop and escalate — do not attempt automated resolution.

## Step-by-step

1. Confirm the file exists and is readable at `<file_path>`.
2. Identify `<op_kind>` (e.g. `skill-auditing/v2`) and `<record_filename>`
   (e.g. `claude-haiku.md`). These must match the values used when the
   original record was written.
3. Run the script:
   - PowerShell: `pwsh rekey.ps1 <file_path> <op_kind> <record_filename>`
   - Bash:       `bash rekey.sh  <file_path> <op_kind> <record_filename>`
4. Capture stdout (one line). Parse the prefix keyword.

## Handling each output

### REKEYED: <new_abs_path>

The record was found under the old hash and moved to the new hash path.

- Stage the moved files: the `git mv` already staged the rename.
- The record's frontmatter `hash:` field still reflects the old hash.
  If frontmatter accuracy is required, update it before committing.
- Proceed — the record is now discoverable via `hash-record-check`.

### CURRENT: <abs_path>

The file's blob hash has not changed. No move was necessary.

- The existing record is already at the correct path.
- Proceed normally.

### NOT_FOUND: no record for <op_kind>/<record_filename>

No record exists for this op_kind + record_filename under any hash.

- A full re-audit is required; there is nothing to re-key.

### AMBIGUOUS: <n> records found -- manual resolution required

More than one record matches the op_kind/record_filename pattern under
different hashes. Automated re-keying is unsafe.

- Escalate to the operator. Do not attempt automated resolution.
- The operator must inspect `.hash-record/` and delete stale duplicates.

### ERROR: <reason>

An argument validation or runtime error occurred.

- Check the error message and fix the argument.
- Common causes: missing `file_path`, invalid `op_kind` with backslash,
  `git hash-object` failure (file not found or not readable).

## Important constraints

- `rekey` does NOT update the record's frontmatter `hash:` field after
  moving. The frontmatter will still contain the old blob hash. If the
  downstream consumer reads frontmatter and validates the `hash:` field
  against the current file hash, it will fail. Update frontmatter if needed.
- Only one file is moved per call. If multiple records across multiple
  op_kinds need re-keying, call rekey once per (op_kind, record_filename) pair.
- The move is staged in git automatically (`git mv`). Commit the repo after
  re-keying as part of the normal workflow.
- Works only within a git repo. Falls back gracefully (WARN on stderr)
  when run outside a repo, but path construction may be unreliable.

## Examples

```bash
# After markdown-hygiene changed skills/foo/SKILL.md:
bash rekey.sh /repo/skills/foo/SKILL.md skill-auditing/v2 claude-haiku.md
# -> REKEYED: /repo/.hash-record/3a/3abcdef.../skill-auditing/v2/claude-haiku.md

# File content unchanged (hash same):
bash rekey.sh /repo/skills/foo/SKILL.md skill-auditing/v2 claude-haiku.md
# -> CURRENT: /repo/.hash-record/ab/abcdef.../skill-auditing/v2/claude-haiku.md

# No prior audit record:
bash rekey.sh /repo/skills/bar/SKILL.md markdown-hygiene lint.md
# -> NOT_FOUND: no record for markdown-hygiene/lint.md
```

```powershell
pwsh rekey.ps1 /path/to/skills/foo/SKILL.md skill-auditing/v2 claude-haiku.md
# -> REKEYED: /path/to/.hash-record/3a/3abcdef.../skill-auditing/v2/claude-haiku.md
```

## Folder mode

When the first argument resolves to an existing **directory** (not a file),
the tool enters folder mode. It uses `git status` to detect changed files
under the directory, gathers all associated hash-record entries (and
optionally manifest files), and rekeys them in bulk.

Use folder mode after a sealing chain (skill-optimize → skill-audit →
spec-audit → tool-audit → hygiene analysis → hygiene lint) when you do not
want to call per-file rekey for each changed file individually. Always run
folder mode BEFORE `hash-record-prune`; pruning first would delete the
records the rekey is trying to preserve.

### Folder-mode invocation

```bash
bash rekey.sh  /path/to/folder [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

```powershell
pwsh rekey.ps1 /path/to/folder [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

### Folder-mode flags

- `--include <glob>` — restrict scope to files matching the glob (repeatable;
  default: all files).
- `--exclude <glob>` — skip files matching the glob (repeatable; default: none).
- `--dry-run` — report what would be rekeyed without making any filesystem or
  git changes.
- `--manifests` — also rekey manifest files that reference changed files
  (default: true).

### Folder-mode output

One line per record, then a final summary line:

```text
REKEYED: /path/to/.hash-record/3a/3abc.../skill-auditing/v2/claude-haiku.md
CURRENT: /path/to/.hash-record/ab/abcd.../markdown-hygiene/lint.md
MANIFEST_UPDATED: /path/to/.hash-record/cd/cdef.../manifests/set.json:entry-1
NOT_FOUND: no record for skills/bar/SKILL.md
SUMMARY: rekeyed=1 current=1 manifest_updated=1 not_found=1 errors=0
```

Exit codes: 0 = all succeeded (or `--dry-run` completed); 1 = any per-record
ERROR occurred; 2 = invocation error (bad path, conflicting flags).

### Important constraints (folder mode)

- Does NOT re-run any upstream operation (no re-audit, no re-lint).
- Does NOT delete records; use `hash-record-prune` for that (run AFTER rekey).
- Ignores records referencing files outside `folder_path`.
- Safety: does not classify whitespace-only vs semantic changes. Assumes the
  caller has already verified the rekey is safe.
