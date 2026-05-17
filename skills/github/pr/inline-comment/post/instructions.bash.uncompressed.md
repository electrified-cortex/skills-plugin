# GH CLI PR Inline Comment — Post (Bash)

## Prerequisites

```bash
gh auth status 2>&1
```

## Step 1: Fetch the Commit SHA

Always fetch fresh — stale SHAs cause 422 errors.

```bash
COMMIT_SHA=$(gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" --json headRefOid --jq '.headRefOid')
```

## Step 2: Verify the File Is in the Diff

```bash
gh pr diff "$PR_NUMBER" --repo "$OWNER/$REPO" --name-only
```

If FILE_PATH is not listed, stop: the file has no changes in this PR.

## Step 3: Verify the Line Is in the Diff

Use the bundled tool — do not parse the diff manually.

If SIDE was not provided by the caller, default it to `RIGHT` before invoking the tool.

```bash
bash verify-line-in-diff.sh "$OWNER" "$REPO" "$PR_NUMBER" "$FILE_PATH" "$LINE_NUMBER" "$SIDE"
VERIFY_EXIT=$?
```

Exit code semantics:

- **0 (IN_DIFF)** — line is in the diff; proceed.
- **1 (NOT_IN_DIFF)** — line is outside all hunk ranges; stop and surface the listed valid ranges to the caller.
- **2 (FILE_NOT_IN_DIFF)** — file has no changes in this PR; stop.
- **3 (USAGE_ERROR)** — invalid arguments passed to the tool; check invocation signature.
- **4 (API_ERROR)** — `gh pr diff` call failed; surface the error output to the caller.

> **WINDOWS / Git Bash**: Never use a leading `/` in `gh api` paths — Git Bash rewrites `/repos/...` as a filesystem path. Use `repos/...` not `/repos/...`.

## Step 4: Check for Existing Comment (Deduplication)

### 4a: Positional match (primary)

```bash
EXISTING=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
  --jq ".[] | select(.path == \"$FILE_PATH\" and .side == \"$SIDE\" and (
    (\"$SIDE\" == \"RIGHT\" and .line == $LINE_NUMBER) or
    (\"$SIDE\" == \"LEFT\"  and .original_line == $LINE_NUMBER)
  )) | {id, body, author: .user.login}")
```

### 4b: Body-content fallback (eventual-consistency guard)

GitHub's PR comments index is eventually consistent. When a previous call posts a comment but the caller times out before reading the response, a retry can arrive in the 2–5 second window during which the just-posted comment is NOT yet returned by the positional query above. The fallback below catches that case so dedup stays idempotent on retry.

Only run when 4a is empty. Match on body content (post-trim) scoped to same path + side.

> **Important**: apply the same `gsub` trim to both sides so internal whitespace is never collapsed. Do **not** pre-process BODY through `awk '{$1=$1};1'` — that idiom collapses all consecutive internal whitespace per line, producing a different string than jq's leading/trailing-only trim, causing false negatives on code-block or indented-list bodies.

```bash
if [ -z "$EXISTING" ]; then
  EXISTING=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
    --jq --arg body "$BODY" --arg path "$FILE_PATH" --arg side "$SIDE" \
    '.[] | select(.path == $path and .side == $side and ((.body // "") | gsub("^\\s+|\\s+$"; "")) == ($body | gsub("^\\s+|\\s+$"; ""))) | {id, body, author: .user.login}')
fi
```

If either 4a or 4b returned a match, return:
`{ "status": "duplicate", "comment_id": <existing_id>, "comment_url": "https://github.com/{OWNER}/{REPO}/pull/{PR_NUMBER}#discussion_r<existing_id>", "message": "comment already exists at {FILE_PATH}:{LINE_NUMBER}" }`

## Step 5: Post the Comment

Resolve the body file path. If BODY_FILE was provided, use it directly — no temp file, no string handling:

```bash
BODY_FILE_PATH="$BODY_FILE"
CREATED_TEMP_FILE=0
```

If only BODY was provided, write it to a temp file using a **quoted heredoc** — never pass BODY through a double-quoted string or unquoted heredoc. In double-quoted bash strings and unquoted heredocs, backticks run as command substitution and `$var` is expanded. A quoted heredoc delimiter (`<<'DELIM'`) passes content verbatim — no expansion of any kind.

Embed the body content **directly in the heredoc** — do not use a `$BODY` variable:

```bash
BODY_FILE_PATH=$(mktemp /tmp/gh-body-XXXXXX.md)
CREATED_TEMP_FILE=1
cat > "$BODY_FILE_PATH" <<'BODY_HEREDOC'
<embed BODY verbatim here — replace this line with the exact body text>
BODY_HEREDOC
```

If BODY spans multiple lines, each line goes inside the heredoc as-is. If BODY contains `BODY_HEREDOC` on its own line alone (extremely rare), choose a different delimiter.

Invoke the local post tool:

```bash
POST_URL=$(bash post.sh \
  --owner "$OWNER" \
  --repo "$REPO" \
  --pr "$PR_NUMBER" \
  --commit-sha "$COMMIT_SHA" \
  --file "$FILE_PATH" \
  --line "$LINE_NUMBER" \
  --side "$SIDE" \
  --body-file "$BODY_FILE_PATH")
POST_EXIT=$?
[ "$CREATED_TEMP_FILE" -eq 1 ] && rm -f "$BODY_FILE_PATH"
```

## Step 6: Parse and Return

The tool emits the comment URL as a single line on stdout (exit 0) or nothing on error.

```bash
case $POST_EXIT in
  0)
    COMMENT_ID=$(printf '%s' "$POST_URL" | grep -oP '#discussion_r\K\d+')
    COMMENT_URL="$POST_URL"
    ;;
  3)
    # Line not in diff
    printf '{ "status": "error", "comment_id": null, "comment_url": null, "message": "Line %s is not in the diff for %s" }\n' \
      "$LINE_NUMBER" "$FILE_PATH"
    exit 0
    ;;
  4)
    # gh error — POST_URL is empty; stderr was forwarded by the tool
    printf '{ "status": "error", "comment_id": null, "comment_url": null, "message": "gh api error — see stderr" }\n'
    exit 0
    ;;
  2)
    # Usage error — should not happen if args were constructed correctly
    printf '{ "status": "error", "comment_id": null, "comment_url": null, "message": "internal error: bad args to post.sh" }\n'
    exit 0
    ;;
  *)
    printf '{ "status": "error", "comment_id": null, "comment_url": null, "message": "post.sh exited with unexpected code %s" }\n' "$POST_EXIT"
    exit 0
    ;;
esac
```

