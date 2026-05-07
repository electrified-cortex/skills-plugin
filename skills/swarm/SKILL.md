---
name: swarm
description: Multi-personality review infrastructure — selects personalities, gates availability, dispatches in parallel, arbitrates, and synthesizes a verdict. Triggers - swarm review, multi-reviewer, parallel personalities, run all reviewers, arbitrate findings.
---

Usage: This skill is host-executed. The host agent reads and follows these steps directly. Never dispatch this skill as a sub-agent — it cannot orchestrate further dispatches from a leaf position.

Key Terms:
Artifact: input content under review — conversation excerpt, file path, diff, plan, doc, or structured description. Passed as `problem`.
Review packet: self-contained brief assembled from artifact. Fields: Goal, Approach, Key decisions, Artifacts (actual content), Files affected, Blast radius, Conventions. Omit inapplicable fields.
Personality: named reviewer role defined by `reviewers/<name>.md` with YAML frontmatter. Has trigger condition, suggested model list (preference-ordered), backend preference list, scope limiter. Loaded lazily — full prompts absent at selection time.
Personality registry: set of personalities discovered by crawling `reviewers/` at runtime. Not static table. Extended per-invocation by caller-supplied custom menu.
Custom menu: caller-supplied list of additional personalities appended to registry for current invocation only. Doesn't persist.
Selection: filtering combined registry against artifact problem traits to produce active personality set.
Availability gate: probe step confirming personality's required backend is reachable before dispatch.
Swarm: surviving personalities after selection and availability gating.
Dispatch skill: `dispatch` skill — runtime-specific how-to for launching sub-agents. Reference for the host agent executing this skill — not a delegation target. Host dispatches directly using its own runtime mechanism (runSubagent in VS Code Copilot, Task in Claude Code).
Disagree set: subset of swarm findings where two or more personalities reached contradictory conclusions on same point.
Confidence rating: High / Medium / Low scalar on synthesis output. Reflects reviewer agreement, evidence quality, scope coverage.
Model class: abstract tier — `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning, default), `opus-class` (heavy architectural reasoning), `gpt-class` (external OpenAI-hosted model). No bare model names anywhere.
Caller override: caller-supplied `model_overrides` map pinning one or more personalities to specific model class for current invocation.
High-severity point: finding that would block shipping or require architectural change. Used in confidence rating.
Availability probe: lightweight shell command (e.g., `copilot --version`) or tool call confirming backend is live before including personality.
Backend: execution target for personality. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
Arbitrator: single sonnet-class sub-agent dispatched after all swarm members complete. Receives full member outputs and review packet. Returns structured action list only. Not reviewer. Not in registry. Not subject to personality selection, availability gating, or `personality_filter`.

Personality Registry:
Registry is external to skill. Built-in personality definitions live as separate files at `swarm/reviewers/<name>.md`. Registry = directory listing — every `*.md` in `reviewers/` that passes metadata-validation gate is registered. Adding personality = drop new file; no spec or SKILL.md edit needed.
Registry loading: crawl `reviewers/` at runtime when swarm invocation begins. Compile-time enumeration not used. `reviewers/index.yaml` = ordered manifest — provides metadata and ordering for personalities discovered during crawl.
Metadata-validation gate: any file in `reviewers/` subject to automatic metadata-validation before registration. File failing validation silently skipped. No human approval required. Valid files auto-registered.

Built-in personalities (informative — not normative):

| # | Personality | Trigger | Suggested model class | Backend | Scope |
| --- | --- | --- | --- | --- | --- |
| 1 | Devil's Advocate | always | sonnet-class | dispatch-sonnet | Challenge assumptions; no constructive suggestions |
| 2 | Security Auditor | auth, user input, API endpoints, data access, secrets, network calls | sonnet-class | dispatch-sonnet | Find vulnerabilities only; no design advice |
| 3 | Code Quality Critic | code (new or modified) | sonnet-class | dispatch-sonnet | Code conventions, readability, duplication; no security or arch |
| 4 | Test Reviewer | new or modified logic requiring test coverage | sonnet-class | dispatch-sonnet | Test coverage and quality only |
| 5 | Architect | system structure, new abstractions, service boundaries, shared infrastructure | sonnet-class | dispatch-sonnet | Structural and interface concerns only |
| 6 | Operational Readiness | new failure modes, external dependencies, error handling, production-facing behavior | sonnet-class | dispatch-sonnet | Observability, recovery, degraded-mode behavior |
| 7 | Performance Reviewer | data access, loops, serialization, caching, computationally significant logic | sonnet-class | dispatch-sonnet | Throughput, latency, resource use only |
| 8 | Copilot Reviewer | code + copilot-cli available | external | copilot-cli | Full code review via Copilot; availability-gated |
| 9 | Custom Specialist | caller supplies via custom menu | varies | varies | Defined by caller in custom menu entry |

Integer index is informative only. Stable runtime index = alphabetical crawl (1-based). Personality renames change index; callers using `personality_filter` by name unaffected.

Pre-implementation gate — entry 8: before implementing entry 8 or any CLI-backed personality, verify task 10-0845 (dispatch skill CLI-extension) has reached PASS. Entry 8 MUSTN'T be implemented until that task is complete.

Personality Metadata Schema:
Each `reviewers/<name>.md` MUST begin with YAML frontmatter. Files missing required fields or with malformed frontmatter fail validation gate and are silently skipped.

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

Model selection at dispatch: read `suggested_models` from frontmatter, pick first available. Caller `model_overrides` take precedence. If no `suggested_models` available and no override, fall back to `sonnet-class`.

Custom Personality Menu:
Callers may supply additional personalities for single invocation. Each entry MUST specify: name, trigger condition, model class (or inherit from caller override), backend, scope limiter. Custom entries appended after entry 9 in evaluation order. Don't mutate built-in registry.

Inputs:

| Input | Required | Description |
| --- | --- | --- |
| `problem` | required | Content under review. |
| `personality_filter` | optional | List of personality names or indices. Named personalities dispatched regardless of trigger evaluation; triggers bypassed for named entries. Inclusion list only — not exclusion gate. |
| `model_overrides` | optional | Map of personality name to model class. Affects model class only, not backend type. |

Caller Tier:
Host agent executing skill MUST be sonnet-class minimum. Callers dispatching swarm via `dispatch` skill MUST use `tier: standard` or higher.

Step Sequence:

Step 1 — Build review packet:
Construct review packet from `problem`. Packet MUST be self-contained: reader with zero prior context must understand what is reviewed, why, and what key decisions were.

Packet fields (omit if not applicable):
Goal: problem being solved or output being evaluated.
Approach: what was proposed, implemented, or produced.
Key decisions: why this approach over alternatives.
Artifacts: actual content under review (diffs, text, config — not a description).
Files affected: list with brief descriptions.
Blast radius: downstream consumers, imports, integrations affected.
Conventions: applicable project conventions.

Verify packet before proceeding: Goal must be specific enough to evaluate; Artifacts must include actual content, not just references. If either fails, attempt to resolve gap from available context. Don't ask caller to fill gaps.

Step 2 — Select personalities:
Build combined registry by crawling `reviewers/` (applying metadata-validation gate) and appending caller-supplied custom menu entries.

If `personality_filter` supplied: restrict candidate set to named personalities; dispatch regardless of trigger evaluation (triggers bypassed). If no filter: evaluate trigger conditions against problem traits inferred from review packet; exclude personalities whose trigger isn't satisfied.

For each personality in active set, read `suggested_models` from frontmatter and select first available. Caller `model_overrides` take precedence. If no `suggested_models` available and no override, default to `sonnet-class`.

Selection logic MUST be inline within skill.

Personalities with `required: true` MUST always be included regardless of trigger evaluation. `personality_filter` may exclude required personality only when caller explicitly names subset omitting it. Devil's Advocate carries `required: true`.

Step 3 — Availability gating:
For each selected personality whose backend is NOT `dispatch-sonnet`, `dispatch-haiku`, or `dispatch-opus` (i.e., any external backend such as `copilot-cli`):
Run availability probe before including.
Probe succeeds: include.
Probe fails: drop from swarm for this invocation. Note drop in synthesis output. Don't fail-stop or surface error to caller.

For `dispatch-*` backends, no probe required; dispatch skill handles errors internally. If all personalities are dropped (swarm empty), return error per B2.

Step 4 — Load reviewer prompts:
Only after swarm is finalized (post-gating) load prompt for each surviving personality. Reviewer prompts stored as separate sub-skill files under `swarm/reviewers/<name>.md`. Filename = personality name lowercased with spaces and apostrophes replaced by hyphens (e.g., `devils-advocate.md`, `security-auditor.md`). Load only files for dispatched personalities. Don't load files for non-dispatched personalities.

Step 5 — Dispatch:
Dispatch swarm personalities using your runtime dispatch mechanism, following the `dispatch` skill for implementation details. Maximum concurrency: rolling window of 3. Dispatch up to 3 personalities in parallel; as each completes, dispatch the next until all personalities have run. Don't dispatch more than 3 at once.

Each personality dispatch receives:
1. Full review packet from Step 1.
2. Personality's prompt loaded in Step 4.
3. Explicit read-only constraint (see C1–C3).

Apply `model_overrides` at dispatch time: if caller override exists, use it; otherwise use first available entry from `suggested_models`; otherwise fall back to `sonnet-class`. Apply diversity rule B8 after model selection: if all selected personalities resolve to the same model family, execute the resolution order defined in B8 before dispatching.

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-personality:<personality-name>`

