---
name: skill-index
description: Root skill for the skill-index toolkit. Governs sub-skills that let agents discover available skills by reading compact index nodes rather than walking the filesystem. Triggers - discover skills, find available skill, skill discovery, read skill index, what skills are available.
---

Root skill for skill-index toolkit. Governs sub-skills letting agents discover skills by reading compact index nodes instead of walking filesystem.

What This Skill Covers:
skill-index toolkit produces, validates, stamps cascading tree-structured index of skills in dir hierarchy. Index node in agent's working dir = complete discovery surface for that dir + descendants. Agent reads node; doesn't traverse filesystem.

Three sub-skills:
`skill-index-building` — creates/updates two artifacts per indexed dir: `skill.index` (raw index) + `skill.index.md` (metadata overlay). Doesn't write integrity stamp.
`skill-index-auditing` — validates existing cascade, returns rebuild-needed signal when stale or broken. On PASS, writes `skill.index.sha256` (integrity stamp) at each validated node.
`skill-index-crawling` — reads existing cascade to locate skill matching agent's stated need without opening skill contents.

Core Concepts:
Artifacts: every indexed dir holds three files: `skill.index` (plain text, deterministic, authoritative), `skill.index.md` (human/agent descriptions, LLM-authored), `skill.index.sha256` (SHA-256 hex digest of `skill.index` stored bytes, written by auditor on PASS). Builder produces first two; auditor writes third.

Index node: `skill.index` file. Each line = one entry: `key: keyword, keyword, keyword`. Entries reference direct children by default; multi-segment shortcut entries (curator-added) reference deeper descendants. Every node is self-contained — references only descendants within own subtree.

Cascade: directed acyclic graph of index nodes + their referenced entries. Self-contained. No cycles.

Leaf skill: dir containing skill manifest file. Unit of discovery.

Combo node: dir simultaneously leaf skill + parent of further leaf skills. Emits self entry (key `.`) in own `skill.index`; marked as combo in parent's `skill.index`.

Integrity stamp: SHA-256 hex digest of raw index's exact stored bytes. Written by auditor on PASS — never by builder. Absent stamp after build = "unaudited since last build," not "needs rebuild." Mismatch = raw index changed since last audit.

Drift: metadata overlay no longer corresponds to raw index; detected by stamp mismatch.

Two-step sequence: builder runs → auditor runs → auditor writes stamp on PASS. Builder doesn't write stamp at any point.

Key Rules:
Toolkit doesn't load, execute, or validate skill contents — only presence.
Raw index content authoritative over overlay at all times.
Cascade graph must be acyclic. Auditor enforces; crawler terminates loops at consumption time.
Dot-prefixed dirs skipped by default. Explicit allow-list of bare dir names overrides for those names only.
Symlinks not followed by default.
Index files mustn't use `.md` extension.
Toolkit doesn't require network access or elevated privileges.
Builder doesn't write integrity stamp. Auditor writes on PASS.
Builder compares computed raw content hash against stored `skill.index` bytes for change detection. Never consults stamp for this.

Footguns:
F1: Builder writes stamp, bypassing auditor. → Enforce spec R18, B7. Builder mustn't write `skill.index.sha256`. Only auditor writes stamp, only on PASS.
F2: Combo node treated as pure leaf. → Enforce spec R4, R9–R12. Combo node must emit self entry + enumerate manifest-bearing subdirs. Traversal not suppressed.
F3: Dot-folder allow-list misused as path expression. → Enforce spec C7. Allow-list entries are bare dir names only — no globs, paths, regexes.
F4: Shortcut entry escapes subtree. → Enforce spec R33. Shortcut entry keys mustn't use `..` segments or absolute paths. Target must remain in current node's subtree.
F5: Curator shortcuts form cycle. → Enforce spec R34. Auditor tracks visited nodes on each resolution path; flags revisit.
F6: Builder erases curated shortcuts on rebuild. → Enforce spec R36. Builder preserves curator-added shortcut entries verbatim across all runs.

Sub-Skill Invocation:
All three sub-skills are dispatch skills — invoke via Dispatch agent (zero context) with `instructions.txt` in respective sub-skill dir.
Builder: `skill-index-building/instructions.txt`
Auditor: `skill-index-auditing/instructions.txt`
Crawler: `skill-index-crawling/instructions.txt`
Integration: `skill-index-integration/` — governs agent context wiring; read SKILL.md for integration contract.

Don'ts:
Doesn't load, execute, validate, or audit skill contents.
Doesn't govern skill naming, structure, or authoring — see `skill-writing`.
Doesn't version or archive prior index states.
Doesn't replace filesystem walks for every use case — provides cached cascading dir for consumers preferring compact lookup.
Doesn't define metadata overlay's content schema — that's `skill-index-building`'s concern.

Related:
`skill-index-building` — produces `skill.index` + `skill.index.md` per indexed dir
`skill-index-auditing` — validates cascade, writes stamp on PASS
`skill-index-crawling` — reads cascade to locate skill
`skill-index-integration` — governs agent context wiring to consume cascade
`skill-writing` — governs skill naming, structure, authoring
