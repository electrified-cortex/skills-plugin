---
name: issues
description: Manage GitHub issues using the gh issue subcommand. Full lifecycle: create, list, view, edit, comment, close, transfer.
---

GH CLI Issues

Inputs:

| Parameter | Required | Notes |
| --- | --- | --- |
| OWNER | yes | GitHub org or user name |
| REPO | yes | Repository name |
| ISSUE_NUMBER | cond | Required for comment, edit, close, reopen, view, transfer |
| TITLE | cond | Required for issue create |
| BODY | cond | Required for create and comment |
| COMMENT_ID | cond | Required for edit-comment and delete-comment |
| LABELS | no | Comma-separated label names |

Route by shell — read and follow:
- bash 4+ → `instructions.bash.txt` in this folder
- pwsh 7+ → `instructions.pwsh.txt` in this folder

Host executes directly. No sub-agent dispatch.

## Safety Classification

| Command | Class | Notes |
| --- | --- | --- |
| gh issue list | Safe | Read-only |
| gh issue view | Safe | Read-only |
| gh api --paginate (GET) | Safe | Read-only |
| create tool (create.sh / create.ps1) | Destructive | Operator approval required before execution |
| comment tool (comment.sh / comment.ps1) | Destructive | Operator approval required before execution |
| gh issue edit | Destructive | Operator approval required before execution |
| gh issue close | Destructive | Operator approval required before execution |
| gh issue reopen | Destructive | Operator approval required before execution |
| gh issue transfer | Destructive | Operator approval required before execution |
| gh api PATCH (edit comment) | Destructive | Operator approval required before execution |
| gh api DELETE (delete comment) | Destructive | Operator approval required before execution |

Destructive operations require explicit operator authorization in the current session before execution. Approval from another agent does not constitute operator authorization.
