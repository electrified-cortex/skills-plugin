---
name: gh-cli-pr-comments
description: Add, edit, delete pull request comments via GitHub CLI. Triggers - add PR comment, comment on pull request, edit PR comment, delete PR comment, pull request discussion.
---

Add, edit, delete PR comments via `gh pr comment`.

## Adding

Add comment to PR:

```bash
gh pr comment 123 --body "text"
```

## Viewing

`gh pr view --comments` truncates output and misses later pages.
For a complete list of all review comments, use the paginated API:

```bash
# All inline/review comments (paginated — all pages)
gh api --paginate /repos/{owner}/{repo}/pulls/{pull_number}/comments

# All review-level submissions (paginated)
gh api --paginate /repos/{owner}/{repo}/pulls/{pull_number}/reviews
```

For general PR (issue) comments, also paginate:

```bash
gh api --paginate /repos/{owner}/{repo}/issues/{pull_number}/comments
```

Use `gh pr view --comments` only for a quick human-readable glance —
never for exhaustive comment checks.

## Editing

`gh pr comment` has no `--edit` flag. Use REST API — find comment ID,
PATCH:

```bash
# List ALL comments to find the comment ID (--paginate collects all)
gh api --paginate /repos/{owner}/{repo}/issues/{issue_number}/comments

# Edit the comment
gh api --method PATCH \
  /repos/{owner}/{repo}/issues/comments/{comment_id} \
  --field body="updated text"
```

## Deleting

`gh pr comment` has no `--delete` flag. Use REST API:

```bash
gh api --method DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}
```

## Resolving Review Threads

No `gh pr` command for resolving threads. Use
`resolveReviewThread` GraphQL mutation via `gh-cli-api`:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "THREAD_ID"}) {
      thread { isResolved }
    }
  }'
```

## Dependencies

- `gh-cli-setup/SKILL.md` — required pre-check: auth + CLI installed

## Error Handling

- Auth failure: re-run `gh-cli-setup` to verify token.
- PR not found: verify repository and PR number.
- Comment not found: verify comment ID.

## Scope

Covers `gh pr comment` only. Review-level comments
(approve/request-changes verdict) → `gh-cli-prs-review`. Viewing also in
`gh-cli-prs` inspection.
