---
created: 2026-05-15
task: 10-0004
status: staged-pending-review
---

# CHANGES.md — gh-cli → github rename

## Rename Map

| Old path | New path |
| --- | --- |
| `gh-cli/` | `github/` |
| `gh-cli/gh-cli-actions/` | `github/actions/` |
| `gh-cli/gh-cli-api/` | `github/api/` |
| `gh-cli/gh-cli-issues/` | `github/issues/` |
| `gh-cli/gh-cli-pr/` | `github/pr/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-comments/` | `github/pr/comments/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-create/` | `github/pr/create/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-file-viewed/` | `github/pr/file-viewed/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-inline-comment/` | `github/pr/inline-comment/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-inline-comment/gh-cli-pr-inline-comment-delete/` | `github/pr/inline-comment/delete/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-inline-comment/gh-cli-pr-inline-comment-edit/` | `github/pr/inline-comment/edit/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-inline-comment/gh-cli-pr-inline-comment-post/` | `github/pr/inline-comment/post/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-merge/` | `github/pr/merge/` |
| `gh-cli/gh-cli-pr/gh-cli-pr-review/` | `github/pr/review/` |
| `gh-cli/gh-cli-projects/` | `github/projects/` |
| `gh-cli/gh-cli-releases/` | `github/release/` |
| `gh-cli/gh-cli-repos/` | `github/repo/` |
| `gh-cli/gh-cli-setup/` | `github/setup/` |

All files inside each folder preserved with git mv; history retained.

## Decisions Made

### 1. Singular vs plural for noun routers

Decision: match `gh` CLI subcommand naming.

- `gh release` → `github/release/` (singular — gh uses "release")
- `gh repo` → `github/repo/` (singular — gh uses "repo")
- `gh-cli-releases` was plural; renamed to `release/` to match `gh release create` etc.
- `gh-cli-repos` was plural; renamed to `repo/` to match `gh repo clone` etc.
- `pr/` kept as abbreviation (no plural ambiguity per spec guidance)
- `issues/` kept as plural (gh uses `gh issue` singular for commands, but "issues" is the conceptual domain; left as-is to match existing)
- `projects/` kept as plural (gh uses `gh project` singular for commands, but `projects/` matches the conceptual domain)

Outstanding question: operator may prefer `issue/` and `project/` for strict gh-verb alignment. See Outstanding Questions below.

### 2. Verb-leaf nesting preferred

Decision: verb-leaf under noun-router. No hyphenated-leaf alternative.

`github/pr/inline-comment/post/` not `github/pr/inline-comment-post/`.

### 3. Root instructions.txt deletion

The `gh-cli/instructions.txt` and `gh-cli/instructions.uncompressed.md` were deleted (git rm).

Pre-deletion check: grep confirmed no caller in any active file depends on
`gh-cli/instructions.txt` directly. The content was a compressed version of
the router routing table — now redundant because `github/SKILL.md` contains
the full routing inline (pure router, no dispatch).

### 4. setup/ survival

`github/setup/` kept as a depth-2 dispatch leaf. Rationale: the setup skill
documents auth, install, and config — it is useful as an explicit pre-check
for agents entering the github router for the first time in a session.
No operator sign-off yet; flagged as outstanding question below.

### 5. Naming convention rule update in skill-writing

The `skill-writing/SKILL.md`, `spec.md`, and `uncompressed.md` referenced
`gh-cli` as the canonical example for fully-qualified sub-skill naming. The
new pattern (pure router → bare child names) is a departure from the old
advice. Updated the prose to reflect the distinction: fully-qualified names
required for independently-discoverable sub-skills; bare names OK under a
pure router that owns routing exclusively.

## Files Changed

### electrified-cortex/skills

- **Renames (git mv):** 105 files
- **Deleted:** 2 (root `instructions.txt`, root `instructions.uncompressed.md`)
- **Content-edited (non-rename):** 7
  - `skill.index` (root) — entry updated
  - `skill.index.md` (root) — entry updated
  - `skill-writing/SKILL.md` — naming convention example updated
  - `skill-writing/spec.md` — naming convention example updated
  - `skill-writing/uncompressed.md` — naming convention example updated
  - `hash-record/hash-record-check/SKILL.md` — glob example updated
  - `hash-record/hash-record-check/check.spec.md` — glob example updated
- **New files:** 1
  - `github/CHANGES.md` (this file)
- **Active tasks updated:** 1
  - `.tasks/40-queued/15-0001-add-plugin-depth-visibility-audit-check.md` — canonical example updated from `gh-cli/SKILL.md` to `github/SKILL.md`

Total unique file changes in skills repo: ~116

### cortex.lan

- **Content-edited:** 2
  - `docs/skill-master-index.md` — plugin path entries updated from `gh-cli` to `github`
  - `tasks/10-drafts/needs-refinement/20-0855-gh-cli-dispatch-skill-upgrades.md` — all skill name references updated to new paths

### electrified-cortex/task-engine

- **0 changes** — single `gh-cli` ref in `.foreman-pod/test-plan.md` is historical narrative ("gh-cli dedup shipped end-to-end"). Classified HISTORICAL, left unchanged.

## Reference Sweep

### Active refs found and updated

