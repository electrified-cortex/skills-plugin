---
name: hash-record-prune
description: Remove orphaned hash directories from a repository's .hash-record/ store. Triggers — prune hash records, clean up hash-record, remove orphaned records, hash-record maintenance, reclaim disk.
---

Run script directly. Don't reimplement. Tools: `prune.sh` (Bash) · `prune.ps1` (PS7+).

- PS7: `pwsh <this-skill-dir>/prune.ps1 "<repo_root>" [-target "<glob>"] [-dry_run] [-limit <N>]`
- Bash: `bash <this-skill-dir>/prune.sh "<repo_root>" [--target "<glob>"] [--dry-run] [--limit <N>]`

- `repo_root` (required): absolute path to repo root containing `.hash-record/` dir.
- `--target <glob>` (optional): relative glob; only matching hash dirs are candidates. No absolute paths.
- `--dry-run` (optional): list orphans, no delete. Default: delete.
- `--limit <N>` (optional): cap deletions per invocation. Default: unlimited.

Validity scoped to `repo_root` (active worktree only):

- Manifest records: orphaned if any listed file missing or manifest hash changes.
- Non-manifest records: orphaned if `<full-hash>` not in repo blob-hash set (excludes `.worktrees/` and submodule paths).

Returns: `CLEAN` | `pruned: <count>` | `dry-run: <count>` | `ERROR: <reason>`

Related: `hash-record`, `hash-record-index`, `hash-record-manifest`
