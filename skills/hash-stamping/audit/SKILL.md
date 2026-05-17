---
name: audit
description: Read-only skill. Verifies SHA-256 stamp integrity across a skill tree. Finds all .sha256 companion files and checks each against the current hash of its target. Triggers - stamp verification, hash mismatch detection, companion file audit, stamp drift check, integrity check, sha256 validation.
---

Dispatch: "Read and follow `instructions.txt` (in this dir). Input: `root=<path> [--git-only]`"

`root` (required): audit root. `--git-only`: limit to companions of git-modified/untracked files.

Output: table (path | PASS/FAIL/MISSING/MALFORMED) + summary line. FAIL rows show 8-char prefix (stored→actual). Non-zero exit on any FAIL, MISSING, or MALFORMED.
