---
name: github
description: GitHub umbrella router — directs to child skills for actions, api, issues, pr, projects, release, repo, setup. Triggers - github, github CLI, gh command, github operations, github skill.
---

Routes GitHub tasks to the correct domain sub-skill. Does not execute `gh` commands itself.

When domain is known, dispatch the sub-skill directly. When unclear, parse the task and route by domain below.

Domain Routing:

| Domain | Sub-skill | Use for |
| --- | --- | --- |
| actions | actions/ | Workflows, runs, secrets, variables, caches |
| api | api/ | Raw REST and GraphQL API calls |
| issues | issues/ | Issue lifecycle: create, list, edit, close, comment |
| projects | projects/ | GitHub Projects v2: boards, items, fields |
| pr | pr/ | Pull request lifecycle router |
| release | release/ | Release lifecycle: create, publish, upload assets |
| repo | repo/ | Repository management: create, clone, fork, sync |
| setup | setup/ | Install, authenticate, and configure gh |

PR sub-skills under `pr/`:

**Routing rule for PR comments:** No FILE_PATH or LINE_NUMBER → use `pr/comments/` (general PR conversation). Anchored to a specific diff line → use `pr/inline-comment/post/`.

| Sub-skill | Handles |
| --- | --- |
| pr/comments/ | Add, edit, delete general PR comments |
| pr/create/ | Open new PRs |
| pr/file-viewed/ | Mark or unmark files as viewed |
| pr/inline-comment/ | Post, edit, delete inline diff comments (router) |
| pr/merge/ | Merge strategies, branch updates, revert |
| pr/review/ | Approve, request changes, dismiss reviews |

Inline comment sub-skills under `pr/inline-comment/`:

| Sub-skill | Handles |
| --- | --- |
| pr/inline-comment/post/ | Post a new inline diff comment |
| pr/inline-comment/edit/ | Edit an existing inline comment |
| pr/inline-comment/delete/ | Delete an inline comment |

Rules:

Load `setup/` to verify auth before any `gh` command if setup skill not yet run in session.
Never improvise commands — use only what the sub-skill documents.
One domain per invocation; multiple domains → complete primary first, report remaining.

Related: `actions`, `api`, `issues`, `projects`, `pr`, `release`, `repo`, `setup`