| File | Classification | Action |
| --- | --- | --- |
| `skills/.tasks/40-queued/15-0001-add-plugin-depth-visibility-audit-check.md` | ACTIVE_REF | Updated |
| `skills/skill-writing/SKILL.md` | ACTIVE_REF | Updated |
| `skills/skill-writing/spec.md` | ACTIVE_REF | Updated |
| `skills/skill-writing/uncompressed.md` | ACTIVE_REF | Updated |
| `skills/hash-record/hash-record-check/SKILL.md` | ACTIVE_REF | Updated |
| `skills/hash-record/hash-record-check/check.spec.md` | ACTIVE_REF | Updated |
| `skills/skill.index` | ACTIVE_REF | Updated |
| `skills/skill.index.md` | ACTIVE_REF | Updated |
| `cortex.lan/docs/skill-master-index.md` | ACTIVE_REF | Updated |
| `cortex.lan/tasks/10-drafts/needs-refinement/20-0855-gh-cli-dispatch-skill-upgrades.md` | ACTIVE_REF | Updated |

Total active refs updated: 10 files

### Left alone (HISTORICAL/PROSE)

| File | Classification | Reason |
| --- | --- | --- |
| `electrified-cortex/task-engine/.foreman-pod/test-plan.md` | HISTORICAL | "gh-cli dedup shipped end-to-end" — historical event narrative, old name is intrinsic |
| `cortex.lan/docs/architecture/post-verification-dispatcher.md` | PROSE | References `tools/gh-cli/` — the PowerShell script toolkit in cortex.lan/tools/, not the skills. Different artifact. |
| `cortex.lan/tools/gh-cli/SKILL.md` | DIFFERENT_ARTIFACT | The cortex.lan PowerShell toolkit, not the skills repo. Not renamed; different scope. |
| `cortex.lan/logs/session/202604/**` | HISTORICAL | Session logs; old name intrinsic to the narrative |
| `cortex.lan/research/findings.md` | HISTORICAL | Research snapshot; old name intrinsic |
| `cortex.lan/tasks/70-done/**` | HISTORICAL | Per spec: 70-done left unchanged |
| `cortex.lan/tasks/.trash/**` | HISTORICAL | Archived/deleted tasks |
| `.agents/tasks/70-done/**` | HISTORICAL | Per spec: 70-done left unchanged |
| `.agents/tasks/notes/2026-05-04-gh-cli-skill-audit-sweep.md` | HISTORICAL | Audit sweep record; old name intrinsic |
| `.agents/tasks/notes/2026-05-05-skills-plugin-dist-repo-spike.md` | HISTORICAL | Spike note; old name intrinsic |
| `.agents/agents/curator/audit-reports/**` | HISTORICAL | Audit records; old name intrinsic |
| `.agents/agents/curator/notes/2026-05-06-skills-plugin-v0.1.2-publish.md` | HISTORICAL | v0.1.2 was published with old names; historical record |
| `.agents/agents/curator/notes/60-review-triage-2026-05-15.md` | HISTORICAL | Triage note points to audit sweep path (old name) |
| `.agents/tasks/00-ideas/trigger-phrase-sweep-2026-05-05.md` | HISTORICAL | Stale proposals that were already applied; old names intrinsic to the snapshot |
| `.agents/skills/- GitHub/copilot-exhaustion/*.md` | PROSE | References `tools/gh-cli/` — PowerShell scripts, not skills |
| `electrified-cortex/skills/.worktrees/**` | HISTORICAL | Git worktrees; old copies, not active |
| `electrified-cortex/skills/.hash-record/**` | OUT_OF_SCOPE | Per spec exclusion |
| `electrified-cortex/skills-plugin/skills/gh-cli/**` | PENDING_REBUILD | skills-plugin is the published dist snapshot; will be rebuilt separately after merge |

### skills-plugin repo

The `electrified-cortex/skills-plugin/` repo contains a published copy of the
skills with the old `gh-cli/` structure. This is the dist artifact from v0.1.2.
It requires a full plugin rebuild after this rename lands in skills. The rebuild
is a separate step (skill-publishing pipeline). The `cortex.lan/docs/skill-master-index.md`
has been updated to reflect the new paths with a `(pending plugin rebuild)` marker.

## Outstanding Questions

1. **`issues/` vs `issue/`** — gh CLI uses `gh issue` (singular) for commands. Current choice `issues/` matches the conceptual domain noun. Operator may prefer `issue/` for strict verb alignment.

2. **`projects/` vs `project/`** — same concern. `gh project` (singular) vs `projects/` (plural domain noun). Current choice is `projects/`.

3. **setup/ redundancy** — If `github` is a pure router and auth is a workspace prereq, `setup/` may be redundant. Kept for now with no operator sign-off. Operator may want to remove it.

4. **skill-writing naming rule update** — The prose in `skill-writing/SKILL.md`, `spec.md`, and `uncompressed.md` was updated to reflect the new router-bare-child naming pattern. This is a behavioral change to how new skills should be named under router parents. Operator should review this change to ensure it doesn't conflict with other skill-writing guidance.

5. **skills-plugin rebuild** — The published plugin still has old `gh-cli` structure. Plugin rebuild is required after this merge. The skill-auditing 15-0001 task (add plugin-depth-visibility check) now uses `github/SKILL.md` as the canonical positive example per the update.

## Verification

Phase 9 zero-hit check result (run after all edits):

```
rg "gh-cli" electrified-cortex/skills/ --hidden --glob '!**/.git/**' --glob '!**/.hash-record/**' --glob '!**/70-done/**' --glob '!**/icebox/**' --glob '!**/.worktrees/**' (excluding .tasks/10-drafts/10-0004 task spec)
```

Result: **ZERO HITS** in active files.

Spot-check (3 random leaf SKILL.md files):

| File | `name:` field | Matches folder | Classification |
| --- | --- | --- | --- |
| `github/pr/inline-comment/post/SKILL.md` | `post` | yes | DISPATCH |
| `github/release/SKILL.md` | `release` | yes | DISPATCH |
| `github/pr/review/SKILL.md` | `review` | yes | DISPATCH |

git log SHA at start: `275bccb`
git log SHA at end: `275bccb` (no commits made)
