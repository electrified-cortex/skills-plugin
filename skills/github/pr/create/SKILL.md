---
name: create
description: Open a pull request via GitHub CLI. Triggers - create pr, open pull request, submit pr, create draft pr.
---

GH CLI PR Create

Inputs:

| Parameter | Required | Notes |
| --- | --- | --- |
| OWNER | yes | GitHub org or user name |
| REPO | yes | Repository name |
| BASE | yes | Base branch name (e.g., `main`) |
| TITLE | yes | PR title |
| BODY | yes | PR body markdown; written to temp file before use |
| LABEL | no | Comma-separated label names |
| DRAFT | no | Any non-empty value enables `--draft` |

Route by shell — read and follow:
- bash 4+ → `instructions.bash.txt` in this folder
- pwsh 7+ → `instructions.pwsh.txt` in this folder

Host executes directly. No sub-agent dispatch.

Return: create → PR URL; list → table or JSON; promote/edit → exit 0.

## Safety Classification

| Command | Class | Notes |
| --- | --- | --- |
| gh pr create | Destructive | Operator approval required before execution |
| gh pr ready | Destructive | Operator approval required before execution |
| gh pr edit | Destructive | Operator approval required before execution |
| gh pr list (GET) | Safe | Read-only |

Destructive operations require explicit operator authorization in the current session before execution. Approval from another agent does not constitute operator authorization.
