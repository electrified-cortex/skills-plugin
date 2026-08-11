---
name: skill-index
description: Router for the skill-index toolkit — cascading index of skills in a directory hierarchy. Agents read index nodes to discover skills without walking the filesystem. Triggers - discover skills, find available skill, skill discovery, read skill index, what skills are available, build skill index, audit skill index, crawl skill index, integrate skill index, find skill, locate skill, where is skill, finding.
---

**Looking for a specific skill by name?** Go directly to `finding/SKILL.md` — cache-first, Haiku tier, minimum token cost.

Cascading skill discovery toolkit. Sequence: building → auditing → crawling. Crawling and auditing require a built index. Only the auditor writes the integrity stamp — never the builder. Pick the right sub-skill:

- **finding** — locate a named skill by cache lookup; invokes crawling on miss. Read `finding/SKILL.md`.
- **building** — create/update `skill.index` + `skill.index.md` at every indexed dir. Read `building/SKILL.md`.
- **auditing** — validate an existing cascade; write integrity stamp on PASS. Read `auditing/SKILL.md`.
- **crawling** — locate a skill matching a stated need by reading index nodes only. Read `crawling/SKILL.md`.
- **integration** — one-time setup: wire the cascade into an agent's context for on-demand discovery. Read `integration/SKILL.md`.
