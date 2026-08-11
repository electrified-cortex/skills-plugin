---
name: skill-manifest
description: Produce the complete file list for a skill folder by walking SKILL.md refs recursively. Results cached in hash-record — LLM scan only on cache miss. Triggers — skill file list, skill manifest, what files does this skill need, skill dependency scan, skill publish file set.
---

Compute complete file set required to publish skill folder.

Input:
`skill_dir` (required): absolute or repo-relative path to skill folder containing `SKILL.md`.
`repo_root` (optional): absolute path to skills repo root. Defaults to git repo root of `skill_dir`.
`depth_limit` (optional): max ref recursion depth. Default: 4. Max: 8.

Host steps (before dispatch):

1. Resolve `repo_root` (from input or `git rev-parse --show-toplevel`).
2. Verify `skill_dir` exists, contains `SKILL.md`. Fail → return `ERROR: <reason>`.
3. Enumerate files in `skill_dir` (non-recursive, no dot-files).
4. Dispatch `hash-record/manifest` with file list + `repo_root`. Receive `manifest_hash`.
5. Probe `hash-record(manifest_hash, "skill-manifest")`.
   - Hit: return stored result with `"cached": true`. Done — no subagent needed.
     Cache key covers `skill_dir` direct files only. Stale `files` or `broken_refs` possible if transitive deps outside `skill_dir` changed since last scan. Callers force fresh scan by touching any `skill_dir` file.
   - Miss: proceed to dispatch.

Dispatch:
Variables:
`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `skill_dir=<path> repo_root=<path> manifest_hash=<hash> files=<comma-separated repo-relative paths> [depth_limit=<n>]`
`<tier>` = `standard` — semantic ref walk; comprehension tasks
`<description>` = `skill-manifest: <skill_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill: `../dispatch/SKILL.md`.

Returns:

```json
{
  "skill": "<folder name>",
  "manifest_hash": "<40-char hash>",
  "files": ["<repo-relative path>", ...],
  "broken_refs": ["<unresolved ref>", ...],
  "cached": true,
  "depth_limit": 4
}
```

`broken_refs` empty = all refs resolved. `cached: true` = LLM not invoked.
