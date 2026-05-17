# GH CLI PR Create (PowerShell 7+)

## Prerequisites

```powershell
gh auth status 2>&1
```

## Check for Existing PR

Before creating, confirm no open PR exists for the current branch:

```powershell
$currentBranch = git branch --show-current
gh pr list --repo "$OWNER/$REPO" --head $currentBranch --json number,url
```

If an open PR is returned, report it to the caller and stop — do not create a duplicate.

## Creating a Pull Request

Write BODY to a temp file — inline string interpolation corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences. Use `WriteAllText` to guarantee UTF-8 encoding without BOM and no shell expansion.

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
```

Invoke the local create tool. `create.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters.

```powershell
$createArgs = @(
    '--owner', $OWNER,
    '--repo',  $REPO,
    '--base',  $BASE,
    '--title', $TITLE,
    '--body-file', $bodyFile
)
if ($LABEL) { $createArgs += '--label', $LABEL }
if ($DRAFT) { $createArgs += '--draft' }

$PR_URL = pwsh create.ps1 @createArgs
$CREATE_EXIT = $LASTEXITCODE
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

Exit code semantics from `create.ps1`:

- **0** — created; `$PR_URL` holds the PR URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Listing Existing PRs

Check open PRs for the repository:

```powershell
gh pr list --repo "$OWNER/$REPO" --state open
```

Filter by branch:

```powershell
$currentBranch = git branch --show-current
gh pr list --repo "$OWNER/$REPO" --head $currentBranch
```

## Promoting a Draft to Ready

When the PR is ready for review, promote it using the PR number:

```powershell
gh pr ready $PR_NUMBER --repo "$OWNER/$REPO"
```

## Editing Metadata After Creation

Add reviewers, labels, or remove labels after the PR is open:

```powershell
gh pr edit $PR_NUMBER --repo "$OWNER/$REPO" `
  --add-reviewer user3 --add-label bug --remove-label wip
```

