---
name: iteration-safety
description: Rules for iterating audit, compression, hygiene, or review passes. Reference this skill from callers; do not embed these rules elsewhere. Triggers - iteration rules, re-audit rules, when to re-run a pass, prevent redundant re-runs, pass iteration safety.
---

## Rules

**Rule A — Fix before re-pass.** If a pass returns findings, resolve them (fix source, dispatch fix, or record accept/waive if the calling skill permits) before re-passing. Re-pass without resolving is forbidden.

**Rule B — Never re-pass on unchanged content.** "Never re-audit a file that has not been modified since the previous audit, period, full stop." Unchanged source → deterministic verdict → re-dispatch forbidden.

Rule B's opening sentence is verbatim. Do not reword.

## Caller obligations

Before re-dispatching, verify:

1. At least one source file changed since last pass.
2. Prior findings (if any) resolved or recorded.

Either check fails → do not re-dispatch.

## Cite

Callers embed this block (adjust the relative path to match the caller's folder depth):

```markdown
## Iteration Safety

Do not re-audit unchanged files.
See `../iteration-safety/SKILL.md`.
```

Do not copy Rules A or B text into caller specs — embed the pointer block above instead.
Do not restate Rule B's quote in callers.
