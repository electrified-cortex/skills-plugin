---
name: gh-cli-issues
description: Manage GitHub issues using the gh issue subcommand. Full lifecycle: create, list, view, edit, comment, close, transfer. Triggers - create issue, github issue, list issues, close issue, comment on issue, manage issues.
---

`gh issue` subcommand. Full lifecycle: create, list, view, edit, comment, close, transfer.

## Create

```bash
gh issue create --title "title" --body "body" --label bug,high-priority --assignee user1,@me
```

## Body from file

```bash
gh issue create --title "title" --body-file issue.md
```

## List (default state: open)

```bash
gh issue list --state all --assignee @me --label bug --milestone "v1.0" --limit 50
```

## Search + jq

```bash
gh issue list --search "is:open label:stale" --json number,title --jq '.[].number'
```

States: `open`, `closed`, `all`.

## View

```bash
gh issue view 123 --comments
```

## Edit

```bash
gh issue edit 123 --title "new" --add-label triage --remove-label stale
gh issue edit 123 --add-assignee user1 --remove-assignee user2 --milestone "v2.0"
```

## Close/reopen

```bash
gh issue close 123 --comment "Fixed in #456"
gh issue reopen 123
```

## Comment

```bash
gh issue comment 123 --body "text"
```

`gh issue comment` has no `--edit`/`--delete` flags. Use REST API. Find comment ID first:

```bash
# list → find comment ID
gh api /repos/{owner}/{repo}/issues/{issue_number}/comments

# edit
gh api --method PATCH /repos/{owner}/{repo}/issues/comments/{comment_id} \
  --field body="updated"

# delete
gh api --method DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}
```

## Transfer

```bash
gh issue transfer 123 --repo owner/other-repo
```
