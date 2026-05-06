---
name: gh-cli-pr-inline-comment-edit
description: Edit the body of an existing inline PR review comment by comment ID via GitHub CLI. Triggers - edit inline comment, update PR comment, modify review comment, change diff annotation.
---

Input: OWNER, REPO, COMMENT_ID, BODY

```bash
gh api --method PATCH repos/{OWNER}/{REPO}/pulls/comments/{COMMENT_ID} \
  --field body="{BODY}"
```

Note: endpoint is `/pulls/comments/{id}`, not `/issues/comments/{id}`.
