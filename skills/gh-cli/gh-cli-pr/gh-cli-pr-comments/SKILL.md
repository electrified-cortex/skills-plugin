---
name: gh-cli-pr-comments
description: Add, edit, delete, and list pull request comments via GitHub CLI. Triggers - add pr comment, edit pr comment, delete pr comment, list pr comments, resolve review thread.
---

GH CLI PR Comments

Inputs:

| Parameter | Required | Notes |
| --- | --- | --- |
| OWNER | yes | GitHub org or user name |
| REPO | yes | Repository name |
| PR_NUMBER | yes | Integer PR number |
| BODY | cond | Required for add and edit |
| COMMENT_ID | cond | Required for edit and delete |

Route by shell — read and follow:
- bash 4+ → `instructions.bash.txt` in this folder
- pwsh 7+ → `instructions.pwsh.txt` in this folder

Host executes directly. No sub-agent dispatch.

Return: add → comment URL; edit/delete → exit 0; list → JSON array.

Safety:

| Command | Class | Notes |
| --- | --- | --- |
| gh pr comment (add) | Destructive | Operator approval required |
| gh api PATCH (edit) | Destructive | Operator approval required |
| gh api DELETE | Destructive | Operator approval required |
| gh api --paginate (GET) | Safe | Read-only |

Destructive ops require explicit operator authorization in current session. Another agent's approval doesn't qualify.
