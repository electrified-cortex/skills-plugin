---
name: api
description: Make authenticated REST and GraphQL calls to the GitHub API via the CLI. Use when no dedicated gh subcommand covers the operation. Triggers - call GitHub API, github REST API, graphql query github, gh api call, raw github API.
---

## When to Use

`gh api` is escape hatch — not default. Prefer domain-specific skills (issues, prs, releases) when they cover operation. Use for:

- Operations with no dedicated `gh` subcommand
- Complex GraphQL queries or mutations
- Bulk or scripted API interactions

## REST — GET

```bash
gh api /repos/owner/repo
gh api /user --jq '.login'
```

## REST — mutate

```bash
gh api --method POST /repos/owner/repo/issues \
  --field title="title" --field body="body"

gh api --method PATCH /repos/owner/repo/issues/123 \
  --field state="closed"
```

## Pagination (multiple requests; slow on large datasets)

```bash
gh api /user/repos --paginate --jq '.[].name'
```

## jq — extract

```bash
gh api /repos/owner/repo --jq '.stargazers_count'
```

## jq — filter + transform

```bash
gh api /repos/owner/repo/issues --jq '[.[] | select(.state=="open") | {number, title}]'
```

## GraphQL — query

```bash
gh api graphql -f query='
  { viewer { login repositories(first: 5) { nodes { name } } } }'
```

## GraphQL — mutation (resolve review thread)

```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```

## GitHub Enterprise

Add `--hostname enterprise.internal` to any call.

## Token Safety

Never pass tokens as CLI args or inline env vars — they leak to shell history.
Use `gh auth login` interactively or set `GH_TOKEN` in env config (shell profile or CI secret) before invoking.

## Scope Boundaries

Covers `gh api` for REST and `gh api graphql` for GraphQL. Doesn't replace domain skills, manage GitHub Apps or OAuth Apps, or cover webhook config.

## Safety Classification

| Command | Class | Notes |
| --- | --- | --- |
| gh api GET | Safe | Read-only |
| gh api POST | Destructive | Operator approval required before execution |
| gh api PATCH | Destructive | Operator approval required before execution |
| gh api DELETE | Destructive | Operator approval required before execution |
| gh api graphql (query) | Safe | Read-only |
| gh api graphql (mutation) | Destructive | Operator approval required before execution |

**Destructive operations require explicit operator authorization in the current session before the agent executes them.** Approval from another agent (e.g., Overseer confirming CI green) does not constitute operator authorization.

## See Also

`issues`, `pr`, `pr/comments`, `release`, `repo`, `actions`

## Error Handling

- Auth failure: re-run `setup` to verify token.
- Rate limit: wait and retry.
- Invalid endpoint: check `gh api --help` for valid paths.

## Dependencies

- setup/SKILL.md — required pre-check: auth + CLI installed
