---
name: skill-writing
description: How to write skills. Decision tree for inline vs dispatch, structure, quality criteria. Triggers — write a skill, author SKILL.md, create new skill, draft skill file, implement skill spec.
---

Create skills agents can discover, invoke, rely on.
Never reference `spec.md` at runtime. Minimize tokens.

Frontmatter description carries 3-6 trigger phrases — name the
situations or keywords that should fire the skill. Shy descriptions
undertrigger; pushy descriptions trigger correctly. Trigger phrases
double as index keywords.

## Workflow

New skill — follow order. Never skip steps.

1. Spec first — write `spec.md` via `spec-writing`. Defines requirements, constraints, acceptance criteria.
2. Write `uncompressed.md` from spec. Human-readable baseline. For dispatch skills: also write `instructions.uncompressed.md`.
3. Markdown hygiene — run `markdown-hygiene` on every uncompressed source file (`uncompressed.md`, and `instructions.uncompressed.md` if present). Zero errors required before proceeding.
4. Intermediate audit — `skill-auditing --uncompressed` on the skill. FAIL → fix source → re-audit. Repeat until PASS.
5. Compress via `compression` skill (`--source uncompressed.md --target SKILL.md`; same for instructions if dispatch). SKILL.md = compressed runtime.
6. Pre-submit dispatch gate — load `skill-auditing/SKILL.md` and follow the dispatch pattern it describes on the completed skill folder. Do not declare done without a returned PASS. FAIL → fix source → recompress → re-dispatch until PASS.

Dispatch skills: companion instruction source file written in step 2; both compressed in step 5.

Eval Readiness:
High-frequency (many files/dispatches per session) → invest in haiku-class readiness; add specificity until haiku catches what sonnet catches; drop `eval.md` to log rounds.
Low-frequency / one-off → sonnet-class is fine; `eval.md` not required.
Examples: markdown-hygiene, code-review = high-frequency (haiku justified). compression = low-frequency (sonnet fine).

Completion Gate:
NOT done until both audits return PASS. Intermediate gate (step 4): PASS required before compression. Final gate (step 6): PASS required — skill-auditing MUST be dispatched (not applied inline); do not submit without a returned PASS. No exceptions. Receiving FAIL and stopping is a workflow violation.

Revising: update spec first. Exception: non-normative changes (README, examples, typo fixes) → skip to step 2. Update `uncompressed.md` → hygiene → intermediate audit (`--uncompressed`) → compress → final audit. Never modify SKILL.md directly — compiled artifact.

## Decision: Inline or Dispatch

"Could someone with no context do this from just inputs?" Yes → dispatch. No → inline.

Inline = needs caller's context, judgment, creative intent. Inline skills don't need dispatch mechanics.
Dispatch = mechanical processing against rules. Use Dispatch agent (zero context).

## Skill Folder Convention

```text
skill-name/
├── SKILL.md            ← compressed runtime (what agents load)
├── instructions.txt    ← dispatch procedure (dispatch skills only)
├── uncompressed.md     ← human-readable baseline
└── spec.md             ← normative spec (never at runtime)
```

`instructions.txt` present = dispatch skill. Absent = inline.

## Inline Skill

SKILL.md IS the full instruction set. Agent reads and applies directly.

## Dispatch Skill (Routing Card)

SKILL.md = minimal routing card. `instructions.txt` holds procedure.
Dispatch via Dispatch agent: "Read and follow `instructions.txt`. Input: `<params>`"
Parameters: types, required/optional, defaults. Output format specified.

Dispatch instruction file must be in same dir or known path.
Compressed `instructions.txt`: only instructions — no title headers, no descriptions, no preamble. `instructions.uncompressed.md` MAY include H1 title for markdown-hygiene (MD041); strip after compression. When running markdown-hygiene on `SKILL.md`, pass `--ignore MD041` (no H1 sanctioned per R-FM-3).

## Requirements

### Naming

Dir name = kebab-case, equal to `name` frontmatter. Mismatch → skill unreachable.
Nested sub-skills must use fully-qualified names including parent prefix. Example: under `electrified-cortex/skill-index/`, children are `skill-index-auditing/`, `skill-index-building/` — not bare `auditing/`, `building/`. Ref: `electrified-cortex/gh-cli/` (`gh-cli-actions`, `gh-cli-api`). Bare unqualified names don't resolve.
Never use "SKILL" in any filename except `SKILL.md`.

### Content

Frontmatter: `name` + `description`
Self-contained: no spec dependency at runtime
Concise: agent-facing, every line earns place
Token-efficient: no prose, no rationale, no redundancy
Breadcrumbs: end with related skills (verified, not stale)
No secrets
No cross-file-path refs to sibling skill internals (R-FM-11): FORBIDDEN: `../other-skill/uncompressed.md` or `../other-skill/spec.md` in any skill artifact. ALLOWED: own `instructions.txt`; sibling by skill name ("see the `compression` skill").

Verify with `skill-auditing`. Flags markdown issues.

## Footgun Mirroring

If companion spec has `Footguns` section, mirror it in `uncompressed.md`/`SKILL.md`:
Preserve all F#: entries, Mitigation: lines, ANTI-PATTERN: examples.
Canonical ref: `dispatch` skill.

## Related

`spec-writing` — write spec first (step 1)
`markdown-hygiene` — run on uncompressed sources (step 3)
`skill-auditing` — intermediate (step 4) + final (step 6) audits
`compression` — compress `uncompressed.md` → SKILL.md (step 5)
`dispatch` — dispatch mechanics; read before writing any dispatch skill
