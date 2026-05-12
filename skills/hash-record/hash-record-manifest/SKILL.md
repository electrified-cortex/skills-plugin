---
name: hash-record-manifest
description: Probe the hash-record cache for a set of files via a combined manifest hash. Triggers - compute manifest hash, multi-file cache key, hash-record manifest, manifest hash, bundle file hashes, cache key for directory.
---

Probe hash-record cache for set of files via combined manifest hash. Returns cache path as `HIT` (exists) or `MISS` (absent); caller reads or writes at that path.

Inputs:

| Parameter         | Required | Description                                                                 |
| ----------------- | -------- | --------------------------------------------------------------------------- |
| `op_kind`         | yes      | Operation kind, e.g. `skill-auditing/v2`. May contain `/`; no `..`, `\`, `*`. |
| `record_filename` | yes      | Leaf filename, e.g. `report.md`. No path separators or `..`.               |
| `files`           | yes      | One or more file paths (absolute or relative). At least one required.      |

Procedure: Call local tool directly — no sub-agent dispatch.

bash: `bash manifest.sh <op_kind> <record_filename> <file1> [<file2> ...]`

pwsh: `pwsh manifest.ps1 <op_kind> <record_filename> <file1> [<file2> ...]`

Tool resolves repo root from first file, computes git blob hash per file, sorts pairs lexically, builds manifest text, hashes via `git hash-object --stdin`, tests resulting cache path.

Return:

| Output            | Exit | Meaning                                      |
| ----------------- | ---- | -------------------------------------------- |
| `HIT: <abs-path>` | 0    | Cache file exists; caller reads its contents |
| `MISS: <abs-path>`| 0    | No cache entry; caller writes to this path   |
| `ERROR: <reason>` | 1    | Argument or runtime error                    |

Related: `hash-record`, `hash-record-index`, `hash-record-prune`
