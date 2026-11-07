---
name: swarm
description: Multi-lens review of anything (the current conversation by default, or a file, a diff, a plan, a concept). Cheap parallel reviewers, a skeptic for each, one arbiter, one result file. Triggers - /swarm, swarm this, swarm the discussion, double check what we discussed, swarm review, multi-reviewer, run all reviewers.
---

# swarm

Usage: never dispatch this skill as sub-agent.

Key Terms:
- Subject: what is swarmed, decided first in Step 0. No explicit subject = current discussion.
- Artifact: subject's content under review (conversation excerpt, file path, diff, plan, doc, concept, structured description). Passed as `problem`, or taken from conversation.
- Review packet: self-contained brief from artifact. Fields: Goal, Approach, Key decisions, Files affected, Blast radius, Conventions, Artifacts (actual content; last, bulk). Omit inapplicable fields.
- Personality: named reviewer role. Prompt file `reviewers/<name>.md` + `reviewers/index.yaml` entry. Has trigger, optional advisory escalation model, backend preference list, scope limiter. Loaded lazily; full prompts absent at selection time.
- Selection: filter combined registry against artifact problem traits to get active personality set.
- Availability gate: probe confirming personality's required backend reachable before dispatch.
- Swarm: surviving personalities after selection and gating.
- Dispatch skill: `dispatch` skill, runtime-specific how-to for launching sub-agents. Reference for host, not delegation target. Host dispatches directly via its runtime mechanism (runSubagent in VS Code Copilot, Agent in Claude Code).
- Disagree set: findings where 2+ personalities reached contradictory conclusions on same point.
- Confidence rating: High / Medium / Low scalar on synthesis. Reflects reviewer agreement, evidence quality, scope coverage.
- Model class: abstract tier. `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning), `opus-class` (heavy architectural), `gpt-class` (external OpenAI). Each resolves to one family (haiku/sonnet/opus: Anthropic; gpt: OpenAI).
- Caller override: caller `model_overrides` map pinning personalities to model class for invocation.
- High-severity point: finding that would block shipping or require architectural change. = member `blocking` severity (see member-contract.md). Maps to arbiter Critical actions. Used in E5 truncation priority and arbiter confidence rule.
- Availability probe: lightweight shell cmd (e.g., `copilot --version`) or tool call confirming backend live before including personality.
- Backend: execution target. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
- Arbiter: single sub-agent (haiku-class default) dispatched after all members complete. Reads member reports, challenge files, packet header (not whole packet) at host-given paths. Writes `RESULT.md` in run folder. Replies brief summary. Not a reviewer. Not in registry. Not subject to selection, gating, or `personality_filter`.
- Run folder: unique scratch dir (session scratchpad or temp) host creates after packet verifies, before dispatch, at new path (`swarm-<first 8 hex of manifest hash>-<UTC timestamp>`). Holds `packet.md`, generated-persona reports, `RESULT.md`. Host only picks path and creates it; does not read reports by default. After creation arbiter owns it.
- Report file: member's full findings, written by member itself (no size cap).
- Challenger: haiku-class sub-agent paired with one member. Reads packet and that member's report, adds no findings, writes verdict (`CONFIRMED`, `REJECTED`, `UNSURE`) for every finding to challenge file. Follows `challenger-contract.md`.
- RESULT.md: arbiter's structured action list at `<run>/RESULT.md`. File host reads by default (Step 6 host options).
- Generated persona: personality manifested inline at runtime when registry yields <3 suitable. Name, critique lens, scope limiter all domain-specific. Current invocation only; not cached; no `reviewers/` file.
- Manifest hash: SHA-256 of manifest text: one line `<path> <SHA-256 of content>` per file, paths sorted bytewise, LF endings. Non-file artifacts (text, conversation excerpts): SHA-256 of artifact content. Artifact key for per-persona hash-record entries.

## Personality Registry

Registry external to skill. Built-in definitions: separate files `swarm/reviewers/<name>.md`. Registry = directory listing: every `*.md` in `reviewers/` passing metadata-validation gate is registered. Adding built-in = `index.yaml` entry + `reviewers/<name>.md` (C8 requires spec amendment). One-off uses custom menu.

Registry loading: crawl `reviewers/` at runtime when invocation begins. No compile-time enumeration. `reviewers/index.yaml` = ordered manifest; provides metadata and ordering for crawled personalities.

Metadata-validation gate: any file in `reviewers/` auto-validated before registration. Failing file silently skipped. Validation reads each persona's `index.yaml` entry and dir listing, never persona body. File with no complete index entry fails. No human approval. Valid files auto-registered.

Built-in personalities: `reviewers/index.yaml` is source of truth (trigger, scope, escalation hint per persona). Callers select by name, never index.

## Personality Metadata Schema

Each persona's metadata = entry in `reviewers/index.yaml`. `<name>.md` holds reviewer prompt only.
Required: `name` (unique across `reviewers/`); `trigger` ("always" = unconditional); `required` (true = dispatched regardless of `personality_filter` unless explicitly excluded); `suggested_backends` (preference-ordered backend kinds; model class resolved separately, Step 5); `scope` (reviews / ignores).
Optional: `vendor` (hint for B8); `escalation_model` (advisory tier to re-run at if persona asks escalation; absent = next tier up; never raises starting tier).
No `model` field: every personality starts at lowest tier. Entry missing required field fails gate; file skipped.

## Custom Personality Menu

Callers may supply extra personalities per invocation. Each entry specifies: name, trigger condition, model class (or inherit caller override), backend, scope limiter. Custom entries appended after built-in in evaluation order. Never mutate built-in registry.

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `problem` | optional | What to review: any artifact (Step 0). Absent = current discussion. |
| `personality_filter` | optional | List of personality names (strings). Restricts swarm to named personalities; bypasses trigger evaluation for them. Names whole swarm: required personality dropped if omitted (safety-critical auto-trigger still adds three). Indices not accepted (registry built by crawl; indices unstable across reviewer-file changes). |
| `model_overrides` | optional | Map of personality name to model class. Affects model class only, not backend type. |
| `arbiter_model` | optional | Model class for arbiter. Default `haiku-class`. Upgrade to `sonnet-class` when artifact safety-critical (Step 2 auto-trigger), security- or privacy-sensitive, result gates ship decision, or first `haiku-class` result looks off (no Dropped section, near-wholesale acceptance of proposed cuts, many UNSURE verdicts). Use `opus-class` for highest stakes. |

## Model Economics

haiku-class swarm is where value is: breadth (several independent lenses plus skeptical check) is cheap, and breadth finds problems. Return per step up in class shrinks, so stronger model in one role buys little vs another lens. Prefer haiku-class for every role (members, challengers, arbiter). Upgrade only where specific lens or verdict needs it, one role at a time: persona via `model_overrides`, then arbiter via `arbiter_model`. Upgrading whole swarm = highest-stakes reviews only. Adding another haiku lens usually returns more than upgrading existing one. Every personality starts haiku-class. Personality may ask escalation; host may re-run just that persona higher (Step 6, host option 4), so extra spend follows evidence. Each agent has large fixed cost; run = 2N+1 agents (N reviewers, N challengers, one arbiter), so small artifacts suit fewer lenses.

## Caller Tier

Host executing this skill must be sonnet-class minimum. If no dispatch mechanism in host runtime: return E_NO_DISPATCH: "Swarm requires dispatch capability; no dispatch mechanism available."

## Step 0 — Decide what is being swarmed

Do first, before anything else. Say in one line before any dispatch: `Swarming: <subject> — <what review will check>`. Do not ask which subject unless truly impossible: pick most likely, state choice, let operator correct.

Subject can be anything: conversation, file(s), diff, plan, doc, concept, idea, decision, claim, question, code. Resolve in order:
1. Explicit subject in request or `problem`: path, diff, quoted text, URL, or named thing ("swarm the caching design", "swarm this file").
2. Deictic ("this", "that", "it", "what you just said"): most recent matching thing in conversation (last file touched, last proposal, last answer).
3. No subject (`/swarm`, "swarm", or "swarm this" with nothing to point at): swarm the discussion = current topic from where it began to now, including own statements, claims, decisions, reasoning.

Conversation subject: artifact = conversation excerpt. Write relevant turns into packet verbatim, not summarized, covering stretch on current topic (whole session only if all one topic). Goal states review checks discussion for correctness, gaps, unsupported claims. Prefer topic-specific generated lenses (e.g., claim checker) in addition to always-on lenses.

## Step Sequence

Steps 1-8 run in order for every invocation.

### Step 1 — Build the review packet

Cache key: before building packet, extract file list directly from `problem` (deterministic parse, by script, no LLM). Read file contents, compute manifest hash HASH (sorted paths + content hashes, SHA-256; or SHA-256 of artifact text for non-file input). Per-persona reports cached under `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/` (XX = first two hex chars of HASH; D7 sets base path), holding `review.md` and `challenge-<challenger_key>.md`.
- `persona_key` = first 8 hex of SHA-256 of that persona's file, `member-contract.md`, and raw subject text (`problem` string or conversation excerpt), concatenated in that order, no separator.
- `challenger_key` = first 8 hex of SHA-256 of `challenger-contract.md`. Challenge file: `challenge-<challenger_key>.md`.
- Step 5 reuses cached report. No whole-run cache.

Construct packet from `problem`. Packet must be self-contained: reader with zero prior context must understand what is reviewed, why, and key decisions.

Packet fields (omit if N/A to artifact type):
- Goal: what problem is solved or what output is evaluated.
- Approach: what was proposed, implemented, or produced.
- Key decisions: why this approach over alternatives.
- Files affected: list with brief descriptions.
- Blast radius: downstream consumers, imports, integrations affected.
- Conventions: applicable project conventions.
- Artifacts: actual content under review (diffs, text, config — not description of it).

Keep packet under about 50 KB: members' Read calls cap near 25,000 tokens, so trim artifact to what review needs.

Verify packet before proceeding: Goal must name artifact type and state outcome evaluated (e.g., "evaluate diff for correctness and security"). Artifacts must include actual content, not references. If either fails, resolve gap from available context. Do not ask caller to fill gaps. If unresolvable: return E_PACKET_INCOMPLETE and halt.

Once packet verifies, create run folder (new path that did not exist before; see Run folder) and write packet to `<run>/packet.md`. A halt above leaves no folder behind.

### Step 2 — Select personalities

Build combined registry: crawl `reviewers/` (applying gate), then append caller custom menu entries.

If `personality_filter` supplied: restrict active set to named personalities; dispatch them regardless of trigger evaluation (triggers bypassed for named). No filter: evaluate trigger conditions against problem traits inferred from packet; exclude personalities whose trigger is unsatisfied. Evaluation is semantic judgment against packet content, not literal string match against `trigger` text.

Safety-critical auto-trigger: fires when packet's Files-affected list (or, if omitted, files named in Artifacts) contains any artifact whose failure could break host environment, propagate across fleet, or compromise process lifecycle (control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar). When fires, add Engineer, Devil's Advocate, Minimalist to active set regardless of trigger evaluation or `personality_filter`. Callers cannot opt out via filter. Supersedes `personality_filter` override of trigger evaluation for those three. Additions protected from 6-cap drop.

Caller `model_overrides` take precedence. Personality `escalation_model` is advisory: names tier to re-run at if personality asks escalation (Step 6, host option 4); never raises starting tier. Internal-dispatch backends (handled by `dispatch` skill): no model-class probe.

Always include `required: true` personalities regardless of trigger evaluation. `personality_filter` may exclude a required personality only when caller explicitly names subset omitting it. Devil's Advocate and Minimalist carry `required: true`.

6-cap: if more than 6 pass trigger evaluation, apply priority:
1. Devil's Advocate and Minimalist always.
2. Personalities added by safety-critical auto-trigger (Engineer, Devil's Advocate, Minimalist) and generated conversation lens: protected from cap.
3. Most-specific trigger match (specificity = count of distinct comma-delimited terms in `trigger`; `"always"` = 0; tie-break alphabetical personality name).
4. Drop lowest-priority remaining until count = 6.

Manifest gap fill: if selection yields fewer than 3 suitable after filter and trigger evaluation, manifest one or more generated personas inline to reach at least 3. Each: invent domain-relevant name, critique lens covering traits not already represented, scope limiter avoiding overlap. Dispatch same as built-in. Not added to registry; not cached in hash record.

Conversation lens: when subject is conversation (Step 0), also add one topic-specific generated lens (e.g., claim checker) even if 3+ selected. Counts toward 6-cap; never the one dropped.

### Step 3 — Availability gating

For each selected personality with external backend (not handled internally by `dispatch` skill, e.g., `copilot-cli`):
- Run availability probe before including.
- Probe succeeds: include.
- Probe fails: drop for this invocation. Note drop in synthesis. Do not fail-stop or surface error to caller.

Internal-dispatch backends: no probe; dispatch skill handles errors.

### Step 4 — Resolve reviewer prompts

Only after swarm finalized (post-gating), resolve absolute path of each surviving personality's prompt: `swarm/reviewers/<name>.md`. Filename = personality name lowercased, spaces→hyphens, apostrophes dropped (e.g., `devils-advocate.md`, `security-auditor.md`). Host does not read these; each member reads its own. Missing file: treat as non-contributing per E3, continue. Custom Specialist entry has no file; replaced by generated persona. Generated persona prompt (name, critique lens, scope limiter) written by host to `<run>/<persona-name>.persona.md`, passed same way.

### Step 5 — Dispatch

Dispatch via runtime dispatch mechanism, following `dispatch` skill. Use `dispatch` agent type for personalities, not `scout` (scout is read-only; reviewers must write report file).

Concurrency: haiku-class personalities no cap, launch all at once (size already bounded by 6-cap). Other classes: rolling window of 3; as each completes, dispatch next until all run. Personality not returned within host threshold (default: 5 min for member or arbiter, 3 min for challenger) = timed out per B4. Default tool-call budgets in dispatch prompts: 10 for member or challenger; 2N+6 for arbiter (reads N reports and N challenge files).

Reuse before dispatch: for each persona, compute per-persona dir (Step 1 key) at its resolved class. Cached `review.md` ending with line `END OF REPORT` (and not "No findings") satisfies persona; not dispatched. Use its `challenge-<challenger_key>.md` too if present and ending `END OF REPORT`; otherwise dispatch only challenger. Reports at other classes do not satisfy.

Reports go to files, not host. Each member writes full report to its report path and replies exactly one line: `done: <path>`. Report paths:
- Built-in persona: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/review.md`. `<persona-name>` uses same slugification as reviewer filename (Step 4). Member creates missing dirs.
- Generated persona: `<run>/<persona-name>.md` (never written to hash record).

