---
name: swarm
description: Multi-personality review infrastructure — selects personalities, gates availability, dispatches in parallel, arbitrates, and synthesizes a verdict. Triggers - swarm review, multi-reviewer, parallel personalities, run all reviewers, arbitrate findings.
---

Usage: Never dispatch this skill as a sub-agent — it can't orchestrate further dispatches from a leaf position.

Key Terms:
Artifact: input content under review — conversation excerpt, file path, diff, plan, doc, or structured description. Passed as `problem`.
Review packet: self-contained brief assembled from artifact. Fields: Goal, Approach, Key decisions, Artifacts (actual content), Files affected, Blast radius, Conventions. Omit inapplicable fields.
Personality: named reviewer role defined by `reviewers/<name>.md` with YAML frontmatter. Has trigger condition, suggested model list (preference-ordered), backend preference list, scope limiter. Loaded lazily — full prompts absent at selection time.
Personality registry: set of personalities discovered by crawling `reviewers/` at runtime. Not static table. Extended per-invocation by caller-supplied custom menu.
Custom menu: caller-supplied list of additional personalities appended to registry for current invocation only. Doesn't persist.
Selection: filtering combined registry against artifact problem traits to produce active personality set.
Availability gate: probe step confirming personality's required backend is reachable before dispatch.
Swarm: surviving personalities after selection and availability gating.
Dispatch skill: `dispatch` skill — runtime-specific how-to for launching sub-agents. Reference for host agent executing this skill — not delegation target. Host dispatches directly using its own runtime mechanism (runSubagent in VS Code Copilot, Task in Claude Code).
Disagree set: subset of swarm findings where 2+ personalities reached contradictory conclusions on same point.
Confidence rating: High/Medium/Low scalar on synthesis output. Reflects reviewer agreement, evidence quality, scope coverage.
Model class: abstract tier — `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning, default), `opus-class` (heavy architectural reasoning), `gpt-class` (external OpenAI-hosted model). No bare model names anywhere. Implementor note (informative, not normative — subject to change without spec amendment): as of this writing, `gpt-class` resolves to current GPT-5-family release via `copilot-cli` backend; `sonnet-class` resolves to current Claude Sonnet release via `dispatch-sonnet` backend. Each model class resolves to exactly one model family/vendor (`haiku-class`/`sonnet-class`/`opus-class` → Anthropic; `gpt-class` → OpenAI); heterogeneity enforcement (B8) achieved by changing model class, within `model_overrides` scope (model class only, not backend — see spec.md Requirement 15).
Caller override: caller-supplied `model_overrides` map pinning 1+ personalities to specific model class for current invocation.
High-severity point: finding that would block shipping or require architectural change. Covers both HIGH and CRITICAL severity labels from Step 5 dispatch output — share same threshold. Maps to arbitrator's Critical actions section. Used in confidence rating (D6) and E5 truncation priority; HIGH and CRITICAL receive equal truncation priority.
Availability probe: lightweight shell command (e.g., `copilot --version`) or tool call confirming backend is live before including personality.
Backend: execution target for personality. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
Arbitrator: single sonnet-class sub-agent dispatched after all swarm members complete. Receives full member outputs and review packet. Returns structured action list only. Not reviewer. Not in registry. Not subject to personality selection, availability gating, or `personality_filter`.
Generated persona: reviewer personality manifested inline at runtime when registry yields <3 suitable personalities for artifact. Has name, critique lens, scope limiter — all specific to artifact's domain. Exists for current invocation only; not cached; no `reviewers/` file.
Manifest hash: SHA-256 of canonical input manifest — sorted file paths concatenated with their content hashes. For non-file artifacts (text, conversation excerpts), SHA-256 of artifact content. Used as cache key for all hash-record entries.

Personality Registry:
Registry is external to skill. Built-in personality definitions live as separate files at `swarm/reviewers/<name>.md`. Registry = directory listing — every `*.md` in `reviewers/` that passes metadata-validation gate is registered. Adding personality = drop new file; no spec or `SKILL.md` edit needed.
Registry loading: crawl `reviewers/` at runtime when swarm invocation begins. Compile-time enumeration not used. `reviewers/index.yaml` = ordered manifest — provides metadata and ordering for personalities discovered during crawl.
Metadata-validation gate: any file in `reviewers/` subject to automatic metadata-validation before registration. File failing validation silently skipped. No human approval required. Valid files auto-registered.

Built-in personalities (informative — not normative):

| # | Personality | Trigger | Suggested model class | Backend | Scope |
| --- | --- | --- | --- | --- | --- |
| 1 | Devil's Advocate | always | sonnet-class | dispatch-sonnet | Challenge assumptions; no constructive suggestions |
| 2 | Minimalist | always | sonnet-class | dispatch-sonnet | Reduce complexity; focus on essentials |
| 3 | Accessibility Officer | UI, web rendering, forms, interactive elements, color, user-facing text | sonnet-class | dispatch-sonnet | WCAG 2.2 AA only; no logic, security, or performance |
| 4 | Architect | system structure, new abstractions, service boundaries, shared infrastructure | sonnet-class | dispatch-sonnet | Structural concerns only; no implementation details |
| 5 | Designer | public interfaces, APIs, library surfaces, shared types, config contracts | sonnet-class | dispatch-sonnet | Public surface and caller experience only; no internals |
| 6 | Engineer | new logic, integrations, state mutation, error handling, partial failure | sonnet-class | dispatch-sonnet | Practical correctness only; no style or architecture |
| 7 | Linguist | code, docs, error messages, log strings, user-visible text, named abstractions | sonnet-class | dispatch-sonnet | Naming, clarity, communication only |
| 8 | Penny Pincher | API calls, DB queries, loops, caching, storage, cloud resource usage | sonnet-class | dispatch-sonnet | Cost and resource efficiency only |
| 9 | Privacy Advocate | user data, PII, analytics, logging, storage, data transmission, identity, consent | sonnet-class | dispatch-sonnet | Privacy and data handling only; no unrelated security |
| 10 | Security Auditor | auth, user input, API endpoints, data access, secrets, network calls, file system writes, process execution | sonnet-class | dispatch-sonnet | Find vulnerabilities only; no design advice |
| 11 | Custom Specialist | caller supplies via custom menu | varies | varies | Defined by caller in custom menu entry |

Integer index is informative only. Stable runtime index = alphabetical crawl (1-based). Personality renames change index; callers using `personality_filter` by name unaffected.

Pre-implementation gate — CLI-backed personalities: before adding any CLI-backed personality to runtime registry, verify the dispatch skill's CLI-extension has landed. CLI-backed personalities mustn't be added until that extension is complete.

Personality Metadata Schema:
Each `reviewers/<name>.md` must begin with YAML frontmatter block. Files missing required fields or with malformed frontmatter fail validation gate and are silently skipped.

Required fields:

```yaml
---
name: <string>          # display name; unique across all files in reviewers/
trigger: <string>       # trigger condition; "always" for unconditional inclusion
required: <bool>        # true = always dispatched regardless of personality_filter (unless explicitly excluded)
suggested_models:       # preference-ordered list of model-class terms only
  - <model-class>       # first entry = most preferred
