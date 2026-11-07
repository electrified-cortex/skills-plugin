---
name: swarm
description: Multi-lens review of anything (the current conversation by default, or a file, a diff, a plan, a concept). Cheap parallel reviewers, a skeptic for each, one arbiter, one result file. Triggers - /swarm, swarm this, swarm the discussion, double check what we discussed, swarm review, multi-reviewer, run all reviewers.
---

Usage: Never dispatch this skill as a sub-agent — it can't orchestrate further dispatches from a leaf position.

Key Terms:
Subject: what is being swarmed, decided first in Step 0. With no explicit subject it is the current discussion.
Artifact: the subject's content under review — conversation excerpt, file path, diff, plan, doc, concept, or structured description. Passed as `problem`, or taken from the conversation.
Review packet: self-contained brief assembled from artifact. Fields: Goal, Approach, Key decisions, Artifacts (actual content), Files affected, Blast radius, Conventions. Omit inapplicable fields.
Personality: named reviewer role defined by `reviewers/<name>.md` with YAML frontmatter. Has trigger condition, optional advisory escalation model, backend preference list, scope limiter. Loaded lazily — full prompts absent at selection time.
Personality registry: set of personalities discovered by crawling `reviewers/` at runtime. Not static table. Extended per-invocation by caller-supplied custom menu.
Custom menu: caller-supplied list of additional personalities appended to registry for current invocation only. Doesn't persist.
Selection: filtering combined registry against artifact problem traits to produce active personality set.
Availability gate: probe step confirming personality's required backend is reachable before dispatch.
Swarm: surviving personalities after selection and availability gating.
Dispatch skill: `dispatch` skill — runtime-specific how-to for launching sub-agents. Reference for host agent executing this skill — not delegation target. Host dispatches directly using its own runtime mechanism (runSubagent in VS Code Copilot, Task in Claude Code).
Disagree set: subset of swarm findings where 2+ personalities reached contradictory conclusions on same point.
Confidence rating: High/Medium/Low scalar on synthesis output. Reflects reviewer agreement, evidence quality, scope coverage.
Model class: abstract tier — `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning), `opus-class` (heavy architectural reasoning), `gpt-class` (external OpenAI-hosted model). Each model class resolves to one model family (haiku-class, sonnet-class, opus-class: Anthropic; gpt-class: OpenAI).
Caller override: caller-supplied `model_overrides` map pinning 1+ personalities to specific model class for current invocation.
High-severity point: finding that would block shipping or require architectural change. Corresponds to member's `blocking` severity (see `member-contract.md`). Maps to arbiter's Critical actions section. Used in confidence rating (D6) and E5 truncation priority.
Availability probe: lightweight shell command (e.g., `copilot --version`) or tool call confirming backend is live before including personality.
Backend: execution target for personality. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
Arbiter: single sub-agent (haiku-class by default) dispatched after all swarm members complete. Reads member reports, challenge files and packet header (not whole packet) from run folder, writes `RESULT.md` there, replies with brief summary. Not reviewer. Not in registry. Not subject to personality selection, availability gating, or `personality_filter`.
Run folder: unique scratch dir (session scratchpad/temp) host creates after packet verifies and before any dispatch, at new path that didn't exist before (`swarm-<first 8 hex of manifest hash>-<UTC timestamp>`). Holds `packet.md`, generated-persona reports, `RESULT.md`. Host only picks path and creates it; does not read reports from it by default. After creation arbiter owns it.
Report file: member's full findings, written by member itself (no size cap).
Challenger: `haiku-class` sub-agent paired with one member. Reads packet and that member's report, adds no findings, writes verdict (`CONFIRMED`, `REJECTED`, `UNSURE`) for every finding to challenge file. Follows `challenger-contract.md`.
RESULT.md: arbiter's structured action list at `<run>/RESULT.md`. File host reads by default (see Host options in Step 6).
Generated persona: reviewer personality manifested inline at runtime when registry yields <3 suitable personalities for artifact. Has name, critique lens, scope limiter — all specific to artifact's domain. Exists for current invocation only; not cached; no `reviewers/` file.
Manifest hash: SHA-256 of canonical input manifest — sorted file paths concatenated with their content hashes. For non-file artifacts (text, conversation excerpts), SHA-256 of artifact content. Used as artifact key for per-persona hash-record entries.

Personality Registry:
Registry is external to skill. Built-in personality definitions live as separate files at `swarm/reviewers/<name>.md`. Registry = directory listing — every `*.md` in `reviewers/` that passes metadata-validation gate is registered. Adding personality = drop new file; no spec or `SKILL.md` edit needed.
Registry loading: crawl `reviewers/` at runtime when swarm invocation begins. Compile-time enumeration not used. `reviewers/index.yaml` = ordered manifest — provides metadata and ordering for personalities discovered during crawl.
Metadata-validation gate: any file in `reviewers/` subject to automatic metadata-validation before registration. File failing validation silently skipped. Validation uses `reviewers/index.yaml` and the directory listing; persona bodies are never read at selection. No human approval required. Valid files auto-registered.

Built-in personalities (informative — not normative):

| # | Personality | Trigger | Start class | Backend | Scope |
| --- | --- | --- | --- | --- | --- |
| 1 | Devil's Advocate | always | haiku-class | dispatch-sonnet | Challenge assumptions; no constructive suggestions |
| 2 | Minimalist | always | haiku-class | dispatch-sonnet | Reduce complexity; focus on essentials |
| 3 | Accessibility Officer | UI, web rendering, forms, interactive elements, color, user-facing text | haiku-class | dispatch-sonnet | WCAG 2.2 AA only; no logic, security, or performance |
| 4 | Architect | system structure, new abstractions, service boundaries, shared infrastructure | haiku-class | dispatch-sonnet | Structural concerns only; no implementation details |
| 5 | Designer | public interfaces, APIs, library surfaces, shared types, config contracts | haiku-class | dispatch-sonnet | Public surface and caller experience only; no internals |
| 6 | Engineer | new logic, integrations, state mutation, error handling, partial failure | haiku-class | dispatch-sonnet | Practical correctness only; no style or architecture |
| 7 | Linguist | code, docs, error messages, log strings, user-visible text, named abstractions | haiku-class | dispatch-sonnet | Naming, clarity, communication only |
| 8 | Penny Pincher | API calls, DB queries, loops, caching, storage, cloud resource usage | haiku-class | dispatch-sonnet | Cost and resource efficiency only |
| 9 | Privacy Advocate | user data, PII, analytics, logging, storage, data transmission, identity, consent | haiku-class | dispatch-sonnet | Privacy and data handling only; no unrelated security |
| 10 | Security Auditor | auth, user input, API endpoints, data access, secrets, network calls, file system writes, process execution | haiku-class | dispatch-sonnet | Find vulnerabilities only; no design advice |
| 11 | Custom Specialist | caller supplies via custom menu | varies | varies | Defined by caller in custom menu entry |

Integer index is informative only. Stable runtime index = alphabetical crawl (1-based). Personality renames change index; callers using `personality_filter` by name unaffected.

Personality Metadata Schema:
Each `reviewers/<name>.md` must begin with YAML frontmatter block. Files missing required fields or with malformed frontmatter fail validation gate and are silently skipped.

Required fields:

```yaml
---
name: <string>          # display name; unique across all files in reviewers/
trigger: <string>       # trigger condition; "always" for unconditional inclusion
required: <bool>        # true = always dispatched regardless of personality_filter (unless explicitly excluded)
# no model field: every personality starts at the lowest tier (see escalation_model under optional fields)
suggested_backends:     # preference-ordered list of backend identifiers
  - <backend>           # first entry = most preferred
