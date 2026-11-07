---
name: swarm
description: Multi-lens review of anything (the current conversation by default, or a file, a diff, a plan, a concept). Cheap parallel reviewers, a skeptic for each, one arbiter, one result file. Triggers - /swarm, swarm this, swarm the discussion, double check what we discussed, swarm review, multi-reviewer, run all reviewers.
---

# swarm

Usage: never dispatch this skill as sub-agent.

Key Terms:
- Subject: what is swarmed, decided Step 0. No explicit subject = current discussion.
- Artifact: subject's content under review (conversation excerpt, file path, diff, plan, doc, concept, structured description). Passed as `problem`, or taken from conversation.
- Review packet: self-contained brief from artifact. Fields: Goal, Approach, Key decisions, Files affected, Blast radius, Conventions, Artifacts (actual content; last, bulk). Omit inapplicable fields.
- Personality: named reviewer role. Prompt at `reviewers/<name>.md`, metadata at `reviewers/index.yaml` entry. Has trigger, optional advisory escalation model, backend preference list, scope limiter. Loaded lazily; full prompts absent at selection.
- Vocabulary: persona, personality, reviewer, member = same role. Disagree set, Disagreements, Conflicting conclusions = same list.
- Selection: filter combined registry vs artifact problem traits into active personality set.
- Availability gate: probe confirming required backend reachable before dispatch.
- Swarm: surviving personalities after selection and gating.
- Dispatch skill: `dispatch` skill, runtime how-to for launching sub-agents. Reference for host, not delegation target. Host dispatches directly via runtime mechanism (runSubagent in VS Code Copilot, Agent in Claude Code).
- Disagree set: swarm findings where 2+ personalities contradict on same point.
- Confidence rating: High / Medium / Low scalar on synthesis. Reflects agreement, evidence quality, scope coverage.
- Model class: abstract tier. `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning), `opus-class` (heavy architectural), `gpt-class` (external OpenAI). Each resolves to one family (haiku/sonnet/opus: Anthropic; gpt: OpenAI).
- Caller override: caller `model_overrides` map pinning personalities to model class for this invocation.
- High-severity point: finding that blocks shipping or requires architectural change. = member `blocking` severity (`member-contract.md`). Maps to arbiter Critical actions. Used in E5 truncation and arbiter confidence rule.
- Availability probe: lightweight shell cmd (e.g. `copilot --version`) or tool call confirming backend live.
- Backend: execution target. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
- Arbiter: single sub-agent (haiku-class default) dispatched after all members complete. Reads member reports, challenge files, packet header (not whole packet) at host-given paths. Writes `RESULT.md` in run folder. Replies brief summary. Not reviewer. Not in registry. Not subject to selection, gating, or `personality_filter`.
- Run folder: unique scratch dir (session scratchpad or temp) host creates after packet verifies, before dispatch, at new path that didn't exist before (`swarm-<first 8 hex of manifest hash>-<UTC timestamp>`). Holds `packet.md`, generated-persona reports, `RESULT.md`. Host only picks path and creates it; doesn't read reports by default. After creation arbiter owns it.
- Report file: member's full findings, written by member itself (no size cap).
- Challenger: haiku-class sub-agent paired with one member. Reads packet and that member's report, adds no findings, writes verdict (`CONFIRMED`, `REJECTED`, `UNSURE`) per finding to challenge file. Follows `challenger-contract.md`.
- RESULT.md: arbiter's structured action list at `<run>/RESULT.md`. Host reads by default (Step 6 host options).
- Generated persona: personality manifested inline at runtime when registry yields fewer than 3 suitable for artifact. Name, critique lens, scope limiter all artifact-specific. Current invocation only; not cached; no `reviewers/` file.
- Manifest hash: SHA-256 of manifest text: one line `<path> <SHA-256 of content>` per file, paths sorted bytewise, LF endings. Non-file artifacts (text, conversation excerpts): SHA-256 of artifact content. Artifact key for per-persona hash-record entries.

## Personality Registry

Registry external to skill. Built-in definitions at `swarm/reviewers/<name>.md`. Registry = directory listing: every `*.md` in `reviewers/` passing metadata-validation gate is registered. Adding built-in = `index.yaml` entry + `reviewers/<name>.md` (C8: needs spec amendment). One-off uses custom menu.

Registry loading: crawl `reviewers/` at runtime when invocation begins. No compile-time enumeration. `reviewers/index.yaml` = ordered manifest: metadata and ordering for crawled personalities.

Metadata-validation gate: any file in `reviewers/` validated before registration. Failing file silently skipped. Validation reads each persona's `index.yaml` entry and directory listing, never persona body. File with no complete index entry fails. No human approval; valid files auto-registered.

Built-in personalities: `index.yaml` is source of truth (trigger, scope, escalation hint). Callers select by name, never index.

## Personality Metadata Schema

Each persona's metadata = entry in `reviewers/index.yaml`. `<name>.md` holds prompt only. Required: `name` (unique across `reviewers/`), `trigger` ("always" = unconditional), `required` (true = dispatched regardless of `personality_filter` unless explicitly excluded), `suggested_backends` (preference-ordered backend kinds; model class resolved separately, Step 5), `scope` (what reviewed, what ignored). Optional: `vendor` (B8 hint only; never selects backend), `escalation_model` (advisory tier to re-run at if persona asks escalation; absent = next tier up; never raises starting tier). No `model` field: every personality starts at lowest tier. Entry missing required field fails gate; file skipped.

## Custom Personality Menu

Callers may supply extra personalities per invocation. Each entry specifies: name, trigger condition, model class (or inherit caller override), backend, scope limiter. Appended after built-ins in evaluation order. Doesn't mutate built-in registry.

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `problem` | optional | What to review: any artifact (Step 0). Absent = current discussion. |
| `personality_filter` | optional | List of personality names. Restricts swarm to named, bypasses trigger evaluation for them. Names whole swarm: required personality dropped when omitted (safety-critical auto-trigger still adds three). Indices not accepted (registry built by crawl; indices unstable). |
| `model_overrides` | optional | Map personality name to model class. Affects model class only, not backend type. `gpt-class` has no dispatch backend until C7 lifts: `gpt-class` value in `model_overrides` or `arbiter_model` ignored; host says so in one line. |
| `arbiter_model` | optional | Model class for arbiter dispatch. Default `haiku-class`. Upgrade to `sonnet-class` when artifact safety-critical (Step 2 auto-trigger), security- or privacy-sensitive, result gates ship decision, or first `haiku-class` result looks off (no Dropped section, near-wholesale acceptance of proposed cuts, many UNSURE verdicts). `opus-class` for highest-stakes. |

## Model Economics

`haiku-class` swarm is where value is: breadth (several independent lenses plus skeptical check) is cheap, and breadth finds problems. Return per model-class step shrinks; stronger model in one role buys little vs another lens. Prefer `haiku-class` for every role (members, challengers, arbiter). Upgrade only where specific lens or verdict needs it, one role at a time: persona via `model_overrides`, then arbiter via `arbiter_model`. Upgrading whole swarm is for highest-stakes reviews. Adding another `haiku-class` lens usually returns more than upgrading one. Every personality starts `haiku-class`. Personality may ask escalation; host may re-run just that persona higher (Step 6, option 4), so extra spend follows evidence. Each agent has large fixed cost; run = 2N+1 agents (N reviewers, N challengers, one arbiter), so small artifacts suit fewer lenses.

## Caller Tier

Host executing skill MUST be sonnet-class minimum. No dispatch mechanism in host runtime: return E_NO_DISPATCH: "Swarm requires dispatch capability; no dispatch mechanism available." Host knowing it's below sonnet-class says so in one line and continues.

## Step 0: Decide what is swarmed

Do first, before anything else. Say in one line before any dispatch: `Swarming: <subject> — <what the review will check>`. Don't ask which subject unless truly impossible: pick most likely, state choice, let operator correct.

Subject can be anything: conversation, file(s), diff, plan, doc, concept, decision, claim, question, code. Resolve in order:
1. Explicit subject in request or `problem`: path, diff, quoted text, URL, or named thing ("swarm the caching design", "swarm this file").
2. Deictic ("this", "that", "it", "what you just said"): most recent matching thing in conversation (last file touched, last proposal, last answer).
3. No subject (`/swarm`, "swarm", "swarm this" with nothing to point at): swarm the discussion = current topic from where it began to now, including own statements, claims, decisions, reasoning.

Conversation subject: artifact = conversation excerpt. Write relevant turns into packet verbatim, not summarized, covering stretch on current topic (whole session only if all one topic). Goal states review checks discussion for correctness, gaps, unsupported claims. Prefer topic-specific generated lenses (e.g. claim checker) in addition to always-on lenses.

## Step Sequence

Steps 1-8 run in order for every invocation.

### Step 1: Build review packet

Cache key: before building packet, extract file list directly from `problem` (deterministic parse by script, no LLM). Read contents, compute manifest hash HASH (paths named in `problem`, sorted, with content hashes SHA-256; or SHA-256 of artifact text when `problem` names no files). Hashes via shell `sha256sum`; timestamps via `date -u +%Y%m%dT%H%M%SZ`. Per-persona reports cached under `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/` (XX = first 2 hex of HASH; D7 sets base path), holding `review.md` and `challenge-<challenger_key>.md`. `persona_key` = first 8 hex of SHA-256 of that persona's file, `member-contract.md`, and raw subject text (`problem` string or conversation excerpt), concatenated in that order, no separator. Challenge file `challenge-<challenger_key>.md`, where `challenger_key` = first 8 hex of SHA-256 of `challenger-contract.md`. Step 5 reuses cached report. No whole-run cache.

Construct packet from `problem`. Packet must be self-contained: reader with zero prior context must understand what is reviewed, why, and key decisions.

Packet fields (omit if N/A):
- Goal: what problem is solved or output evaluated.
- Approach: what was proposed, implemented, or produced.
- Key decisions: why this approach over alternatives.
- Files affected: list with brief descriptions.
- Blast radius: downstream consumers, imports, integrations affected.
- Conventions: applicable project conventions.
- Artifacts: actual content under review (diffs, text, config; not description of it).

Keep packet under ~50 KB: members' Read calls cap near 25,000 tokens, so trim artifact to what review needs.

Verify packet: Goal must name artifact type and state outcome evaluated (e.g. "evaluate diff for correctness and security"). Artifacts must include actual content, not references. If either fails, resolve from available context. Don't ask caller to fill gaps. Unresolvable: return E_PACKET_INCOMPLETE and halt.

Once packet verifies, create run folder (new path not existing before; see Run folder) and write packet to `<run>/packet.md`. Halt above leaves no folder behind.

### Step 2: Select personalities

Build combined registry: crawl `reviewers/` (metadata gate) and append caller custom menu entries.

If `personality_filter`: restrict active set to named personalities; dispatch them regardless of trigger evaluation (triggers bypassed for named entries). Name in `personality_filter` or `model_overrides` matching no persona is ignored; host says so in one line. No filter: evaluate trigger conditions against problem traits inferred from packet; exclude personalities whose trigger unsatisfied. Evaluation is semantic judgment against packet content, not literal string match against `trigger` text.

Safety-critical artifact auto-trigger: fires when packet Files-affected list (or, if omitted, files named in Artifacts) contains any artifact whose failure could break host environment, propagate across fleet, or compromise process lifecycle (control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar). For plan, conversation, or concept subject with no files, fires when subject proposes changing such system. When fires, add Engineer, Devil's Advocate, Minimalist to active set regardless of trigger evaluation or `personality_filter`. Callers can't opt out via filter. Supersedes `personality_filter` override of trigger evaluation for these three. Additions protected from 6-cap drop.

Caller `model_overrides` take precedence. Personality's optional `escalation_model` is advisory: names tier to re-run at if persona asks escalation (Step 6, option 4); never raises starting tier. Internal-dispatch backends (handled by `dispatch` skill): no model-class probe.

Always include `required: true` personalities, regardless of trigger evaluation. `personality_filter` may exclude a required one only when caller explicitly names subset omitting it. Devil's Advocate and Minimalist carry `required: true`.

6-cap: if more than 6 pass trigger evaluation, priority: (1) Devil's Advocate and Minimalist always; (2) safety-critical auto-trigger additions (Engineer, Devil's Advocate, Minimalist) and generated conversation lens, protected from cap; (3) most-specific trigger match (specificity = count of distinct comma-delimited terms in `trigger`; "always" scores 0; tie-break alphabetical by name); (4) drop lowest-priority remaining until count = 6.

Manifest gap fill: if fewer than 3 suitable after filter and trigger evaluation, manifest generated personas inline to reach at least 3. For each: invent name relevant to artifact domain, critique lens covering traits not already represented, scope limiter avoiding overlap. Dispatch same as built-in. Not added to registry; not cached in hash record.

Conversation lens: when subject is conversation (Step 0), also add one topic-specific generated lens (e.g. claim checker) even if 3+ selected. Counts toward 6-cap; never the one dropped.

### Step 3: Availability gating

For each selected personality with external backend (not handled internally by `dispatch` skill, e.g. `copilot-cli`):
- Run availability probe before including.
- Probe succeeds: include.
- Probe fails: drop for this invocation. Note drop in synthesis. Don't fail-stop or surface error to caller.

Internal-dispatch backends: no probe required; dispatch skill handles errors.

### Step 4: Resolve reviewer prompts

Only after swarm finalized (post-gating): resolve absolute path of each surviving personality prompt: `swarm/reviewers/<name>.md`, filename = name lowercased, spaces to hyphens, apostrophes dropped (e.g. `devils-advocate.md`, `security-auditor.md`). Host doesn't read these; each member reads its own. Missing file: non-contributing per E3, continue. Custom Specialist entry has no file; replaced by generated persona. Generated persona prompt (name, critique lens, scope limiter) written by host to `<run>/<persona-name>.persona.md`, passed same way.

### Step 5: Dispatch

Dispatch via runtime mechanism, following `dispatch` skill. Use `dispatch` agent type for personalities, NOT `scout` (scout is read-only; reviewers must write report file). Concurrency: `haiku-class` has no cap; launch all at once (size bounded by 6-cap). Other classes: rolling window of 3; as each completes, dispatch next until all run. Host-defined timeout (default 5 min for member or arbiter, 3 min for challenger) = timed out per B4. Default tool-call budgets in dispatch prompts: 10 for member or challenger, 2N+6 for arbiter (reads N reports and N challenge files).

Reuse before dispatch: for each persona, compute per-persona dir (Step 1 key) at resolved class. Cached `review.md` there ending with line `END OF REPORT` (and not "No findings") satisfies persona: not dispatched. Use its `challenge-<challenger_key>.md` too if present and ending `END OF REPORT`; otherwise dispatch only challenger. Reports at other classes don't satisfy. Two runs on same subject share cache paths: don't start second while one in flight.

Reports go to files, not host. Each member writes full report to report path and replies exactly one line: `done: <path>`. Report paths:
- Built-in persona: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/review.md`. `<persona-name>` uses same slugification as Step 4. Member creates missing dirs.
- Generated persona: `<run>/<persona-name>.md` (never written to hash record).

