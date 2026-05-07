---
name: gh-cli-repos
description: Create, clone, fork, sync, edit, delete GitHub repositories via CLI. Triggers - create repo, clone repository, fork repo, github repo operations, manage repositories.
---

## Dependencies

- gh-cli-setup/SKILL.md — required pre-check: auth + CLI installed

Create:
Always specify visibility — no default:

```bash
gh repo create owner/name --public --description "desc" --clone
gh repo create owner/name --private --gitignore node --license mit
```

Clone: `gh repo clone owner/repo [dir]`

Fork:
Fork and set upstream remote:

```bash
gh repo fork owner/repo --clone --remote-name upstream
```

`--remote-name upstream` sets original as `upstream` remote in cloned fork.

Fork Sync: `gh repo sync [--branch branch] [--force]`
`--force` overwrites local changes to match upstream.

Edit Metadata:

```bash
gh repo edit --description "new" --homepage https://example.com
gh repo edit --visibility private
gh repo edit --default-branch main
```

Rename: `gh repo rename new-name`
Archive: `gh repo archive` / `gh repo unarchive`
Delete: `gh repo delete owner/repo --yes`

List:

```bash
gh repo list [owner] --limit 50 --json name,visibility,owner --jq '.[].name'
```

Default Repo:
Set default for current dir so subsequent commands don't need `--repo`:
`gh repo set-default owner/repo` / `gh repo set-default --unset`

Scope:
Covers `gh repo` only. Doesn't manage repo content (files, branches, commits — git ops), secrets, deploy keys, GitHub Apps, webhooks, or integrations.

## Error Handling

- Auth failure: re-run gh-cli-setup.
- Repo not found: verify org/name and visibility.
- Name conflict: repository name already in use.

Related: `gh-cli-actions`, `gh-cli-api`
