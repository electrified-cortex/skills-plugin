---
name: gh-cli-projects
description: Create, manage GitHub Projects v2 boards, items, fields via CLI. Triggers - github projects, manage project board, add item to project, project board, github project v2.
---

Commands use project numbers, not names. Resolve name -> number first:

```bash
gh project list --owner owner --format json --jq '.projects[] | select(.title=="My Project") | .number'
```

Create:

```bash
gh project create --owner owner --title "My Project"
gh project create --owner orgname --title "Project"
```

Add items (issues/PRs) by URL:

```bash
gh project item-add PROJECT_NUM --owner owner --url https://github.com/owner/repo/issues/123
```

List: `gh project item-list PROJECT_NUM --owner owner`

Create field:

```bash
gh project field-create PROJECT_NUM --owner owner --name "Status" --data-type "SINGLE_SELECT"
```

Types: `TEXT`, `NUMBER`, `DATE`, `SINGLE_SELECT`, `ITERATION`.

Edit field — single-select: option ID required, not label text:

```bash
gh project field-list PROJECT_NUM --owner owner --format json --jq '.fields[] | select(.name=="Status") | .options'
gh project item-edit PROJECT_NUM --owner owner --id ITEM_ID --field-id FIELD_ID --single-select-option-id OPTION_ID
```

Archive (hides, keeps): `gh project item-archive PROJECT_NUM --owner owner --id ITEM_ID`
Delete (permanent): `gh project item-delete PROJECT_NUM --owner owner --id ITEM_ID`

Copy as template:

```bash
gh project copy PROJECT_NUM --source-owner owner --target-owner owner --title "New Project"
```

Delete project: `gh project delete PROJECT_NUM --owner owner`

Scope:
Covers `gh project` only. Doesn't cover: Projects v1 (classic boards), automation rules. Item-add is the link mechanism.

Related: `gh-cli-issues`, `gh-cli-api`
