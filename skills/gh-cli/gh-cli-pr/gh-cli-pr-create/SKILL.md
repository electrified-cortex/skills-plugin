---
name: gh-cli-pr-create
description: Open pull request via GitHub CLI. Triggers - create pull request, open PR, submit PR, new pull request, open a pull request.
---

Before Creating:
Check for existing open PR on current branch:

```bash
gh pr list --head $(git branch --show-current)
```

If PR exists, edit or view — don't create duplicate.

Creating:
PR with title, body, base branch:

```bash
gh pr create --title "title" --body "body" --base main
```

PR with full metadata — reviewers, assignee, labels, draft:

```bash
gh pr create --title "title" --body-file .github/PULL_REQUEST_TEMPLATE.md \
  --reviewer user1,user2 --assignee @me --label enhancement --draft
```

Closing Issue:
Include closing keyword in PR body to auto-close linked issue on merge:

```bash
# In the --body value or --body-file content:
Closes #123
```

Promote Draft:
PR ready for review — promote:

```bash
gh pr ready 123
```

Edit Metadata:
Add/remove reviewers, labels after PR is open:

```bash
gh pr edit 123 --add-reviewer user3 --add-label bug --remove-label wip
```

## Inputs

- `base_branch` — target branch for the PR (default: repo default branch).
- `head_branch` — source branch.
- `title` — PR title.
- `body` — optional PR description.

## Dependencies

- `gh-cli-setup/SKILL.md` — required pre-check: auth + CLI installed

## Error Handling

- Auth failure: re-run `gh-cli-setup`.
- Branch not found: verify branch names.
- Duplicate PR: a PR from this branch already exists.

## Scope

Covers `gh pr create`, `gh pr ready`, `gh pr edit`. Doesn't cover branch creation or `git push` — branch must exist on remote first. Reviewing and merging → respective sub-skills.
