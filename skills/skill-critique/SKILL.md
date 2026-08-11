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

Inspect:
`<instructions>` = `instructions.txt` (NEVER READ)
`<instructions-abspath>` = absolute path to `<instructions>`
`<report_path>` = absolute path for the critique report
`<input-args>` = `skill_dir=<skill_dir> --report-path <report_path>`
`<tier>` = `standard` (sonnet) by default — the best fit for this quality judgment. Reserve `deep` (opus) for a final pass, unless otherwise decided. `fast-cheap` (haiku) is not appropriate: haiku hallucinates and suits only quick, obvious passes.
`<description>` = `Critiquing skill: <skill_dir>`
`<prompt>` = `Read and follow <instructions-abspath>; Input: <input-args>`

Cache check (Sonnet default pass only — skip for Haiku/Opus):
Run `result.sh <skill_dir>` (Bash) or `result.ps1 <skill_dir>` (PS7) from skill-critique folder.
`MISS: <abs-path>` → bind `<report_path>` = `<abs-path>`, dispatch.
Any other stdout → emit verbatim; stop.

Follow dispatch skill. See `../dispatch/SKILL.md`.

Post-execute (Sonnet default pass only): run result tool again to register the report in the hash-record.

Returns (last line of stdout):
`CRITIQUE: <READY|BORDERLINE|ITERATE> | <dim>=<v> <dim>=<v> ... robustness=<n> decomposition=<v>` (one token per dimension plus decomposition verdict, headline first; soft dimensions emit a 0–5 score, efficiency emits a raw count) or `ERROR: <reason>`.

`ITERATE` → load `../dispatch/SKILL.md`, dispatch a `standard`-tier agent to apply the report's refinements, re-run this critique. Repeat until `READY` (or `BORDERLINE` accepted). Sonnet passes until exhausted, then one `deep` (opus) pass.
`ERROR: <reason>` → surface stdout, stop.

Related: `skill-auditing` (conformity layer, runs after), `skill-writing` (invokes this as the quality-iteration phase), `skill-optimize` (compression), `dispatch` (launch).
