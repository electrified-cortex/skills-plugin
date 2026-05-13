# Changelog

All notable changes to this project will be documented in this file.

## [0.4.2] - 2026-05-13

- **fix(gh-cli-pr-inline-comment-post):** bash Step 4b body-trim mismatch causing dedup false negatives. `awk '{$1=$1};1'` collapsed internal whitespace per line while jq's `gsub("^\\s+|\\s+$"; "")` only trims outer whitespace; mismatch caused dedup to miss on every retry within the eventual-consistency window, producing N copies of the same comment. Fix passes BODY directly to jq and applies the same gsub trim on both sides. pwsh path was already correct (uses `.Trim()`). Upstream PR: electrified-cortex/skills#27.

## [0.4.1] - 2026-05-12

- README rewrite: skills/README.md is now lean (foundational journey of 5 entries; stale 13-skill table and 12-section per-skill journey removed).
- skills-plugin/README.md structure block corrected — references `.claude-plugin/plugin.json` (the consumer manifest); removed stale root `plugin.json` reference.
- Plugin manifest collapse: root `plugin.json` deleted; `.claude-plugin/plugin.json` is now the sole version of record. `bump.ps1`/`publish.ps1` updated accordingly.
- Session-noise cleanup: removed `gh-cli/redundancy-audit.md`, `prd-auditing/research.md`, `skill-auditing/result/audit-report.md` (~664 lines of session work-notes that leaked into 0.4.0 dist).
- markdownlint configuration added to skills source to ignore directories that should not be linted.
- Cross-cutting markdown hygiene normalizations: table-pipe alignment and code-fence language tags across spec/doc files.
- gh-cli-pr-inline-comment-post dedup fallback was already in 0.4.0; no change here.


## [0.4.0] - 2026-05-12

- gh-cli refactor: bash/pwsh shell split across PR/issues/inline-comment skills; co-located per-skill body-post tools (post.sh/post.ps1) replace shared dispatcher; body-content dedup fallback added to inline-comment-post for GitHub API eventual-consistency window
- copilot-cli + hash-record-manifest: 4 over-dispatched skills collapsed to routers (3 copilot-cli sub-skills + hash-record-manifest)
- skill-auditing: new rules A-IR-1/2/3 detect input-redefinition, return-redefinition, and frontmatter-leak in instructions files; dispatch-vs-router fitness scan added
- spec-writing / spec-auditing: Domain-Flavor Extension support added (parent enables typed extension skills); spec-auditing host card trimmed (cache mechanics + fix-iteration moved to instructions)
- prd-writing + prd-auditing: new domain-flavor skill pair for Product Requirements Documents (parent: spec-writing); full spec coverage including Content Modes inheritance, Behavior, Defaults, Error Handling
- code-review: DS-5 substrate duplication eliminated (delegates to hash-record-manifest by name)
- 15+ skills: cross-cutting redundancy trim; instructions no longer restate Inputs/Returns from SKILL.md; frontmatter and parity fixes across gh-cli, spec-writing, etc.
- Plugin tooling: .claude-plugin/plugin.json now syncs in lockstep with root plugin.json on every bump/publish (consumer-facing version was stuck at 0.1.8)


## [0.3.0] - 2026-05-08

add messaging skill; add skill-manifest dispatch skill; fix premature gate violations in spec-writing, skill-index-building

## [0.2.0] - 2026-05-08

code-review skill: full optimization pass (Tier 1-3, 26 topics). Executor and dispatch card fully optimized. skill-auditing PASS on first attempt.

## [0.1.8] - 2026-05-07

Rebuild distribution — sync updated skills from electrified-cortex/skills (swarm skill, code-review skill, dispatch rolling-window, hash-record rekey, skill-auditing improvements, and other fixes)

## [0.1.7] - 2026-05-06

copilot-cli skill bundle — 3 dogfood findings fixed (task 10-1033):

- A1 HIGH: add instructions.txt + instructions.uncompressed.md to all 3 sub-skills (copilot-cli-ask, copilot-cli-review, copilot-cli-explain); sub-skills now dispatch via proper routing cards
- A2 MED: document --model flag constraint in instructions files; named models may be unavailable; graceful error handling already present
- A5 MED: fix triggers mismatch in router (removed non-routing triggers); add NEEDS_CLARIFICATION status + result envelope to router; convert sub-skill SKILL.md to dispatch routing cards (NEVER READ guard, Variables block); rewrite sub-skill uncompressed.md to match routing card format; remove non-instructional Skill Index section from router

All 4 skills (router + 3 sub-skills) audited PASS. Seal records written.

## [0.1.6] - 2026-05-07

Fix (markdown-hygiene-lint): step 3 result-check now invokes `result.sh`/`result.ps1` directly instead of "dispatching" another skill. Sub-agents are forbidden from dispatching other skills (skill-writing rule); the wording was misleading even though behavior was working.

## [0.1.5] - 2026-05-07

Skills update: dispatch-wording disambiguation across 9 skills.
"Follow the dispatch skill" / "dispatch \`X\`" boilerplate replaced with
explicit "load X/SKILL.md and follow the pattern it describes" form.
Makes the READ step explicit so consuming agents don't fire the Skill
tool blindly without first reading the dispatch skill's content.

Affected: skill-writing, skill-auditing, spec-auditing, tool-writing,
tool-auditing, code-review, compression, swarm, skill-index-auditing.

## [0.1.4] - 2026-05-07

Fix (publish): Step 2c now flat-mirrors ALL non-denied files in each skill folder, instead of only files referenced in SKILL.md. Convention-named scripts (e.g. `manifest.ps1`, `prune.sh`, `rekey.ps1`, `check.sh`) that aren't explicitly referenced in SKILL.md are now correctly included. Stage 2 reference walk scoped down to cross-folder includes only.

Fix (publish): deny pattern broadened from `*.uncompressed.md` to `*uncompressed.md` so bare `uncompressed.md` files are denied alongside prefixed `<name>.uncompressed.md`.

Fix (publish): `.claude-plugin/plugin.json` version now bumped in lockstep with root `plugin.json`. Previously only root was bumped.

Affected skills (now ship with backing scripts): `hash-record-manifest`, `hash-record-rekey`, `hash-record-prune`, `hash-record-check`, `markdown-hygiene-*`, all dispatch skills with sibling tools.

## [0.1.3] - 2026-05-06

Fix: Stage 2 reference resolution now picks up bare filenames (e.g. `instructions.txt`, `result.ps1`, `result.sh`) in addition to path-qualified refs. Previously, skills that reference sibling files by bare name (no `/`) were not having those files included in the dist, causing 40+ skills to ship with only SKILL.md and missing their runtime backing files.

## [0.1.2] - 2026-05-06

Drain skills dev: R-FM-11 hybrid + A-XR-1 parity, 21-ref path-style sweep, gh-cli sweep (16 NEEDS_REVISION -> PASS), capability-cache + swarm-review + single-adversary-code-review skills, skill-writing fully sealed.

## [0.1.0] - 2026-05-05

Initial release: scaffold, Stage 1 mechanical crawler with deny-list filtering, publish skill (dispatch pattern), build/config.yaml sibling-mode default.

- Scaffold landed: `publish/`, `build/build.ps1`, `build/config.yaml`, `plugin.json`, `CHANGELOG.md`, `README.md`.
