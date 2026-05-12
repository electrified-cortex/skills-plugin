# Redundancy Audit — gh-cli Router Skills

Audit date: 2026-05-12. Read-only. All findings reference `uncompressed.md` sources only.

Scope files per skill:
- `uncompressed.md` (SKILL.md source — authoritative)
- `instructions.bash.uncompressed.md`
- `instructions.pwsh.uncompressed.md`

---

## 1. Summary Table

| Skill | Cat 1 Input redef | Cat 2 Return redef | Cat 3 Scope restatement | Cat 4 Frontmatter dup | Cat 5 Constraint dup | Cat 6 Cross-shell dup | Total hits |
|---|---|---|---|---|---|---|---|
| gh-cli-pr-comments | 2 | 0 | 2 | 0 | 2 | 5 | **11** |
| gh-cli-pr-create | 2 | 0 | 2 | 0 | 2 | 5 | **11** |
| gh-cli-pr-review | 2 | 0 | 2 | 0 | 2 | 6 | **12** |
| gh-cli-pr-inline-comment-post | 2 | 2 | 2 | 0 | 2 | 6 | **14** |
| gh-cli-issues | 2 | 0 | 2 | 0 | 2 | 7 | **13** |
| **Total** | **10** | **2** | **10** | **0** | **10** | **29** | **61** |

---

## 2. Per-Skill Findings

### 2.1 gh-cli-pr-comments

**Source:** `gh-cli-pr\gh-cli-pr-comments\`

#### Cat 1 — Input Redefinition

`uncompressed.md` lines 8–16 define the full Inputs table (5 rows: OWNER, REPO, PR_NUMBER, BODY, COMMENT_ID).

`instructions.bash.uncompressed.md` lines 5–13 restate an identical table verbatim.
`instructions.pwsh.uncompressed.md` lines 5–13 restate an identical table verbatim.

**Diff proposal:** Delete `instructions.bash.uncompressed.md` lines 5–13 (the `## Inputs` section through the closing table row). Replace with a single bridging line:

```
<!-- Inputs defined in uncompressed.md — see SKILL.md at load time. -->
```

Same deletion for `instructions.pwsh.uncompressed.md` lines 5–13.

#### Cat 3 — Scope Restatement

`instructions.bash.uncompressed.md` line 3:
> "Execution sequence and parameter handling for the gh-cli-pr-comments skill — Bash shell only."

`instructions.pwsh.uncompressed.md` line 3:
> "Execution sequence and parameter handling for the gh-cli-pr-comments skill — PowerShell 7+ only."

`uncompressed.md` lines 6–25 already name and scope the skill completely. The opening sentence of each instructions file restates the skill name and "Bash/pwsh only" qualifier. The shell qualifier is redundant with the `## Route by shell` section in `uncompressed.md` and with the file name itself.

**Diff proposal:** Delete the subtitle paragraph (line 3) from each instructions file. The H1 (`# GH CLI PR Comments (Bash)`) is sufficient orientation.

#### Cat 5 — Constraint Duplication

`uncompressed.md` line 29:
> "On add: comment URL string. On edit/delete: exit code 0 on success. On list: JSON array of comment objects."

`instructions.bash.uncompressed.md` lines 104–111: Safety Classification table + trailing constraint paragraph (line 111):
> "Destructive operations require explicit operator authorization in the current session before execution. Approval from another agent does not constitute operator authorization."

`instructions.pwsh.uncompressed.md` lines 104–111: identical Safety Classification table and identical trailing constraint paragraph.

The safety rule "Destructive operations require explicit operator authorization..." is a global invariant that belongs in the SKILL.md (or a shared parent). Neither shell-specific file should restate it.

**Diff proposal:** Delete Safety Classification table and trailing paragraph from both instructions files (`instructions.bash.uncompressed.md` lines 103–111, `instructions.pwsh.uncompressed.md` lines 103–111). Move the table to `uncompressed.md` as a new `## Safety Classification` section after `## Return`.

#### Cat 6 — Cross-Shell Duplication

Sections in bash that are **structurally identical** to pwsh (differing only in syntax markers):

| Section | bash lines | pwsh lines | Identical content |
|---|---|---|---|
| `## Inputs` table | 5–13 | 5–13 | All 5 rows identical |
| `## Editing a Comment` prose | 50–51 | 50–51 | "`gh pr comment` has no `--edit` flag. Use the REST API directly." |
| `## Listing Comments` prose | 77–78 | 77–78 | "`gh pr view --comments` truncates and misses later pages." |
| `## Resolving Review Threads` prose | 94–96 | 94–96 | "There is no `gh pr` command for resolving review threads." |
| Safety Classification table structure | 103–110 | 103–110 | All 4 rows, identical Classes and Notes |

