---
name: publish
version: 0.1.0
description: Cut a new tagged release of skills-plugin. Bumps version, rebuilds skills/ dist, updates CHANGELOG, commits, tags, pushes.
inputs:
  version_bump: "required. patch | minor | major"
  release_notes: "required. Human-authored changelog body."
  source_root: "optional. Override build/config.yaml source path."
  dry_run: "optional bool. Default false. Skip commit/tag/push."
---

Caller decides WHEN to release. This skill executes the release.

## Definitions

- **release branch** — branch skill operates on; default `main`; set in `build/config.yaml` `release_branch`.
- **plugin version** — SemVer string in `plugin.json` `version` field.
- **build** — `pwsh build/build.ps1`; crawls source tree per config; writes dist to `skills/`.
- **deny list** — patterns in `build/deny-list.ps1`; must not appear in dist `skills/`.
- **dry run** — all steps except commit/tag/push; returns planned outcome.
- **release commit** — single commit: bumped `plugin.json`, prepended `CHANGELOG.md`, regenerated `skills/`.

## Pre-flight (R1–R4) — all mandatory; none skippable

**R1 dirty_working_tree** — if uncommitted changes exist outside `skills/`, `plugin.json`, `CHANGELOG.md`: stop, list offending paths.

**R2 wrong_branch** — if current branch != release branch: stop, surface current branch.

**R3 bad_config** — if `build/config.yaml` missing or unparseable: stop.

**R4 bad_prior_version** — if most recent tag version !SemVer: stop.

## Procedure

**1. Compute version (R5).** Read `plugin.json` `version`. Apply `version_bump` per SemVer: patch=increment patch; minor=increment minor+reset patch; major=increment major+reset minor+patch.

**2. Run build (R6).** `pwsh build/build.ps1`. Non-zero exit -> stop `build_failed`. Post-build: if deny-list validation finds any deny-pattern file in `skills/` -> stop `build_validation_failed`, list offending paths.

**3. Update plugin.json (R7).** Set `version` = new SemVer. Set `built` = UTC date `YYYY-MM-DD`.

**4. Update CHANGELOG.md (R8).** Prepend:

```markdown
## [<new-version>] - <YYYY-MM-DD>

<release_notes>
```

Preserve all prior entries verbatim.

**5. Stage + commit (R9).** Stage exactly:

```text
plugin.json
CHANGELOG.md
skills/
```

No `git add -A`. Commit message: `release: v<new-version>`.

**6. Tag (R10).** Annotated tag:

```sh
git tag -a v<new-version> -m "v<new-version>"
```

**7. Dry-run gate (R11).** If `dry_run=true` -> stop; return dry-run report. No push.

**8. Push (R11, R12).** Push branch and tag:

```sh
git push origin <release-branch>
git push origin v<new-version>
```

Force-push forbidden (R12). Push failure -> stop `push_failed`; surface git error; leave local commit+tag intact. No auto-resolution of divergence.

## Outputs

- Release commit on release branch: bumped `plugin.json`, prepended `CHANGELOG.md`, rebuilt `skills/`.
- Annotated tag `v<new-version>`.
- Status report: prev version, new version, files changed, build report (skills count, included, denied), push result.

## Bailout

| Status | Trigger | State |
| --- | --- | --- |
| `dirty_working_tree` | R1 | No mutations |
| `wrong_branch` | R2 | No mutations |
| `bad_config` | R3 | No mutations |
| `bad_prior_version` | R4 | No mutations |
| `build_failed` | Build exit != 0 | No commit |
| `build_validation_failed` | Deny-pattern in dist | No commit |
| `push_failed` | Push rejected | Local commit+tag intact |

## Constraints

- Must NOT decide whether to release.
- Must NOT auto-generate `release_notes`.
- Must NOT modify `skills/` by hand.
- Must NOT bump per-skill versions in `plugin.json`.
- Must NOT amend/rewrite prior commit history.
- Must NOT skip R1–R4 on caller request.

## Dependencies

- `build/build.ps1` present, exits 0 on success.
- `build/config.yaml` valid `source` block; optional `release_branch`.
- `build/deny-list.ps1` loaded by build, applied during validation.
- Working tree on configured release branch.
- `pwsh` 7+ on PATH.
