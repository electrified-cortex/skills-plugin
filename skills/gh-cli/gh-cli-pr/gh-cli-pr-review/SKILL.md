---
name: gh-cli-pr-review
description: Approve, request changes on, dismiss pull request review via GitHub CLI. Triggers - approve PR, request changes, dismiss review, pr approval, review pull request.
---

PR review + dismiss via `gh pr review`.

Approve:
Optional body:

```bash
gh pr review 123 --approve --body "LGTM"

```

Request Changes:
Body required:

```bash
gh pr review 123 --request-changes --body "Please address X before merging"

```

Comment-Only (No Verdict):

```bash
gh pr review 123 --comment --body "Thoughts inline"

```

Dismiss:
`--review-id` required; `gh` CLI won't accept `--dismiss` without it:

```bash
gh pr review 123 --dismiss --review-id <review-id> --body "reason"

```

Get review ID:

```bash
gh pr view 123 --json reviews --jq '.reviews[].id'

```

Add Reviewers:
Creation-time: `gh pr create --reviewer`. After creation:

```bash
gh pr edit 123 --add-reviewer user

```

Covered by `gh-cli-pr-create`, not this skill.

Resolve Threads:
No `gh pr` command. Use `resolveReviewThread` GraphQL via `gh-cli-api`:

```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'

```

Scope:
Covers `gh pr review` only. Excludes: inline comments, requesting reviewers (`gh-cli-prs-create`), resolving threads (`gh-cli-api`).

Error Paths:
`--request-changes` without `--body` → prompt caller for change rationale before running.
`--dismiss` with non-existent review ID → surface `gh` error; run `gh pr view --json reviews` to list valid IDs, ask caller to reconfirm.

Related:
`gh-cli-prs-create` — adding reviewers, creating PRs
`gh-cli-api` — resolving review threads via GraphQL
