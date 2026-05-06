---
name: gh-cli-pr-merge
description: Merge, update, revert, close pull request via GitHub CLI. Triggers - merge PR, merge pull request, close PR, revert PR, squash merge, rebase merge.
---

Finalize PRs via `gh pr merge`, `gh pr update-branch`, `gh pr revert`. Covers merging, branch sync, revert, close.

Merging:
Choose strategy matching repo policy:

```bash
gh pr merge 123 --merge --delete-branch    # merge commit — full history
gh pr merge 123 --squash --delete-branch   # squash — single commit
gh pr merge 123 --rebase                   # rebase — replay on base
```

`--delete-branch` removes source branch after merge.

Branch Update:
PR branch behind base:

```bash
gh pr update-branch 123
gh pr update-branch 123 --force    # force if conflicts — may overwrite local changes
```

Revert:
Opens new revert PR undoing changes from merged PR:

```bash
gh pr revert 123 --branch revert-pr-123
```

Close Without Merge:

```bash
gh pr close 123 --comment "Superseded by #456"
```

Pre-Merge Readiness:
CI check: `gh pr checks 123` — covered by `gh-cli-prs` inspection skill, not this one.

Scope:
Covers `gh pr merge`, `gh pr update-branch`, `gh pr revert`, `gh pr close`. Doesn't cover PR review before merge (see `gh-cli-prs-review`) or git ops post-merge.

## Dependencies

- gh-cli-setup/SKILL.md — required pre-check: auth + CLI installed

## Error Handling

- Auth failure: re-run gh-cli-setup.
- Merge conflict: resolve conflicts before merging.
- Required checks failing: wait for CI or use --admin flag only if authorized.
- Permission denied: confirm merge rights.