The prose rationale in Editing, Listing, and Resolving sections is shell-agnostic and could live in `uncompressed.md` once, with instructions files containing only the syntax-specific command blocks.

---

### 2.2 gh-cli-pr-create

**Source:** `gh-cli-pr\gh-cli-pr-create\`

#### Cat 1 — Input Redefinition

`uncompressed.md` lines 8–18 define the Inputs table (7 rows: OWNER, REPO, BASE, TITLE, BODY, LABEL, DRAFT).

`instructions.bash.uncompressed.md` lines 5–15 restate an identical 7-row table. Note: `uncompressed.md` line 16 carries the note "written to temp file before use" on BODY; the bash file strips that note (line 13: "PR body markdown"). Minor semantic divergence on top of the redundancy.

`instructions.pwsh.uncompressed.md` lines 5–15 restate the same 7-row table (also drops the "written to temp file" note on BODY).

**Diff proposal:** Delete `## Inputs` section from both instructions files (bash lines 5–15, pwsh lines 5–15). `uncompressed.md` is already authoritative. Restore the dropped BODY note to `uncompressed.md` if it was intentional.

#### Cat 3 — Scope Restatement

`instructions.bash.uncompressed.md` line 3:
> "Execution sequence and parameter handling for the gh-cli-pr-create skill — Bash shell only."

`instructions.pwsh.uncompressed.md` line 3:
> "Execution sequence and parameter handling for the gh-cli-pr-create skill — PowerShell 7+ only. Windows PowerShell 5.1 is NOT supported."

Same pattern as gh-cli-pr-comments. Scope and shell restriction already implicit in file name and `## Route by shell` section.

**Diff proposal:** Delete line 3 from each instructions file. Optionally promote "Windows PowerShell 5.1 is NOT supported" to `uncompressed.md` `## Route by shell` section.

#### Cat 5 — Constraint Duplication

`instructions.bash.uncompressed.md` lines 99–106: Safety Classification table (4 rows) + trailing authorization sentence.
`instructions.pwsh.uncompressed.md` lines 99–106: identical table and sentence.

**Diff proposal:** Same as gh-cli-pr-comments — consolidate to `uncompressed.md`, remove from both instruction files.

#### Cat 6 — Cross-Shell Duplication

| Section | bash lines | pwsh lines | Identical content |
|---|---|---|---|
| `## Inputs` table | 5–15 | 5–15 | 7 rows identical |
| `## Check for Existing PR` prose | 25–31 | 25–31 | "do not create a duplicate" gate |
| Safety Classification table | 99–106 | 99–106 | All 4 rows identical |
| Exit code semantics doc | 61–64 | 62–65 | Codes 0/2/4 with same text |
| `## Promoting a Draft to Ready` prose | 81–82 | 80–81 | "promote it using the PR number" |

---

### 2.3 gh-cli-pr-review

**Source:** `gh-cli-pr\gh-cli-pr-review\`

#### Cat 1 — Input Redefinition

`uncompressed.md` lines 8–17 define the Inputs table (6 rows: OWNER, REPO, PR_NUMBER, DECISION, BODY_FILE, REVIEW_ID).

`instructions.bash.uncompressed.md` lines 5–13 restate an identical 6-row table.
`instructions.pwsh.uncompressed.md` lines 5–13 restate an identical 6-row table.

**Diff proposal:** Delete `## Inputs` section from both instructions files (lines 5–13 each).

#### Cat 2 — Return Contract Missing from SKILL, but Return Stated in Instructions

`uncompressed.md` has no `## Return` section — the return contract is absent at the SKILL level. Both instructions files do not restate a return section either. This is a gap rather than a redundancy: the SKILL source has no authoritative return definition. (Flagging as a gap, not a redundancy hit.)

#### Cat 3 — Scope Restatement

`instructions.bash.uncompressed.md` line 3: scope subtitle, same pattern.
`instructions.pwsh.uncompressed.md` line 3: scope subtitle + "Windows PowerShell 5.1 is NOT supported."

**Diff proposal:** Delete line 3 from each file.

#### Cat 5 — Constraint Duplication

`instructions.bash.uncompressed.md` lines 92–102: Safety Classification table (6 rows) + trailing authorization sentence.
`instructions.pwsh.uncompressed.md` lines 92–102: identical.

**Diff proposal:** Move to `uncompressed.md`, remove from both instruction files.

#### Cat 6 — Cross-Shell Duplication