Challenge pass (each member is a pair): as soon as member returns report, dispatch that member's `haiku-class` challenger (`dispatch` agent type) asynchronously, in background, without waiting for other members. Host dispatches challengers (sub-agents cannot dispatch): launches each challenger as soon as its member returns. Dispatch prompt is short: "Read and follow `challenger-contract.md`" (absolute path of `swarm/challenger-contract.md`), absolute paths of packet, that member's report, and challenge file; same in-prompt sentence that writing challenge file is required deliverable; read-only constraint (write only challenge file). Challenger adds no findings; writes verdict for every finding (CONFIRMED, REJECTED with contradicting quote, UNSURE) to challenge file and replies `done: <path>`.
- Challenge path: `challenge-<challenger_key>.md` beside report (generated: `<run>/<persona-name>.challenge.md`).
- Challengers haiku-class: uncapped, run as each member returns.
- Usable report = structured, ends with line `END OF REPORT`, not "No findings". Member without usable report gets no challenger.
- Challenger that fails or times out is simply absent; arbiter verifies that member's findings itself.
- Challenger dispatch: `<tier>` = `fast-cheap`, `<description>` = `swarm-challenger:<persona-name>`.

Host does not read report files by default (Step 6 host options). Checking usable (last line is `END OF REPORT`) = one-line shell test of last line, not a read. A `done:` reply alone proves nothing: refused write can still answer `done:`, so confirm file exists. Host gives arbiter report paths of returned members, and names of timed-out or crashed ones (B4). Timed-out member is non-contributing; any file it left is ignored, so half-written report never read.

