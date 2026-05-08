---
name: swarm
description: Multi-personality review infrastructure — selects personalities, gates availability, dispatches in parallel, arbitrates, and synthesizes a verdict. Triggers - swarm review, multi-reviewer, parallel personalities, run all reviewers, arbitrate findings.
---

Usage: Never dispatch this skill as a sub-agent — it cannot orchestrate further dispatches from a leaf position.

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
High-severity point: finding that would block shipping or require architectural change. Covers both HIGH and CRITICAL severity labels from Step 5 dispatch output — they share the same threshold. Maps to the arbitrator's Critical actions section. Used in confidence rating (D6) and E5 truncation priority; HIGH and CRITICAL receive equal truncation priority.
Availability probe: lightweight shell command (e.g., `copilot --version`) or tool call confirming backend is live before including personality.
Backend: execution target for personality. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
Arbitrator: single sonnet-class sub-agent dispatched after all swarm members complete. Receives full member outputs and review packet. Returns structured action list only. Not reviewer. Not in registry. Not subject to personality selection, availability gating, or `personality_filter`.
Generated persona: reviewer personality manifested inline at runtime when registry yields fewer than 3 suitable personalities for the artifact. Has name, critique lens, scope limiter — all specific to artifact's domain. Exists for current invocation only; not persisted; no `reviewers/` file; not cached in hash record.
Manifest hash: SHA-256 of canonical input manifest — sorted file paths concatenated with their content hashes. For non-file artifacts (text, conversation excerpts), SHA-256 of artifact content. Used as cache key for all hash-record entries.

Personality Registry:
Registry is external to skill. Built-in personality definitions live as separate files at `swarm/reviewers/<name>.md`. Registry = directory listing — every `*.md` in `reviewers/` that passes metadata-validation gate is registered. Adding personality = drop new file; no spec or SKILL.md edit needed.
Registry loading: crawl `reviewers/` at runtime when swarm invocation begins. Compile-time enumeration not used. `reviewers/index.yaml` = ordered manifest — provides metadata and ordering for personalities discovered during crawl.
Metadata-validation gate: any file in `reviewers/` subject to automatic metadata-validation before registration. File failing validation silently skipped. No human approval required. Valid files auto-registered.

Built-in personalities (informative — not normative):

| # | Personality | Trigger | Suggested model class | Backend | Scope |
| --- | --- | --- | --- | --- | --- |
| 1 | Devil's Advocate | always | sonnet-class | dispatch-sonnet | Challenge assumptions; no constructive suggestions |
| 2 | Accessibility Officer | UI, web rendering, forms, interactive elements, color, user-facing text | sonnet-class | dispatch-sonnet | WCAG 2.2 AA only; no logic, security, or performance |
| 3 | Architect | system structure, new abstractions, service boundaries, shared infrastructure | sonnet-class | dispatch-sonnet | Structural concerns only; no implementation details |
| 4 | Designer | public interfaces, APIs, library surfaces, shared types, config contracts | sonnet-class | dispatch-sonnet | Public surface and caller experience only; no internals |
| 5 | Engineer | new logic, integrations, state mutation, error handling, partial failure | sonnet-class | dispatch-sonnet | Practical correctness only; no style or architecture |
| 6 | Linguist | code, docs, error messages, log strings, user-visible text, named abstractions | sonnet-class | dispatch-sonnet | Naming, clarity, communication only |
| 7 | Penny Pincher | API calls, DB queries, loops, caching, storage, cloud resource usage | sonnet-class | dispatch-sonnet | Cost and resource efficiency only |
| 8 | Privacy Advocate | user data, PII, analytics, logging, storage, data transmission, identity, consent | sonnet-class | dispatch-sonnet | Privacy and data handling only; no unrelated security |
| 9 | Security Auditor | auth, user input, API endpoints, data access, secrets, network calls, file system writes, process execution | sonnet-class | dispatch-sonnet | Find vulnerabilities only; no design advice |
| 10 | Copilot Reviewer | code + copilot-cli available | external | copilot-cli | Full code review via Copilot; availability-gated |
| 11 | Custom Specialist | caller supplies via custom menu | varies | varies | Defined by caller in custom menu entry |

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

Model selection at dispatch: see Step 2.