scope: <string>         # what this personality reviews and what it ignores
---
```

Optional fields:

```yaml
vendor: <string>        # model vendor hint (e.g. anthropic, openai); used by diversity rule B8
escalation_model: <model-class>   # advisory: tier to re-run this personality at if it asks for escalation; absent = next tier up; never raises the starting tier
```

Model selection at dispatch: see Step 2.

Custom Personality Menu:
Callers may supply additional personalities for single invocation. Each entry must specify: name, trigger condition, model class (or inherit from caller override), backend, scope limiter. Custom entries appended after all built-in entries in evaluation order. Don't mutate built-in registry.

Inputs:

| Input | Required | Description |
| --- | --- | --- |
| `problem` | optional | What to review: any artifact (see Step 0). Absent means the current discussion. |
| `personality_filter` | optional | List of personality names (strings). Named personalities dispatched regardless of trigger evaluation; triggers bypassed for named entries. Inclusion list only — not exclusion gate. Indices not accepted (registry built by filesystem crawl; index positions unstable across reviewer-file changes). |
| `model_overrides` | optional | Map of personality name to model class. Affects model class only, not backend type. |
| `arbiter_model` | optional | Model class for arbiter dispatch. Defaults to `haiku-class`. Upgrade to `sonnet-class` when artifact is safety-critical (Step 2 auto-trigger), security- or privacy-sensitive, or result gates ship decision, or when first `haiku-class` result looks off (no Dropped section, near-wholesale acceptance of proposed cuts, many UNSURE verdicts). Use `opus-class` for highest-stakes reviews. |

Model economics:
`haiku-class` swarm is where the value is: breadth (several independent lenses plus skeptical check) is cheap, and breadth is what finds problems. Return on each step up in model class shrinks, so stronger model in one role buys little compared with another lens. Prefer `haiku-class` for every role (members, challengers, arbiter); upgrade only where specific lens or verdict needs it, one role at a time: persona via `model_overrides`, then arbiter via `arbiter_model`. Upgrading whole swarm is for highest-stakes reviews. Adding another `haiku-class` lens usually returns more than upgrading existing one. Every personality starts at `haiku-class`. Personality may ask for escalation, and host may then re-run just that persona at higher tier (Step 6, host option 4), so extra spend follows evidence of need. Each agent also has large fixed cost and run is 2N+1 agents (N reviewers, N challengers, one arbiter), so small artifacts suit fewer lenses.

Caller Tier:
Host agent executing skill must be sonnet-class minimum. Swarm runs in the host and is never dispatched as a sub-agent. If no dispatch mechanism available in host runtime, return error E_NO_DISPATCH: "Swarm requires dispatch capability; no dispatch mechanism available."

Step 0 — Decide what is being swarmed:
Do this first, before anything else, and say it in one line before any dispatch: `Swarming: <subject> — <what the review will check>`. Don't ask which subject unless truly impossible to tell: pick most likely, state the choice, let operator correct it.
Subject can be anything: the conversation, a file or files, a diff, a plan, a document, a concept or idea, a decision, a claim, a question, code. Resolve in this order:
1. Explicit subject in request or `problem`: a path, diff, quoted text, URL, or named thing ("swarm the caching design", "swarm this file").
2. Deictic subject ("this", "that", "it", "what you just said"): most recent matching thing in the conversation (last file touched, last proposal, last answer).
3. No subject (`/swarm`, "swarm", or "swarm this" with nothing to point at): swarm the discussion — current topic of conversation, from where it began to now, including your own statements, claims, decisions, reasoning. Purpose: double-check what was discussed (verify claims, find gaps, challenge conclusions).
When subject is conversation, artifact is a conversation excerpt: write the relevant turns into packet verbatim, not summarized, covering the stretch on the current topic (whole session only if it is all one topic). Goal states it checks the discussion for correctness, gaps, unsupported claims. Prefer topic-specific generated lenses (for example a claim checker) in addition to always-on lenses.

Step Sequence:
Step 0 decides the subject; eight steps then run in order for every swarm invocation, from packet assembly through final synthesis.

Step 1 — Build review packet:
Cache key: before building packet, extract file list directly from `problem` (deterministic parse, computed by script — no LLM). Read file contents, compute manifest hash HASH (sorted paths + content hashes, SHA-256; or SHA-256 of artifact text for non-file inputs). Per-persona reports are cached under `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/` (XX = first two hex chars of HASH; D7 sets base path), holding `report.md` and `challenge-<challenger_key>.md`. `persona_key` = first 8 hex chars of SHA-256 of that persona's file, `member-contract.md` and raw subject text (the `problem` string, or the conversation excerpt). Challenge file named `challenge-<challenger_key>.md`, `challenger_key` = first 8 hex chars of SHA-256 of `challenger-contract.md`. Step 5 reuses a cached report. No whole-run cache.

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

Once packet verifies, create run folder (new path that didn't exist before; see Run folder) and write packet to `<run>/packet.md`. Halt above leaves no folder behind.

Step 2 — Select personalities:
Build combined registry by crawling `reviewers/` (applying metadata-validation gate) and appending any caller-supplied custom menu entries.

If `personality_filter` supplied: restrict active personality set to named personalities; dispatch those regardless of trigger evaluation (triggers bypassed for named entries). If no filter: evaluate trigger conditions against problem traits inferred from review packet; exclude personalities whose trigger isn't satisfied. Evaluation is semantic judgment against review packet content, not literal string matching against `trigger` field text.

Safety-critical artifact auto-trigger: fires when review packet's Files-affected list (or, if packet omits it, files named in Artifacts) contains any artifact whose failure could break host environment, propagate across fleet, or compromise process lifecycle — control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar. When it fires, add Engineer, Devil's Advocate, Minimalist to active personality set, regardless of trigger evaluation or `personality_filter`. Callers can't opt out via filter. Precedence: rule supersedes `personality_filter` override of trigger evaluation for the 3 named personalities. Additions here protected from 6-cap drop step.

Every personality starts at `haiku-class`. Caller `model_overrides` take precedence. Personality's optional `escalation_model` is advisory: names tier to re-run at if that personality asks for escalation (Step 6, host option 4); never raises starting tier. For internal-dispatch backends (handled by `dispatch` skill), no model-class probe run.

Selection logic must be inline within skill.

Always include personalities with `required: true`, regardless of trigger evaluation. `personality_filter` may exclude required personality only when caller explicitly names subset that omits it. Devil's Advocate and Minimalist carry `required: true`.

6-cap: if >6 personalities pass trigger evaluation, apply priority order: (1) Devil's Advocate and Minimalist always; (2) personalities added by safety-critical-artifact auto-trigger (Engineer) — protected from cap because rule is mandatory and caller can't opt out; (3) personalities with most-specific trigger match (specificity score = count of distinct comma-delimited terms in `trigger` field; `"always"` scores 0; tie-break by alphabetical personality name); (4) drop lowest-priority remaining until count reaches 6.

Manifest gap fill: if selection yields <3 suitable personalities after filter and trigger evaluation, manifest 1+ generated personas inline to reach ≥3. For each: invent name relevant to artifact's domain, critique lens covering problem traits not already represented by selected personalities, scope limiter avoiding overlap. Dispatch same as built-in; don't add to registry; don't cache in hash record.

Step 3 — Availability gating:
For each selected personality whose backend is external (not handled internally by `dispatch` skill, e.g., `copilot-cli`):
Run availability probe before including personality.
Probe succeeds: include personality.
Probe fails: drop personality from swarm for this invocation. Note drop in synthesis output. Don't fail-stop or surface error to caller.

For internal-dispatch backends (handled by `dispatch` skill), no probe required; dispatch skill handles errors internally.

Step 4 — Resolve reviewer prompts:
Only after swarm finalized (post-gating), resolve absolute path of prompt for each surviving personality: `swarm/reviewers/<name>.md`, filename = personality name lowercased, spaces replaced with hyphens, apostrophes dropped (e.g., `devils-advocate.md`, `security-auditor.md`). Host doesn't read these files; each member reads its own. If prompt file doesn't exist, treat personality as non-contributing per E3 and continue; Custom Specialist entry has no file and is replaced by generated persona. Generated persona's prompt (name, critique lens, scope limiter) written by host to `<run>/<persona-name>.persona.md`, passed same way.

Step 5 — Dispatch:
Dispatch swarm personalities using your runtime dispatch mechanism, following `dispatch` skill for implementation details. Use `dispatch` agent type for personalities, not `scout` (scout read-only; reviewers must write report file). Concurrency: `haiku-class` personalities uncapped — launch all at once (swarm size already bounded by 6-cap in Step 2). Other classes: rolling window of 3; as each completes, dispatch next until all have run. Treat any personality not returned within host-defined threshold (recommended: 5 minutes for member or arbiter, 3 minutes for challenger) as timed out per B4. Recommended tool-call budgets in dispatch prompts: 8 for member or challenger, 2N+6 for arbiter (14 at N=4), since it reads N reports and N challenge files.

Reuse before dispatch: for each persona, compute its per-persona directory (Step 1 key) at its resolved class. A cached `report.md` there ending with line `END OF REPORT` satisfies the persona, so it is not dispatched; use its `challenge-<challenger_key>.md` too if present, else dispatch only the challenger. Reports at other classes don't satisfy the request.

Reports go to files, not host. Each member writes full report to its report path, replies exactly one line: `done: <path>`. Report paths:
- Built-in persona: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/report.md`. `<persona-name>` uses same slugification as reviewer filename (Step 4): personality name lowercased, spaces replaced with hyphens, apostrophes dropped. Model class suffix prevents re-run at different tier from overwriting prior result. Member creates missing dirs.
- Generated persona: `<run>/<persona-name>.md` (never written to hash record).