Each personality dispatch receives:
- Absolute path of `<run>/packet.md` (member reads it; host does not paste packet).
- Absolute paths of personality prompt (Step 4) and `swarm/member-contract.md`; member reads both. Always absolute paths: sub-agent cwd may differ.
- Its report path (absolute). Reply rule, report format, evidence checks, severity vocabulary live in `member-contract.md`, so dispatch prompt is short: "Read and follow member-contract.md", the three paths, tool-call budget, and one sentence saying in prompt's own words that writing findings file is the explicit required deliverable and findings must not be returned as text. That sentence must be in prompt itself, not only in contract file.
- Read-only constraint and its single exception (write only own report file), stated in prompt as well as `member-contract.md` (C1).

Apply `model_overrides` at dispatch: if caller override exists, use it; otherwise `haiku-class`. For internal-dispatch backends, dispatch tier follows resolved model class, not backend name. Run B8 diversity check after model selection, before dispatching.

Dispatch parameters:
- `<tier>` = dispatch tier of resolved class (`haiku-class` = `fast-cheap`, `sonnet-class` = `standard`, `opus-class` = `deep`).
- `<description>` = `swarm-personality:<personality-name>`.

Report format, evidence shapes, severity vocabulary live in `member-contract.md`.

### Step 6 — Arbiter consolidation

