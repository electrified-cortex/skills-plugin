---
name: analysis
description: Semantic advisory scan of a .md file against SA001-SA038 rules. Triggers - semantic advisory, style advisories, markdown analysis, style rule scan, advisory analysis.
---

## Input

`<markdown_file_path>` — absolute path to the `.md` file to analyze.

## Cached Result Check

Run inline result check for `analysis`. See `../result/SKILL.md`.

- `MISS: <abs-path>` — bind `<analysis_path>`. Jump to Dispatch.
- Otherwise: stop here, return result to caller.

## Dispatch

Variables:

`<instructions>` = `instructions.txt` (this folder; NEVER READ THIS FILE)
`<instructions-abspath>` = absolute path to `<instructions>`
`<input-args>` = `<markdown_file_path> --analysis-path <analysis_path> [--ignore <RULE>[,<RULE>...]]`
`<tier>` = `standard`
`<description>` = `Markdown Hygiene Analysis: <markdown_file_path>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`
Optional: `<model-override>` = `sonnet-class`

Follow `dispatch` skill. See `../../dispatch/SKILL.md`.

Should return: `clean` | `pass: <analysis_path>` | `findings: <analysis_path>` | `ERROR: <reason>`

## Result

If `ERROR:` stop here and return the result to the caller.
Otherwise rerun the result check for `analysis`.
If that result is a `MISS: <abs-path>` then something is wrong and report it as: `ERROR: Expected analysis report at <abs-path>. None found.`

If `clean`, return the result to the caller and stop here.

If `pass: <analysis_path>` or `findings: <analysis_path>`, review advisories in `<analysis_path>` and decide:
- Acceptable as-is → write `result: accepted` to `<analysis_path>` frontmatter. Bind `<analysis_result>` as `accepted`.
- Addressed (edited target or appended `Skipped: <reason>` notes) → write `result: fixed` to `<analysis_path>` frontmatter. Bind `<analysis_result>` as `fixed`.
- Deferring to caller — leave `<analysis_result>` as-is.

Return the result to the caller.