| Section | bash lines | pwsh lines | Identical content |
|---|---|---|---|
| `## Inputs` table | 5–13 | 5–13 | 6 rows identical |
| `## Decision Mapping` table | 53–59 | 53–59 | All 4 rows identical |
| `## No URL on Success` prose | 62–65 | 62–65 | "review.sh/review.ps1 retrieves the PR URL via follow-up call" |
| `## Resolving Review Threads` prose | 81–83 | 81–83 | "There is no `gh pr` command..." |
| Safety Classification table | 92–101 | 92–101 | All 6 rows identical |
| Exit code semantics | 47–50 | 47–50 | Codes 0/2/4 identical |

`## Decision Mapping` and `## No URL on Success` are entirely shell-agnostic and belong in `uncompressed.md` once. Currently duplicated verbatim across both files.

---

### 2.4 gh-cli-pr-inline-comment-post

**Source:** `gh-cli-pr\gh-cli-pr-inline-comment\gh-cli-pr-inline-comment-post\`

Note: This skill uses a dispatch pattern (not a bare router), but the same redundancy principle applies because the instructions files are still continuations of the loaded SKILL context.

#### Cat 1 — Input Redefinition

`uncompressed.md` lines 8–20 define the Inputs table (8 rows: OWNER, REPO, PR_NUMBER, FILE_PATH, LINE_NUMBER, BODY, SIDE, START_LINE).

`instructions.bash.uncompressed.md` lines 5–15 restate 7 rows (START_LINE is absent — silent drop).
`instructions.pwsh.uncompressed.md` lines 5–15 restate 7 rows (START_LINE absent — same silent drop).

The dropped START_LINE parameter is a silent divergence: the SKILL advertises it, the instructions never handle it. This is both a redundancy and a spec gap.

**Diff proposal:** Delete `## Inputs` section from both instruction files (lines 5–15 each). Address START_LINE omission in SKILL `uncompressed.md` or add it to both instruction files' Step 5 invocation.

#### Cat 2 — Return Contract Redefinition

`uncompressed.md` lines 39–42: Return section with the full JSON shape.

`instructions.bash.uncompressed.md` lines 124–139: `## Return` section restates the full JSON shape across 5 cases.
`instructions.pwsh.uncompressed.md` lines 125–140: `## Return` section restates the same full JSON shape across 5 cases.

The SKILL-level `## Return` is a single canonical compact block. Both instruction files then expand it into 5 named cases — this is the heaviest return-contract duplication in the audit.

**Diff proposal:** The case-by-case breakdown is operationally useful but belongs in `uncompressed.md` as an expanded `## Return` section, not duplicated in both instruction files. Delete `## Return` sections from both instruction files (bash lines 124–139, pwsh lines 125–140). Expand `uncompressed.md` return section to include the 5 cases once.

#### Cat 3 — Scope Restatement

`instructions.bash.uncompressed.md` line 3: scope subtitle.
`instructions.pwsh.uncompressed.md` line 3: scope subtitle + "Windows PowerShell 5.1 is NOT supported."

**Diff proposal:** Delete line 3 from each file.

#### Cat 5 — Constraint Duplication

`instructions.bash.uncompressed.md` line 58:
> "WINDOWS / Git Bash: Never use a leading `/` in `gh api` paths — Git Bash rewrites `/repos/...` as a filesystem path. Use `repos/...` not `/repos/...`."

`instructions.pwsh.uncompressed.md` line 58:
> "WINDOWS: Never use a leading `/` in `gh api` paths — PowerShell on Windows does not rewrite paths like Git Bash, but bare `gh api` calls still require `repos/...` not `/repos/...` for consistency and portability."

Both state the same constraint (no leading slash in `gh api` paths) from different perspectives. This is not truly duplicated between files since the rationale differs by shell, but the rule itself is shared. Consider lifting the rule to `uncompressed.md` with a single note, then leaving only the shell-specific nuance in each file.

#### Cat 6 — Cross-Shell Duplication

| Section | bash lines | pwsh lines | Identical content |
|---|---|---|---|
| `## Inputs` table | 5–15 | 5–15 | 7 rows identical (both silently omit START_LINE) |
| Step 1 prose | 24–25 | 24–25 | "Always fetch fresh — stale SHAs cause 422 errors." |
| Step 2 prose | 32–37 | 32–37 | File-in-diff check + stop rule |
| Step 3 prose | 41–43 | 41–43 | "Use the bundled tool — do not parse the diff manually." + SIDE default |
| Exit code semantics (Step 3) | 50–56 | 50–56 | All 5 codes identical |
| Step 4 prose | 60–68 | 60–68 | Deduplication query intent + return shape |
| `## Return` section | 124–139 | 125–140 | All 5 cases identical text |

The step prose (Steps 1–4 rationale) is shell-agnostic and could live in `uncompressed.md` once. Instructions files would then contain only the syntax-specific command blocks per step.

---

### 2.5 gh-cli-issues

