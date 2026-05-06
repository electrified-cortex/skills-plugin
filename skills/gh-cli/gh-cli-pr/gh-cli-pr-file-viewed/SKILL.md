---
name: gh-cli-pr-file-viewed
description: Mark or unmark one, multiple, or all files in a PR as viewed via GitHub GraphQL mutations. Handles node ID resolution and pagination for large PRs. Triggers - mark file as viewed, PR file viewed, unmark file, mark all files reviewed, PR file review status.
---

## When to Use

Use when an agent needs to mark files as reviewed/viewed in the GitHub PR file-by-file review UI. Applies to mark or unmark operations on one, several, or all changed files in a PR.

## Concepts

- **Viewed state** — per-file, per-viewer state tracked by GitHub. Values: `VIEWED`, `UNVIEWED`, `DISMISSED` (pushed commit reset a previously viewed file).
- **PR node ID** — the GraphQL global ID for the PR, not the PR number. Get it from `gh pr view --json id`. The `id` field returns the older base64 format (`MDExOl...`) which is deprecated but still works. No alternative is available from `gh pr view` — use it and accept any deprecation warning.
- **File path** — must exactly match the path returned by `gh pr view --json files`. Case-sensitive.

## Step 1 — Resolve PR node ID and file list

```bash
gh pr view {PR_NUMBER} --repo {OWNER}/{REPO} --json id,files \
  --jq '{id: .id, paths: [.files[].path]}'
```

This returns both the node ID and all changed file paths in one call.

> **Gotcha — fork PRs**: If `gh pr list --repo {fork}` was used to discover the PR, verify the `url` field. The URL shows the real repo (often upstream, not the fork). Use the owner/repo from the URL — not the fork — for all subsequent calls. `gh pr view` on a fork fails with "Could not resolve to a PullRequest" when the PR actually lives upstream.

> **Gotcha — large PRs**: `--json files` from `gh pr view` returns all changed files. However, the GraphQL `files` connection has a default page size of 100. For PRs with >100 files, query files via GraphQL with pagination (see Step 4).

## Step 2 — Mark one file as viewed

```bash
gh api graphql -f query='
  mutation {
    markFileAsViewed(input: {
      pullRequestId: "{PR_NODE_ID}",
      path: "{FILE_PATH}"
    }) {
      pullRequest { number }
    }
  }'
```

## Step 3 — Unmark one file as viewed

```bash
gh api graphql -f query='
  mutation {
    unmarkFileAsViewed(input: {
      pullRequestId: "{PR_NODE_ID}",
      path: "{FILE_PATH}"
    }) {
      pullRequest { number }
    }
  }'
```

## Step 4 — Check viewed state for all files

Returns each file and its current `viewerViewedState` (`VIEWED`, `UNVIEWED`, or `DISMISSED`):

```bash
gh api graphql -f query='
  query {
    repository(owner: "{OWNER}", name: "{REPO}") {
      pullRequest(number: {PR_NUMBER}) {
        files(first: 100) {
          nodes { path viewerViewedState }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }'
```

For PRs with >100 files, paginate using `endCursor`:

```bash
gh api graphql -f query='
  query {
    repository(owner: "{OWNER}", name: "{REPO}") {
      pullRequest(number: {PR_NUMBER}) {
        files(first: 100, after: "{END_CURSOR}") {
          nodes { path viewerViewedState }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }'
```

Repeat until `hasNextPage` is `false`.

## Step 5 — Mark all files as viewed

Combine Step 1 (get all paths) with Step 2 (mark each). In a shell loop:

```bash
# Get paths as newline-separated list
PATHS=$(gh pr view {PR_NUMBER} --repo {OWNER}/{REPO} --json files --jq '.files[].path')
PR_ID=$(gh pr view {PR_NUMBER} --repo {OWNER}/{REPO} --json id --jq '.id')

echo "$PATHS" | ForEach-Object {
  gh api graphql -f query="
    mutation {
      markFileAsViewed(input: {pullRequestId: \"$PR_ID\", path: \"$_\"}) {
        pullRequest { number }
      }
    }"
}
```

PowerShell version:

```powershell
$pr = gh pr view {PR_NUMBER} --repo {OWNER}/{REPO} --json id,files | ConvertFrom-Json
$prId = $pr.id
$pr.files | ForEach-Object {
  gh api graphql -f query="mutation { markFileAsViewed(input: {pullRequestId: `"$prId`", path: `"$($_.path)`"}) { pullRequest { number } } }"
}
```

## Known Gotchas

| Gotcha | Symptom | Fix |
| --- | --- | --- |
| Fork PR resolution | `gh pr view` fails: "Could not resolve to a PullRequest" | Extract real repo from `url` in `gh pr list --json url`; use that repo for all calls |
| Deprecated node ID | Mutation succeeds but response includes `next_global_id` deprecation warning | Ignore — mutation works. No `gh pr view` flag returns the new format. |
| `viewerViewedFiles` on PullRequest | GraphQL error: "Field 'viewerViewedFiles' doesn't exist on type 'PullRequest'" | Use `files.nodes[].viewerViewedState` in a query instead |
| Path mismatch | Mutation succeeds but file state doesn't change | Path must match exactly (case-sensitive) as returned by `--json files[].path` |
| `DISMISSED` state | File shows as `DISMISSED` even after marking | A commit pushed after marking resets state to `DISMISSED`. Re-mark after review. |

## Scope

Covers `markFileAsViewed` and `unmarkFileAsViewed` GraphQL mutations only. Does not submit PR reviews, post comments, or manage review threads — see `gh-cli-pr-review/` and `gh-cli-pr-inline-comment/`.
