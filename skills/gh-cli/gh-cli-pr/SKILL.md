---
name: gh-cli-pr
description: Entry point for pull request management via the GitHub CLI. Handles common PR inspection and routes write operations to sub-skills. Triggers - manage pull request, PR status, view PR, list PRs, pull request operations, check PR.
---

When to Use:
Inspect PRs (list, view, diff, check status) or auto-route write ops. Know sub-skill → dispatch directly.

Inspection Commands:
List open PRs by you:

```bash
gh pr list --state open --author @me --json number,title,headRefName
```

View PR with comments:

```bash
gh pr view 123 --comments
```

Show PR diff:

```bash
gh pr diff 123
```

Watch CI until complete:

```bash
gh pr checks 123 --watch
```

PR status summary:

```bash
gh pr status
```

Sub-skills:

| Sub-skill | Handles |
| --- | --- |
| gh-cli-pr-create/ | Open PRs, convert drafts to ready |
| gh-cli-pr-review/ | Approve, request changes, dismiss reviews |
| gh-cli-pr-comments/ | Add, edit, delete general PR comments |
| gh-cli-pr-inline-comments/ | Post, edit, delete inline diff comments |
| gh-cli-pr-merge/ | Merge, update branch, revert, close |
| gh-cli-pr-file-viewed/ | Mark or unmark files as viewed (single, multiple, or all) |

Notes:
Use `--repo owner/name` when not in local clone of target repo.
`gh pr checks --watch` blocks until CI completes.
Covers `gh pr` commands only. Git ops, branch protection, CODEOWNERS out of scope.

Related: `gh-cli-pr-create`, `gh-cli-pr-review`, `gh-cli-pr-comments`, `gh-cli-pr-merge`
