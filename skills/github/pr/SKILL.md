---
name: pr
description: Pull request router — routes to sub-skills for create, review, comments, inline-comment, merge, file-viewed operations. Handles read-only inspection inline. Triggers - manage pull request, PR status, view PR, list PRs, pull request operations, check PR.
---

Routes PR write operations to sub-skills. Runs read-only inspection commands directly.

Read-only Inspection:

```bash
gh pr list --state open --author @me --json number,title,headRefName
gh pr view 123 --comments
gh pr diff 123
gh pr checks 123 --watch
gh pr status
```

Sub-skills:

| Sub-skill | Handles |
| --- | --- |
| create/ | Open PRs, convert drafts to ready |
| review/ | Approve, request changes, dismiss reviews |
| comments/ | Add, edit, delete general PR comments |
| inline-comment/ | Post, edit, delete inline diff comments (router) |
| merge/ | Merge, update branch, revert, close |
| file-viewed/ | Mark or unmark files as viewed (single, multiple, or all) |

**Comment routing:** No FILE_PATH / LINE_NUMBER → `comments/`. Anchored to a diff line → `inline-comment/`.

Notes:
Use `--repo owner/name` when not in local clone of target repo.
`gh pr checks --watch` blocks until CI completes.
Covers `gh pr` commands only. Git ops, branch protection, CODEOWNERS out of scope.

Related: `create`, `review`, `comments`, `inline-comment`, `merge`, `file-viewed`
