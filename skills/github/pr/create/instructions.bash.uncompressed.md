# GH CLI PR Create (Bash)

## Prerequisites

```bash
gh auth status 2>&1
```

## Check for Existing PR

Before creating, confirm no open PR exists for the current branch:

```bash
gh pr list --repo "$OWNER/$REPO" --head "$(git branch --show-current)" --json number,url
```

If an open PR is returned, report it to the caller and stop — do not create a duplicate.

## Creating a Pull Request

Write BODY to a temp file — inline shell substitution corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences.

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
```

Invoke the local create tool:

```bash
create_args=(
  --owner "$OWNER"
  --repo  "$REPO"
  --base  "$BASE"
  --title "$TITLE"
  --body-file "$BODY_FILE"
)
[[ -n "${LABEL:-}" ]] && create_args+=(--label "$LABEL")
[[ -n "${DRAFT:-}"  ]] && create_args+=(--draft)

PR_URL=$(bash create.sh "${create_args[@]}")
CREATE_EXIT=$?
rm -f "$BODY_FILE"
```

Exit code semantics from `create.sh`:

- **0** — created; `PR_URL` holds the PR URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Listing Existing PRs

Check open PRs for the repository:

```bash
gh pr list --repo "$OWNER/$REPO" --state open
```

Filter by branch:

```bash
gh pr list --repo "$OWNER/$REPO" --head "$(git branch --show-current)"
```

## Promoting a Draft to Ready

When the PR is ready for review, promote it using the PR number:

```bash
gh pr ready "$PR_NUMBER" --repo "$OWNER/$REPO"
```

## Editing Metadata After Creation

Add reviewers, labels, or remove labels after the PR is open:

```bash
gh pr edit "$PR_NUMBER" --repo "$OWNER/$REPO" \
  --add-reviewer user3 --add-label bug --remove-label wip
```