After all members and challengers have returned, failed, or timed out, dispatch single arbiter sub-agent using `arbiter_model` (default haiku-class; see Inputs for upgrade rules), `dispatch` agent type. Dispatch prompt is short: "Read and follow `swarm/arbiter-prompt.md`" (absolute path); run folder; report path of each returned member; challenge file path of each member that has one; each returned persona's `escalation_model` (if set); names of timed-out; any Unavailable personalities and homogeneity warning; tool-call budget; same in-prompt sentence that writing `RESULT.md` is required deliverable; read-only constraint (write only `RESULT.md`). `arbiter-prompt.md` holds verification rules, classification, confidence rule, `RESULT.md` format. If arbiter fails or `RESULT.md` missing: retry once before E6.

File-existence filter (discard findings citing file not in packet's Files-affected list; skipped when packet has no such list), B4 handling of non-contributing reports, and rule that timed-out member's file is never read: all in `arbiter-prompt.md`. Run folder left in place for drill-down; session scratch, no cleanup step.

Dispatch parameters:
- `<tier>` = dispatch tier of `arbiter_model` (default `fast-cheap`).
- `<description>` = `swarm-arbiter`.

Must write `<run>/RESULT.md`: structured three-section action list (Obvious actions, Critical actions, Conflicting conclusions) per `arbiter-prompt.md`, plus Participants, Confidence, Escalation, Dropped, Non-contributing, Reports sections (see `arbiter-prompt.md`). Concise: one line per item where possible, no restating reports. No actionable findings: state "No actionable findings" explicitly. Must reply with: `RESULT.md` path, counts (critical / obvious / conflicts / non-contributing), short headline of most important findings, enough for host to hand off unread (option 1). No word limit; keep brief.

Host options. Host picks by what operator needs. Use cheapest that serves; default is option 1 (arbiter reply gives counts and headline).
1. Hand off: give operator `RESULT.md` path and arbiter reply, unread by host. Steps 7-8 replaced by that handoff message. Choose when operator just needs result or will read it.
2. Read and synthesize: read `RESULT.md`, present per Step 8. Choose when host must act on findings itself or operator asks for synthesized write-up.
3. Read deeper: after reading `RESULT.md`, read specific member reports when a finding needs original reasoning or operator asks about one persona (e.g., what Minimalist said). Choose only when finding needs original reasoning.
4. Escalate: when `RESULT.md` recommends re-running a persona at higher tier and extra cost is worth it, re-run only that persona at recommended tier (default next tier up), asynchronously, passing its earlier report as hypothesis list to confirm, refute, extend, not as fact. Give new run its own report and challenge paths (`<persona-name>-<model-class>-<persona_key>/`), launch its challenger as usual, then re-dispatch arbiter over updated report set, where escalated report replaces that persona's earlier one (which stays on disk). At most one escalation round per persona, at most two personas per run. Operator may decline.

Operator may read `RESULT.md` or any report directly, instead of or in addition to host.
If `RESULT.md` has no actionable findings, option 2 states clean result.

### Step 7 — Aggregate findings and track disagreements

Collect findings from `RESULT.md`. For each item record: personality names cited, finding summary, cited evidence.
Identify disagree set from arbiter's Conflicting conclusions section. Each disagree entry records personalities involved and their conflicting claims as arbiter captured them.

### Step 8 — Synthesize and return

Synthesize from arbiter's structured action list into single host-voice output. Do not dump raw sub-agent or arbiter output. Speak as host, presenting refined takeaways.

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

Synthesis output must be concise: at most 2000 words. When findings exceed budget, truncation must preserve disagreements and high-severity items; medium and low drop first.

Hash record: members and challengers write per-persona reports and challenge files (Step 5); host writes nothing here. `v2` path segment changes only if `persona_key` algorithm changes.

## Error Envelope

All error returns from this skill use shape `{ error: { code, message } }`. Stable codes; callers may branch on these:
- `E_NO_DISPATCH` — no dispatch mechanism available in host runtime.
- `E_NO_ARTIFACT` — no reviewable subject (B1).
- `E_EMPTY_SWARM` — swarm empty after availability gating (B2).
- `E_ARBITER_FAIL` — arbiter dispatch failed or returned no structured output (E6).
- `E_PACKET_INCOMPLETE` — Step 1 packet verification failed and gap not resolvable.

## Constraints

C1. All dispatched sub-agents operate read-only. Must not edit files, run side-effecting commands, commit, or call any mutating tool. Single exception: personality writes only its own report file (and its parent dirs) at assigned path; arbiter writes only `RESULT.md` in run folder and deletes nothing. State constraint and exception explicitly in every dispatch prompt.
C2. Each personality's dispatch prompt includes explicit read-only language: prohibit file edits, commits, and any side-effecting shell command, except writing own report file. Exact wording is implementation choice. Per-finding evidence checks in `member-contract.md`.
C3. Skill cannot technically prevent sub-agent from calling mutating tools; constraint is behavioral, enforced by prompt instruction.
C4. Every finding must cite specific evidence, enforced by `member-contract.md`.
C5. Must not invoke `code-review` skill internally. Siblings with separate intent; neither is dependency of other.
C6. Refer to models by capability tier, not version string. Bare model names forbidden in skill, reviewer files, and synthesis output.
C7. CLI-as-dispatch out of scope until dispatch skill's CLI extension lands. Then CLI-backed personalities may use the CLI dispatch pattern defined there.
C8. Do not expand built-in registry without spec amendment and audit pass.

## Behavior

B1. If subject (Step 0) cannot resolve into packet with non-empty Artifacts (e.g., `/swarm` with no prior discussion): return E_NO_ARTIFACT: "No reviewable artifact found." Dispatch no personalities.
B2. If swarm empty after availability gating: return E_EMPTY_SWARM: "Swarm empty after gating — no personalities available." No synthesis.
B3. If swarm contains only Devil's Advocate: proceed single-personality; note in synthesis that review is adversarial only.
B4. If dispatched personality returns no findings or times out: record as non-contributing, exclude from synthesis. Note in `Non-contributing personalities` synthesis field.
B5. If all dispatched personalities return no findings, or none contributed (every member timed out, was missing, or was unstructured): synthesis states "No findings from any reviewer" (or "No contributing reviewers" when none contributed); confidence rating Low.
B6. Devil's Advocate always dispatched unless `personality_filter` explicitly excludes it with named subset omitting it.
B7. Custom menu personalities evaluated against caller-supplied trigger. Trigger "always": always include (subject to availability gating if backend external).
B8. Cross-vendor diversity: if all finalized swarm personalities resolve to same model family or vendor, attempt resolution before dispatching. Preferred order:
1. Find any personality in full candidate registry on different model family; include it.
2. Internally re-assign Devil's Advocate to model class in different family, informed by its `vendor` hint.
If neither resolves monoculture, proceed with homogeneous swarm and include `homogeneity_warning` in synthesis. Until C7 lifts, `gpt-class` has no dispatch backend, so steps (1)-(2) cannot cross families and warning applies every default run (one line, not error).
B9. Generated personas dispatched like built-in (prompt at `<run>/<persona-name>.persona.md`, read-only), never added to registry or cached, always re-dispatched.

## Defaults

D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: `haiku-class` for every personality (first pass). Callers may override individual personalities via `model_overrides`; escalation is Step 6 host option 4.
D3. Default dispatch: `haiku-class` personalities all at once (no cap); other classes in rolling window of 3 (never more than 3 in flight).
D3b. Member reports and arbiter reply have no word limit; reply and `RESULT.md` kept brief.
D4. Default `model_overrides`: none.
D5. Custom menu entry with no model class and no caller override: default `haiku-class`.
D6. Confidence rating set by arbiter (rule in `arbiter-prompt.md`); host reports it unchanged.
D7. `.hash-record/` base path: workspace root (root of repo or project containing reviewed artifact; in git worktree, worktree root). Relative `.hash-record/` resolves against workspace root. If workspace root ambiguous, use directory containing `problem` artifact's nearest root marker (e.g., `.git`). For conversation subject (no artifact path), use host's current workspace root.

## Footguns

- F1: load reviewer prompt files only after swarm finalized and gated (Step 4); host never reads them.
- F2: failed availability probe drops personality; never fails swarm (Step 3).
- F3: put read-only constraint (C2) and write-the-file sentence in every dispatch prompt.
- F4: never dispatch one at a time: haiku-class all at once, other classes in window of 3 (Step 5).
- F5: speak in host voice; keep each finding's source personalities, not narrative voice-of-persona.
- ANTI-PATTERN: `personality_filter: ["Security Auditor"]` runs only Security Auditor (plus safety-critical additions); name every personality wanted, Devil's Advocate included.

## Error Handling

E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): treat as non-contributing (B4). Do not block synthesis. Incoherent output: response that cannot be parsed into structured findings list and is not recognizable "No findings" statement. "No findings" with or without brief rationale is valid (B4, non-contributing). Structurally garbled, off-topic, or unparseable response is incoherent (E3).
E5. Synthesis exceeds word budget: truncate in priority order: disagreements first, then high-severity (`blocking`), then medium (`issue`), then low (the rest). Note truncation in output.
E6. Arbiter dispatch fails or `RESULT.md` missing or unstructured: return error to caller with list of members that returned (names and report paths), so operator can read reports directly. Do not attempt synthesis from raw member reports.
E7. Report write failure (Step 5): non-fatal. Member that cannot write its report file is non-contributing (B4) and named under Non-contributing in `RESULT.md`; swarm continues. Do not abort swarm or surface write error to caller.

## Precedence

P1. `personality_filter` overrides trigger-condition evaluation; only named personalities dispatched; triggers bypassed for named entries. Exception: safety-critical auto-trigger (Step 2) still adds Engineer, Devil's Advocate, Minimalist.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality that passes selection but fails probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.

## Related

- `dispatch`: how to launch sub-agents; read for mechanics, do not dispatch it.
- `hash-record`: key-addressed layout convention for per-persona cache under `.hash-record/`.
- `member-contract.md`: what every swarm member reads and follows (report format, evidence checks, severity, reply).
- `arbiter-prompt.md`: what arbiter reads and follows (verification, classification, `RESULT.md` format).
- `challenger-contract.md`: what each challenger reads and follows (per-finding verdicts, cut rule).