Challenge pass (each member is a pair): as soon as member returns report, dispatch that member's `haiku-class` challenger (`dispatch` agent type) asynchronously, in background, without waiting for other members. Host dispatches challengers (sub-agents can't dispatch): launch each as soon as its member returns. Dispatch prompt is short: "Read and follow `challenger-contract.md`" (absolute path of `swarm/challenger-contract.md`), absolute paths of packet, that member's report, and challenge file, the same in-prompt sentence that writing challenge file is required deliverable, and read-only constraint (write only challenge file). Challenger adds no findings; writes verdict for every finding (CONFIRMED, REJECTED with contradicting quote, UNSURE) and replies `done: <path>`. Challenge path: `challenge-<challenger_key>.md` beside report (generated persona: `<run>/<persona-name>.challenge.md`). Challengers are `haiku-class`: uncapped, run as each member returns. Usable report = structured, ends `END OF REPORT`, not "No findings". Member without usable report gets no challenger. Failed or timed-out challenger is simply absent; arbiter verifies that member's findings itself. Challenger dispatch: `<tier>` = `fast-cheap`, `<description>` = `swarm-challenger:<persona-name>`.

Host doesn't read report files by default (Step 6 host options). Usable check = one-line shell test that last line is `END OF REPORT`, not a read. A `done:` reply alone proves nothing: a refused write can still answer `done:`. Confirm file exists. Host gives arbiter report paths of members that returned, and names of any that timed out, left no usable file, or crashed (B4). Timed-out member is non-contributing; any file it left is ignored, so half-written report never read.

