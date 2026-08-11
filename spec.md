# skills-plugin — Repository Specification

## Purpose

skills-plugin is a Claude Code plugin that distributes the
[electrified-cortex/skills](https://github.com/electrified-cortex/skills) library
as a pre-built, ready-to-reference file tree. Consumers add this repo as a git
submodule (or install it via the plugin marketplace) and reference skills directly
from the distributed `skills/` output — no build step is required on the consumer
side.

The repo contains the compiled `skills/` output produced by running
`tools/publish.ps1` against the electrified-cortex/skills source repo. The build
is run by maintainers at release time; consumers receive the finished result.

## Inputs to the Build

The build pipeline is inlined in `tools/publish.ps1` and accepts the following
inputs.

### Source root

The build reads skills from the electrified-cortex/skills source repo. By default
the source resolves to the sibling checkout `../skills`; the `-Source` parameter
overrides it. The build refuses to run if the source tree has uncommitted changes
outside ignored or dot-prefixed directories, and it records the source HEAD commit
SHA in the release tag and manifest as provenance.

### Publish ignore list

The source repo carries a `.publish-ignore` file at its root listing top-level
directories that must never enter the dist. The file is required — a missing
ignore file fails the build rather than degrading to publish-everything. The same
list is honored by the validation gate (`build/pre-publish-check.sh`).

### Deny list

Files matching any deny-list rule are excluded from the `skills/` output. The deny
list is defined in `build/deny-list.ps1` and covers the following categories:

**Exact filename matches (never shipped):**

- `spec.md`
- `uncompressed.md`
- `instructions.uncompressed.md`
- `instructions.uncompressed.md.compressed`
- `eval.md`
- `PLAN.md`
- `RESULTS.md`
- `CHANGES.md`

**Wildcard patterns:**

- `*.spec.md` — all companion spec files
- `*.sha256` — all SHA checksum files
- `*.uncompressed.md` — all uncompressed companions

**Structural exclusions:**

- Any file inside a dot-prefixed directory (e.g., `.git/`, `.agents/`) is skipped.
- Any directory component that starts with `.` causes the entire subtree to be skipped.

### Validation gate

`build/pre-publish-check.sh` runs before any version bump. It blocks on UTF-8
BOMs, unparseable or incomplete SKILL.md frontmatter, and missing `## Inheritance`
sections in domain-flavor skills; it warns on dead relative directory references.
It honors `.publish-ignore` and refuses to report PASS if it examined zero files.

### Discovery target

The crawler identifies skill folders by looking for `SKILL.md` at the top
level of each directory. Only directories containing a `SKILL.md` are included
in the output.

## Outputs

A successful build produces the following:

### `skills/` tree

One subdirectory per discovered skill folder, mirroring the source layout:

```text
skills/<name>/SKILL.md
skills/<name>/<other files not denied>
```

All non-denied files in each skill folder are copied. Backtick file references in
a skill's markdown are resolved and pulled in when they point at real files —
containment-checked to the source root and subject to the deny and ignore lists.
After the copy, the build asserts that no denied file and no ignored top-level
name appears anywhere in the dist.

### Index files

`skill.index` and `skill.index.md` files are preserved wherever they appear in the
source. These files enable skill discovery and are never denied.

### `plugin.json`

Carries the plugin version as a single SemVer string under the `version` key. The
`built` field records the date of the last successful build run.

### Release notes

This repo carries no CHANGELOG file. Release notes live in the annotated release
tag body, together with the source commit SHA the release was built from.

## Contracts

The following invariants are non-negotiable. Any change that violates them is a
breaking change and requires explicit operator sign-off.

### 1. `skills/` is build output — never edited by hand

All changes to skills flow from the electrified-cortex/skills source repo through
the build pipeline. Manually editing files under `skills/` is prohibited. If a skill
needs fixing, fix it upstream and re-run the build.

### 2. The plugin is a single SemVer release

The `version` field in `plugin.json` is the unit of release. Every file in a given
release carries the same plugin version. There is no per-skill versioning that
consumers can pin.

### 3. Per-skill version markers are cache busters only

If individual skills contain internal version comments or markers, those are
informational only. Consumers must pin the plugin version (i.e., the git tag or
submodule commit), not any per-skill marker.

### 4. `publish/` lives at repo root as a sibling to `skills/`

The `publish/` directory contains the meta-skill for versioning, tagging, and
pushing releases. It is infrastructure for maintainers, not a distributable
skill. It must never be nested inside `skills/` and must never appear in the
distributed output.

### 5. Spec and audit artifacts never ship

`spec.md`, all `*.spec.md` files, `uncompressed.md`, audit reports, eval files,
and similar development artifacts are excluded by the deny list and must never
appear anywhere under `skills/`. These files are for maintainers only.

### 6. `skill.index` and `skill.index.md` always ship

Index files are discovery aids and are always included in the output whenever they
are present in the source. They must never be added to the deny list.

## Out of Scope

The following are explicitly outside the scope of this repository:

- **Consumer-side build step.** Consumers reference the pre-built `skills/` tree
  directly. They do not run the publish pipeline.
- **Per-skill release tagging.** The plugin is released as a unit. Individual skills
  do not receive their own git tags.
- **Modifications to the upstream source.** Fixing or refactoring skills in the
  electrified-cortex/skills source repo is out of scope here.
- **Automated tests.** No test suite exists at this time.

## Dependencies

- **electrified-cortex/skills** — the canonical source of skill content. The build
  reads from this repo.
- **PowerShell 7+ (`pwsh`)** — required to run `tools/publish.ps1`.
- **bash** (Git-for-Windows bash is auto-detected) — required by the validation
  gate `build/pre-publish-check.sh`.
- **Claude Code** — the consumer-side runtime that invokes skills referenced from
  the distributed `skills/` tree.
- **`git`** — used for version control, submodule consumption, and release tagging.

## Branch Flow

- **`main`** — stable, release-tagged branch.
- **Feature branches** — pushed to `origin/<branch>`, PR to `origin/main`.
- **Release tags** — format `v<version>` matching `plugin.json` version (e.g.,
  `v0.8.0`). Applied to the release commit on `main` after a successful publish run.
