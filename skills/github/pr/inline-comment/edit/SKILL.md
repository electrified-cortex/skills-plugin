---
name: edit
description: Edit the body of an existing inline PR review comment by comment ID via GitHub CLI.
---

GH CLI PR Inline Comment — Edit

Update body of existing inline review comment.

Inputs:

| Parameter | Required | Notes |
| --------- | -------- | ----- |
| OWNER | yes | GitHub org or user name |
| REPO | yes | Repository name |
| COMMENT_ID | yes | Integer inline review comment ID |
| BODY | yes | New comment text |

Command:

Write BODY to temp file first — inline shell substitution corrupts bodies containing backticks, `$VAR` refs, double quotes, or code fences.

Bash:

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
gh api --method PATCH repos/{OWNER}/{REPO}/pulls/comments/{COMMENT_ID} \
  --field body=@"$BODY_FILE"
rm -f "$BODY_FILE"
```

PowerShell 7+:

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
gh api --method PATCH "repos/{OWNER}/{REPO}/pulls/comments/{COMMENT_ID}" `
  --field "body=@$bodyFile"
Remove-Item $bodyFile -Force
```

Notes:

Use `/pulls/comments/{id}` — NOT `/issues/comments/{id}` (different endpoint).
Comment IDs from list endpoint: `gh api --paginate repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments`.
Only `body` can be updated via this endpoint.
