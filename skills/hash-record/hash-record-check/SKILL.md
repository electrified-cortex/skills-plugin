---
name: hash-record-check
description: Probe the hash-record cache for a file. Triggers -- cache check hash-record, check hash-record hit or miss, hash-record cache probe, skip if cached, cache-first lookup, check hash cache before running operation.
---

Invoke directly via Bash or PowerShell — no agent dispatch.

```bash
bash check.sh <file_path> <op_kind> <record_filename>
pwsh check.ps1 <file_path> <op_kind> <record_filename>
```

Pass `--help` / `-h` to print usage.

**Arguments** (all required, positional):

- `file_path` — absolute path to the file to probe.
- `op_kind` — operation kind folder, e.g. `markdown-hygiene`. No path separators or `..`.
- `record_filename` — leaf filename, e.g. `report.md`. No path separators or `..`.

**Output** (stdout, one line):

| Line              | Meaning                                       | Exit |
| ----------------- | --------------------------------------------- | ---- |
| `HIT: <abs-path>` | Cache file exists; caller reads it.           | 0    |
| `MISS: <abs-path>`| No cache file; caller writes to this path.    | 0    |
| `ERROR: <reason>` | Argument or runtime failure.                  | 1    |

HIT and MISS return the SAME path. On HIT it exists; on MISS it doesn't.

**Script locations** (relative to this folder):

- `check.sh` — Bash implementation.
- `check.ps1` — PowerShell 7+ implementation.
- `misses.ps1` — PowerShell 7+ batch variant (see below).

Both `check` variants produce byte-identical stdout for the same inputs. Forward-slash paths on every platform.

Full CLI contract: `check.spec.md` (in this folder).

---

**`misses.ps1` — parallel batch miss probe**

```powershell
pwsh misses.ps1 <glob> <op_kind> <record_filename>
```

Expands `<glob>`, probes all matched files in parallel, and outputs one absolute path per line for each file that has **no** cache entry. Sorted. Zero output means every file is already cached.

Paths under `.hash-record/` are excluded by default.

Use this before dispatching agents to find exactly which files still need work:

```powershell
$misses = pwsh misses.ps1 'gh-cli/**/*.md' markdown-hygiene lint.md
# $misses is now a list of file paths to dispatch
```

Related: `hash-record`, `hash-record-prune`, `hash-record-index`
