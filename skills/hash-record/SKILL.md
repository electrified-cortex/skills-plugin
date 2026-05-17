---
name: hash-record
description: Content-hash-keyed durable record store — one substrate for caching audit, review, and hygiene results. Probe / Read / Write / Invalidate / Rekey / Prune / Index API. Triggers - cache result, look up cached record, hash-record store.
---

Routes hash-record questions to the correct sub-skill. Does not perform
reviews, audits, or consumer operations — it is infrastructure only.

## Sub-Skill Routing

| Question | Sub-skill |
| --- | --- |
| Does a cache record already exist for this file + operation? | `check/` |
| Does a cache record exist for a set of files (multi-file key)? | `manifest/` |
| Move a stale record to the new hash after a file's content changed? | `rekey/` |
| Remove orphaned hash directories from `.hash-record/`? | `prune/` |
| Build or refresh `manifest.yaml` index files inside each hash dir? | `index/` |

## Rules

- Load the matching sub-skill and let it produce the result.
- When in doubt between `check/` (single file) and `manifest/` (multi-file), ask: is the cache key one file or multiple files?
- Sub-skills call scripts directly; no further dispatch is needed inside them.
- `operation_kind` values in existing records are LEFT UNCHANGED by any refactor. The store is append-only bookkeeping; skill folder names do not affect record frontmatter.
- Never store records outside `.hash-record/`. Never truncate the hash except the 2-char shard prefix.

## Design Principles

- **One substrate, not per-skill caches.** All consumer skills write into and read from `.hash-record/`. There is no `.audit-reports/`, no `.code-reviews/` — only `.hash-record/`.
- **Content hash is the key.** The git blob hash of file content (`git hash-object`) is the canonical cache key. Same content = same key; content change = different key.
- **Consumers compute, hash-record stores.** Consumer skills perform the work and call hash-record to persist and retrieve results. Hash-record does not run audits, lint, or reviews.
- **Lazy invalidation is the default.** Stale records accumulate harmlessly — consumers query by current hash, so stale entries are never returned. `prune/` handles bulk cleanup on demand.
- **Rekey before prune.** After a formatting pass changes file bytes, run `rekey/` first, then `prune/`. Pruning first destroys records the rekey needs.

## Storage path

```text
.hash-record/<hash[0:2]>/<full-hash>/<skill>/[v<version>/]<model>.md
```

Related: `check/`, `manifest/`, `rekey/`, `prune/`, `index/`, `code-review`, `markdown-hygiene`, `skill-auditing`, `spec-auditing`.
