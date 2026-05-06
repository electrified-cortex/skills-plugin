---
name: hash-record-rekey
description: Re-key a stale hash-record entry after a file's content changes. Finds the old record under any blob hash, moves it to the new hash path via git mv. Triggers - rekey hash-record, move stale hash record, update hash record after lint, refresh hash-record key, hash-record entry changed.
---

Invoke directly via Bash or PowerShell — no agent dispatch.

**Per-file mode** (three required args + optional source_hash):

```bash
bash rekey.sh <file_path> <op_kind> <record_filename> [source_hash]
pwsh rekey.ps1 <file_path> <op_kind> <record_filename> [source_hash]
```

**Folder mode** (single directory arg + optional flags):

```bash
bash rekey.sh <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
pwsh rekey.ps1 <folder_path> [--include <glob>] [--exclude <glob>] [--dry-run] [--manifests]
```

Pass `--help` / `-h` to print usage.

**Arguments** (first three required in per-file mode, positional):

- `file_path` — absolute path to the changed file (new content, not yet committed).
- `op_kind` — operation kind, e.g. `markdown-hygiene` or `skill-auditing/v2`. May contain `/`.
- `record_filename` — leaf filename, e.g. `claude-haiku.md`. No path separators or `..`.
- `source_hash` — (optional) known old content hash to rekey from. Must be a valid 40-character lowercase hex string; an invalid value produces `ERROR` and exit 1. When provided, bypasses full-tree search and prevents AMBIGUOUS when multiple records exist.

**Folder-mode flags:**

- `--include <glob>` — restrict scope to matching files (repeatable; default: all files).
- `--exclude <glob>` — skip matching files (repeatable; default: none).
- `--dry-run` — report what would be rekeyed without making changes.
- `--manifests` — include manifest files in the rekey pass (default: true).

**Output** (stdout, one line):

| Line | Meaning | Exit |
| --- | --- | --- |
| `REKEYED: <abs-path>` | Record moved to new hash path. | 0 |
| `CURRENT: <abs-path>` | Hash unchanged; no move needed. | 0 |
| `NOT_FOUND: no record for <op_kind>/<record_filename>` | No record found. | 0 |
| `AMBIGUOUS: <n> records found -- manual resolution required` | Multiple records found; manual resolution required. | 1 |
| `ERROR: <reason>` | Argument or runtime error. | 1 |

**Output** (folder mode — one line per record, then a SUMMARY line):

| Line | Meaning | Exit |
| --- | --- | --- |
| `REKEYED: <abs-path>` | Record moved to new hash path. | 0 |
| `CURRENT: <abs-path>` | Hash unchanged; no move needed. | 0 |
| `NOT_FOUND: no record for <file-rel-path>` | No record for this file. | 0 |
| `MANIFEST_UPDATED: <manifest-path>:<entry-id>` | Multi-file manifest record rekeyed. | 0 |
| `SUMMARY: rekeyed=<n> current=<n> manifest_updated=<n> not_found=<n> errors=<n>` | Aggregate counts for the folder run. | 0 |
| `ERROR: <reason>` | Argument or runtime error. | 1 or 2 |

Exit code 2 = invocation error (bad arguments). Exit code 1 = runtime error.

Moves at the **record-file level** (`git mv` of the individual `<record_filename>`). Creates the target parent directory before moving. Leaves the old hash directory if other records remain there.

**Script locations** (relative to this folder):

- `rekey.sh` — Bash implementation.
- `rekey.ps1` — PowerShell 7+ implementation.

Usage guide: `usage-guide.md`.

Related: `hash-record`, `hash-record-check`, `hash-record-prune`
