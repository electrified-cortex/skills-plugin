---
name: gh-cli-pr-inline-comment-delete
description: Delete an existing inline PR review comment by comment ID via GitHub CLI. Triggers - delete inline comment, remove PR comment, delete review comment, delete diff annotation.
---

Input: OWNER, REPO, COMMENT_ID

```bash
gh api --method DELETE repos/{OWNER}/{REPO}/pulls/comments/{COMMENT_ID}
```

Note: endpoint is `/pulls/comments/{id}`, not `/issues/comments/{id}`.
