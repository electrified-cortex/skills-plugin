# GH CLI PR Review (Bash)

## Prerequisites

```bash
gh auth status 2>&1
```

## Submitting a Review

Invoke the local review tool. Body file is passed by path — this tool never reads body content.

```bash
review_args=(
  --owner "$OWNER"
  --repo "$REPO"
  --pr "$PR_NUMBER"
  --decision "$DECISION"
)

if [[ -n "$BODY_FILE" ]]; then
  review_args+=(--body-file "$BODY_FILE")
fi

if [[ -n "$REVIEW_ID" ]]; then
  review_args+=(--review-id "$REVIEW_ID")
fi

PR_URL=$(bash review.sh "${review_args[@]}")
REVIEW_EXIT=$?
```

Exit code semantics from `review.sh`:

- **0** — submitted; `PR_URL` holds the PR URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Getting the Review ID (for dismiss)

```bash
gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" --json reviews \
  --jq '.reviews[] | {id, author: .author.login, state}'
```

## Listing Reviews

```bash
# Review-level submissions — all pages
gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

## Resolving Review Threads

There is no `gh pr` command for resolving review threads. Use the
`resolveReviewThread` GraphQL mutation via `gh-cli-api`:

```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```

