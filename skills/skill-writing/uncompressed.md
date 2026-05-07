---
name: skill-writing
description: How to write skills. Decision tree for inline vs dispatch, structure, quality criteria. Triggers — write a skill, author SKILL.md, create new skill, draft skill file, implement skill spec.
---

# Skill Writing

Create skills agents can discover, invoke, rely on.
Never reference `spec.md` at runtime. Minimize tokens.

## Workflow

When creating a new skill, follow this order. Never skip steps.

1. **Spec first** — write `spec.md` using the `spec-writing` skill. The
   spec defines what the skill does, its requirements, constraints, and
   acceptance criteria.
2. **Write uncompressed** — write `uncompressed.md` derived from the
   spec. This is the human-readable baseline.
3. **Markdown hygiene** — run the `markdown-hygiene` skill on
   every uncompressed source file (`uncompressed.md`, and
   `instructions.uncompressed.md` if present). Zero errors required
   before proceeding.
4. **Intermediate audit** — dispatch `skill-auditing --uncompressed` on the skill.
   FAIL → fix all findings → re-audit. **Repeat until PASS.**
5. **Compress** — use the `compression` skill (source→target mode:
   `--source uncompressed.md --target SKILL.md`). The SKILL.md is the
   compressed runtime agents load.
6. **Final audit** — dispatch `skill-auditing` (standard mode) on `SKILL.md`.
   FAIL → fix all findings → recompress → re-audit. **Repeat until PASS.**

For dispatch skills, also write the companion instruction source file (see
Dispatch Skill section).

### Eval Readiness

Skills are evaluated L1 (haiku-class) vs L2 (sonnet-class).

- **High-frequency** (many files per run or many dispatches per session):
  invest in haiku-class readiness.
  Add specificity until haiku catches what sonnet catches.
  Drop `eval.md` to log L1/L2 round results.
- **Low-frequency / one-off** (once per skill, once per file, infrequent):
  sonnet-class is fine. `eval.md` not required.

Examples: markdown-hygiene and code-review are high-frequency — haiku-readiness
justified. compression is low-frequency — sonnet fine.

### Completion Gate

> **The skill is NOT done until both audits return PASS.**

Intermediate gate (step 4): `skill-auditing --uncompressed` on `uncompressed.md`
must PASS before compression runs. FAIL → fix → re-audit. Never compress a
failing `uncompressed.md`.

Final gate (step 6): `skill-auditing` (standard) on `SKILL.md` must PASS.
FAIL → fix source (`uncompressed.md`) → recompress → re-audit.

Do not declare a skill complete, commit it, or hand it off until the final
standard-mode PASS verdict is in hand. There are no exceptions. Receiving FAIL
and stopping work is a workflow violation.

When revising an existing skill: always update the spec first. The only
exception is changes limited to non-normative content (README, examples,
typo fixes in informational sections) — in that case skip to step 2.
Then update `uncompressed.md` → hygiene → intermediate audit (`--uncompressed`)
→ compress → final audit. Never modify SKILL.md directly — it is a compiled
artifact.

## Decision: Inline or Dispatch

> "Could someone with no context do this from just the inputs?"
> **Yes** → dispatch. **No** → inline.

**Inline** = needs caller's context, judgment, creative intent. Inline skills don't need to understand dispatch mechanics.
**Dispatch** = mechanical processing against rules. Use Dispatch agent (zero context).

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

Dispatch via Dispatch agent: "Read and follow `instructions.txt`.
Input: `<params>`"

Parameters: types, required/optional, defaults. Output format specified.

Routing card = invocation signature + output format. Stop gates (refusal
conditions, git-clean checks, path escape guards, eligibility rules) belong in
`instructions.txt` only — not the routing card.

Dispatch instruction file must be in the same directory or a known path.
Compressed `instructions.txt` contains only instructions — no title
headers, no descriptions, no preamble. The uncompressed baseline
`instructions.uncompressed.md` MAY include an H1 title so markdown-hygiene
passes (MD041); strip the title after compression. When invoking
markdown-hygiene on `SKILL.md`, pass `--ignore MD041` (no H1 sanctioned
per R-FM-3).

## Requirements

### Naming

- Skill directory name = kebab-case and **equal to the `name` frontmatter
  field**. Discovery matches folder name to frontmatter name; a mismatch
  makes the skill unreachable.
- **Nested sub-skills** under a parent skill folder must use
  fully-qualified names that include the parent as a prefix. Example:
  under `electrified-cortex/skill-index/`, children are
  `skill-index-auditing/`, `skill-index-building/` — not bare
  `auditing/`, `building/`. Canonical reference: `electrified-cortex/gh-cli/`
  (`gh-cli-actions`, `gh-cli-api`, etc.). Bare unqualified names inside a
  parent folder do not resolve.
- Never use "SKILL" in any filename except `SKILL.md`.

### Content

- Frontmatter: `name` + `description`
- Description carries trigger phrases (3-6): name the situations or
  keywords that should fire the skill. Shy descriptions undertrigger;
  pushy descriptions trigger correctly. Trigger phrases double as
  index keywords downstream.
- Self-contained: no spec dependency at runtime
- Concise: agent-facing, every line earns its place
- Token-efficient: no prose, no rationale, no redundancy
- No "why": rationale belongs in `spec.md`; skills state *what*, not *why*
- Decision trees not prose: conditional logic uses tables or decision trees, not paragraphs
- Breadcrumbs: end with related skills (verified, not stale)
- No secrets
- No cross-file-path references to sibling skill internals (R-FM-11)

### R-FM-11 — No Cross-File-Path References to Sibling Skill Internals

Skill files MUST NOT reference another skill's `uncompressed.md` or `spec.md`
by file path. Every such pointer is a load invitation — even
uncompressed-to-uncompressed references compound bloat.

Allowed:

- Own `instructions.txt`, sub-instructions, `tooling.md` in the same folder
- Sibling skill by name: `"see the compression skill"`

Forbidden:

```text
See `../compression/uncompressed.md` for details.
Consult `../spec-writing/spec.md` for the format.
```

Allowed:

```text
Read and follow `instructions.txt` (in this directory).
For dispatch mechanics, read the `dispatch` skill.
```

Verify completed skills with `skill-auditing`. The audit flags any
markdown issues.

## Footgun Mirroring

If the companion spec has a `Footguns` section, mirror it in uncompressed.md/SKILL.md:

- Preserve all F#: entries, Mitigation: lines, and any ANTI-PATTERN: examples
- Canonical reference: `dispatch` skill

## Related

- `spec-writing` — write the spec first (step 1 of workflow)
- `markdown-hygiene` — run on uncompressed sources (step 3)
- `skill-auditing` — intermediate + final audits
- `compression` — compress uncompressed.md to SKILL.md (step 5)
- `dispatch` — dispatch mechanics (decision tree, model tiers, prompt construction); read before writing any dispatch skill