suggested_backends:     # preference-ordered list of backend identifiers
  - <backend>           # first entry = most preferred
scope: <string>         # what this personality reviews and what it ignores
---
```

Optional fields:

```yaml
vendor: <string>        # model vendor hint (e.g. anthropic, openai); used by diversity rule B8
```

Model selection at dispatch: see Step 2.

Custom Personality Menu:
Callers may supply additional personalities for single invocation. Each entry must specify: name, trigger condition, model class (or inherit from caller override), backend, scope limiter. Custom entries appended after all built-in entries in evaluation order. Don't mutate built-in registry.

Inputs:

| Input | Required | Description |
| --- | --- | --- |
| `problem` | required | Content under review. |
| `personality_filter` | optional | List of personality names (strings). Named personalities dispatched regardless of trigger evaluation; triggers bypassed for named entries. Inclusion list only — not exclusion gate. Indices not accepted (registry built by filesystem crawl; index positions unstable across reviewer-file changes). |
| `model_overrides` | optional | Map of personality name to model class. Affects model class only, not backend type. |
| `arbitrator_model` | optional | Model class for arbitrator dispatch. Defaults to `sonnet-class`. Use `opus-class` for high-stakes reviews where arbitrator judgment quality is critical. |

Caller Tier:
Host agent executing skill must be sonnet-class minimum. Callers dispatching swarm via `dispatch` skill must use `tier: standard` or higher. If no dispatch mechanism available in host runtime, return error: "Swarm requires dispatch capability; no dispatch mechanism available."

Step Sequence:
Eight steps run in order for every swarm invocation, from packet assembly through final synthesis.

Step 1 — Build review packet:
Hash record check (early gate): before building packet, extract file list directly from `problem` (deterministic parse — no LLM required). Read file contents, compute manifest hash (sorted paths + content hashes, SHA-256; or SHA-256 of artifact text for non-file inputs). Compute `invocation_hash` = SHA-256 of canonical JSON serialization of `{ filter: sorted(personality_filter) or [], overrides: sorted(model_overrides) or {}, arbitrator: arbitrator_model or "sonnet-class" }` — covers filter, model overrides, arbitrator tier so re-run with different tiers produces distinct cache key. Check `.hash-record/XX/HASH/swarm/v1/<invocation_hash>/report.md` (XX = first two hex chars of HASH, `v1` = current skill version). Cache hit: return cached result, skip Steps 2-8. Cache miss: before proceeding to Step 2, check `.hash-record/XX/HASH/swarm/v1/` for existing per-persona results under same `invocation_hash` (B10 partial recovery). Treat found result as complete; proceed with remaining personalities only. Per-persona result paths additionally include resolved model class so re-run at different tier writes to distinct subdirectory: `.hash-record/XX/HASH/swarm/v1/<invocation_hash>/<persona-name>-<model-class>/report.md`.

Continue to packet assembly on cache miss:

Construct review packet from `problem`. Packet must be self-contained: reader with zero prior context must understand what's reviewed, why, and key decisions.

Packet fields (omit if inapplicable):
Goal: problem being solved or output being evaluated.
Approach: what was proposed, implemented, or produced.
Key decisions: why this approach over alternatives.
Artifacts: actual content under review (diffs, text, config — not description).
Files affected: list with brief descriptions.
Blast radius: downstream consumers, imports, integrations affected.
Conventions: applicable project conventions.

Verify packet before proceeding: Goal must name artifact type and state outcome being evaluated (e.g., "evaluate diff for correctness and security"); Artifacts must include actual content, not just references. If either fails, attempt to resolve gap from available context. Don't ask caller to fill gaps. If gap can't be resolved, return error per B1 and halt.

Step 2 — Select personalities:
Build combined registry by crawling `reviewers/` (applying metadata-validation gate) and appending any caller-supplied custom menu entries.

If `personality_filter` supplied: restrict active personality set to named personalities; dispatch those regardless of trigger evaluation (triggers bypassed for named entries). If no filter: evaluate trigger conditions against problem traits inferred from review packet; exclude personalities whose trigger isn't satisfied. Evaluation is semantic judgment against review packet content, not literal string matching against `trigger` field text.

Safety-critical artifact auto-trigger: fires when review packet's Files-affected list contains any artifact whose failure could break host environment, propagate across fleet, or compromise process lifecycle — control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar. When it fires, add Engineer, Devil's Advocate, Minimalist to active personality set, regardless of trigger evaluation or `personality_filter`. Callers can't opt out via filter. Precedence: rule supersedes `personality_filter` override of trigger evaluation for the 3 named personalities. Additions here protected from 6-cap drop step.

For each personality in active set, read `suggested_models` from frontmatter, select first available model. For internal-dispatch backends (handled by `dispatch` skill), no model-class probe run — treat all listed entries as available, select first. Caller `model_overrides` take precedence. If no `suggested_models` entry available and no override applies, default to `sonnet-class`.

Selection logic must be inline within skill.

Always include personalities with `required: true`, regardless of trigger evaluation. `personality_filter` may exclude required personality only when caller explicitly names subset that omits it. Devil's Advocate carries `required: true`.

6-cap: if >6 personalities pass trigger evaluation, apply priority order: (1) Devil's Advocate and Minimalist always; (2) personalities added by safety-critical-artifact auto-trigger (Engineer) — protected from cap because rule is mandatory and caller can't opt out; (3) personalities with most-specific trigger match (specificity score = count of distinct comma-delimited terms in `trigger` field; `"always"` scores 0; tie-break by alphabetical personality name); (4) drop lowest-priority remaining until count reaches 6.

Manifest gap fill: if selection yields <3 suitable personalities after filter and trigger evaluation, manifest 1+ generated personas inline to reach ≥3. For each: invent name relevant to artifact's domain, critique lens covering problem traits not already represented by selected personalities, scope limiter avoiding overlap. Dispatch same as built-in; don't add to registry; don't cache in hash record.

Step 3 — Availability gating:
For each selected personality whose backend is external (not handled internally by `dispatch` skill, e.g., `copilot-cli`):
Run availability probe before including personality.
Probe succeeds: include personality.
Probe fails: drop personality from swarm for this invocation. Note drop in synthesis output. Don't fail-stop or surface error to caller.

For internal-dispatch backends (handled by `dispatch` skill), no probe required; dispatch skill handles errors internally.

Step 4 — Load reviewer prompts:
Only after swarm finalized (post-gating) load prompt for each surviving personality. Reviewer prompts stored as separate sub-skill files under `swarm/reviewers/<name>.md`. Filename = personality name lowercased, spaces replaced with hyphens, apostrophes dropped (e.g., `devils-advocate.md`, `security-auditor.md`). Load only files for dispatched personalities. Don't load files for non-dispatched personalities. If prompt file can't be loaded, treat personality as non-contributing per E3 and continue.

Step 5 — Dispatch:
Dispatch swarm personalities using your runtime dispatch mechanism, following `dispatch` skill for implementation details. Maximum concurrency — dispatch up to 3 in parallel; as each completes, dispatch next until all have run. Treat any personality not returned within host-defined threshold (recommended: typical sonnet-class response time + 20%) as timed out per B4.

As each personality dispatch completes, immediately write its raw output to `.hash-record/XX/HASH/swarm/v1/<invocation_hash>/<persona-name>-<model-class>/report.md` (built-in personas only — generated personas never written). `<persona-name>` uses same slugification as reviewer filename (Step 4): personality name lowercased, spaces replaced with hyphens, apostrophes dropped. Model class suffix prevents re-run at different tier from overwriting prior result. Don't wait for all dispatches to complete before writing per-persona results.

Each personality dispatch receives:
1. Full review packet from Step 1.
2. Personality's prompt loaded in Step 4.
3. Explicit read-only constraint — include language in each prompt prohibiting file edits, commits, side-effecting shell commands (see Constraints C1-C3). Exact wording left to implementor.

Apply `model_overrides` at dispatch time: if caller override exists, use it; otherwise use first available entry from `suggested_models`; otherwise fall back to `sonnet-class`. Diversity check after model selection: if all selected personalities resolve to same model family, apply resolution order before dispatching — (1) include any personality from full candidate registry on different model family; (2) re-assign Devil's Advocate to different vendor via `vendor` override; (3) if neither resolves, proceed and set `homogeneity_warning`. (B8 governs this rule.)

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-personality:<personality-name>`