Each personality dispatch receives:
- Path to `<run>/packet.md` (member reads it; host doesn't paste packet).
- Absolute paths of personality prompt (Step 4) and `swarm/member-contract.md`; member reads both. Always absolute paths: sub-agent cwd may differ.
- Its report path (absolute). Reply rule, report format, evidence checks, severity vocabulary live in `member-contract.md`. Dispatch prompt stays short: "Read and follow member-contract.md", the three paths, tool-call budget, and one sentence in the prompt's own words that writing findings file is the explicit required deliverable and findings must not be returned as text. That sentence MUST be in prompt itself, not only contract file.
- Read-only constraint and single exception (write only own report file), stated in prompt as well as `member-contract.md` (C1).

Apply `model_overrides` at dispatch: caller override if exists, else `haiku-class`. Internal-dispatch tier follows resolved model class, not backend name. Run B8 diversity check after model selection, before dispatch.

Dispatch parameters:
- `<tier>` = dispatch tier of resolved model class (`haiku-class` = `fast-cheap`, `sonnet-class` = `standard`, `opus-class` = `deep`)
- `<description>` = `swarm-personality:<personality-name>`

Report format, evidence shapes, severity vocabulary: `member-contract.md`.

### Step 6: Arbiter consolidation

After all members and challengers returned, failed, or timed out: dispatch single arbiter sub-agent using `arbiter_model` (default `haiku-class`; see Inputs for upgrade), `dispatch` agent type. Dispatch prompt is short: "Read and follow `swarm/arbiter-prompt.md`" (absolute path), run folder, each returned member (name, model class, report path), challenge file path of each member that has one, each returned persona's `escalation_model` (if set), names of timed-out or no-usable-file members, any Unavailable personalities and homogeneity warning, tool-call budget, same in-prompt sentence that writing `RESULT.md` is required deliverable, and read-only constraint (write only `RESULT.md`). `arbiter-prompt.md` holds verification rules, classification, confidence rule, `RESULT.md` format. If arbiter fails, or `RESULT.md` missing or not ending with `END OF REPORT`: retry once before E6.

File-existence filter (discard findings citing file not in packet's Files-affected list; skipped when packet has no such list), B4 handling, and rule that timed-out member's file is never read: all in `arbiter-prompt.md`. Run folder left in place for drill-down; session scratch, no cleanup step.

Dispatch parameters:
- `<tier>` = dispatch tier of `arbiter_model` (default `fast-cheap`)
- `<description>` = `swarm-arbiter`

Must write `<run>/RESULT.md`: structured three-section action list (Obvious actions, Critical actions, Conflicting conclusions) per `arbiter-prompt.md`, plus Participants, Confidence, Escalation, Dropped, Non-contributing, Reports sections. Concise: one line per item where possible, no restating reports. No actionable findings: state "No actionable findings" explicitly. Reply with: `RESULT.md` path, counts (critical / obvious / conflicts / non-contributing), short headline of most important findings, enough for host to hand off unread (option 1). No word limit; keep brief.

Host options. Host picks by what operator needs. Use cheapest option that serves; default is option 1 (arbiter reply gives counts and headline). Option 1 when operator just needs result or will read it; option 2 when host must act on findings or operator asks for synthesized write-up; option 3 only when a finding needs original reasoning:
1. Hand off: give operator `RESULT.md` path and arbiter reply, unread by host. Steps 7-8 replaced by that handoff message.
2. Read and synthesize: read `RESULT.md`, present per Step 8.
3. Read deeper: after reading `RESULT.md`, read specific member reports when a finding needs original reasoning or operator asks about one persona (e.g. what Minimalist said).
4. Escalate: when `RESULT.md` recommends re-running a persona at higher tier and extra cost is worth it, re-run only that persona at recommended tier (default next tier up), asynchronously. Pass its earlier report as hypothesis list to confirm, refute, extend, not as fact. Give new run own report and challenge paths (`<persona-name>-<model-class>-<persona_key>/`), launch its challenger as usual, then re-dispatch arbiter over updated report set. Escalated report replaces that persona's earlier one (which stays on disk). At most one escalation round per persona, at most two personas per run. Operator may decline.

Operator may read `RESULT.md` or any report directly, instead of or in addition to host.

If `RESULT.md` has no actionable findings, option 2 states clean result.

### Step 7: Aggregate findings, track disagreements

Collect findings from `RESULT.md`. For each item record: personality names cited, finding summary, cited evidence.

Identify disagree set from arbiter's Conflicting conclusions section. Each entry records personalities involved and their conflicting claims as arbiter captured them.

### Step 8: Synthesize and return

Host option 1 returns arbiter's reply instead of this output; options 2 and 3 return it. Synthesize from arbiter's structured action list into single host-voice output. Don't dump raw sub-agent or arbiter output. Speak as host, presenting refined takeaways.

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

Synthesis output max 2000 words. Truncation preserves disagreements and high-severity items; medium and low drop first.

Hash record: members and challengers write per-persona reports and challenge files (Step 5); host writes nothing here. Path segment `v2` changes only if `persona_key` algorithm changes.

## Error Envelope

All error returns use shape `{ error: { code, message } }`. Stable codes; callers may branch on them:
- `E_NO_DISPATCH`: no dispatch mechanism in host runtime.
- `E_NO_ARTIFACT`: no reviewable subject (B1).
- `E_EMPTY_SWARM`: swarm empty after gating (B2).
- `E_ARBITER_FAIL`: arbiter dispatch failed or returned no structured output (E6).
- `E_PACKET_INCOMPLETE`: Step 1 packet verification failed and gap not resolvable.

## Constraints

C1. All dispatched sub-agents are read-only. They MUST NOT edit files, run side-effecting commands, commit, or call mutating tools. Single exception: a personality writes only its own report file (and parent dirs) at assigned path; arbiter writes only `RESULT.md` in run folder and deletes nothing. State constraint and exception explicitly in every dispatch prompt.

C2. Include explicit read-only language in each personality's dispatch prompt: prohibit file edits, commits, side-effecting shell commands, except writing its own report file. Exact wording is implementation choice. Per-finding evidence checks live in `member-contract.md`.

C3. Skill can't technically prevent sub-agent from calling mutating tools. Constraint is behavioral, enforced by prompt instruction.

C4. Every finding MUST cite specific evidence, enforced by `member-contract.md`.

C5. MUST NOT invoke `code-review` skill internally. The two are siblings with separate intent; neither depends on the other.

C6. Refer to models by capability tier, not version string. Bare model names are forbidden in skill, reviewer files, and synthesis output.

C7. CLI-as-dispatch is out of scope until dispatch skill's CLI extension lands. Then CLI-backed personalities may use the CLI dispatch pattern defined there.

C8. Don't expand personality registry with new built-in entries without spec amendment and audit pass.

## Behavior

B1. If subject (Step 0) can't resolve into review packet with non-empty Artifacts (e.g. `/swarm` with no prior discussion): return E_NO_ARTIFACT: "No reviewable artifact found." Dispatch no personalities.

B2. If swarm is empty after availability gating: return E_EMPTY_SWARM: "Swarm empty after gating — no personalities available." Don't attempt synthesis.

B3. If swarm contains only Devil's Advocate: proceed as single-personality swarm; note in synthesis that review is adversarial only.

B4. If dispatched personality returns no findings or times out: record as non-contributing, exclude from synthesis. Note in `Non-contributing personalities` synthesis field.

B5. If all dispatched personalities return no findings, or none contributed (every member timed out, was missing, or was unstructured): synthesis states "No findings from any reviewer" (or "No contributing reviewers" when none contributed); confidence rating Low.

B6. Devil's Advocate MUST always be dispatched unless `personality_filter` names a subset that omits it.

B7. Custom menu personalities evaluated against caller trigger condition. If trigger is "always", always include (subject to availability gating if backend is external).

B8. Cross-vendor diversity: if all finalized swarm personalities resolve to same model family or vendor, attempt resolution before dispatching. Preferred order:
1. Find any personality in full candidate registry on different model family; include it.
2. Internally re-assign Devil's Advocate to model class in different family, informed by its `vendor` hint.

If neither resolves monoculture, proceed with homogeneous swarm and include `homogeneity_warning` in synthesis. Until C7 lifts, `gpt-class` has no dispatch backend, so steps 1-2 can't cross families and warning applies on every default run (one line, not error).

B9. Generated personas are dispatched like built-in ones (prompt at `<run>/<persona-name>.persona.md`, read-only), are never added to registry or cached, and are always re-dispatched.

## Defaults

D1. Default `personality_filter`: none (all registry entries evaluated).

D2. Default model class: `haiku-class` for every personality (first pass). Callers may override individual personalities via `model_overrides`; escalation is Step 6 host option 4.

D3. Default dispatch: `haiku-class` personalities all at once (no cap); other classes in rolling window of 3 (never more than 3 in flight).

D3b. Member reports and arbiter reply have no word limit; reply and `RESULT.md` kept brief.

D4. Default `model_overrides`: none.

D5. Custom menu entry with no model class and no caller override: default `haiku-class`.

D6. Confidence rating set by arbiter (rule in `arbiter-prompt.md`); host reports it unchanged.

D7. `.hash-record/` base path: workspace root (root of repository or project containing reviewed artifact; in git worktree, worktree root). Relative `.hash-record/` resolves against workspace root. If workspace root ambiguous, use directory containing `problem` artifact's nearest root marker (e.g. `.git`). For conversation subject (no artifact path), use host's current workspace root. On Windows keep root path short: cache paths add about 150 characters against 260-character path limit.

## Footguns

- F1: load reviewer prompt files only after swarm finalized and gated (Step 4); host never reads them.
- F2: failed availability probe drops personality; never fails swarm (Step 3).
- F3: put read-only constraint (C2) and write-the-file sentence in every dispatch prompt.
- F4: never dispatch one at a time: `haiku-class` all at once, other classes in window of 3 (Step 5).
- F5: speak in host voice; keep each finding's source personalities, not narrative voice-of-persona.
- ANTI-PATTERN: `personality_filter: ["Security Auditor"]` runs only Security Auditor (plus safety-critical additions); name every personality wanted, Devil's Advocate included.

## Error Handling

E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): treat as non-contributing (B4). Don't block synthesis. Incoherent output: response that can't be parsed into structured findings list and isn't recognizable "No findings" statement. "No findings" with or without brief rationale is valid (B4, non-contributing). Structurally garbled, off-topic, or unparseable response is incoherent (E3).

E5. Synthesis exceeds word budget: truncate in priority order: disagreements first, then high-severity (`blocking`), then medium (`issue`), then low (the rest). Note truncation in output.

E6. Arbiter dispatch fails or `RESULT.md` missing or unstructured: return error to caller with list of members that returned (names and report paths), so operator can read reports directly. Don't attempt synthesis from raw member reports.

E7. Report write failure (Step 5): non-fatal. Member that can't write its report is non-contributing (B4) and named under Non-contributing in `RESULT.md`; swarm continues. Don't abort swarm or surface write error to caller.

## Precedence

P1. `personality_filter` overrides trigger evaluation; only named personalities dispatched; triggers bypassed for named entries. Exception: safety-critical auto-trigger (Step 2) still adds Engineer, Devil's Advocate, Minimalist.

P2. `model_overrides` override registry defaults.

P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.

P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.

## Related

- `dispatch`: how to launch sub-agents; read for mechanics, don't dispatch it.
- `hash-record`: key-addressed layout convention for per-persona cache under `.hash-record/`.
- `member-contract.md`: what every member reads and follows (report format, evidence checks, severity, reply).
- `arbiter-prompt.md`: what arbiter reads and follows (verification, classification, `RESULT.md` format).
- `challenger-contract.md`: what each challenger reads and follows (per-finding verdicts, cut rule).
