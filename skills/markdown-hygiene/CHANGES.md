---
date: 2026-05-15
kind: flatten
---

# markdown-hygiene — Flatten Rename

## Rename Map

| Old folder | New folder |
| --- | --- |
| `markdown-hygiene/markdown-hygiene-lint/` | `markdown-hygiene/lint/` |
| `markdown-hygiene/markdown-hygiene-analysis/` | `markdown-hygiene/analysis/` |
| `markdown-hygiene/markdown-hygiene-result/` | `markdown-hygiene/result/` |

All file contents within each folder are unchanged except where noted below.

## File Changes

### Renames (git mv — 20 files total)

- `markdown-hygiene-lint/` → `lint/` (16 files: SKILL.md, spec.md, lint.spec.md, verify.spec.md, lint.sh, lint.ps1, verify.sh, verify.ps1, instructions.txt, instructions.uncompressed.md)
- `markdown-hygiene-analysis/` → `analysis/` (6 files: SKILL.md, spec.md, instructions.txt, instructions.uncompressed.md, .optimization/.log.md, .optimization/dispatch.md)
- `markdown-hygiene-result/` → `result/` (4 files: SKILL.md, result.spec.md, result.sh, result.ps1)

### Content Updates

**Frontmatter `name:` fields updated:**

- `lint/SKILL.md`: `name: markdown-hygiene-lint` → `name: lint`
- `analysis/SKILL.md`: `name: markdown-hygiene-analysis` → `name: analysis`
- `result/SKILL.md`: `name: markdown-hygiene-result` → `name: result`

**Path references updated (folder → new folder):**

- `markdown-hygiene/SKILL.md` — 5 path refs updated
- `markdown-hygiene/uncompressed.md` — 3 path refs updated
- `markdown-hygiene/spec.md` — 6 path refs updated (Mermaid diagram, step list, dispatch surface section)
- `markdown-hygiene/skill.index` — sub-skill names updated
- `markdown-hygiene/skill.index.md` — sub-skill heading names updated
- `markdown-hygiene/lint/SKILL.md` — no path refs (was clean)
- `markdown-hygiene/lint/spec.md` — title updated; 1 cross-ref updated
- `markdown-hygiene/lint/lint.spec.md` — 1 self-ref updated
- `markdown-hygiene/lint/instructions.uncompressed.md` — 1 result script path updated
- `markdown-hygiene/analysis/SKILL.md` — 1 path ref updated (`../markdown-hygiene-result/SKILL.md` → `../result/SKILL.md`)
- `markdown-hygiene/analysis/spec.md` — title updated; 1 cross-ref updated
- `markdown-hygiene/result/SKILL.md` — 1 self-ref updated (`markdown-hygiene-result/` → `result/`)
- `markdown-hygiene/result/result.spec.md` — title updated
- `skill-optimize/topics/dispatch.spec.md` — 2 golden-reference paths updated
- `skill-optimize/topics/dispatch.md` — 1 golden-reference path updated

**Unchanged (data contracts, not paths):**

- `operation_kind: markdown-hygiene-lint` and `operation_kind: markdown-hygiene-analysis` in spec/instructions files — these are output record schema values, not folder paths. Left as stable data contracts.
- `.hash-record/**` — historical records; operation_kind values unchanged.
- `analysis/.optimization/.log.md` title — PROSE, historical label.

## Reference Sweep

### Scope

- `electrified-cortex/skills/**/*.md` (non-hash-record)
- `cortex.lan/.agents/tasks/**/*.md` (non-icebox, non-70-done)

### Classification

| File | Classification | Action |
| --- | --- | --- |
| `skill-optimize/topics/dispatch.spec.md` | ACTIVE — golden reference path | Updated |
| `skill-optimize/topics/dispatch.md` | ACTIVE — golden reference path | Updated |
| `.agents/tasks/00-ideas/trigger-phrase-sweep-2026-05-05.md` | ACTIVE — folder paths in table | Updated |
| `.agents/tasks/00-ideas/markdown-hygiene-orchestrator-redesign.md` | ACTIVE — sub-skill dispatch refs | Updated |
| `.agents/tasks/icebox/10-0927-*` | HISTORICAL — icebox | Skipped |
| `.agents/tasks/icebox/10-0921-*` | HISTORICAL — icebox | Skipped |
| `.agents/tasks/70-done/**` | HISTORICAL | Skipped |
| `.hash-record/**` | DATA — operation_kind values | Skipped |

### Post-sweep verification

Active file grep for `markdown-hygiene-lint|markdown-hygiene-analysis|markdown-hygiene-result` (excluding .hash-record, 70-done, icebox) returned zero hits in path-reference positions. Only `operation_kind` data values remain, which are correct.

## Decisions

1. **`operation_kind` values unchanged.** `operation_kind: markdown-hygiene-lint` and `operation_kind: markdown-hygiene-analysis` are output record schema identifiers, not folder references. Changing them would break record readers. Left as-is per data-contract stability principle.

2. **Router shape unchanged.** `markdown-hygiene/SKILL.md` is already a clean router/orchestrator — it delegates to `lint/`, `analysis/`, and `result/` sub-skills. No structural change to the routing pattern was needed.

3. **Icebox + 70-done left as historical.** References in closed tasks describe past state. Updating them provides no operational value and adds noise to completed records.

4. **Hash-record stamp refresh deferred.** Per task spec — separate Haiku pass.
