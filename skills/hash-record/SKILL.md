---
name: hash-record
version: 0.1
description: Content-hash-keyed durable record store. Probe / Read / Write / Invalidate API. Replaces .audit-reports/ and .code-reviews/ with one substrate that consumer skills call into directly. Triggers - cache result, store audit result, look up cached record, skip if already done, hash-record store.
---

Consumer skills call into this for storage; hash-record never runs operations of its own.

## Path

```text
.hash-record/<hash[0:2]>/<full-hash>/<skill>/[v<version>/]<model>.md
```

- 2-char shard, full 40-char hash inside, then skill / optional version / model.
- Version segment omitted when skill has no `version` frontmatter.

## API

| Op | Input | Output |
| --- | --- | --- |
| Probe | `(hash, skill, version|null, model)` | `{ hit, path }` |
| Read | path | record content |
| Write | `(hash, skill, version|null, model, content)` | new path |
| Invalidate | `[(path, old, new)]` | count deleted |
| Rekey | `(file_path, op_kind, record_filename)` | `REKEYED / CURRENT / NOT_FOUND` |

Path is deterministic from input. Probe and Write agree.

## Record frontmatter (required)

```yaml
---
hash: <full git blob hash>
file_path: <git-relative path>
operation_kind: <skill name>
model: <model-identifier>
result: pass | findings | error | skipped
---
```

`result` is a closed enum. Malformed records are treated as misses, never raise.

## Don'ts

Don't store outside `.hash-record/`. Don't truncate hash except shard prefix. Re-runs overwrite the canonical record at the same path. Don't auto-invoke eager cleanup. Don't perform consumer ops. Don't mutate git state.

## Transition

`.sha256` sidecars and `operator-signoff` records both currently valid governance signals during rollout. Either suffices; consumers MUST NOT require both.

Related: `code-review`, `swarm`, `skill-auditing`, `spec-auditing`, `markdown-hygiene`, `hash-record-rekey`.