Challenge pass (each member is a pair): as soon as a member returns with a report, dispatch that member's `haiku-class` challenger (`dispatch` agent type) asynchronously, in the background, without waiting for other members. Host dispatches challengers (sub-agents cannot dispatch): it launches each member's challenger as soon as that member returns. Its dispatch prompt is short: "Read and follow `challenger-contract.md`" and absolute paths of packet, that member's report, challenge file, plus same in-prompt sentence that writing challenge file is the required deliverable. Challenger adds no findings; writes verdict for every finding (CONFIRMED, REJECTED with contradicting quote, UNSURE), replies `done: <path>`. Challenge path: `challenge-<challenger_key>.md` beside the report (generated persona: `<run>/<persona-name>.challenge.md`). Challengers are `haiku-class`: uncapped, run as each member returns. Report is usable if structured, ends with line `END OF REPORT`, and is not "No findings"; member without usable report gets no challenger. Challenger that fails or times out is simply absent; arbiter then verifies that member's findings itself.

Host doesn't read report files by default (see Host options in Step 6). Host gives arbiter report paths of members that returned, and names of any that timed out or crashed (B4). Timed-out member is non-contributing; any file it left behind is ignored, so half-written report never read.

Each personality dispatch receives:
1. Path to `<run>/packet.md` (member reads it; host doesn't paste packet).
2. Absolute paths of personality's prompt (Step 4) and of `swarm/member-contract.md`; member reads both. Always pass absolute paths: sub-agent's working directory may differ from host's.
3. Its report path (absolute). Reply rule, report format, evidence checks, severity vocabulary live in `member-contract.md`, so dispatch prompt is short: "Read and follow member-contract.md", three paths, tool-call budget, and one sentence saying in prompt's own words that writing the findings file is the explicit required deliverable and findings must not be returned as text. Sentence must be in the prompt itself, not only in a contract file.
4. Read-only constraint and its single exception (write only your own report file) stated in `member-contract.md` (see C1).

Apply `model_overrides` at dispatch time: if caller override exists, use it; otherwise `haiku-class`. For internal-dispatch backends dispatch tier follows resolved model class, not backend name. Diversity check after model selection: if all selected personalities resolve to same model family, apply resolution order before dispatching — (1) include any personality from full candidate registry on different model family; (2) re-assign Devil's Advocate to different vendor via `vendor` override; (3) if neither resolves, proceed and set `homogeneity_warning`. (B8 governs this rule.)

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-personality:<personality-name>`

Report file must contain structured findings list. Each finding: description of issue, evidence cite (snippet, line reference, scenario, or direct quote). Report of "No findings", no report file, or report not ending with line `END OF REPORT`, is non-contributing (B4).

Structured-evidence requirement (enforced by `member-contract.md`): `blocking` finding must carry complete evidence shape: for behavioral flaw, Source (where problem enters), Sink (where it causes harm), Missing guard (what defense is absent); for structural flaw, invariant or boundary violated, components involved, what breaks as system grows. Without complete shape it is marked `issue`. Members use severity vocabulary `nit`, `non-blocking`, `question`, `issue`, `blocking`, already used by reviewer files.

Step 6 — Arbiter consolidation:
After all members and their challengers returned, failed, or timed out, dispatch single arbiter sub-agent using `arbiter_model` (default: `haiku-class`; see Inputs for when to upgrade), `dispatch` agent type. Dispatch prompt is short: "Read and follow `swarm/arbiter-prompt.md`" (absolute path), run folder, report path of each member that returned, challenge file path of each member that has one, names of any that timed out, any Unavailable personalities and homogeneity warning, tool-call budget, same in-prompt sentence that writing `RESULT.md` is required deliverable. `arbiter-prompt.md` holds verification rules, classification, confidence rule, `RESULT.md` format. If arbiter fails or `RESULT.md` missing, retry once before E6.

File-existence filter (discard findings citing file not in packet's Files-affected list; skipped when packet has no such list), B4 handling of non-contributing reports, rule that timed-out member's file never read: all in `arbiter-prompt.md`. Arbiter writes only `RESULT.md`, deletes nothing. Run folder left in place for drill-down; lives in session scratch space, no cleanup step.

Dispatch parameters:
`<tier>` = `standard`
`<description>` = `swarm-arbiter`

Must write `<run>/RESULT.md`: structured three-section action list — Obvious actions, Critical actions, Conflicting conclusions — as specified in `arbiter-prompt.md` — plus Participants, Confidence, Dropped, Non-contributing, Reports sections (see `arbiter-prompt.md`). Keep `RESULT.md` concise: one line per item where possible, no restating reports. If no actionable findings: "No actionable findings" stated explicitly. Must reply with: the `RESULT.md` path, the counts (critical / obvious / conflicts / non-contributing), and a short headline of the most important findings, enough for the host to hand off to the operator unread (option 1). No word limit; keep it brief.

Arbiter's sole job: produce structured action list — not narrative synthesis.

Arbiter mustn't include speculative, low-confidence, or duplicate items. `RESULT.md` is input to Step 7. It opens with a Participants line (name, model class, contributed or not) and ends with a Reports list (persona → path), so the host always knows what exists and where.

Host options. Host picks by what operator needs. Use cheapest option that serves. Choose option 1 when operator just needs result or will read it themselves, option 2 when host must act on it or present it, option 3 only when finding needs original reasoning:

1. Hand off: give the operator the `RESULT.md` path and the arbiter's reply, unread by the host. Step 8 is replaced by that handoff message.
2. Read and synthesize: read `RESULT.md` and present it per Step 8.
3. Read deeper: after reading `RESULT.md`, read specific member reports when a finding needs the original reasoning or the operator asks about one persona (for example, what the Minimalist said).
4. Escalate: when `RESULT.md` recommends re-running persona at higher tier and extra cost is worth it, re-run only that persona at recommended tier (default: next tier up), asynchronously, passing its earlier report as hypothesis list to confirm, refute and extend, not as fact. Give new run its own report and challenge paths (`<persona-name>-<model-class>-<persona_key>/`), launch its challenger as usual, then re-dispatch arbiter over updated report set, where escalated report replaces that persona's earlier one (stays on disk). At most one escalation round per persona, at most two personas per run. Operator may decline.

The operator may read `RESULT.md` or any report directly, instead of or in addition to the host. These are options, not prohibitions.

Grounded-challenge requirement: before citing member finding as incorrect, arbiter must quote exact sentence from that finding it believes is wrong. Challenging interpretation rather than explicit claim isn't permitted.

If arbiter produces empty list, it must state "No actionable findings" explicitly. When synthesizing (option 2), host must still note clean result.

Arbiter is structurally separate from registry (see Arbiter entry in Key Terms): never selected, gated, or filtered the way personalities are.

Step 7 — Aggregate findings, track disagreements:
Collect findings from `RESULT.md`. For each item, record: personality names cited, finding summary, cited evidence.

Identify disagree set from arbiter's Conflicting conclusions section. Each disagree entry records personalities involved and their conflicting claims as arbiter captured them.

Step 8 — Synthesize, return:
Synthesize from arbiter's structured action list into single host-voice output. Don't dump raw sub-agent output or raw arbiter output to caller. Speak as host, presenting refined takeaways.

Required synthesis output fields:
Active personalities: name (model-class) for each personality that completed successfully; tag generated personas with "(generated)".
Critical actions: each item from arbiter's Critical actions section — High-severity point items.
Findings: remaining consensus findings from arbiter's Obvious actions section.
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

**Truncation note** (omit if N/A): Synthesis exceeded the conciseness budget. Items truncated per E5 priority order (low-severity findings dropped first). Full per-persona reports remain on disk; `RESULT.md` lists their paths.
```

Synthesis output must be concise (strong guidance: ~2000 words). When findings exceed budget, truncation must preserve disagreements + high-severity items; medium and low drop first.

Hash record: members and challengers write per-persona reports and challenge files (Step 5); host writes nothing here. Path segment `v2` changes only if `persona_key` algorithm changes.

Error Envelope:
All error returns from this skill use shape `{ error: { code, message } }`. Stable codes — callers may branch on these:
`E_NO_DISPATCH` — no dispatch mechanism available in host runtime.
`E_NO_ARTIFACT` — no reviewable subject (B1).
`E_EMPTY_SWARM` — swarm empty after availability gating (B2).
`E_ARBITER_FAIL` — arbiter dispatch failed or returned no structured output (E6).
`E_PACKET_INCOMPLETE` — Step 1 packet verification failed and gap not resolvable.

Constraints:
C1. All dispatched sub-agents operate in read-only mode. Sub-agents mustn't edit files, run side-effecting commands, commit, or call any mutating tool. Single exception: personality writes only its own report file (and its parent dirs) at assigned path; arbiter writes only `RESULT.md` in run folder, deletes nothing. State constraint and exception explicitly in every dispatch prompt.

C2. Include explicit read-only language in each personality's dispatch prompt — prohibit file edits, commits, any side-effecting shell command, except writing its own report file. Exact wording is implementation choice. For each finding, verify before including: (1) cited file path appears in provided diff/artifact; (2) cited line within changed/relevant section or within 10 lines of one; (3) any verbatim code quotes appear in artifact; (4) directional claims (added/removed/changed) match artifact. Findings failing any check must be omitted, not downgraded.

C3. Skill doesn't technically prevent sub-agent from calling mutating tools; constraint is behavioral, enforced by prompt instruction. If sub-agent violates it, violation is prompt-design defect, not dispatch-skill defect.

C4. Every finding must cite specific evidence: snippet, line reference, scenario, or direct quote. Instruct each reviewer to either cite or retract.

C5. Mustn't invoke `code-review` skill internally. Two are siblings with separate intent; neither is dependency of other.

C6. Skill must refer to models by capability tier, not version string. Insulates contract from model retirements, lets dispatch layer evolve model selection independently. Bare model names forbidden in skill, reviewer files, synthesis output.

C7. CLI-as-dispatch out of scope until the dispatch skill's CLI-extension lands. Once it lands, CLI-backed personalities may use CLI dispatch pattern defined there.

C8. Don't expand personality registry with new built-in entries without spec amendment and audit pass.

Behavior:
B1. If subject (Step 0) can't be resolved into review packet with non-empty Artifacts field (for example `/swarm` with no prior discussion), return error: "No reviewable artifact found." Don't dispatch any personalities.

B2. If swarm empty after availability gating, return error: "Swarm empty after gating — no personalities available." Don't attempt synthesis.

B3. If swarm contains only Devil's Advocate, proceed with single-personality swarm and note in synthesis that review is adversarial only.

B4. If dispatched personality returns no findings or times out, record as non-contributing, exclude from synthesis. Note in `Non-contributing personalities` synthesis field.

B5. If all dispatched personalities return no findings, or none contributed (every member timed out, was missing, or was unstructured), synthesis must state "No findings from any reviewer" (or "No contributing reviewers" when none contributed), assign confidence rating Low.

B6. Devil's Advocate must always be dispatched unless explicitly excluded by `personality_filter` with named subset that omits it.

B7. Custom menu personalities evaluated against their caller-supplied trigger condition. If trigger is "always", always include (subject to availability gating if backend external).

B8. Cross-vendor diversity: if all finalized swarm personalities resolve to same model family or vendor, attempt resolution before dispatching. Preferred resolution order: (1) find any personality in full candidate registry on different model family — include it in swarm; (2) re-assign Devil's Advocate to different vendor using `vendor` frontmatter field. If neither resolves monoculture, proceed with homogeneous swarm, include `homogeneity_warning` in synthesis output. Do NOT degrade to `code-review`.

B9. Generated persona dispatch: generated personas dispatched in Step 5 same way as built-in personalities. Each receives: review packet, inline system prompt synthesized from its name, critique lens, scope limiter, explicit read-only constraint. Generated personas not added to registry, never cached. Always re-dispatched on any re-run.

Defaults:
D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: `haiku-class` for every personality (first pass). Callers may override individual personalities via `model_overrides`; escalation is Step 6 host option 4.
D3. Default dispatch: `haiku-class` personalities all at once (no cap); other classes rolling window of 3 (never more than 3 in flight).
D3b. Member reports and arbiter reply have no word limit; reply and `RESULT.md` kept brief.
D4. Default `model_overrides`: none.
D4b. Default `arbiter_model`: `haiku-class` (upgrade guidance: see Inputs).
D5. Custom menu entry with no model class and no caller override: default `haiku-class`.
D6. Confidence rating default: Medium. When (1) disagree set empty AND (2) every dispatched personality returned ≥1 finding AND all findings cite evidence, raise to High. When disagree set non-empty on high-severity point, or any personality returns no findings, lower to Low.
D7. `.hash-record/` base path: workspace root (root of repository or project containing reviewed artifact). Relative path `.hash-record/` resolves against workspace root. If workspace root ambiguous, use directory containing `problem` artifact's nearest root marker (e.g., `.git`). For a conversation subject (no artifact path), use the host's current workspace root.

Calibration examples:
High: Security Auditor, Engineer, Devil's Advocate all flag same SQL injection risk with evidence cites; no disagreements. → High.
Low (one empty reviewer): Reviewers agree on 2 findings but one personality returns "No findings"; any personality returning no findings triggers Low. → Low.
Medium: Reviewers produce 3 findings with evidence; no high-severity disagreements; all personalities contributed. → Medium.
Low: Devil's Advocate flags no concerns (returns "No findings"); or Security Auditor and Architect reach contradictory conclusions on shipping-blocking concern. → Low; state what would raise it (e.g., "re-run with explicit security artifact to get Security Auditor finding").

Error Handling:
E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): treat as non-contributing (B4). Don't block synthesis. Incoherent output: response that can't be parsed into structured findings list and isn't recognizable "No findings" statement. Response of "No findings" with or without brief rationale is valid (B4, non-contributing). Structurally garbled, off-topic, or unparseable response is incoherent (E3).
E5. Synthesis exceeds word budget: truncate at priority order — disagreements first, then high-severity, then medium, then low. Note truncation in output.
E6. Arbiter dispatch fails or `RESULT.md` missing or unstructured: return error to caller with list of members that returned (names and report paths), so operator can read reports directly. Don't attempt synthesis from raw member reports.
E7. Report write failure (Step 5): non-fatal. Member that can't write its report file is non-contributing (B4), named under Non-contributing in `RESULT.md`; swarm continues. Don't abort swarm or surface write error to caller.

Precedence:
P1. `personality_filter` overrides trigger-condition evaluation; only named personalities dispatched; triggers bypassed for named entries. One exception: safety-critical auto-trigger (Step 2) still adds Engineer, Devil's Advocate, Minimalist.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.

Related:
`dispatch` — agent-launching skill; swarm delegates all sub-agent launches here.
`member-contract.md` — what every swarm member reads and follows (report format, evidence checks, severity, reply).
`arbiter-prompt.md` — what arbiter reads and follows (verification, classification, `RESULT.md` format).
`challenger-contract.md` — what each challenger reads and follows (per-finding verdicts, cut rule).
