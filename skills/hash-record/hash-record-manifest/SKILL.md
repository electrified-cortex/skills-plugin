---
name: hash-record-manifest
description: Compute a manifest hash for a set of files. Triggers — compute manifest hash, multi-file cache key, hash-record manifest, manifest hash, bundle file hashes, cache key for directory.
---

Compute deterministic manifest hash for set of files. Manifest hash = multi-file cache key for hash-record consumers (skill audits, dir code reviews, anything bundling multiple sources into single result).

Input:
`repo_root` (required): abs path to repo root. Computes repo-relative paths for manifest text.
`files` (required): paths to include. Abs or repo-relative; skill normalizes all to repo-relative against `repo_root`.

Dispatch:
Variables:
`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = abs path to `<instructions>`
`<input-args>` = `repo_root=<abs-path> files=<comma-or-newline-separated-list>`
`<tier>` = `fast-cheap`
`<description>` = `Computing manifest hash: <repo_root>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.
Returns: `manifest: <40-char-hash>` | `ERROR: <reason>`

Related: `hash-record`, `hash-record-index`, `hash-record-prune`