Custom Personality Menu:
Callers may supply additional personalities for single invocation. Each entry MUST specify: name, trigger condition, model class (or inherit from caller override), backend, scope limiter. Custom entries appended after entry 9 in evaluation order. Don't mutate built-in registry.

Inputs:

| Input | Required | Description |
| --- | --- | --- |
| `problem` | required | Content under review. |
| `personality_filter` | optional | List of personality names or indices. Named personalities dispatched regardless of trigger evaluation; triggers bypassed for named entries. Inclusion list only — not exclusion gate. |
| `model_overrides` | optional | Map of personality name to model class. Affects model class only, not backend type. |
| `arbitrator_model` | optional | Model class for the arbitrator dispatch. Defaults to `sonnet-class`. Use `opus-class` for high-stakes reviews where arbitrator judgment quality is critical. |

Caller Tier:
Host agent executing skill MUST be sonnet-class minimum. Callers dispatching swarm via `dispatch` skill MUST use `tier: standard` or higher. If no dispatch mechanism is available in the host runtime, return error: "Swarm requires dispatch capability; no dispatch mechanism available."

Step Sequence:

Step 1 — Build review packet:
Hash record check (early gate): before building the packet, extract the file list directly from `problem` (deterministic parse — no LLM). Read file contents and compute manifest hash (sorted paths + content hashes, SHA-256; or SHA-256 of artifact text for non-file inputs). Compute `filter_hash` = SHA-256 of sorted `personality_filter` list (empty list if no filter). Check `.hash-record/XX/HASH/swarm/v1/<filter_hash>/report.md` (where XX = first two hex chars of HASH, v1 is the current skill version). Hit: return cached result, skip Steps 2-8. Miss: apply B10 partial recovery check before proceeding — check `.hash-record/XX/HASH/swarm/v1/` for any existing per-persona results; treat found results as complete, proceed with remaining personalities only.

Continue to packet assembly only on miss:
Construct review packet from `problem`. Packet MUST be self-contained: reader with zero prior context must understand what is reviewed, why, and what key decisions were.

Packet fields (omit if not applicable):
Goal: problem being solved or output being evaluated.
Approach: what was proposed, implemented, or produced.
Key decisions: why this approach over alternatives.
Artifacts: actual content under review (diffs, text, config — not a description).
Files affected: list with brief descriptions.
Blast radius: downstream consumers, imports, integrations affected.
Conventions: applicable project conventions.

Verify packet before proceeding: Goal must name the artifact type and state what outcome is being evaluated (e.g., "evaluate diff for correctness and security"); Artifacts must include actual content, not just references. If either fails, attempt to resolve gap from available context. Don't ask caller to fill gaps. If gap cannot be resolved, return error per B1 and halt.

Step 2 — Select personalities:
Build combined registry by crawling `reviewers/` (applying metadata-validation gate) and appending caller-supplied custom menu entries.

If `personality_filter` supplied: restrict candidate set to named personalities; dispatch regardless of trigger evaluation (triggers bypassed). If no filter: evaluate trigger conditions against problem traits inferred from review packet; exclude personalities whose trigger isn't satisfied.

For each personality in active set, read `suggested_models` from frontmatter and select first available. For `dispatch-*` backends, no model-class probe is run — treat all listed entries as available and select the first. Caller `model_overrides` take precedence. If no `suggested_models` available and no override, default to `sonnet-class`.

Selection logic MUST be inline within skill.

Personalities with `required: true` MUST always be included regardless of trigger evaluation. `personality_filter` may exclude required personality only when caller explicitly names subset omitting it. Devil's Advocate carries `required: true`.

5-cap: if more than 5 personalities pass trigger evaluation and availability gating, apply priority order: (1) Devil's Advocate always; (2) personalities with most-specific trigger match (specificity score = count of distinct comma-delimited terms in `trigger` field; `"always"` = 0; tie-break: alphabetical personality name); (3) drop lowest-priority remaining until count reaches 5.

Manifest gap fill: if selection yields fewer than 3 suitable personalities after filter and trigger evaluation, manifest one or more generated personas inline to reach at least 3. For each: invent name relevant to artifact domain, critique lens covering problem traits not already represented, scope limiter avoiding overlap with selected personalities. Dispatch same as built-in; don't add to registry; don't cache in hash record.

