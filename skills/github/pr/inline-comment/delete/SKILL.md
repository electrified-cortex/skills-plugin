---
name: delete
description: Delete an existing inline PR review comment by comment ID via GitHub CLI. Triggers - delete inline comment, remove PR comment, delete review comment, delete diff annotation.
---

Input: OWNER, REPO, COMMENT_ID

```bash
gh api --method DELETE repos/{OWNER}/{REPO}/pulls/comments/{COMMENT_ID}
```

Note: endpoint is `/pulls/comments/{id}`, not `/issues/comments/{id}`.

## When to Use

When a previously posted PR inline comment needs to be removed. Prefer editing over deleting if the comment can be revised.

## Constraints

- Only the comment author or a repo admin can delete comments.
- Deletion is permanent — no undo.

## Error Handling

- Comment not found: verify comment ID is correct.
- Permission denied: confirm you are the comment author or an admin.
