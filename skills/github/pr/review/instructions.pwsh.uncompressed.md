# GH CLI PR Review (PowerShell 7+)

## Prerequisites

```powershell
gh auth status 2>&1
```

## Submitting a Review

Invoke the local review tool. `review.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters. Body file is passed by path — this tool never reads body content.

```powershell
$reviewArgs = @(
  '--owner', $OWNER,
  '--repo',  $REPO,
  '--pr',    $PR_NUMBER,
  '--decision', $DECISION
)

if ($BODY_FILE) {
  $reviewArgs += '--body-file', $BODY_FILE
}

if ($REVIEW_ID) {
  $reviewArgs += '--review-id', $REVIEW_ID
}

$PR_URL = pwsh review.ps1 @reviewArgs
$REVIEW_EXIT = $LASTEXITCODE
```

Exit code semantics from `review.ps1`:

- **0** — submitted; `$PR_URL` holds the PR URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Getting the Review ID (for dismiss)

```powershell
gh pr view $PR_NUMBER --repo "$OWNER/$REPO" --json reviews `
  --jq '.reviews[] | {id, author: .author.login, state}'
```

## Listing Reviews

```powershell
# Review-level submissions — all pages
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

## Resolving Review Threads

There is no `gh pr` command for resolving review threads. Use the
`resolveReviewThread` GraphQL mutation via `api`:

```powershell
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```
