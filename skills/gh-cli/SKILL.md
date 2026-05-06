---
name: gh-cli
description: GitHub CLI operations — routes to domain-specific sub-skills via dispatch. Triggers - use GitHub CLI, gh command, github CLI task, github operations, gh CLI.
---

Routes GitHub CLI tasks to correct domain sub-skill. Doesn't run `gh` commands itself.

When to Use

Use when unsure which sub-skill owns task, or want auto-routing. If domain known, dispatch sub-skill directly.

How It Works

1. Parse task → identify domain.
2. Domain unclear → ask caller before proceeding.
3. Load + invoke domain sub-skill, follow its instructions.
4. Await sub-skill result; relay outcome to caller.
5. Task spans multiple domains → handle primary, report remaining to caller.

Domain Routing

| Domain | Sub-skill | Use for |
| --- | --- | --- |
| actions | gh-cli-actions/ | Workflows, runs, secrets, variables, caches |
| api | gh-cli-api/ | Raw REST and GraphQL API calls |
| issues | gh-cli-issues/ | Issue lifecycle: create, list, edit, close, comment |
| projects | gh-cli-projects/ | GitHub Projects v2: boards, items, fields |
| prs | gh-cli-prs/ | Pull request lifecycle router |
| releases | gh-cli-releases/ | Release lifecycle: create, publish, upload assets |
| repos | gh-cli-repos/ | Repository management: create, clone, fork, sync |
| setup | gh-cli-setup/ | Install, authenticate, and configure gh |

PR Sub-skills

prs domain sub-skills under `gh-cli-prs/`:
`gh-cli-prs-comments/` — add/edit/delete PR comments
`gh-cli-prs-create/` — open new PRs
`gh-cli-prs-merge/` — merge strategies, branch updates, revert
`gh-cli-prs-review/` — approve, request changes, dismiss reviews

Rules

If setup skill wasn't loaded, load `gh-cli-setup/` to verify auth before delegating.
**Never** improvise commands — use only what sub-skill documents.
One domain per invocation. Multiple domains → complete primary first, note remaining.

Related: `dispatch`, `gh-cli-actions`, `gh-cli-api`, `gh-cli-issues`, `gh-cli-projects`, `gh-cli-prs`, `gh-cli-releases`, `gh-cli-repos`, `gh-cli-setup`