**Source:** `gh-cli-issues\`

#### Cat 1 — Input Redefinition

`uncompressed.md` lines 8–18 define the Inputs table (7 rows: OWNER, REPO, ISSUE_NUMBER, TITLE, BODY, COMMENT_ID, LABELS).

`instructions.bash.uncompressed.md` lines 5–15 restate an identical 7-row table.
`instructions.pwsh.uncompressed.md` lines 5–15 restate an identical 7-row table.

**Diff proposal:** Delete `## Inputs` section from both instruction files (lines 5–15 each).

#### Cat 3 — Scope Restatement

`instructions.bash.uncompressed.md` line 3: scope subtitle.
`instructions.pwsh.uncompressed.md` line 3: scope subtitle + "Windows PowerShell 5.1 is NOT supported."

**Diff proposal:** Delete line 3 from each file.

#### Cat 5 — Constraint Duplication

`instructions.bash.uncompressed.md` lines 173–189: Safety Classification table (10 rows) + trailing authorization sentence (line 189).
`instructions.pwsh.uncompressed.md` lines 168–184: identical 10-row table and trailing sentence.

This is the largest Safety Classification table in the audit and is duplicated wholesale.

**Diff proposal:** Move to `uncompressed.md` as `## Safety Classification`, remove from both instruction files.

#### Cat 6 — Cross-Shell Duplication

| Section | bash lines | pwsh lines | Identical content |
|---|---|---|---|
| `## Inputs` table | 5–15 | 5–15 | 7 rows identical |
| `## Editing a Comment` prose | 104–106 | 99–101 | "`gh issue comment` has no `--edit` flag." |
| `## Deleting a Comment` header + command | 124–126 | 119–121 | Identical REST DELETE call |
| `## Viewing an Issue` header | 130–131 | 125–126 | Same command, same args |
| `## Closing and Reopening` header | 152–154 | 147–149 | Two commands, identical args |
| `## Transferring` header | 158–160 | 153–155 | Identical command + args |
| Safety Classification table | 173–189 | 168–184 | All 10 rows identical |

`## Editing a Comment` rationale, `## Deleting a Comment`, `## Viewing an Issue`, `## Closing and Reopening`, and `## Transferring` are shell-agnostic prose plus nearly identical command signatures. Only the `gh issue list` (Bulk Operations with `xargs` vs `ForEach-Object`) section has genuine shell-specific content.

---

## 3. Inheritance Principle

An `instructions.<shell>.uncompressed.md` file is a **continuation** of the SKILL context already loaded in the agent's window. By the time the agent reads it, `uncompressed.md` is already in context — every parameter name, every Required flag, every return shape, every scope statement is already known. The instructions file's sole job is to provide the **shell-specific execution sequence**: command syntax, tool invocation patterns, temp-file idioms, and exit-code handling specific to that runtime. It must not restate inputs (the agent already has them), must not restate the return contract (already defined), must not repeat the safety rule (a global invariant), and must not introduce a scope paragraph that the file name and H1 already communicate. Any prose that is identical between the bash and pwsh files is by definition shell-agnostic and belongs in `uncompressed.md` once.

---

## 4. Quick-Win Order (by Redundancy Density)

Density = total hits ÷ number of instruction-file lines (rough proxy for redundancy per line of content).

| Rank | Skill | Total hits | Notes |
|---|---|---|---|
| 1 | **gh-cli-pr-inline-comment-post** | 14 | Highest absolute count; also has the Cat 2 return-contract duplication and START_LINE spec gap. Best ROI: deleting `## Inputs` + `## Return` from both instruction files removes ~32 lines of pure duplication and fixes the spec gap simultaneously. |
| 2 | **gh-cli-issues** | 13 | Largest Safety Classification table (10 rows) duplicated verbatim; deleting it from both instruction files is the single biggest line-count reduction across the audit (~34 lines). |
| 3 | **gh-cli-pr-review** | 12 | `## Decision Mapping` and `## No URL on Success` sections are 100% shell-agnostic; moving them to `uncompressed.md` eliminates 2 full sections from each instruction file. Also has the `## Return` gap that should be addressed. |
| 4 | **gh-cli-pr-comments** | 11 | Tied with gh-cli-pr-create; fix order can go either way. No exotic issues. |
| 5 | **gh-cli-pr-create** | 11 | Minor semantic divergence on BODY note (see Cat 1) worth preserving when editing. |

**Lowest-hanging fruit across all skills:** The `## Inputs` table deletion pattern is mechanically identical for all 5 skills (10 file edits, no judgment calls). Each deletion is ~9–11 lines per file with zero risk of content loss. Do all 10 in a single pass before tackling Safety Classification consolidation or Return section moves.
