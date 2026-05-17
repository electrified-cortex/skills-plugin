Use when: file byte content changed by formatting/hygiene pass (lint, whitespace norm,
markdown-hygiene, trailing-newline fix, etc.), file has an existing hash-record entry,
and you need the old record accessible under the new hash without re-auditing.
Do NOT use after substantive content changes — those require full re-audit.

Phase 4A (re-sign path) workflow:
1. Lint pass changed a file -> `hash-record-check` returns MISS for new hash.
2. Run `hash-record-rekey` to find/move the old record.
3. REKEYED -> old result now discoverable at new hash. Proceed.
4. NOT_FOUND -> no old record; full audit required.
5. CURRENT -> file content unchanged; continue normally.
6. AMBIGUOUS -> stop and escalate; no automated resolution.

Invocation:
  pwsh rekey.ps1 <file_path> <op_kind> <record_filename>
  bash rekey.sh  <file_path> <op_kind> <record_filename>

Steps:
1. Confirm file exists and is readable at <file_path>.
2. Identify <op_kind> and <record_filename> — must match values used when record was written.
3. Run script. Capture stdout (one line). Parse prefix keyword.

Output handling:

REKEYED: <new_abs_path>
  `git mv` already staged the rename. Frontmatter hash: field still reflects old hash —
  update if downstream consumer validates it. Record now discoverable via `hash-record-check`.

CURRENT: <abs_path>
  Blob hash unchanged. Existing record at correct path. Proceed normally.

NOT_FOUND: no record for <op_kind>/<record_filename>
  No record under any hash. Full re-audit required.

AMBIGUOUS: <n> records found -- manual resolution required
  Multiple records match. Escalate to operator. Operator must inspect .hash-record/
  and delete stale duplicates. Do not attempt automated resolution.

ERROR: <reason>
  Fix the argument. Common causes: missing file_path, invalid op_kind with backslash,
  git hash-object failure (file not found or not readable).

Constraints:
- Does NOT update frontmatter hash: field — only moves the file.
- One file moved per call; call once per (op_kind, record_filename) pair.
- `git mv` auto-stages the rename; commit as part of normal workflow.
- Requires git repo; falls back with WARN on stderr if not in one.
- op_kind MUST NOT contain .. or \
- record_filename MUST NOT contain .., /, or \

Output contract:

| Line | Meaning | Exit |
| --- | --- | --- |
| REKEYED: <abs-path> | Record moved to new hash path. | 0 |
| CURRENT: <abs-path> | Hash unchanged; no move needed. | 0 |
| NOT_FOUND: ... | No record for this op_kind/record_filename. | 0 |
| AMBIGUOUS: <n> ... | Multiple records found; manual resolution required. | 1 |
| ERROR: <reason> | Argument or runtime error. | 1 |

Examples:

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

When the first argument resolves to an existing directory, the tool enters
folder mode. It detects all changed files under that directory, finds their
associated hash-record entries (and optionally manifest files), and rekeys
them in bulk.

Invocation:

```bash
bash rekey.sh  /path/to/folder [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

```powershell
pwsh rekey.ps1 /path/to/folder [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

Flags:

- `--include <glob>` — restrict to files matching the glob (repeatable).
- `--exclude <glob>` — skip files matching the glob (repeatable).
- `--dry-run` — report what would be rekeyed without making changes.
- `--manifests` — also rekey manifest files (default: true).

Folder-mode output is one line per record, plus a final summary:

```text
REKEYED: /path/to/.hash-record/3a/3abc.../skill-auditing/v2/claude-haiku.md
CURRENT: /path/to/.hash-record/ab/abcd.../markdown-hygiene/lint.md
SUMMARY: rekeyed=1 current=1 manifest_updated=0 not_found=0 errors=0
```

Exit codes: 0 = all succeeded, 1 = any per-record ERROR, 2 = invocation error.

Run folder-mode BEFORE `hash-record-prune`; pruning first would delete records
the rekey is trying to preserve.
