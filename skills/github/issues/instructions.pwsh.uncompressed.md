# GH CLI Issues (PowerShell 7+)

## Prerequisites

```powershell
gh auth status 2>&1
```

## Creating an Issue

Write BODY to a temp file — inline string interpolation corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences. Use `WriteAllText` to guarantee UTF-8 encoding without BOM and no shell expansion.

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
```

Invoke the local create tool. `create.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters.

```powershell
$createArgs = @('--owner', $OWNER, '--repo', $REPO, '--title', $TITLE, '--body-file', $bodyFile)
if ($LABELS) { $createArgs += '--label', $LABELS }
$ISSUE_URL = pwsh create.ps1 @createArgs
$CREATE_EXIT = $LASTEXITCODE
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

Exit code semantics from `create.ps1`:

- **0** — created; `$ISSUE_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Commenting on an Issue

Write BODY to a temp file — inline string interpolation corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences. Use `WriteAllText` to guarantee UTF-8 encoding without BOM and no shell expansion.

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
```

Invoke the local comment tool. `comment.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters.

```powershell
$COMMENT_URL = pwsh comment.ps1 `
  --owner $OWNER `
  --repo $REPO `
  --issue $ISSUE_NUMBER `
  --body-file $bodyFile
$COMMENT_EXIT = $LASTEXITCODE
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

Exit code semantics from `comment.ps1`:

- **0** — posted; `$COMMENT_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Editing Issue Metadata

Edit title, labels, assignees, or milestone inline — no body involved:

```powershell
gh issue edit $ISSUE_NUMBER --repo "$OWNER/$REPO" `
  --title "new title" `
  --add-label triage --remove-label stale `
  --add-assignee user1 --remove-assignee user2 `
  --milestone "v2.0"
```

## Editing an Issue Body

`gh issue edit` supports `--body-file` for body replacement. Write BODY to a temp file first:

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
gh issue edit $ISSUE_NUMBER --repo "$OWNER/$REPO" --body-file $bodyFile
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

## Editing a Comment

`gh issue comment` has no `--edit` flag. Use the REST API directly.

First, obtain COMMENT_ID via the paginated list if not already known:

```powershell
gh api --paginate "repos/$OWNER/$REPO/issues/$ISSUE_NUMBER/comments" `
  --jq '.[] | {id, body: .body[:80], author: .user.login}'
```

Write BODY to a temp file before PATCHing:

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
gh api --method PATCH "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID" `
  --field "body=@$bodyFile"
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

## Deleting a Comment

```powershell
gh api --method DELETE "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID"
```

## Viewing an Issue

```powershell
gh issue view $ISSUE_NUMBER --repo "$OWNER/$REPO" --comments
```

## Listing Issues

Default state is open:

```powershell
gh issue list --repo "$OWNER/$REPO" `
  --state all --assignee @me --label bug --milestone "v1.0" --limit 50
```

Search + structured extract:

```powershell
gh issue list --repo "$OWNER/$REPO" `
  --search "is:open label:stale" --json number,title --jq '.[].number'
```

## Closing and Reopening

```powershell
gh issue close $ISSUE_NUMBER --repo "$OWNER/$REPO" --comment "Fixed in #456"
gh issue reopen $ISSUE_NUMBER --repo "$OWNER/$REPO"
```

## Transferring

```powershell
gh issue transfer $ISSUE_NUMBER --repo "$OWNER/$REPO" owner/other-repo
```

## Bulk Operations

```powershell
gh issue list --repo "$OWNER/$REPO" `
  --search "label:stale" --json number --jq '.[].number' |
  ForEach-Object { gh issue close $_ --repo "$OWNER/$REPO" --comment "Closing stale" }
```

