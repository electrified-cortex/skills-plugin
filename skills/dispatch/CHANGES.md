# dispatch/ flatten — CHANGES

## Rename map

| Before | After |
| --- | --- |
| `dispatch/dispatch-setup/` | `dispatch/setup/` |

## File count

- 3 files renamed via `git mv` (`SKILL.md`, `spec.md`, `uncompressed.md`)
- 5 files updated for references

## References updated

| File | Change |
| --- | --- |
| `dispatch/setup/SKILL.md` | `name: dispatch-setup` → `name: setup` |
| `dispatch/setup/uncompressed.md` | `name: dispatch-setup` → `name: setup` |
| `dispatch/setup/spec.md` | `# dispatch-setup spec` → `# setup spec` |
| `dispatch/SKILL.md` | `` `dispatch-setup/SKILL.md` `` → `` `setup/SKILL.md` `` in See also |
| `dispatch/skill.index` | `dispatch-setup:` key → `setup:` |
| `dispatch/skill.index.md` | `## dispatch-setup` → `## setup` |

## Decisions

- Only one sub-skill had the `dispatch-` prefix: `dispatch-setup`.
- References in `.agents/tasks/70-done/` and `notes/` are archival — left untouched per historical convention.
- `00-ideas/trigger-phrase-sweep-2026-05-05.md` contains a path reference (`dispatch/dispatch-setup/SKILL.md`) but is an archival snapshot, not an active routing file — left untouched.
- `uncompressed.md` in `dispatch/agents/README.md` contains no `dispatch-setup` references.
- Hash-record entries left untouched per deferred scope.