Step 3 — Availability gating:
For each selected personality whose backend is NOT `dispatch-sonnet`, `dispatch-haiku`, or `dispatch-opus` (i.e., any external backend such as `copilot-cli`):
Run availability probe before including.
Probe succeeds: include.
Probe fails: drop from swarm for this invocation. Note drop in synthesis output. Don't fail-stop or surface error to caller.

For `dispatch-*` backends, no probe required; dispatch skill handles errors internally. If all personalities are dropped (swarm empty), return error per B2.

Step 4 — Load reviewer prompts:
Only after swarm is finalized (post-gating) load prompt for each surviving personality. Reviewer prompts stored as separate sub-skill files under `swarm/reviewers/<name>.md`. Filename = personality name lowercased with spaces and apostrophes replaced by hyphens (e.g., `devils-advocate.md`, `security-auditor.md`). Load only files for dispatched personalities. Don't load files for non-dispatched personalities. If a prompt file cannot be loaded, treat the personality as non-contributing per E3 and continue.

Step 5 — Dispatch:
Dispatch swarm personalities using your runtime dispatch mechanism, following the `dispatch` skill for implementation details. Maximum concurrency — dispatch up to 3 in parallel; as each completes, dispatch the next until all have run. Treat any personality that has not returned within a host-defined threshold (recommended: typical sonnet-class response time + 20%) as timed out per B4.

As each personality completes, immediately write its raw output to `.hash-record/XX/HASH/swarm/v1/<persona-name>/report.md` (built-in personas only — not generated). `<persona-name>` uses the same slugification as the reviewer filename (Step 4): personality name lowercased with spaces and apostrophes replaced by hyphens. Do not wait for all dispatches to complete before writing.

Each personality dispatch receives:
1. Full review packet from Step 1.
2. Personality's prompt loaded in Step 4.
3. Explicit read-only constraint — include verbatim in each prompt: "read-only review — analyze and report only, no file edits, no commits, no shell commands" (see C1–C3).

Apply `model_overrides` at dispatch time: if caller override exists, use it; otherwise use first available entry from `suggested_models`; otherwise fall back to `sonnet-class`. Diversity check after model selection: if all selected personalities resolve to the same model family, apply resolution order before dispatching — (1) include any personality from the full candidate registry on a different model family; (2) re-assign Devil's Advocate to a different vendor via `vendor` override; (3) if neither resolves, proceed and set `homogeneity_warning`. (B8 governs this rule.)

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-personality:<personality-name>`

Must return: structured findings list. Each finding: description + evidence cite (snippet, line reference, scenario, or direct quote). Empty response or "No findings" = valid return — treated as non-contributing (B4).

Structured-evidence requirement (high/critical findings): any finding marked HIGH or CRITICAL severity MUST include three fields: Source (where the vulnerability/bug enters), Sink (where it causes harm), Missing guard (what defense is absent). Findings at HIGH/CRITICAL without this structure are automatically downgraded to MEDIUM.

Step 6 — Arbitrator consolidation:
File-existence filter (pre-arbitration): before forwarding member findings to the arbitrator, discard any finding that cites a file not present in the review packet's Files-affected list. Deterministic string match (exact path). Do not use LLM judgment for this filter — it is mechanical. If a finding does not cite a specific file, retain it.

After all swarm member outputs collected, dispatch single arbitrator sub-agent using `arbitrator_model` (default: `sonnet-class`). Arbitrator receives all raw member outputs and original review packet. Per B4, non-contributing member outputs (empty/timeout) excluded from arbitrator's input set.

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-arbitrator`

Must return: structured two-section action list — Obvious actions and Critical actions — as specified in required arbitrator output format below. If no actionable findings: "No actionable findings" stated explicitly.

Arbitrator's sole job: produce structured action list — not narrative synthesis.

Required arbitrator output format (two sections):
Obvious actions: 2+ swarm members independently flagged same concern, or concern is self-evident from artifact. Each entry: action description + source personality names + evidence cite.
Critical actions: items that, if unaddressed, would block shipping or require architectural change, regardless of reviewer agreement count. Each entry: action description + source personality names + evidence cite + severity rationale.

Authoritative format: `specs/arbitrator.md` — inline above is a summary only. On any amendment to the output structure, update both in the same commit.

Arbitrator MUSTN'T include speculative, low-confidence, or duplicate items. Its output = input to Step 7; host synthesizes from this list only, not raw member output.

