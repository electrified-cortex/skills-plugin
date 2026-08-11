---
name: stamp
description: Writes or updates SHA-256 companion files alongside target files. Triggers - stamp this file, write sha256, update stamp, create companion hash, hash stamp.
---

Dispatch: "Read and follow `instructions.txt` (in this dir). Input: `<path|glob|--tree <root>> [--force]`"

`<path>`/`<glob>`: explicit targets. `--tree <root>`: stamp all stampable files under root. `--force`: overwrite unconditionally.

Output: table (path | WRITTEN/UPDATED/UNCHANGED/ERROR) + summary. Non-zero exit on ERROR only.
