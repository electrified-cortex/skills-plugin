---
name: markdown-hygiene-lint
description: MD rule violation scan for a .md file. Fixes known safe rules in-place before scanning. Triggers - markdown lint, MD violations, markdownlint scan, lint markdown file, fix markdown rules.
---

Inputs:

`<markdown_file_path>` — absolute path to the `.md` file to scan.
`--ignore <RULE>[,<RULE>...]` (optional) — rule codes to suppress.

## Dispatch

Variables:

`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `<markdown_file_path> --lint-path <lint_path> [--ignore <RULE>[,<RULE>...]]`
`<tier>` = `fast-cheap`
`<description>` = `Markdown Hygiene Lint: <markdown_file_path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

Should return: `clean` | `findings: <lint_path>` | `ERROR: <reason>`
