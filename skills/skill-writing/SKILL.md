---
name: skill-writing
description: How to write skills. Decision tree for inline vs dispatch, structure, quality criteria. Triggers — write a skill, author SKILL.md, create new skill, draft skill file, implement skill spec.
---

Create skills agents can discover, invoke, rely on.
NEVER reference `spec.md` at runtime. Minimize tokens.

Workflow: new skill — follow order. NEVER skip steps.

1. Spec first — write `spec.md` via `spec-writing`. Defines what skill does, requirements, constraints, acceptance criteria. Simple inline skill under ~30 lines with no design decisions worth recording may omit `spec.md` entirely.
2. Write uncompressed — write `uncompressed.md` derived from spec. Human-readable baseline.
3. Markdown hygiene — run `markdown-hygiene` on every uncompressed source file (`uncompressed.md`, `instructions.uncompressed.md` if present). Zero errors required before proceeding.
4. Intermediate audit — dispatch `skill-auditing --uncompressed` on skill. FAIL → fix all findings → re-audit. Repeat until PASS.
5. Compress — use `compression` skill (source→target mode: `--source uncompressed.md --target SKILL.md`). `SKILL.md` = compressed runtime agents load.
6. Quality iteration — run `skill-critique` (dispatch skill) on draft. Iterate on refinements until READY: sonnet (standard-tier) passes until exhausted, then one opus-class final pass. THEN proceed to final audit.
7. Final audit — dispatch `skill-auditing` (standard mode) on `SKILL.md`. FAIL → fix all findings → recompress → re-audit. Repeat until PASS.
8. Eval verification (MANDATORY GATE) — dispatch haiku-class sub-agent (via `dispatch`) against known-good input; ask whether skill did what it says (yes/no); record run in `eval.md`. Required before skill complete (R-EV-1).

Dispatch skills: also write companion instruction source file (see Dispatch Skill section).

Durable Artifacts and Hash-Record Integration:

R-HR-1: skill producing durable audit/findings/result artifact — report, verdict, record meant to persist, read back across invocations — its `spec.md` MUST require `hash-record` integration: probe by content hash before running, write on miss, return cached record on hit. See `hash-record` skill (`../hash-record`) for hash construction, Probe/Read/Write/Invalidate API. `skill-auditing`, `markdown-hygiene`, `skill-critique` = reference exemplars — each wraps `result` sub-skill around `hash-record`.

R-HR-2: multi-file artifact bundles (e.g. swarm review composing N personality outputs) MUST use `manifest` sub-skill (part of `hash-record`, `../hash-record`) to compute combined cache key. Single-file artifacts use direct `hash-record` `check` sub-skill instead.

Eval Verification (Mandatory):

R-EV-1: every newly-written skill ships `eval.md`: at least one run proving skill executes. Revision bumping declared spec version, or otherwise changing runtime behavior, MUST also refresh `eval.md`. Pattern: dispatch haiku-class sub-agent (via `dispatch`) against known-good input; ask binary question — did it work? — record answer. Distinct from `skill-eval` skill (multi-trial, multi-model benchmarking) — R-EV-1 needs only one minimal proof-of-execution run.

R-EV-2: `eval.md` shape — H1 `# Eval log`; one `##` section per run: date, dispatch invocation (prompt + model tier), expected outcome, observed outcome, verdict (yes/no + one-line reason). Template:

```markdown
# Eval log

## <YYYY-MM-DD> — <run label>

- Dispatch: `<prompt sent to the sub-agent>` @ haiku-class
- Expected: <what a correct run looks like>
- Observed: <what actually happened>
- Verdict: <yes/no> — <one-line reason>
```

R-EV-3: producing `eval.md` is skill author's deliverable (step 8 in both creation and revision workflows), NEVER caller's. Author may dispatch haiku-class sub-agent as eval target itself.

Eval Readiness: skills evaluated L1 (haiku-class) vs L2 (sonnet-class). `eval.md` mandatory per R-EV-1 regardless of frequency — this decision rule governs how much more goes into it, not whether it exists.

High-frequency (many files per run or many dispatches per session): invest in haiku-class readiness; add specificity until haiku catches what sonnet catches; log L1/L2 round results in `eval.md`, alongside mandatory entry.
Low-frequency / one-off (once per skill, once per file, infrequent): sonnet-class fine; `eval.md` still carries mandatory R-EV-1 entry; L1/L2 comparison rounds not required.
Examples: markdown-hygiene, code-review = high-frequency (haiku-readiness justified); compression = low-frequency (sonnet fine).

Completion Gate: skill not done until Intermediate, Quality, Final, Eval gates all pass.

Intermediate gate (step 4): `skill-auditing --uncompressed` on `uncompressed.md` must PASS before compression runs. FAIL → fix → re-audit. NEVER compress failing `uncompressed.md`.
Quality gate (step 6): `skill-critique` must return READY (or accepted BORDERLINE) before final audit runs. ITERATE → apply refinements → recompress → re-critique.
Final gate (step 7): `skill-auditing` (standard) on `SKILL.md` must PASS. FAIL → fix source (`uncompressed.md`) → recompress → re-audit.
Eval gate (step 8): `eval.md` must document at least one dispatch run + verdict (R-EV-1). No exception for low-frequency skills — see Eval Readiness for what's optional vs mandatory.

