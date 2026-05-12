# GH CLI PR Comments (PowerShell 7+)

## Prerequisites

```powershell
gh auth status 2>&1
```

## Adding a Comment

Write BODY to a temp file — inline string interpolation corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences. Use `WriteAllText` to guarantee UTF-8 encoding without BOM and no shell expansion.

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.Encoding]::UTF8)
```

Invoke the local post tool. `post.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters.

```powershell
$COMMENT_URL = pwsh post.ps1 `
  --owner $OWNER `
  --repo $REPO `
  --pr $PR_NUMBER `
  --body-file $bodyFile
$POST_EXIT = $LASTEXITCODE
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

Exit code semantics from `post.ps1`:

- **0** — posted; `$COMMENT_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Editing a Comment

`gh pr comment` has no `--edit` flag. Use the REST API directly.

First, obtain COMMENT_ID via the paginated list if not already known:

```powershell
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" `
  --jq '.[] | {id, body: .body[:80], author: .user.login}'
```

Write BODY to a temp file before PATCHing:

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.Encoding]::UTF8)
gh api --method PATCH "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID" `
  --field "body=@$bodyFile"
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

## Deleting a Comment

```powershell
gh api --method DELETE "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID"
```

## Listing Comments

`gh pr view --comments` truncates and misses later pages. Use the paginated API for exhaustive results:

```powershell
# General PR (issue) comments — all pages
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments"

# Inline/review comments — all pages
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments"

# Review-level submissions — all pages
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

Use `gh pr view --comments` only for a quick human-readable glance.

## Resolving Review Threads

There is no `gh pr` command for resolving review threads. Use the
`resolveReviewThread` GraphQL mutation via `gh-cli-api`:

```powershell
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```

