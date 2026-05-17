---
name: post
description: Post an inline PR review comment on a diff line. Triggers - post inline comment, pr review comment, inline diff comment, pr inline annotation, gh api pr comment, gh cli pr inline comment post.
---

Inputs:

| Parameter | Required | Notes |
| --- | --- | --- |
| OWNER | yes | org or user |
| REPO | yes | repo name |
| PR_NUMBER | yes | int PR number |
| FILE_PATH | yes | repo-relative (e.g. `src/foo.ts`) |
| LINE_NUMBER | yes | absolute line number |
| BODY | yes* | text (* required if no BODY_FILE) |
| BODY_FILE | no | abs path to body file; use instead of BODY to skip shell escaping |
| SIDE | no | `RIGHT` (default) or `LEFT` |

Pre-dispatch — BODY_FILE promotion:
If BODY contains `` ` ``, `$`, `"`, or ` ``` ` — write BODY to temp file (verbatim at caller level), pass `BODY_FILE`, omit `BODY` from `<input-args>`.

Shell — resolve `<shell>`:
bash 4+ on Linux, macOS, or Windows Git Bash → `<shell>` = `bash`
PowerShell 7+ on any platform → `<shell>` = `pwsh`

Dispatch:
`<instructions>` = `instructions.<shell>.txt` in this skill folder (NEVER READ)
`<instructions-abspath>` = abs path to `<instructions>`
`<input-args>` = `OWNER={OWNER} REPO={REPO} PR_NUMBER={PR_NUMBER} FILE_PATH={FILE_PATH} LINE_NUMBER={LINE_NUMBER} BODY={BODY} BODY_FILE={BODY_FILE} SIDE={SIDE}`
`<tier>` = fast-cheap
`<description>` = post inline PR comment on {FILE_PATH}:{LINE_NUMBER}
`<prompt>` = Read and follow `<instructions-abspath>`. Input: `<input-args>`

Follow `../../../../dispatch/SKILL.md`.

Return:

```json
{ "status": "posted" | "duplicate" | "error", "comment_id": <integer or null>, "comment_url": "<url or null>", "message": "<one-line summary>" }
```

Success: `{ "status": "posted", "comment_id": <id from response>, "comment_url": "https://github.com/{OWNER}/{REPO}/pull/{PR_NUMBER}#discussion_r<id from response>", "message": "posted at {FILE_PATH}:{LINE_NUMBER}" }`
Duplicate: `{ "status": "duplicate", "comment_id": <existing_id>, "comment_url": "https://github.com/{OWNER}/{REPO}/pull/{PR_NUMBER}#discussion_r<existing_id>", "message": "comment already exists at {FILE_PATH}:{LINE_NUMBER}" }`
Line not in diff (exit 3): `{ "status": "error", "comment_id": null, "comment_url": null, "message": "Line {LINE_NUMBER} is not in the diff for {FILE_PATH}" }`
gh error (exit 4): `{ "status": "error", "comment_id": null, "comment_url": null, "message": "gh api error — see stderr" }`
Any other error: `{ "status": "error", "comment_id": null, "comment_url": null, "message": "<error description>" }`
