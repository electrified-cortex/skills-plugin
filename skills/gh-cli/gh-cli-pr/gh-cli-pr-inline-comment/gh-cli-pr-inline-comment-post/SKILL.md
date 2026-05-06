---
name: gh-cli-pr-inline-comment-post
description: Post an inline PR review comment on a diff line. Triggers — post inline comment, pr review comment, inline diff comment, pr inline annotation, gh api pr comment.
---

Input: OWNER, REPO, PR_NUMBER, FILE_PATH, LINE_NUMBER, BODY, SIDE (optional — default RIGHT), START_LINE (optional — multi-line only)

`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>` in this skill folder
`<input-args>` = `OWNER={OWNER} REPO={REPO} PR_NUMBER={PR_NUMBER} FILE_PATH={FILE_PATH} LINE_NUMBER={LINE_NUMBER} BODY={BODY} SIDE={SIDE} START_LINE={START_LINE}`
`<tier>` = fast-cheap — scripted API sequence; sub-agent executes fixed CLI steps, no LLM judgment required
`<description>` = post inline PR comment on {FILE_PATH}:{LINE_NUMBER}
`<prompt>` = Read and follow `<instructions-abspath>`. Input: `<input-args>`

Follow dispatch skill. See `../../../../dispatch/SKILL.md`.
Should return: `{ "status": "posted" | "duplicate" | "error", "comment_id": <integer or null>, "comment_url": "<https://github.com/{OWNER}/{REPO}/pull/{PR_NUMBER}#discussion_r{ID} or null>", "message": "<one-line summary>" }`
