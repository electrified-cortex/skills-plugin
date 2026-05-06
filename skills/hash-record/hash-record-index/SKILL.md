---
name: hash-record-index
description: Build and refresh manifest.yaml index files inside each hash directory under .hash-record/. Triggers - index hash records, refresh hash-record manifest, build index for hash-record, hash record manifest index.
---

Walks every `<shard>/<full-hash>/` dir under `.hash-record/`. For each, reads leaf record frontmatter, collects distinct `file_path` values, writes `<shard>/<full-hash>/manifest.yaml`. Regenerates manifest whenever its path set differs from current leaf records. Never modifies leaf records; never deletes.

Dispatch isolated agent (Dispatch, zero context): "Read and follow `instructions.txt` (in this directory). Input: `repo_root=<absolute-path>`"

- `repo_root` (required): absolute path to repo root containing `.hash-record/`.

Returns: `CLEAN` | `indexed: <count>` | `ERROR: <reason>`

## Verify (no dispatch needed)

A consumer / operator can verify or rebuild manifests in-place without dispatching this skill. The procedure is a small shell loop:

```bash
# bash (run from repo root)
for hash_dir in $(find .hash-record -mindepth 2 -maxdepth 2 -type d); do
  paths=$(find "$hash_dir" -name "*.md" -not -name "manifest.yaml" | while read f; do
    awk '/^file_path:/ { sub(/^file_path:[ \t]*/,""); print; next }
         /^file_paths:/ { in_list=1; next }
         in_list && /^[ \t]*-[ \t]/ { sub(/^[ \t]*-[ \t]*/,""); print; next }
         in_list && /^[^ \t-]/ { in_list=0 }' "$f"
  done | sort -u)
  [ -z "$paths" ] && continue
  { echo "file_paths:"; echo "$paths" | sed 's/^/  - /'; } > "$hash_dir/manifest.yaml"
done
```

```powershell
# PowerShell (run from repo root)
Get-ChildItem .hash-record -Directory -Depth 1 | ForEach-Object {
  $paths = Get-ChildItem $_.FullName -Recurse -Filter '*.md' |
    Where-Object Name -ne 'manifest.yaml' |
    ForEach-Object { Select-String '^file_path: (.+)$|^  - (.+)$' $_.FullName -AllMatches |
      ForEach-Object { $_.Matches.Groups[1..2] | Where-Object Value | Select-Object -ExpandProperty Value } } |
    Sort-Object -Unique
  if ($paths) { ("file_paths:`n" + ($paths | ForEach-Object { "  - $_" }) -join "`n") | Set-Content "$($_.FullName)/manifest.yaml" }
}
```

Use the dispatch path when an isolated agent context is desired (e.g., as part of a maintenance pipeline). Use the inline shell path when the operator just wants to refresh manifests quickly.

Related: `hash-record`, `hash-record-prune`
