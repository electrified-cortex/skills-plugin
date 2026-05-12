# GH CLI Issues (Bash)

## Prerequisites

```bash
gh auth status 2>&1
```

## Creating an Issue

Write BODY to a temp file — inline shell substitution corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences.

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
```

Invoke the local create tool:

```bash
ISSUE_URL=$(bash create.sh \
  --owner "$OWNER" \
  --repo "$REPO" \
  --title "$TITLE" \
  --body-file "$BODY_FILE" \
  --label "$LABELS")
CREATE_EXIT=$?
rm -f "$BODY_FILE"
```

Omit `--label` when LABELS is empty.

Exit code semantics from `create.sh`:

- **0** — created; `ISSUE_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Commenting on an Issue

Write BODY to a temp file — inline shell substitution corrupts bodies containing backticks, `$VAR` references, double quotes, or code fences.

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
```

Invoke the local comment tool:

```bash
COMMENT_URL=$(bash comment.sh \
  --owner "$OWNER" \
  --repo "$REPO" \
  --issue "$ISSUE_NUMBER" \
  --body-file "$BODY_FILE")
COMMENT_EXIT=$?
rm -f "$BODY_FILE"
```

Exit code semantics from `comment.sh`:

- **0** — posted; `COMMENT_URL` holds the URL.
- **2** — usage error; check invocation.
- **4** — gh error; stderr forwarded by the tool.

## Editing Issue Metadata

Edit title, labels, assignees, or milestone inline — no body involved:

```bash
gh issue edit "$ISSUE_NUMBER" --repo "$OWNER/$REPO" \
  --title "new title" \
  --add-label triage --remove-label stale \
  --add-assignee user1 --remove-assignee user2 \
  --milestone "v2.0"
```

## Editing an Issue Body

`gh issue edit` supports `--body-file` for body replacement. Write BODY to a temp file first:

```bash
BODY_FILE=$(mktemp /tmp/gh-body-XXXXXX.md)
printf '%s' "$BODY" > "$BODY_FILE"
gh issue edit "$ISSUE_NUMBER" --repo "$OWNER/$REPO" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
```

## Editing a Comment

`gh issue comment` has no `--edit` flag. Use the REST API directly.

First, obtain COMMENT_ID via the paginated list if not already known:

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$ISSUE_NUMBER/comments" \
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

## Viewing an Issue

```bash
gh issue view "$ISSUE_NUMBER" --repo "$OWNER/$REPO" --comments
```

## Listing Issues

Default state is open:

```bash
gh issue list --repo "$OWNER/$REPO" \
  --state all --assignee @me --label bug --milestone "v1.0" --limit 50
```

Search + structured extract:

```bash
gh issue list --repo "$OWNER/$REPO" \
  --search "is:open label:stale" --json number,title --jq '.[].number'
```

## Closing and Reopening

```bash
gh issue close "$ISSUE_NUMBER" --repo "$OWNER/$REPO" --comment "Fixed in #456"
gh issue reopen "$ISSUE_NUMBER" --repo "$OWNER/$REPO"
```

## Transferring

```bash
gh issue transfer "$ISSUE_NUMBER" --repo "$OWNER/$REPO" owner/other-repo
```

## Bulk Operations

```bash
gh issue list --repo "$OWNER/$REPO" \
  --search "label:stale" --json number --jq '.[].number' \
  | xargs -I {} gh issue close {} --repo "$OWNER/$REPO" --comment "Closing stale"
```

