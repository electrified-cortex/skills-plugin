---
name: index
description: Build and refresh manifest.yaml index files inside each hash directory under .hash-record/. Triggers — index hash records, refresh hash-record index, build manifest.yaml.
---

Walks every `<shard>/<full-hash>/` dir under `.hash-record/`. For each, reads leaf record frontmatter, collects distinct `file_path` values, writes `<shard>/<full-hash>/manifest.yaml`. Regenerates when path set differs from current leaf records. Never modifies leaf records; never deletes.

Dispatch isolated agent (zero context): "Read and follow `instructions.txt` (in this directory). Input: `repo_root=<absolute-path>`"

- `repo_root` (required): absolute path to repo root containing `.hash-record/`.

Returns: `CLEAN` | `indexed: <count>` | `ERROR: <reason>`

Related: `hash-record`, `prune/`