Must return: structured findings list. Each finding: description of issue, evidence cite (snippet, line reference, scenario, or direct quote). Empty response or "No findings" is valid return — treated as non-contributing (B4).

Structured-evidence requirement (high/critical findings): any finding marked HIGH or CRITICAL severity must include three fields: Source (where vulnerability/bug enters), Sink (where it causes harm), Missing guard (what defense is absent). Findings at HIGH/CRITICAL lacking this structure are automatically downgraded to MEDIUM.

Step 6 — Arbitrator consolidation:
File-existence filter (pre-arbitration): before forwarding member findings to arbitrator, discard any finding citing file not present in review packet's Files-affected list. Path comparison: normalize both sides before matching — lowercase on case-insensitive filesystems, unify forward/backward slashes to forward, strip leading `./` and trailing whitespace. Use exact match after normalization. Don't use LLM judgment for this filter — it's mechanical. If finding doesn't cite specific file, retain it.

After all swarm member outputs collected, dispatch single arbitrator sub-agent using `arbitrator_model` (default: `sonnet-class`). Arbitrator receives all raw member outputs and original review packet. Per B4, non-contributing member outputs (empty/timeout) excluded from arbitrator's input set.

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-arbitrator`

Must return: structured three-section action list — Obvious actions, Critical actions, Conflicting conclusions — as specified in Required arbitrator output format. If no actionable findings: "No actionable findings" stated explicitly.

Arbitrator's sole job: produce structured action list — not narrative synthesis.

Required arbitrator output format (three sections):
Obvious actions: items where 2+ swarm members independently flagged same concern, or concern self-evident from artifact. Each entry: action description + source personality names + evidence cite.
Critical actions: items meeting High-severity point threshold, regardless of reviewer agreement count. Each entry: action description + source personality names + evidence cite + severity rationale.
Conflicting conclusions: items where 2+ swarm members reached contradictory conclusions on same point — disagree set referenced in confidence rating. Each entry: point in dispute (neutral framing) + personalities involved with conflicting claims + severity if applicable. If empty, state "No conflicting conclusions" explicitly.

Authoritative format: `specs/arbitrator.md` — Required arbitrator output format section here is summary only. On any amendment to output structure, update both in same commit.

Arbitrator mustn't include speculative, low-confidence, or duplicate items. Its output is input to Step 7; host synthesizes from this list only, not raw member output.

Grounded-challenge requirement: before citing member finding as incorrect, arbitrator must quote exact sentence from that finding it believes is wrong. Challenging interpretation rather than explicit claim isn't permitted.

If arbitrator produces empty list, it must state "No actionable findings" explicitly. Host must still proceed to synthesis and note clean result.

Arbitrator is structurally separate from registry (see Arbitrator entry in Key Terms): never selected, gated, or filtered the way personalities are.

Step 7 — Aggregate findings, track disagreements:
Collect findings from arbitrator's structured action list. For each item, record: personality names cited, finding summary, cited evidence.

Identify disagree set from arbitrator's Conflicting conclusions section. Each disagree entry records personalities involved and their conflicting claims as arbitrator captured them.

Step 8 — Synthesize, return:
Synthesize from arbitrator's structured action list into single host-voice output. Don't dump raw sub-agent output or raw arbitrator output to caller. Speak as host, presenting refined takeaways.

Required synthesis output fields:
Active personalities: name (model-class) for each personality that completed successfully; tag generated personas with "(generated)".
Critical actions: each item from arbitrator's Critical actions section — High-severity point items.
Findings: remaining consensus findings from arbitrator's Obvious actions section.
Disagreements: explicit statement of each disagree-set item; state tension, apply judgment.
Unavailable personalities: personalities dropped by availability gate with reason.
Non-contributing personalities: personalities dispatched but returned empty output, timed out, or returned incoherent output.
Confidence rating: High, Medium, or Low. Include rationale. If Low, state specifically what would raise it.

Synthesis output template (use this structure exactly):

```md
**Active personalities**: <name (model-class) for each; tag generated personas with "(generated)">

