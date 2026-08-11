---
name: result
description: Check cache state of a markdown-hygiene sub-document. Returns path and cache status for report, lint, or analysis. Triggers - check hygiene cache, hygiene result cache, get cached report, markdown hygiene hit or miss.
---

Run `result.sh` / `result.ps1` from `result/`, whichever your runtime has. DON'T READ the script source.

- Bash: `bash <result-skill-dir>/result.sh <markdown_file_path> <filename>.md`
- PS7: `pwsh <result-skill-dir>/result.ps1 <markdown_file_path> <filename>.md`

`<filename>` is the bare sub-document name to probe: `report`, `lint`, or `analysis`.

Branch on the one-line stdout:

- `MISS: <abs-path>` — no cache entry; bind the path and continue.
- `CLEAN` — cached clean; stop, nothing to do.
- `clean: <abs-path>` — sub-document cached clean; skip to next phase.
- `findings: <abs-path>` — violations present; bind path and continue.
- `pass: <abs-path>` — advisories present; bind path and continue.
- `ERROR: <reason>` — stop, surface reason.

The `<abs-path>` in each response is the full path to the sub-document for that `<filename>` argument.
Call once per sub-document you need to check.
