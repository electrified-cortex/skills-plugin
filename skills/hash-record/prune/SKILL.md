---
name: prune
description: Remove orphaned hash directories from a repository's .hash-record/ store. Triggers — prune hash records, clean up hash-record, remove orphaned records.
---

Deletes hash directories whose content hash can no longer be derived from the active worktree. Does not classify by age, model, or op-kind — orphan status (hash mismatch) is the only signal.

Run script directly — no sub-agent dispatch.

```bash
bash prune.sh "<repo_root>" [--target "<glob>"] [--dry-run] [--limit <N>]
pwsh prune.ps1 "<repo_root>" [-target "<glob>"] [-dry_run] [-limit <N>]
```

Pass `--help` / `-h` to print usage.

**Arguments:**

- `repo_root` (required) — absolute path to the repo root containing `.hash-record/`.
- `--target <glob>` (optional) — relative glob; only hash dirs whose associated file paths match are candidates. No absolute paths.
- `--dry-run` (optional) — list orphans without deleting.
- `--limit <N>` (optional) — cap deletions per run. Default: unlimited.

**Output** (stdout, one line):

| Line | Meaning | Exit |
| --- | --- | --- |
| `CLEAN` | No orphans found. | 0 |
| `pruned: <count>` | Orphans deleted. | 0 |
| `dry-run: <count>` | Orphans found; nothing deleted. | 0 |
| `ERROR: <reason>` | Pre-execution failure. | 1 |

**Orphan classification:**

- Non-manifest dirs: orphaned if `<full-hash>` is not in the repo's current blob-hash set (via `git ls-files`, excluding `.worktrees/` and submodule paths).
- Manifest dirs (contain `manifest.yaml`): orphaned if re-computing the manifest hash from current `file_paths` yields a different value — any listed file is missing or changed.

**Don'ts:**

- Do not run before `rekey/` — prune first destroys records that rekey needs.
- Do not pass an absolute path as `--target` (rejected with ERROR).
- Does not delete records based on age, model, or op-kind alone.
- Does not follow symlinks when walking `.hash-record/`.
- Does not delete `.hash-record/` itself or any admin dot-dir directly under it.

Related: `hash-record`, `rekey/`, `index/`
