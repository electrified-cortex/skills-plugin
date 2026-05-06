---
name: swarm
description: Multi-personality review infrastructure — selects personalities, gates availability, dispatches in parallel, arbitrates, and synthesizes a verdict. Triggers — swarm review, multi-reviewer, parallel personalities, run all reviewers, arbitrate findings.
---

Inputs: `problem` (required artifact), `personality_filter` (inclusion list, bypasses triggers), `model_overrides` (model class only, not backend).

Caller tier: **sonnet-class minimum**. Host must build review packet, evaluate trigger conditions inline, and synthesize findings — haiku-class is insufficient.

## Step Sequence

S1. Build review packet from `problem`. Fields (omit if N/A): Goal, Approach, Key decisions, Artifacts (actual content — not references), Files affected, Blast radius, Conventions. Packet must be self-contained. Verify Goal is evaluable + Artifacts contain real content; resolve gaps from context — don't ask caller.

S2. Select personalities. Crawl `reviewers/` at runtime (metadata-validation gate: skip files with invalid/missing frontmatter). Append caller custom-menu entries. If `personality_filter` supplied: dispatch named only, triggers bypassed. If no filter: evaluate trigger conditions against packet traits; exclude non-matching. `required: true` personalities always included unless explicitly omitted by filter. Devil's Advocate carries `required: true`.

S3. Availability gate. For each selected personality with non-`dispatch-*` backend (e.g. `copilot-cli`): run availability probe. Pass → include. Fail → drop, note in synthesis, continue. Don't fail-stop. `dispatch-*` backends: no probe needed.

S4. Load reviewer prompts. Only after swarm finalized (post-S3). Load `reviewers/<kebab-name>.md` for dispatched personalities only. Don't load files for non-dispatched personalities.

S5. Dispatch. Issue all swarm personalities as single parallel batch via `dispatch` skill. Never sequential. Each dispatch receives: review packet + personality prompt + read-only constraint ("read-only review — analyze and report only, no file edits, no commits, no shell commands"). Model selection: `model_overrides` first → first available from `suggested_models` → fallback `sonnet-class`. Apply diversity rule B8 after selection. Tier: `standard` (evidence-cited findings require moderate reasoning). Description: `swarm-personality:<name>`. Should return: structured findings list — each finding with description + evidence cite; "No findings" is valid (treated as non-contributing per B4).

S6. Arbitrator. After all member outputs collected, dispatch single sonnet-class arbitrator (not in registry, not subject to filter/gating). Tier: `standard` (N-output comparison + judgment). Description: `swarm-arbitrator`. Input: all non-empty/non-timeout member outputs + review packet. Should return: structured two-section action list only — two sections:

- Obvious actions: 2+ members flagged same concern, or self-evident from artifact. Each: description + source personality indices + evidence cite.
- Critical actions: would block shipping or require arch change regardless of agreement count. Each: description + source personality indices + evidence cite + severity rationale.

No speculative, low-confidence, or duplicate items. If empty: state "No actionable findings".

S7. Aggregate. Collect findings from arbitrator's action list. Record per item: personality indices, summary, evidence. Identify disagree set: items where arbitrator flagged contradictory conclusions from different members on same point.

S8. Synthesize. Speak as host only — don't dump raw member or arbitrator output. Synthesize from arbitrator's action list only. Output template: `**Summary**: … / **Disagreements**: … / **Dropped personalities**: … / **Confidence rating**: High|Medium|Low — <rationale>`. Cap: 2000 words. If over: truncate — disagreements first, then high-severity, then medium, then low; note truncation.

## Confidence Rating

Default Medium. High: all personalities agree + all findings cite evidence. Low: disagree set has high-severity point, OR any personality returns no findings (including "No findings" response). If Low, state what would raise it.

## Behaviors

B1. `problem` empty or no resolvable artifact → return "No reviewable artifact found." Don't dispatch.

B2. Swarm empty after gating → return "Swarm empty after gating — no personalities available." Don't synthesize.
B3. Only Devil's Advocate in swarm → proceed, note "adversarial review only" in synthesis.
B4. Personality returns no findings or times out → non-contributing; exclude from synthesis; note in output.
B5. All personalities return no findings → state "No findings from any reviewer"; confidence Low.
B6. Devil's Advocate dispatched unless explicitly omitted by named `personality_filter`.
B7. Custom menu entries evaluated against caller-supplied trigger; "always" = include (subject to gating if external backend).
B8. Cross-vendor diversity best-effort: prefer at least one personality on different model family/vendor than host. If unavailable, proceed + note monoculture. Devil's Advocate is natural diversity carrier (`vendor: openai` in frontmatter, non-Anthropic `suggested_models` preference).

## Precedence

P1. `personality_filter` overrides trigger evaluation.

P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection (fail probe → drop).
P4. Read-only constraint (C1) overrides any personality instruction.
P5. 2000-word cap overrides completeness.

## Don'ts

Don't load prompts before swarm finalized. Don't use fixed roster. Don't fail-stop on unavailable personality. Don't dump raw output. Don't merge with/replace code-review. Don't dispatch sequentially. Don't use bare model names. Don't use CLI-as-dispatch until task 10-0845 lands. Don't expand registry without spec amendment + audit pass. Don't allow `model_overrides` to change backend. Don't allow custom entries to replace built-in entries. Don't treat `personality_filter` as exclusion list. Don't have host parse raw member output — arbitrator's job. Don't add arbitrator to registry. Don't implement `local-llm` in v1. Don't embed normative registry as static table — registry is `reviewers/` dir. Don't fail swarm on monoculture — best-effort only. Don't register `reviewers/*.md` files with invalid frontmatter.

## Personality Metadata Schema

Frontmatter required fields: `name` (unique), `trigger` ("always" or condition string), `required` (bool), `suggested_models` (preference-ordered model-class list), `suggested_backends` (preference-ordered backend list), `scope` (review limiter). Optional: `vendor` (diversity signal for B8). Missing/malformed → silently skipped.

Valid model classes: `haiku-class`, `sonnet-class`, `opus-class`, `gpt-class`. No bare model names anywhere in skill, reviewer files, or synthesis output.

Valid backends: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved), `varies` (custom only).

## Scope

Applies to any agent/skill needing multi-perspective review of any artifact. Does NOT cover: consumer skill internals, reviewer prompt authoring, non-review dispatch, side-effecting personality operations, CLI-as-dispatch (pending 10-0845), local-llm v1.

## Related

`dispatch` — agent-launching primitive used for all personality dispatches.
`compression` — required for overlay compression when building skill artifacts.
`skill-index` — locate skills by trigger phrase.