Grounded-challenge requirement: before citing a member finding as incorrect, arbitrator MUST quote the exact sentence from that finding it believes is wrong. Challenging an interpretation rather than an explicit claim is not permitted.

If arbitrator produces empty list, it MUST state "No actionable findings" explicitly. Host MUST still proceed to synthesis and note clean result.

Arbitrator is structurally separate from registry. MUSTN'T appear in registry, MUSTN'T be subject to personality selection, availability gating, or `personality_filter`.

Step 7 — Aggregate findings and track disagreements:
Collect findings from arbitrator's structured action list. For each item, record: personality names cited, finding summary, cited evidence.

Identify disagree set: items where arbitrator flagged conflicting conclusions (source personality names from different members with contradictory claims on same point). Each disagree entry records personalities involved and conflicting claims.

Step 8 — Synthesize and return:
Synthesize from arbitrator's structured action list into single host-voice output. Don't dump raw sub-agent output or raw arbitrator output to caller. Speak as host, presenting refined takeaways. Strip reviewer attribution — don't name personalities in output.

Required synthesis output fields:
Active personalities: name (model-class) for each; tag generated personas with "(generated)".
Critical actions: each item that would block shipping or require architectural change.
Findings: remaining consensus findings.
Disagreements: explicit statement of each disagree-set item; state tension and apply judgment.
Unavailable personalities: personalities dropped by availability gate with reason.
Non-contributing personalities: personalities dispatched but returned empty output, timed out, or returned incoherent output.
Confidence rating: High, Medium, or Low. Include rationale. If Low, state what would raise it.

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
```

Synthesis output MUSTN'T exceed 2000 words. If findings exceed budget, prioritize high-severity and disagreement items. Note truncation in output.

Hash record write: after synthesis completes, write full result to `.hash-record/XX/HASH/swarm/v1/<filter_hash>/report.md`. Per-persona results were already written during Step 5. Generated personas are not written. If `v1/<filter_hash>/report.md` already exists, skip the write (idempotency guard). Current skill version: `v1`. Bump to `v2` when persona prompts, selection criteria, arbitrator procedure, or hash algorithm changes in a way that could affect review quality. Wording and formatting changes do not require a bump.

Constraints:
C1. All dispatched sub-agents operate in read-only mode. Sub-agents MUSTN'T edit files, run side-effecting commands, commit, or call mutating tool. State constraint explicitly in every personality's dispatch prompt.

C2. Include literal phrase "read-only review — analyze and report only, no file edits, no commits, no shell commands" in each personality's dispatch prompt. For each finding, verify before including: (1) cited file path appears in provided diff/artifact; (2) cited line is within changed/relevant section or within 10 lines of one; (3) verbatim code quotes appear in artifact; (4) directional claims (added/removed/changed) match artifact. Findings failing any check MUST be omitted, not downgraded.

C3. Skill doesn't technically prevent sub-agents from calling mutating tools — constraint is behavioral, enforced by prompt instruction. Violations are prompt-design defects, not dispatch-skill defects.

C4. Every finding MUST cite specific evidence: snippet, line reference, scenario, or direct quote. Instruct each reviewer to either cite or retract.

C5. MUSTN'T invoke `code-review` skill internally. The two are siblings with separate intent; neither is a dependency of the other.

C6. No bare model names in skill, reviewer files, or synthesis output. Use model class terms only: `haiku-class`, `sonnet-class`, `opus-class`, `gpt-class`.

C7. CLI-as-dispatch (e.g., `claude -p`, copilot CLI) out of scope until task 10-0845 reaches PASS. Once 10-0845 lands, Copilot Reviewer and CLI-backed personalities may use CLI dispatch pattern defined there.

C8. Don't expand personality registry with new built-in entries without spec amendment and audit pass.

Behavior:
B1. If `problem` is empty or can't be resolved into review packet with non-empty Artifacts field, return error: "No reviewable artifact found." Don't dispatch any personalities.

B2. If swarm is empty after availability gating, return error: "Swarm empty after gating — no personalities available." Don't attempt synthesis.

B3. If swarm contains only Devil's Advocate, proceed with single-personality swarm and note in synthesis that review is adversarial only.

B4. If dispatched personality returns no findings or times out, record as non-contributing and exclude from synthesis. Note in `Non-contributing personalities` synthesis field.

B5. If all dispatched personalities return no findings, synthesis MUST state "No findings from any reviewer" and assign confidence rating Low.

B6. Devil's Advocate MUST always be dispatched unless explicitly excluded by `personality_filter` with named subset omitting it.

B7. Custom menu personalities evaluated against caller-supplied trigger condition. If trigger is "always", always include (subject to availability gating if external backend).

B8. Cross-vendor diversity: if all finalized swarm personalities resolve to the same model family or vendor, attempt resolution before dispatching. Preferred resolution order: (1) find any personality in the full candidate registry on a different model family — include it; (2) re-assign Devil's Advocate to a different vendor via `vendor` override. If neither resolves the monoculture, proceed with the homogeneous swarm and include `homogeneity_warning` in synthesis output. Do NOT degrade to code-review.

B9. Generated persona dispatch: generated personas dispatched in Step 5 same as built-in. Receive: review packet, inline system prompt synthesized from name + lens + scope, explicit read-only constraint. Not in registry; not cached (always re-dispatched).

B10. Hash record partial recovery: if a previous swarm run on the same manifest hash was interrupted before completion, check `.hash-record/XX/HASH/swarm/vN/` for existing per-persona results. Treat cached built-in persona results as complete; re-dispatch only missing built-in personas and all generated personas.

Defaults:
D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: first available from `suggested_models` frontmatter; fallback `sonnet-class`. Callers may override individual personalities via `model_overrides`.
D3. Default dispatch: rolling window of 3. Never more than 3 personalities in flight at once.
D4. Default `model_overrides`: none.
D4b. Default `arbitrator_model`: `sonnet-class`.
D5. Custom menu entry with no model class and no caller override: default `sonnet-class`.
D6. Confidence rating default: Medium. Raised to High when (1) disagree set is empty AND (2) every dispatched personality returned at least one finding AND all findings cite evidence. Lowered to Low when disagree set non-empty on high-severity point, or when any personality returns no findings.
D7. `.hash-record/` base path: workspace root (root of the repository or project containing the reviewed artifact). Relative path `.hash-record/` resolves against workspace root. If workspace root is ambiguous, use the directory containing the `problem` artifact's nearest root marker (e.g., `.git`).

Calibration examples:
High: Security Auditor, Code Quality Critic, and Devil's Advocate all flag same SQL injection risk with evidence cites; no disagreements. → High.
Medium (default): Reviewers agree on two findings but one personality returns "No findings." Wait — "any personality returns no findings" triggers Low, not Medium. → Low.
Medium (true): Reviewers produce 3 findings with evidence; no high-severity disagreements; all personalities contributed. → Medium.
Low: Devil's Advocate returns "No findings"; or Security Auditor and Architect reach contradictory conclusions on shipping-blocking concern. → Low; state what would raise it.

Error Handling:
E1. Unavailable external backend (probe fails): drop personality, note in synthesis, continue. Don't fail-stop.
E2. Empty swarm after gating: return error (B2). Don't synthesize.
E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): treat as non-contributing (B4). Don't block synthesis. Incoherent output: response cannot be parsed into a structured findings list and is not a recognizable "No findings" statement (a response of "No findings" with or without brief rationale is valid, not incoherent).
E4. Review packet assembly fails (no artifact resolvable): return error (B1). Don't dispatch.
E5. Synthesis exceeds word budget: truncate at priority order — disagreements first, then high-severity, then medium, then low. Note truncation in output.
E6. Arbitrator dispatch fails or returns no structured output: return error to caller with per-personality summary from Step 7 (if any). Don't attempt synthesis from raw member outputs.
E7. Hash record write failure (Steps 5 or 8): non-fatal. Log the failure and continue. Per-persona write failure (Step 5): continue dispatching remaining personalities; B10 re-dispatches missing persona on next run. Synthesis write failure (Step 8): result already returned to caller — log and return normally. Don't abort the swarm or surface a write error to the caller.

Precedence:
P1. `personality_filter` overrides trigger-condition evaluation; only named personalities dispatched; triggers bypassed for named entries.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.
P5. Synthesis word budget (2000-word cap) overrides completeness. Truncation required over exceeding cap.

Related: the `dispatch` skill (`../dispatch/SKILL.md`) — agent-launching skill. `specs/arbitrator.md` — arbitrator format.
