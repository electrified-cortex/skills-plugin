# GH CLI PR Comments (Bash)

## Prerequisites

```bash
gh auth status 2>&1
```

## Adding a Comment

Write BODY to a temp file — inline shell substitution corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences.

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
```

Invoke the local post tool:

```bash
COMMENT_URL=$(bash post.sh \
  --owner "$OWNER" \
  --repo "$REPO" \
  --pr "$PR_NUMBER" \
  --body-file "$BODY_FILE")
POST_EXIT=$?
rm -f "$BODY_FILE"
```

Exit code semantics from `post.sh`:

- **0** — posted; `COMMENT_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Editing a Comment

`gh pr comment` has no `--edit` flag. Use the REST API directly.

First, obtain COMMENT_ID via the paginated list if not already known:

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
  --jq '.[] | {id, body: .body[:80], author: .user.login}'
```

Write BODY to a temp file before PATCHing:

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
gh api --method PATCH "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID" \
  --field "body=@$BODY_FILE"
rm -f "$BODY_FILE"
```

## Deleting a Comment

```bash
gh api --method DELETE "repos/$OWNER/$REPO/issues/comments/$COMMENT_ID"
```

## Listing Comments

`gh pr view --comments` truncates and misses later pages. Use the paginated API for exhaustive results:

```bash
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

```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```

