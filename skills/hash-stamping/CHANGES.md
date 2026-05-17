# hash-stamping — Flatten Changes

Same pattern as `dispatch/` and `markdown-hygiene/` flattens.

## Sub-skills renamed

| Old path | New path |
| --- | --- |
| `hash-stamping/hash-stamp/` | `hash-stamping/stamp/` |
| `hash-stamping/hash-stamp-audit/` | `hash-stamping/audit/` |

## Files updated

- `hash-stamping/stamp/SKILL.md` — `name:` updated from `hash-stamp` to `stamp`
- `hash-stamping/stamp/uncompressed.md` — `name:` updated from `hash-stamp` to `stamp`
- `hash-stamping/audit/SKILL.md` — `name:` updated from `hash-stamp-audit` to `audit`
- `hash-stamping/audit/uncompressed.md` — `name:` updated from `hash-stamp-audit` to `audit`
- `hash-stamping/SKILL.md` — sub-skill folder references updated
- `hash-stamping/uncompressed.md` — sub-skill folder references updated
- `hash-stamping/skill.index` — entry keys updated from `hash-stamp`/`hash-stamp-audit` to `stamp`/`audit`
- `hash-stamping/skill.index.md` — section headings updated

## Reference sweep

Active files updated:

- `cortex.lan/docs/skill-master-index.md` — path column updated for both sub-skill rows
- `.agents/tasks/00-ideas/trigger-phrase-sweep-2026-05-05.md` — path references updated

Skipped per historical convention (70-done):

- `.agents/tasks/70-done/20260507/10-0997-trigger-phrase-sweep-ec-skills.md`
- `.agents/tasks/70-done/2026/05/02/10-820-mass-md-hygiene-sweep-electrified-cortex.md`
- `.agents/tasks/70-done/2026/05/02/10-0912-dispatch-pattern-audit-electrified-cortex.md`
- `cortex.lan/tasks/70-done/2026/04/26/10-0843-full-skill-reindex-from-root.md`

Out of scope:

- `.hash-record/**` — record-format identifiers, schema values, left untouched
- `electrified-cortex/skills-plugin/skills/hash-stamping/` — separate repo on `main` branch, not in task scope; still uses old sub-skill names (`hash-stamp/`, `hash-stamp-audit/`)
- `operation_kind` schema field values — left untouched throughout

## Notes

- `hash-stamping/spec.md` already used `audit/` and `stamp/` folder names in the routing table — no change needed.
- `hash-stamp` (generic noun/concept) in prose left untouched per disambiguation rule.
