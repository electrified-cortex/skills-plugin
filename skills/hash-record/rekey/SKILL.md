---
name: rekey
description: Move a stale hash-record entry to the correct new hash path after a file's content changes. Triggers — rekey hash-record, update hash record after lint, move stale hash record.
---

After a formatting or hygiene pass changes file bytes, the existing hash-record entry is stranded under the old hash. This tool finds the stranded entry and moves it to the new hash path via `git mv` — pure bookkeeping, no re-auditing.

Run BEFORE `hash-record-prune`. Invoke directly — no sub-agent dispatch.

```bash
bash rekey.sh <file_path> <op_kind> <record_filename> [source_hash]
pwsh rekey.ps1 <file_path> <op_kind> <record_filename> [source_hash]
```

**Folder mode** (pass a directory instead of a file):

```bash
bash rekey.sh <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
pwsh rekey.ps1 <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

Pass `--help` / `-h` to print usage.

**Per-file arguments** (first three required, positional):

- `file_path` — absolute path to the changed file (new content, not yet committed).
- `op_kind` — e.g. `markdown-hygiene` or `skill-auditing/v2`. May contain `/`; no `..` or `\`.
- `record_filename` — leaf filename, e.g. `claude-haiku.md`. No path separators or `..`.
- `source_hash` — (optional) known old 40-char hex hash; bypasses full-tree scan and prevents AMBIGUOUS.

**Folder-mode flags:**

- `--include <glob>` — restrict scope to matching files (repeatable).
- `--exclude <glob>` — skip matching files (repeatable).
- `--dry-run` — report without making changes.
- `--manifests` — include manifest files (default: true).

**Output — per-file mode** (one line, stdout):

| Line | Meaning | Exit |
| --- | --- | --- |
| `REKEYED: <abs-path>` | Record moved to new hash path. | 0 |
| `CURRENT: <abs-path>` | Hash unchanged; no move needed. | 0 |
| `NOT_FOUND: no record for <op_kind>/<record_filename>` | No record found. | 0 |
| `AMBIGUOUS: <n> records found -- manual resolution required` | Multiple matches; use `source_hash`. | 1 |
| `ERROR: <reason>` | Argument or runtime error. | 1 |

**Output — folder mode** (one line per record, then SUMMARY):

| Line | Meaning |
| --- | --- |
| `REKEYED: <abs-path>` | Record moved. |
| `CURRENT: <abs-path>` | Hash unchanged. |
| `NOT_FOUND: no record for <file-rel-path>` | No record for this file. |
| `MANIFEST_UPDATED: <manifest-path>:<entry-id>` | Manifest entry rekeyed. |
| `SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>` | Aggregate. |
| `ERROR: <reason>` | Per-record failure. |

Exit: 0 = success; 1 = runtime error; 2 = invocation error (bad path or flags).

**Scripts** (relative to this folder):

- `rekey.sh` — Bash implementation.
- `rekey.ps1` — PowerShell 7+ implementation.

Usage guide: `usage-guide.md`.

**Don'ts:**

- Does not re-run the originating operation (no re-audit, no re-lint).
- Does not replace file contents or delete any record.
- Does not create new audit content.
- Run `prune/` AFTER this, never before.

Related: `hash-record`, `check/`, `prune/`
