---
name: markdown-hygiene
description: Full markdown hygiene pass on a .md file — lint fixes, MD rule scan, semantic advisory analysis. Triggers — lint markdown, fix markdown, MD violations, markdownlint pass, hygiene check, markdown hygiene.
---

Input:

`<markdown_file_path>` — abs path to `.md` file.
`--ignore <RULE>[,<RULE>...]` (optional) — MD rule codes to suppress (lint only).

## Cached Result Check

Run inline `markdown-hygiene-result` for `report`. See `markdown-hygiene-result/SKILL.md`.

- `MISS: <abs-path>` — bind `<report_path>`. Continue.
- Otherwise: stop, return result to caller.

## Analysis

Follow `markdown-hygiene-analysis/SKILL.md` with `<markdown_file_path>`.

- `ERROR: <reason>` — stop, surface reason.
- Otherwise: bind `<analysis_result>`.

## Lint

Run inline result check for `lint`. See `markdown-hygiene-result/SKILL.md`.

- `MISS: <abs-path>` — bind `<lint_path>`. Continue to Dispatch.
- Otherwise: stop, return result to caller.

Follow `markdown-hygiene-lint/SKILL.md` with `<markdown_file_path> [--ignore <RULE>[,<RULE>...]]`.

- `ERROR: <reason>` — stop, surface reason.
- `clean` — bind `<lint_result>` as `clean`. Continue.
- `findings: <path>` — dispatch a standard tier sub-agent to fix reported issues, then re-follow `markdown-hygiene-lint/SKILL.md`. After 3 revision rounds: stop, bind `<lint_result>` as the final findings. On success: bind `<lint_result>`.

## Rekey Analysis

Read `hash-record/hash-record-rekey/SKILL.md`.

```bash
bash hash-record/hash-record-rekey/rekey.sh <markdown_file_path> markdown-hygiene analysis.md <hash_A>
# Windows:
pwsh hash-record/hash-record-rekey/rekey.ps1 <markdown_file_path> markdown-hygiene analysis.md <hash_A>
```

- `REKEYED:` or `CURRENT:` — ok.
- `NOT_FOUND:` — no analysis record.
- `AMBIGUOUS:` or `ERROR:` — warn (non-fatal).

## Aggregate

Derive aggregate from `<lint_result>` and `<analysis_result>`:

- `<lint_result>` starts with `findings:` → aggregate `fail`.
- `<lint_result>` is `clean`, `<analysis_result>` is `accepted` or `fixed` → aggregate `pass`.
- `<lint_result>` is `clean`, `<analysis_result>` starts with `pass:` or `findings:` → aggregate `pass`.
- Both `clean` → aggregate `clean`.

Write `report.md` at `<report_path>`:

Frontmatter: `operation_kind: markdown-hygiene`, `result: <aggregate>`, `file_path: <repo-relative-path>`. No abs paths.

Body:

```md
# Result

lint: `<lint_result>`
analysis: `<analysis_result>`
```

`<lint_result>` and `<analysis_result>` are bare return values (`clean`, `findings: lint.md`, `pass: analysis.md`) using repo-relative paths only.

Return: `clean` → `CLEAN`; `pass` → `PASS: <report_path>`.
