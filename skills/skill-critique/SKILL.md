---
name: skill-critique
description: Quality critic for a skill — judges whether it does what it says, and does it well, then returns concrete refinements. Graded quality, not conformity. Distinct from skill-auditing. Triggers - critique this skill, skill quality, is this skill good, does this skill do what it says, refine this skill, quality critique, skill critic.
---

Quality critic for ONE target skill. Point it at a skill; get back a per-dimension
reading (a separate vector, for version-to-version comparison across drafts) plus a
prioritized list of concrete refinements. Headline question: does this skill do what
it says, and do it excellently? Graded judgment for the soft lenses, a raw token
count for efficiency — never binary conformity rules, which are `skill-auditing`'s
and this critic does not touch. Read-only. Run during skill-writing AFTER drafting,
before the conformity pass.

Input:
`<skill_dir>` — absolute path to the target skill folder.
`<tier>` (optional) — `fast-cheap` (default) | `standard` | `deep`

Inspect:
`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<report_path>` = absolute path for the critique report
`<input-args>` = `skill_dir=<skill_dir> --report-path <report_path>`
`<tier>` = the tier input, else `fast-cheap` (haiku). Reserve `deep` (opus) for a final pass, unless otherwise decided.
`<description>` = `Critiquing skill: <skill_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Size (no tier input only): in `<skill_dir>`, Bash `cat SKILL.md instructions.txt spec.md uncompressed.md instructions.uncompressed.md 2>/dev/null | wc -c`, PS7 `(Get-Item SKILL.md,instructions.txt,spec.md,uncompressed.md,instructions.uncompressed.md -EA 0 | Measure-Object Length -Sum).Sum`. Above 10240 → merge run, else single run. An explicit tier is always a single run.

Cache check:
Run `result.sh <skill_dir> <tier>` (Bash) or `result.ps1 <skill_dir> <tier>` (PS7) from skill-critique folder. A merge run uses `fast-cheap-x3` as `<tier>` here; its dispatch calls still use `fast-cheap`.
`MISS: <abs-path>` → bind `<report_path>` = `<abs-path>`, dispatch.
Any other stdout → emit verbatim; stop.

Merge run (on MISS): dispatch three `fast-cheap` executors, each with its own `<report_path>` in a scratch directory (no result call for them). Write the merged report at `<abs-path>`: base = the run with the strictest recommendation (ITERATE, then BORDERLINE, then READY; ties run 1), kept whole, its `CRITIQUE:` line is this call's result; refinements = the union of the three lists, a defect found by several runs listed once.

Follow dispatch skill. See `../dispatch/SKILL.md`.

Post-execute: run the result call again, same args, to register the report in the hash-record.

Returns (last line of stdout):
`CRITIQUE: <READY|BORDERLINE|ITERATE> | <dim>=<v> <dim>=<v> ... robustness=<n> decomposition=<v>` (one token per dimension plus decomposition verdict, headline first; soft dimensions emit a 0–5 score, efficiency emits a raw count) or `ERROR: <reason>`.

`ITERATE` → load `../dispatch/SKILL.md`, dispatch a `standard`-tier agent to apply the report's refinements, re-run this critique with the same tier input. Repeat until `READY` (or `BORDERLINE` accepted); a final pass at `standard` or `deep` is the caller's choice.
`ERROR: <reason>` → surface stdout, stop.

Related: `skill-auditing` (conformity layer, runs after), `skill-writing` (invokes this as the quality-iteration phase), `skill-optimize` (compression), `dispatch` (launch).
