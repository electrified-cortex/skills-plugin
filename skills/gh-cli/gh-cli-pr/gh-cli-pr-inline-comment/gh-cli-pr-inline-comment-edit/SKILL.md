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

## When to Use

When a previously posted PR inline review comment needs correction or updating. Prefer editing over deleting when the content can be revised.

## Constraints

- Only the comment author can edit their own comments.
- Large content edits may require JSON body escaping.

## Error Handling

- Comment not found: verify comment ID is correct.
- Permission denied: confirm you are the comment author.
- Parse error: ensure body content is properly escaped.
