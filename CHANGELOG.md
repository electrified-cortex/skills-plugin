# Changelog

All notable changes to this project will be documented in this file.

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