**Critical actions**: <list — for each: action description + source personalities + severity rationale; "None" if none>

**Findings**: <list — for each: action description + source personalities + evidence cite; "None" if none>

**Disagreements**: <each disagree-set item with tension stated and judgment applied; "None" if disagree set is empty>

**Unavailable personalities**: <name — probe-failed reason; "None" if none>

**Non-contributing personalities**: <name — empty/timeout/incoherent reason; "None" if none>

**Confidence rating**: <High | Medium | Low> — <rationale; if Low, state what would raise it>

**Homogeneity warning** (omit if N/A): All personalities resolved to the same model family — result may exhibit sycophantic conformity. Re-run with cross-vendor overrides for higher confidence.

**Truncation note** (omit if N/A): Synthesis exceeded the conciseness budget. Items truncated per E5 priority order (low-severity findings dropped first). Full per-persona reports remain in the hash-record under the invocation_hash directory.
```

Synthesis output must be concise (strong guidance: ~2000 words). When findings exceed budget, truncation must preserve disagreements + high-severity items; medium and low drop first.

Hash record write: after synthesis completes, write full result to `.hash-record/XX/HASH/swarm/v1/<invocation_hash>/report.md`. Atomic write: write to `report.md.tmp` first, then rename — concurrent reader must never see partial synthesis. Per-persona results already written during Step 5. Generated personas not written. If `v1/<invocation_hash>/report.md` already exists, skip write (idempotency guard). Current skill version: `v1`. Bump to `v2` when persona prompts, selection criteria, arbitrator procedure, or hash algorithm changes in way that could affect review quality. Wording/formatting changes don't require bump.

Error Envelope:
All error returns from this skill use shape `{ error: { code, message } }`. Stable codes — callers may branch on these:
`E_NO_DISPATCH` — no dispatch mechanism available in host runtime.
`E_NO_ARTIFACT` — `problem` empty or no reviewable artifact (B1).
`E_EMPTY_SWARM` — swarm empty after availability gating (B2).
`E_ARBITRATOR_FAIL` — arbitrator dispatch failed or returned no structured output (E6).
`E_PACKET_INCOMPLETE` — Step 1 packet verification failed and gap not resolvable.

Constraints:
C1. All dispatched sub-agents operate in read-only mode. Sub-agents mustn't edit files, run side-effecting commands, commit, or call any mutating tool. State this constraint explicitly in every personality's dispatch prompt.

C2. Include explicit read-only language in each personality's dispatch prompt — prohibit file edits, commits, any side-effecting shell command. Exact wording is implementation choice. For each finding, verify before including: (1) cited file path appears in provided diff/artifact; (2) cited line within changed/relevant section or within 10 lines of one; (3) any verbatim code quotes appear in artifact; (4) directional claims (added/removed/changed) match artifact. Findings failing any check must be omitted, not downgraded.

C3. Skill doesn't technically prevent sub-agent from calling mutating tools; constraint is behavioral, enforced by prompt instruction. If sub-agent violates it, violation is prompt-design defect, not dispatch-skill defect.

C4. Every finding must cite specific evidence: snippet, line reference, scenario, or direct quote. Instruct each reviewer to either cite or retract.

C5. Mustn't invoke `code-review` skill internally. Two are siblings with separate intent; neither is dependency of other.

C6. Skill must refer to models by capability tier, not version string. Insulates contract from model retirements, lets dispatch layer evolve model selection independently. Bare model names forbidden in skill, reviewer files, synthesis output.

C7. CLI-as-dispatch out of scope until the dispatch skill's CLI-extension lands. Once it lands, CLI-backed personalities may use CLI dispatch pattern defined there.

C8. Don't expand personality registry with new built-in entries without spec amendment and audit pass.

Behavior:
B1. If `problem` empty or can't be resolved into review packet with non-empty Artifacts field, return error: "No reviewable artifact found." Don't dispatch any personalities.

B2. If swarm empty after availability gating, return error: "Swarm empty after gating — no personalities available." Don't attempt synthesis.

B3. If swarm contains only Devil's Advocate, proceed with single-personality swarm and note in synthesis that review is adversarial only.

B4. If dispatched personality returns no findings or times out, record as non-contributing, exclude from synthesis. Note in `Non-contributing personalities` synthesis field.

B5. If all dispatched personalities return no findings, synthesis must state "No findings from any reviewer", assign confidence rating Low.

B6. Devil's Advocate must always be dispatched unless explicitly excluded by `personality_filter` with named subset that omits it.

B7. Custom menu personalities evaluated against their caller-supplied trigger condition. If trigger is "always", always include (subject to availability gating if backend external).

B8. Cross-vendor diversity: if all finalized swarm personalities resolve to same model family or vendor, attempt resolution before dispatching. Preferred resolution order: (1) find any personality in full candidate registry on different model family — include it in swarm; (2) re-assign Devil's Advocate to different vendor using `vendor` frontmatter field. If neither resolves monoculture, proceed with homogeneous swarm, include `homogeneity_warning` in synthesis output. Do NOT degrade to `code-review`.

B9. Generated persona dispatch: generated personas dispatched in Step 5 same way as built-in personalities. Each receives: review packet, inline system prompt synthesized from its name, critique lens, scope limiter, explicit read-only constraint. Generated personas not added to registry, never cached. Always re-dispatched on any re-run.

B10. Hash record partial recovery: if previous swarm run on same `invocation_hash` was interrupted before completion, check hash-record location for existing per-persona results under that hash. Treat any cached built-in persona result as complete. Re-dispatch only missing built-in personas and all generated personas (never cached).

Defaults:
D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: first available from `suggested_models` frontmatter; fallback `sonnet-class`. Callers may override individual personalities via `model_overrides`.
D3. Default dispatch: rolling window of 3. Never more than 3 personalities in flight at once.
D4. Default `model_overrides`: none.
D4b. Default `arbitrator_model`: `sonnet-class`.
D5. Custom menu entry with no model class and no caller override: default `sonnet-class`.
D6. Confidence rating default: Medium. When (1) disagree set empty AND (2) every dispatched personality returned ≥1 finding AND all findings cite evidence, raise to High. When disagree set non-empty on high-severity point, or any personality returns no findings, lower to Low.
D7. `.hash-record/` base path: workspace root (root of repository or project containing reviewed artifact). Relative path `.hash-record/` resolves against workspace root. If workspace root ambiguous, use directory containing `problem` artifact's nearest root marker (e.g., `.git`).

Calibration examples:
High: Security Auditor, Code Quality Critic, Devil's Advocate all flag same SQL injection risk with evidence cites; no disagreements. → High.
Medium (default): Reviewers agree on 2 findings but one personality returns "No findings." Wait — "any personality returns no findings" triggers Low, not Medium. → Low.
Medium (true): Reviewers produce 3 findings with evidence; no high-severity disagreements; all personalities contributed. → Medium.
Low: Devil's Advocate flags no concerns (returns "No findings"); or Security Auditor and Architect reach contradictory conclusions on shipping-blocking concern. → Low; state what would raise it (e.g., "re-run with explicit security artifact to get Security Auditor finding").

Error Handling:
E1. Unavailable external backend (probe fails): drop personality, note in synthesis, continue. Don't fail-stop.
E2. Empty swarm after gating: return error (B2). Don't synthesize.
E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): treat as non-contributing (B4). Don't block synthesis. Incoherent output: response that can't be parsed into structured findings list and isn't recognizable "No findings" statement. Response of "No findings" with or without brief rationale is valid (B4, non-contributing). Structurally garbled, off-topic, or unparseable response is incoherent (E3).
E4. Review packet assembly fails (no artifact resolvable): return error (B1). Don't dispatch.
E5. Synthesis exceeds word budget: truncate at priority order — disagreements first, then high-severity, then medium, then low. Note truncation in output.
E6. Arbitrator dispatch fails or returns no structured output: return error to caller with per-personality summary from Step 7 (if any). Don't attempt synthesis from raw member outputs.
E7. Hash record write failure (Steps 5 or 8): non-fatal. Log failure, continue. Per-persona write failure (Step 5): continue dispatching remaining personalities; B10 will re-dispatch missing persona on next run. Synthesis write failure (Step 8): result already returned to caller — log and return normally. Don't abort swarm or surface write error to caller.

Precedence:
P1. `personality_filter` overrides trigger-condition evaluation; only named personalities dispatched; triggers bypassed for named entries.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.
P5. Synthesis conciseness budget overrides completeness. Truncation required over exceeding budget; preserve disagreements + high-severity first.

Related:
`dispatch` — agent-launching skill; swarm delegates all sub-agent launches here.
`compression` — compression skill used to produce compressed form of this skill.
`specs/arbitrator.md` — sub-specification for arbitrator consolidation role.
`specs/dispatch-integration.md` — sub-specification for dispatch integration patterns.
`specs/glossary.md` — canonical term definitions for swarm skill family.
`specs/personality-file.md` — sub-specification for reviewer personality file format.
`specs/registry-format.md` — sub-specification for personality registry format and crawl behavior.
