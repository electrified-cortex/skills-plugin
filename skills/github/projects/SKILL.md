---
name: projects
description: Create, manage GitHub Projects v2 boards, items, fields via CLI. Triggers - github projects, manage project board, add item to project, project board, github project v2.
---

## Dependencies

- setup/SKILL.md — required pre-check: auth + CLI installed

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

## Error Handling

- Auth failure: re-run setup.
- Project not found: verify project number and org/user scope.
- Permission denied: confirm project membership.

## Safety Classification

| Command | Class | Notes |
| --- | --- | --- |
| gh project list | Safe | Read-only |
| gh project view | Safe | Read-only |
| gh project create | Destructive | Operator approval required before execution |
| gh project edit | Destructive | Operator approval required before execution |
| gh project delete | Destructive | Operator approval required before execution |
| gh project copy | Destructive | Operator approval required before execution |
| gh project link | Destructive | Operator approval required before execution |
| gh project unlink | Destructive | Operator approval required before execution |
| gh project item-add | Destructive | Operator approval required before execution |
| gh project item-edit | Destructive | Operator approval required before execution |
| gh project item-archive | Destructive | Operator approval required before execution |
| gh project item-delete | Destructive | Operator approval required before execution |
| gh project field-create | Destructive | Operator approval required before execution |
| gh project field-delete | Destructive | Operator approval required before execution |

**Destructive operations require explicit operator authorization in the current session before the agent executes them.** Approval from another agent (e.g., Overseer confirming CI green) does not constitute operator authorization.

Related: `issues`, `api`
