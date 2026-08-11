---
name: inline-comment
description: Post, edit, or delete inline code review comments on PR diff lines. Routes to sub-skills by operation. Triggers - inline comment, PR diff comment, comment on code line, annotate diff, inline review comment.
---

| Operation | Sub-skill | Notes |
| --------- | --------- | ----- |
| post | `post/` | Complex: SHA lookup, diff verify, dedup, POST |
| edit | `edit/` | Single PATCH by comment ID |
| delete | `delete/` | Single DELETE by comment ID |

Read the sub-skill SKILL.md for the requested operation and follow it.