Should return: structured findings list. Each finding: description + evidence cite (snippet, line reference, scenario, or direct quote). Empty response or "No findings" = valid return — treated as non-contributing (B4).

Structured-evidence requirement (high/critical findings): any finding marked HIGH or CRITICAL severity MUST include three fields: Source (where the vulnerability/bug enters), Sink (where it causes harm), Missing guard (what defense is absent). Findings at HIGH/CRITICAL without this structure are automatically downgraded to MEDIUM.

Step 6 — Arbitrator consolidation:
File-existence filter (pre-arbitration): before forwarding member findings to the arbitrator, discard any finding that cites a file not present in the review packet's Files-affected list. Deterministic string match (exact path). Do not use LLM judgment for this filter — it is mechanical. If a finding does not cite a specific file, retain it.

After all swarm member outputs collected, dispatch single arbitrator sub-agent (sonnet-class by default). Arbitrator receives all raw member outputs and original review packet. Per B4, non-contributing member outputs (empty/timeout) excluded from arbitrator's input set.

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-arbitrator`

Should return: structured two-section action list — Obvious actions and Critical actions — as specified in required arbitrator output format below. If no actionable findings: "No actionable findings" stated explicitly.

Arbitrator's sole job: produce structured action list — not narrative synthesis.

Required arbitrator output format (two sections):
Obvious actions: 2+ swarm members independently flagged same concern, or concern is self-evident from artifact. Each entry: action description + source personality names + evidence cite.
Critical actions: items that, if unaddressed, would block shipping or require architectural change, regardless of reviewer agreement count. Each entry: action description + source personality names + evidence cite + severity rationale.

Arbitrator MUSTN'T include speculative, low-confidence, or duplicate items. Its output = input to Step 7; host synthesizes from this list only, not raw member output.

Grounded-challenge requirement: before citing a member finding as incorrect, arbitrator MUST quote the exact sentence from that finding it believes is wrong. Challenging an interpretation rather than an explicit claim is not permitted.

If arbitrator produces empty list, it MUST state "No actionable findings" explicitly. Host MUST still proceed to synthesis and note clean result.

Arbitrator is structurally separate from registry. MUSTN'T appear in registry, MUSTN'T be subject to personality selection, availability gating, or `personality_filter`.

Step 7 — Aggregate findings and track disagreements:
Collect findings from arbitrator's structured action list. For each item, record: personality names cited, finding summary, cited evidence.

Identify disagree set: items where arbitrator flagged conflicting conclusions (source personality names from different members with contradictory claims on same point). Each disagree entry records personalities involved and conflicting claims.

Step 8 — Synthesize and return:
Synthesize from arbitrator's structured action list into single host-voice output. Don't dump raw sub-agent output or raw arbitrator output to caller. Speak as host, presenting refined takeaways.

Required synthesis output fields:
Summary: consolidated findings in host voice.
Disagreements: explicit statement of each disagree-set item; state tension and apply judgment.
Dropped personalities: list of personalities dropped by availability gate with reason.
Confidence rating: High, Medium, or Low. Include rationale. If Low, state what would raise it.

Synthesis output template (use this structure exactly):

```md
**Summary**: <consolidated findings in host voice>

