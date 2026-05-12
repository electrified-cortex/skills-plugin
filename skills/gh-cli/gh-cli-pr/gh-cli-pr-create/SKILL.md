---
name: gh-cli-pr-create
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

Safety:

| Command | Class | Notes |
| --- | --- | --- |
| gh pr create | Destructive | Operator approval required |
| gh pr ready | Destructive | Operator approval required |
| gh pr edit | Destructive | Operator approval required |
| gh pr list (GET) | Safe | Read-only |

Destructive ops require explicit operator authorization in current session. Another agent's approval doesn't qualify.
