# copilot-cli Changes

## 2026-05-15 — Sub-skill flatten

Renamed sub-skill folders to drop the `copilot-cli-` prefix, matching the flatten pattern applied to `github/`, `markdown-hygiene/`, `dispatch/`, and `hash-stamping/`.

| Old path | New path |
| --- | --- |
| `copilot-cli/copilot-cli-ask/` | `copilot-cli/ask/` |
| `copilot-cli/copilot-cli-explain/` | `copilot-cli/explain/` |
| `copilot-cli/copilot-cli-review/` | `copilot-cli/review/` |

Files updated (frontmatter `name:`, routing tables, `Related:` lines, spec H1 titles):

- `copilot-cli/SKILL.md` — routing table (`ask/`, `explain/`, `review/`), Related line
- `copilot-cli/spec.md` — routing table
- `copilot-cli/uncompressed.md` — routing table
- `copilot-cli/skill.index` — sub-skill keys
- `copilot-cli/skill.index.md` — sub-skill headings
- `copilot-cli/ask/SKILL.md` — `name: ask`, Related line
- `copilot-cli/ask/uncompressed.md` — `name: ask`, Related line
- `copilot-cli/ask/spec.md` — H1 title, sibling references
- `copilot-cli/explain/SKILL.md` — `name: explain`, Related line
- `copilot-cli/explain/uncompressed.md` — `name: explain`, Related line
- `copilot-cli/explain/spec.md` — H1 title, sibling references
- `copilot-cli/review/SKILL.md` — `name: review`, Related line
- `copilot-cli/review/uncompressed.md` — `name: review`, Related line
- `copilot-cli/review/spec.md` — H1 title

Cross-repo reference updates:

- `dispatch/supplemental.md` — comment updated (`copilot-cli-ask` → `ask`)
- `skills-plugin/skills/copilot-cli/**` — mirrored renames + content updates
- `cortex.lan/docs/skill-master-index.md` — path + name columns updated for `ask` and `review` rows
