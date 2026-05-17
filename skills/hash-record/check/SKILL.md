---
name: check
description: Probe the hash-record cache for a single file — returns HIT or MISS with the canonical record path. Triggers — check hash-record, skip if cached, cache-first lookup.
---

Invoke directly via Bash or PowerShell — no agent dispatch.

```bash
bash check.sh <file_path> <op_kind> <record_filename>
pwsh check.ps1 <file_path> <op_kind> <record_filename>
```

Pass `--help` / `-h` to print usage.

**Arguments** (all required, positional):

- `file_path` — absolute path to the file to probe.
- `op_kind` — operation kind folder, e.g. `markdown-hygiene`. No `..` or `\`; `/` permitted for versioned namespaces.
- `record_filename` — leaf filename, e.g. `report.md`. No path separators or `..`.

**Output** (stdout, one line):

| Line | Meaning | Exit |
| --- | --- | --- |
| `HIT: <abs-path>` | Cache file exists; caller reads it. | 0 |
| `MISS: <abs-path>` | No cache file; caller writes to this path. | 0 |
| `ERROR: <reason>` | Argument or runtime failure. | 1 |

HIT and MISS return the SAME path. On HIT it exists; on MISS it doesn't.

**Scripts** (relative to this folder):

- `check.sh` — Bash implementation.
- `check.ps1` — PowerShell 7+ implementation.
- `misses.ps1` — batch variant: probes a glob, outputs only uncached paths.

---

**`misses.ps1` — parallel batch miss probe**

```powershell
pwsh misses.ps1 <glob> <op_kind> <record_filename>
```

Expands `<glob>`, probes all matched files in parallel, outputs one absolute path per line for each file with no cache entry. Sorted. Zero output = all cached. Paths under `.hash-record/` excluded.

```powershell
$misses = pwsh misses.ps1 'github/**/*.md' markdown-hygiene lint.md
# $misses = files still needing work
```

Related: `hash-record`, `manifest/`, `prune/`, `index/`
