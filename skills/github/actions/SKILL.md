---
name: actions
description: Trigger, monitor, manage GitHub Actions workflows, runs, secrets, variables via CLI. Triggers - run workflow, trigger GitHub Actions, check workflow status, manage workflows, github actions CLI.
---

Workflows:

List: `gh workflow list`
Enable/disable: `gh workflow enable ci.yml` / `gh workflow disable ci.yml`

Trigger + capture run ID:

```bash
gh workflow run ci.yml --ref main --raw-field version="1.0.0"
RUN_ID=$(gh run list --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

Monitor:

```bash
gh run list --workflow ci.yml --branch main --json databaseId,status,conclusion
gh run watch "$RUN_ID"
```

Check overall run health via statusCheckRollup:

```bash
gh run view "$RUN_ID" --json statusCheckRollup --jq '.statusCheckRollup[] | {name, status, conclusion}'
# conclusion: SUCCESS = healthy; FAILURE/CANCELLED = unhealthy; null = in progress
```

Logs:

```bash
gh run view "$RUN_ID" --log-failed
gh run view "$RUN_ID" --job 987654321 --log
```

Rerun/cancel:

```bash
gh run rerun "$RUN_ID" --failed
gh run cancel "$RUN_ID"
```

Download artifacts:

```bash
gh run download "$RUN_ID" --dir ./artifacts
gh run download "$RUN_ID" --name build
```

Secrets (never pass as CLI arg; pipe from stdin or use env var):

```bash
echo "$SECRET_VALUE" | gh secret set MY_SECRET
gh secret set MY_SECRET --body "value"
gh secret list
gh secret delete MY_SECRET
```

Scope to env: `echo "$SECRET_VALUE" | gh secret set MY_SECRET --env production`

`gh secret set` without `--body` or stdin prompts interactively. Always pipe or use `--body` in automated contexts.

Variables:

```bash
gh variable set MY_VAR "value"
gh variable set MY_VAR "value" --env production
gh variable get MY_VAR
gh variable list
gh variable delete MY_VAR
```

Caches:

```bash
gh cache list --branch main
gh cache delete "$CACHE_ID"
gh cache delete --all
```

Scope: `gh run`, `gh workflow`, `gh secret`, `gh variable`, `gh cache`. Doesn't cover workflow YAML, self-hosted runners, or OIDC trust configs.

Related: `pr` (CI checks on PRs), `api` (custom Actions API calls)

## Safety Classification

| Command | Class | Notes |
| --- | --- | --- |
| gh run list | Safe | Read-only |
| gh run view | Safe | Read-only |
| gh run watch | Safe | Read-only |
| gh run download | Safe | Read-only |
| gh run rerun | Destructive | Operator approval required before execution |
| gh run cancel | Destructive | Operator approval required before execution |
| gh workflow list | Safe | Read-only |
| gh workflow view | Safe | Read-only |
| gh workflow enable | Destructive | Operator approval required before execution |
| gh workflow disable | Destructive | Operator approval required before execution |
| gh workflow run | Destructive | Operator approval required before execution |
| gh cache list | Safe | Read-only |
| gh cache delete | Destructive | Operator approval required before execution |
| gh secret list | Safe | Read-only |
| gh secret set | Destructive | Operator approval required before execution |
| gh secret delete | Destructive | Operator approval required before execution |
| gh variable list | Safe | Read-only |
| gh variable get | Safe | Read-only |
| gh variable set | Destructive | Operator approval required before execution |
| gh variable delete | Destructive | Operator approval required before execution |

**Destructive operations require explicit operator authorization in the current session before the agent executes them.** Approval from another agent (e.g., Overseer confirming CI green) does not constitute operator authorization.

## Error Handling

- Auth failure: re-run `setup` to verify token.
- CLI not found: ensure `gh` is installed.
- Action not found: verify workflow name and repository.

## Dependencies

- setup/SKILL.md — required pre-check: auth + CLI installed