**Disagreements**: <each disagree-set item with tension stated and judgment applied; "None" if disagree set is empty>

**Dropped personalities**: <name — reason for each dropped personality; "None" if none dropped>

**Confidence rating**: <High | Medium | Low> — <rationale; if Low, state what would raise it>
```

Synthesis output MUSTN'T exceed 2000 words. If findings exceed budget, prioritize high-severity and disagreement items. Note truncation in output.

Constraints:
C1. All dispatched sub-agents operate in read-only mode. Sub-agents MUSTN'T edit files, run side-effecting commands, commit, or call mutating tool. State constraint explicitly in every personality's dispatch prompt.

C2. Include literal phrase "read-only review — analyze and report only, no file edits, no commits, no shell commands" in each personality's dispatch prompt. For each finding, verify before including: (1) cited file path appears in provided diff/artifact; (2) cited line is within changed/relevant section or within 10 lines of one; (3) verbatim code quotes appear in artifact; (4) directional claims (added/removed/changed) match artifact. Findings failing any check MUST be omitted, not downgraded.

C3. Skill doesn't technically prevent sub-agents from calling mutating tools — constraint is behavioral, enforced by prompt instruction. Violations are prompt-design defects, not dispatch-skill defects.

C4. Every finding MUST cite specific evidence: snippet, line reference, scenario, or direct quote. Instruct each reviewer to either cite or retract.

C5. MUSTN'T merge or replace `code-review` skill. `swarm` is infrastructure; `code-review` is consumer. Maintain defined consumer-service boundary.

C6. No bare model names in skill, reviewer files, or synthesis output. Use model class terms only: `haiku-class`, `sonnet-class`, `opus-class`, `gpt-class`.

C7. CLI-as-dispatch (e.g., `claude -p`, copilot CLI) out of scope until task 10-0845 reaches PASS. Once 10-0845 lands, Copilot Reviewer and CLI-backed personalities may use CLI dispatch pattern defined there.

C8. Don't expand personality registry with new built-in entries without spec amendment and audit pass.

Behavior:
B1. If `problem` is empty or can't be resolved into review packet with non-empty Artifacts field, return error: "No reviewable artifact found." Don't dispatch any personalities.

B2. If swarm is empty after availability gating, return error: "Swarm empty after gating — no personalities available." Don't attempt synthesis.

B3. If swarm contains only Devil's Advocate, proceed with single-personality swarm and note in synthesis that review is adversarial only.

B4. If dispatched personality returns no findings or times out, record as non-contributing and exclude from synthesis. Note in synthesis output.

B5. If all dispatched personalities return no findings, synthesis MUST state "No findings from any reviewer" and assign confidence rating Low.

B6. Devil's Advocate MUST always be dispatched unless explicitly excluded by `personality_filter` with named subset omitting it.

B7. Custom menu personalities evaluated against caller-supplied trigger condition. If trigger is "always", always include (subject to availability gating if external backend).

B8. Cross-vendor diversity: if all available personalities resolve to the same model family or vendor, EITHER swap Devil's Advocate to a different family via `vendor` override OR degrade to single-adversary mode (dispatch code-review skill instead of swarm). Do NOT run a homogeneous swarm — sycophantic conformity risk (homogeneous-debate loss up to 32 pp, arxiv 2605.00914). Preferred resolution order: (1) find any gated personality on a different family; (2) Devil's Advocate override to different vendor; (3) degrade to code-review single-adversary mode. Report chosen resolution in synthesis preamble.

Defaults:
D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: first available from `suggested_models` frontmatter; fallback `sonnet-class`.
D3. Default dispatch: rolling window of 3. Never more than 3 personalities in flight at once.
D4. Default `model_overrides`: none.
D5. Custom menu entry with no model class and no caller override: default `sonnet-class`.
D6. Confidence rating default: Medium. Raised to High when all personalities agree and all findings cite evidence. Lowered to Low when disagree set non-empty on high-severity point, or when any personality returns no findings.

Calibration examples:
High: Security Auditor, Code Quality Critic, and Devil's Advocate all flag same SQL injection risk with evidence cites; no disagreements. → High.
Medium (default): Reviewers agree on two findings but one personality returns "No findings." Wait — "any personality returns no findings" triggers Low, not Medium. → Low.
Medium (true): Reviewers produce 3 findings with evidence; no high-severity disagreements; all personalities contributed. → Medium.
Low: Devil's Advocate returns "No findings"; or Security Auditor and Architect reach contradictory conclusions on shipping-blocking concern. → Low; state what would raise it.

Error Handling:
E1. Unavailable external backend (probe fails): drop personality, note in synthesis, continue. Don't fail-stop.
E2. Empty swarm after gating: return error (B2). Don't synthesize.
E3. Dispatch failure for individual personality (crash or incoherent output): treat as non-contributing (B4). Don't block synthesis.
E4. Review packet assembly fails (no artifact resolvable): return error (B1). Don't dispatch.
E5. Synthesis exceeds word budget: truncate at priority order — disagreements first, then high-severity, then medium, then low. Note truncation in output.

Precedence:
P1. `personality_filter` overrides trigger-condition evaluation; only named personalities dispatched; triggers bypassed for named entries.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.
P5. Synthesis word budget (2000-word cap) overrides completeness. Truncation required over exceeding cap.

Related:
`dispatch` — agent-launching skill; swarm delegates all sub-agent launches here.
`compression` — compression skill used to produce compressed form of this skill.
`specs/arbitrator.md` — sub-specification for arbitrator consolidation role.
`specs/dispatch-integration.md` — sub-specification for dispatch integration patterns.
`specs/glossary.md` — canonical term definitions for swarm skill family.
`specs/personality-file.md` — sub-specification for reviewer personality file format.
`specs/registry-format.md` — sub-specification for personality registry format and crawl behavior.

Scope Boundaries:
Does NOT cover:
`code-review` consumer skill or any other consumer skill's internal logic.
How to write reviewer prompts.
Non-review dispatch use cases (search, generation, transformation).
Any side-effecting operation by dispatched personality; all personalities strictly read-only.
CLI-as-dispatch patterns until task 10-0845 is complete.
`local-llm` backend routing in v1.