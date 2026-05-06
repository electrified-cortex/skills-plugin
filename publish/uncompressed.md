# publish

Orchestrates a new release of the skills-plugin. Bumps the plugin version,
regenerates the distributed `skills/` tree via the build, updates the CHANGELOG,
commits the result, and tags it. When authorized, pushes to the release branch.

This skill does NOT decide when to release. It executes a release the caller
has already decided to cut.

## Definitions

- **release branch** — the git branch the skill operates on. Default `main`.
  Configurable via `build/config.yaml` `release_branch` key.
- **plugin version** — the SemVer string in `plugin.json` `version` field. The
  unit of release.
- **build** — invocation of `pwsh build/build.ps1`, which crawls the source
  skill tree (per `build/config.yaml`) and writes the dist tree under `skills/`.
- **deny list** — patterns from `build/deny-list.ps1` that must NOT appear in
  the dist `skills/` tree.
- **dry run** — execute every step EXCEPT the final commit/tag/push. Caller
  inspects the planned outcome.
- **release commit** — the single commit produced by this skill, containing the
  bumped `plugin.json`, prepended `CHANGELOG.md`, and regenerated `skills/`.

## Inputs

- `version_bump` — required. One of `patch | minor | major`. Determines how
  `plugin.json`'s `version` is incremented.
- `release_notes` — required. Human-authored summary of what changed since the
  last tag. Becomes the new CHANGELOG entry body.
- `source_root` — optional. Overrides the `source` path configured in
  `build/config.yaml`. Default: read from config.
- `dry_run` — optional boolean. Default false. When true, runs every step
  except commit/tag/push and returns a dry-run report.

## Pre-flight checks

Before making any changes, the skill performs four mandatory checks. All four
must pass. None may be skipped on caller request.

### R1 — Dirty working tree

Check whether the working tree contains uncommitted changes in files other than
`skills/`, `plugin.json`, and `CHANGELOG.md`. If any such files are dirty, stop
immediately with status `dirty_working_tree` and list the offending paths. Do
not proceed.

### R2 — Wrong branch

Confirm that the current git branch matches the configured release branch (from
`build/config.yaml`; default `main`). If the current branch is different, stop
with status `wrong_branch` and surface the current branch name. Do not proceed.

### R3 — Bad config

Confirm that `build/config.yaml` exists and can be parsed. If the file is
missing or unparseable, stop with status `bad_config`. Do not proceed.

### R4 — Bad prior version

Confirm that the most recent git tag's version string parses as valid SemVer. If
it does not, stop with status `bad_prior_version`. Do not proceed.

## Procedure

Once all four pre-flight checks pass, execute the following steps in order.

### Step 1 — Compute new version (R5)

Read the current `version` field from `plugin.json`. Apply the `version_bump`
input strictly per SemVer rules:

- `patch`: increment the patch segment, reset nothing.
- `minor`: increment the minor segment, reset patch to 0.
- `major`: increment the major segment, reset minor and patch to 0.

### Step 2 — Run build (R6)

Invoke `pwsh build/build.ps1`. Wait for exit. If the exit code is not 0, stop
with status `build_failed` and surface the error output.

After the build completes successfully, check whether the deny list validation
pass (run by `build.ps1` via `build/deny-list.ps1`) reports any file matching a
deny pattern in the `skills/` dist tree. If any deny-pattern files are present,
stop with status `build_validation_failed` and list the offending paths.

### Step 3 — Update plugin.json (R7)

Set the `version` field to the new SemVer computed in Step 1. Set the `built`
field to today's UTC date in `YYYY-MM-DD` format.

### Step 4 — Update CHANGELOG.md (R8)

Prepend a new section to `CHANGELOG.md` using the format:

```markdown
## [<new-version>] - <YYYY-MM-DD>

<release_notes>
```

Where `<YYYY-MM-DD>` is today's UTC date. All prior entries are preserved
verbatim below the new section.

### Step 5 — Stage and commit (R9)

Stage exactly these files and directories:

```text
plugin.json
CHANGELOG.md
skills/
```

Use explicit paths. Never use `git add -A`. Then create a commit with message:

```text
release: v<new-version>
```

### Step 6 — Tag (R10)

Create an annotated git tag pointing at the release commit:

```sh
git tag -a v<new-version> -m "v<new-version>"
```

### Step 7 — Dry run check (R11)

If `dry_run` is true, stop here. Return the dry-run report showing what would
have been pushed. Do not push anything.

### Step 8 — Push (R11, R12)

Push the release branch and the new tag:

```sh
git push origin <release-branch>
git push origin v<new-version>
```

Force-push is forbidden (R12). If the push fails due to divergence, stop with
status `push_failed`, surface the git error, and leave the local commit and tag
intact for operator inspection. Do not attempt to resolve divergence
automatically.

## Outputs

On success:

- New commit on the release branch containing: bumped `plugin.json`, prepended
  `CHANGELOG.md`, regenerated `skills/` tree.
- Annotated tag `v<new-version>` pointing at the release commit.
- Status report: previous version, new version, files changed, build report
  (skills count, files included, files denied), push result.

## Bailout conditions

| Status | Trigger | State at stop |
| --- | --- | --- |
| `dirty_working_tree` | R1 fails | No mutations |
| `wrong_branch` | R2 fails | No mutations |
| `bad_config` | R3 fails | No mutations |
| `bad_prior_version` | R4 fails | No mutations |
| `build_failed` | Build exits non-zero | No commit |
| `build_validation_failed` | Deny-pattern file in dist | No commit |
| `push_failed` | Push rejected | Local commit + tag intact |

## Constraints

- Must NOT decide whether to release. Caller decides.
- Must NOT auto-generate `release_notes`. Caller authors prose.
- Must NOT modify `skills/` by hand. Build is source of truth.
- Must NOT bump per-skill versions inside `plugin.json`.
- Must NOT amend or rewrite history of prior commits.
- Must NOT skip pre-flight refusals (R1–R4) on caller request. They are
  mandatory.

## Dependencies

- `build/build.ps1` — exists and exits 0 on success.
- `build/config.yaml` — defines a valid `source` block; optionally a
  `release_branch` key.
- `build/deny-list.ps1` — loaded by `build.ps1`; applied during validation.
- Git working tree is on the configured release branch.
- `pwsh` (PowerShell 7+) on PATH.

## Related

- `build/build.ps1` — generates `skills/` tree.
- `build/deny-list.ps1` — exclusion patterns.
- `plugin.json` — version registry.
- `publish/spec.md` — normative specification.
