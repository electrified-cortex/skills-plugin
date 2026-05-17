# GH CLI PR Inline Comment — Post (PowerShell 7+)

## Prerequisites

```powershell
gh auth status 2>&1
```

## Step 1: Fetch the Commit SHA

Always fetch fresh — stale SHAs cause 422 errors.

```powershell
$COMMIT_SHA = gh pr view $PR_NUMBER --repo "$OWNER/$REPO" --json headRefOid --jq '.headRefOid'
```

## Step 2: Verify the File Is in the Diff

```powershell
gh pr diff $PR_NUMBER --repo "$OWNER/$REPO" --name-only
```

If FILE_PATH is not listed, stop: the file has no changes in this PR.

## Step 3: Verify the Line Is in the Diff

Use the bundled tool — do not parse the diff manually.

If SIDE was not provided by the caller, default it to `RIGHT` before invoking the tool.

```powershell
$verifyOutput = pwsh verify-line-in-diff.ps1 -owner $OWNER -repo $REPO -pr_number $PR_NUMBER -file_path $FILE_PATH -line_number $LINE_NUMBER -side $SIDE
$VERIFY_EXIT = $LASTEXITCODE
```

Exit code semantics:

- **0 (IN_DIFF)** — line is in the diff; proceed.
- **1 (NOT_IN_DIFF)** — line is outside all hunk ranges; stop and surface the listed valid ranges to the caller.
- **2 (FILE_NOT_IN_DIFF)** — file has no changes in this PR; stop.
- **3 (USAGE_ERROR)** — invalid arguments passed to the tool; check invocation signature.
- **4 (API_ERROR)** — `gh pr diff` call failed; surface the error output to the caller.

> **WINDOWS**: Never use a leading `/` in `gh api` paths — PowerShell on Windows does not rewrite paths like Git Bash, but bare `gh api` calls still require `repos/...` not `/repos/...` for consistency and portability.

## Step 4: Check for Existing Comment (Deduplication)

### 4a: Positional match (primary)

```powershell
$existing = gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" `
  --jq ".[] | select(.path == \`"$FILE_PATH\`" and .side == \`"$SIDE\`" and (
    (\`"$SIDE\`" == \`"RIGHT\`" and .line == $LINE_NUMBER) or
    (\`"$SIDE\`" == \`"LEFT\`"  and .original_line == $LINE_NUMBER)
  )) | {id, body, author: .user.login}"
```

### 4b: Body-content fallback (eventual-consistency guard)

GitHub's PR comments index is eventually consistent. When a previous call posts a comment but the caller times out before reading the response, a retry can arrive in the 2–5 second window during which the just-posted comment is NOT yet returned by the positional query above. The fallback below catches that case so dedup stays idempotent on retry.

Only run when 4a is empty. Match on body content (post-trim) scoped to same path + side.

```powershell
if ([string]::IsNullOrWhiteSpace($existing)) {
  $bodyTrimmed = $BODY.Trim()
  $allComments = gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" | ConvertFrom-Json
  $existing = $allComments |
    Where-Object { $_.path -eq $FILE_PATH -and $_.side -eq $SIDE -and ($_.body ?? '').Trim() -eq $bodyTrimmed } |
    Select-Object -First 1 |
    ForEach-Object { [pscustomobject]@{ id = $_.id; body = $_.body; author = $_.user.login } } |
    ConvertTo-Json -Compress
}
```

If either 4a or 4b returned a match, return:
`{ "status": "duplicate", "comment_id": <existing_id>, "comment_url": "https://github.com/{OWNER}/{REPO}/pull/{PR_NUMBER}#discussion_r<existing_id>", "message": "comment already exists at {FILE_PATH}:{LINE_NUMBER}" }`

## Step 5: Post the Comment

Write BODY to a temp file — inline string interpolation corrupts bodies that contain backticks, `$VAR` references, double quotes, or code fences. Use `WriteAllText` to guarantee UTF-8 encoding without BOM and no shell expansion.

```powershell
$bodyFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($bodyFile, $BODY, [System.Text.UTF8Encoding]::new($false))
```

Invoke the local post tool. `post.ps1` uses kebab-case flags parsed manually — pass them as double-dash flags, not PowerShell-style parameters.

```powershell
$POST_URL = pwsh post.ps1 `
  --owner $OWNER `
  --repo $REPO `
  --pr $PR_NUMBER `
  --commit-sha $COMMIT_SHA `
  --file $FILE_PATH `
  --line $LINE_NUMBER `
  --side $SIDE `
  --body-file $bodyFile
$POST_EXIT = $LASTEXITCODE
Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
```

## Step 6: Parse and Return

The tool emits the comment URL as a single line on stdout (exit 0) or nothing on error.

```powershell
switch ($POST_EXIT) {
  0 {
    $COMMENT_URL = $POST_URL.Trim()
    if ($COMMENT_URL -match '#discussion_r(\d+)') {
      $COMMENT_ID = $Matches[1]
    }
  }
  3 {
    # Line not in diff
    Write-Output "{ `"status`": `"error`", `"comment_id`": null, `"comment_url`": null, `"message`": `"Line $LINE_NUMBER is not in the diff for $FILE_PATH`" }"
    exit 0
  }
  4 {
    # gh error — stderr was forwarded by the tool
    Write-Output '{ "status": "error", "comment_id": null, "comment_url": null, "message": "gh api error — see stderr" }'
    exit 0
  }
  2 {
    # Usage error — should not happen if args were constructed correctly
    Write-Output '{ "status": "error", "comment_id": null, "comment_url": null, "message": "internal error: bad args to post.ps1" }'
    exit 0
  }
  default {
    Write-Output ('{ "status": "error", "comment_id": null, "comment_url": null, "message": "post.ps1 exited with unexpected code ' + $POST_EXIT + '" }')
    exit 0
  }
}
```

