---
name: manifest
description: Compute a manifest hash for a set of files and probe the hash-record cache using that combined key. Triggers — multi-file cache key, compute manifest hash, cache key for directory.
---

Produces a single cache key from multiple input files by hashing a deterministic manifest text (sorted `<repo-relative-path> <blob-hash>` lines). Returns HIT or MISS at the canonical record path. The caller reads (HIT) or writes (MISS) at that path.

Call local tool directly — no sub-agent dispatch.

```bash
bash manifest.sh <op_kind> <record_filename> <file1> [<file2> ...]
pwsh manifest.ps1 <op_kind> <record_filename> <file1> [<file2> ...]
```

Pass `--help` / `-h` to print usage.

**Arguments** (all required, positional):

- `op_kind` — operation kind folder, e.g. `skill-auditing/v2`. May contain `/`; no `..`, `\`, or `*`.
- `record_filename` — leaf filename, e.g. `report.md`. No path separators or `..`.
- `file1 [file2 ...]` — one or more absolute or repo-relative file paths. At least one required.

**Output** (stdout, one line):

| Line | Meaning | Exit |
| --- | --- | --- |
| `HIT: <abs-path>` | Cache file exists; caller reads it. | 0 |
| `MISS: <abs-path>` | No cache entry; caller writes to this path. | 0 |
| `ERROR: <reason>` | Argument or runtime failure. | 1 |

HIT and MISS return the same path. On HIT it exists; on MISS it doesn't.

**How the key is built:**

1. Resolve each input file to its repo-relative path.
2. Run `git hash-object <file>` per file.
3. Sort (repo-relative-path, blob-hash) pairs lexically.
4. Build manifest text: one `<repo-relative-path> <blob-hash>\n` line per pair.
5. Hash the manifest text via `git hash-object --stdin` → 40-char manifest hash.
6. Test `.hash-record/<hash[0:2]>/<manifest-hash>/<op_kind>/<record_filename>`.

**Don'ts:**

- Do not pass directory paths — enumerate files explicitly (e.g. via `git ls-files`) before calling.
- Do not pass duplicate paths — duplicates produce duplicate manifest lines (caller bug).
- This skill does not write or read record content; it returns a path only.

Related: `hash-record`, `check/`, `prune/`, `index/`
