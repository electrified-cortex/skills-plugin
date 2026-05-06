---
name: hash-stamping
description: SHA-256 integrity stamp suite. Verify stamp drift or write/update stamps. Triggers — verify stamp, check integrity, detect drift, update sha256, stamp this file, hash mismatch.
---

Two dispatch sub-skills:

- `hash-stamp-audit/` — verify stamps, detect drift. Use to check if a file changed since last stamp.
- `hash-stamp/` — write or update `.sha256` companions. Use after editing stamped files.

Policy: stamp files agents load + act on where silent drift causes incorrect behavior. Common candidates: `SKILL.md`, `instructions.txt`, `spec.md`, `CLAUDE.md`, `skill.index`, `skill.index.md`, automation scripts. Don't stamp logs, temp files, generated outputs, or code.

Dispatch each sub-skill via its own `instructions.txt`.