DO NOT declare skill complete, commit it, or hand off until final standard-mode PASS verdict AND `eval.md` run both in hand. No exceptions. Receiving FAIL and stopping work = workflow violation.

Revising existing skill: ALWAYS update spec first. Exception: changes limited to non-normative content (README, examples, typo fixes in informational sections) — skip to step 2. Then update `uncompressed.md` → hygiene → intermediate audit (`--uncompressed`) → compress → critique → final audit → eval (if revision bumped version or changed behavior, refresh `eval.md`, R-EV-1). NEVER modify `SKILL.md` directly — compiled artifact.

Error Handling:

Duplicate name: check existing skills before writing (step 1). Skill already exists with proposed name → use revision workflow instead of creating new one.
Audit never reaches PASS: don't silently accept stalled audit — report blockage, escalate. Never ship skill with unresolved CRIT/HIGH findings.
Dispatch unavailable: no dispatch channel reachable → record exception; host may self-execute steps 2–4; triage routing defect afterward.
Sign-off regression: new CRIT/HIGH findings during Final gate (step 7) return to iteration — don't declare complete until clean.

Inline vs Dispatch: "Could someone with no context do this from just inputs?" Yes → dispatch. No → inline.

Inline = needs caller's context, judgment, creative intent; inline skills don't need dispatch mechanics.
Dispatch = mechanical processing against rules; use Dispatch agent (zero context).

Skill Folder Convention:

```text
skill-name/
├── SKILL.md            ← compressed runtime (what agents load)
├── instructions.txt    ← dispatch procedure (dispatch skills only)
├── uncompressed.md     ← human-readable baseline
├── agents/             ← optional: agent files shipped with the skill
├── installation.md     ← optional: install notes
└── spec.md             ← normative spec (never at runtime)
```

`instructions.txt` present = dispatch skill. Absent = inline.
`agents/` present = skill ships agent; plugin build hoists it to plugin-root `agents/` folder.

Inline Skill: `SKILL.md` IS full instruction set. Agent reads, applies directly.

Dispatch Skill (Routing Card): `SKILL.md` = minimal routing card. `instructions.txt` holds procedure.

Dispatch via Dispatch agent: "Read and follow `instructions.txt`. Input: `<params>`"

Parameters: types, required/optional, defaults. Output format specified.

Routing card = invocation signature + output format. Stop gates (refusal conditions, git-clean checks, path escape guards, eligibility rules) belong in `instructions.txt` only, not routing card.

Dispatch instruction file must be in same dir or known path. Compressed `instructions.txt` contains only instructions — no title headers, no descriptions, no preamble. Uncompressed baseline `instructions.uncompressed.md` may include H1 title so markdown-hygiene passes (MD041); after compression, strip title. When invoking markdown-hygiene on `SKILL.md`, pass `--ignore MD041` (no H1 sanctioned per R-FM-3).

Requirements: rules every skill must satisfy.

Naming: dir name = kebab-case, equal to `name` frontmatter field. Discovery matches folder name to frontmatter name; mismatch makes skill unreachable.
Nested sub-skills under parent skill folder must use fully-qualified names including parent as prefix. Example: under `electrified-cortex/skill-index/`, children are `skill-index-auditing/`, `skill-index-building/` — not bare `auditing/`, `building/`. Pure router intermediates (e.g. `github/`) may use bare folder names for children (`actions/`, `api/`) since only reachable via router — bare names don't need prefix there.
NEVER use "SKILL" in any filename except `SKILL.md`.

Content: frontmatter = `name` + `description`.
Description carries trigger phrases (3-6): name situations or keywords that should fire skill. Shy descriptions undertrigger; pushy descriptions trigger correctly. Trigger phrases double as index keywords downstream.
Self-contained: no spec dependency at runtime.
Concise: agent-facing, every line earns its place (proxy: if removing a line wouldn't change what agent does, cut it).
Token-efficient: no prose, no rationale, no redundancy.
No "why": rationale belongs in `spec.md`; skills state what, not why.
Decision trees not prose: conditional logic uses tables or decision trees, not paragraphs.
Breadcrumbs: end with related skills (verified, not stale).
No secrets.
No cross-file-path references to sibling skill internals (R-FM-11).

R-FM-11 — No Cross-File-Path References: skill files MUST NOT reference another skill's `uncompressed.md` or `spec.md` by file path. Every such pointer is load invitation — even uncompressed-to-uncompressed references compound bloat.

Allowed: own `instructions.txt`, sub-instructions, `tooling.md` in same folder; sibling skill by name (`"see the compression skill"`).

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

Footgun Mirroring: if companion spec has `Footguns` section, mirror in `uncompressed.md`/`SKILL.md`: preserve all F#: entries, Mitigation: lines, ANTI-PATTERN: examples.

Canonical reference: `dispatch` skill.

Related:
`spec-writing` — write spec first (step 1 of workflow)
`markdown-hygiene` — run on uncompressed sources (step 3)
`skill-auditing` — intermediate + final audits
`compression` — compress `uncompressed.md` to `SKILL.md` (step 5)
`skill-critique` — quality iteration on draft until READY (step 6)
`dispatch` — dispatch mechanics (decision tree, model tiers, prompt construction); read before writing any dispatch skill
`hash-record` — durable-artifact cache substrate for skills producing audit/findings/result artifacts (R-HR-1/R-HR-2)
`skill-eval` — multi-trial, multi-model benchmarking; separate from single mandatory `eval.md` run (R-EV-1)
