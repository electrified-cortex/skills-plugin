---
name: swarm
description: Multi-lens review of anything (the current conversation by default, or a file, a diff, a plan, a concept). Cheap parallel reviewers, a skeptic for each, one arbiter, one result file. Triggers - /swarm, swarm this, swarm the discussion, double check what we discussed, swarm review, multi-reviewer, run all reviewers.
---

# swarm

Usage: NEVER dispatch this skill as sub-agent.

Key terms:
Subject: what is swarmed, decided in Step 0. No explicit subject = current discussion.
Artifact: subject content under review (conversation excerpt, file path, diff, plan, doc, concept, structured description). Passed as `problem`, or taken from conversation.
Review packet: self-contained brief from artifact. Fields: Goal, Approach, Key decisions, Files affected, Blast radius, Conventions, Artifacts (actual content, last). Omit N/A fields.
Personality: named reviewer role. Prompt `reviewers/<name>.md` + `reviewers/index.yaml` entry (trigger, optional advisory escalation model, backend preference list, scope limiter). Loaded lazily; full prompts absent at selection.
Personality registry: personalities discovered by crawling `reviewers/` at runtime. Extended per invocation by custom menu.
Custom menu: caller-supplied extra personalities, this invocation only. Not persisted.
Selection: filter combined registry by artifact traits, giving active personalities.
Availability gate: probe confirming personality's backend reachable before dispatch.
Swarm: survivors after selection and gating.
Dispatch skill: `dispatch` skill, runtime how-to for sub-agents. Host reference, not delegation target. Host dispatches directly (runSubagent in VS Code Copilot, Agent in Claude Code).
Disagree set: swarm findings where 2+ personalities contradict on same point.
Confidence rating: High / Medium / Low. Reflects agreement, evidence quality, scope coverage.
Model class: `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning), `opus-class` (heavy architectural), `gpt-class` (external OpenAI-hosted). Each resolves to one family (haiku/sonnet/opus: Anthropic; gpt: OpenAI).
Caller override: caller `model_overrides` pinning personalities to model class, this invocation only.
High-severity point: would block shipping or require architectural change. = member `blocking` severity (`member-contract.md`). Maps to arbiter Critical actions. Used in E5 truncation and arbiter confidence rule.
Availability probe: lightweight shell command (e.g. `copilot --version`) or tool call confirming backend live.
Backend: execution target. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
Arbiter: single sub-agent (haiku-class default) dispatched after all members complete. Reads member reports, challenge files, packet header (not whole packet) at host-given paths. Writes `RESULT.md` in run folder. Replies brief summary. Not reviewer. Not in registry. Not subject to selection, gating, or `personality_filter`.
Run folder: unique scratch dir (session scratchpad or temp) host creates after packet verifies, before dispatch, at new path (`swarm-<first 8 hex of manifest hash>-<UTC timestamp>`). Holds `packet.md`, generated-persona reports, `RESULT.md`. Host picks and creates path; doesn't read reports by default. After creation, arbiter owns it.
Report file: member's full findings, written by member (no size cap).
Challenger: haiku-class sub-agent paired with one member. Reads packet and that member's report, adds no findings, writes verdict (`CONFIRMED`, `REJECTED`, `UNSURE`) per finding to challenge file. Follows `challenger-contract.md`.
RESULT.md: arbiter's structured action list at `<run>/RESULT.md`. File host reads by default (Step 6 host options).
Generated persona: reviewer manifested inline when registry yields fewer than 3 suitable personalities. Domain-specific name, critique lens, scope limiter. Current invocation only; not cached; no `reviewers/` file.
Manifest hash: SHA-256 of canonical input manifest (sorted file paths concatenated with content hashes). Non-file artifacts: SHA-256 of artifact content. Artifact key for per-persona hash-record entries.

Personality registry: external to skill. Built-in definitions at `swarm/reviewers/<name>.md`. Registry = directory listing; every `*.md` in `reviewers/` passing metadata-validation gate is registered. Adding built-in = `index.yaml` entry + `reviewers/<name>.md` (C8 requires spec amendment); one-off uses custom menu.
Registry loading: crawl `reviewers/` at runtime when invocation begins. No compile-time enumeration. `reviewers/index.yaml` = ordered manifest (metadata, ordering).
Metadata-validation gate: any `reviewers/` file validated before registration. Failing file silently skipped. Validation reads `index.yaml` entry and directory listing, never persona body; file with no complete index entry fails. No human approval.
Built-in personalities: `reviewers/index.yaml` is source of truth (trigger, scope, escalation hint). Runtime index = alphabetical crawl, 1-based; callers select by name, never index.

Personality metadata schema: each entry in `reviewers/index.yaml`; `<name>.md` holds reviewer prompt only. Required: `name` (unique across `reviewers/`), `trigger` ("always" = unconditional), `required` (true = dispatched regardless of `personality_filter` unless explicitly excluded), `suggested_backends` (preference-ordered backend kinds; model class resolved separately, Step 5), `scope` (what reviewed, what ignored). Optional: `vendor` (B8 hint), `escalation_model` (advisory tier to re-run at if persona asks escalation; absent = next tier up; never raises starting tier). No `model` field: every personality starts lowest tier. Entry missing required field fails gate; file skipped.

Custom personality menu: callers may supply extra personalities per invocation. Each entry specifies: name, trigger condition, model class (or inherit caller override), backend, scope limiter. Appended after built-ins in evaluation order. Doesn't mutate built-in registry.

Inputs:

| Input | Required | Description |
| --- | --- | --- |
| `problem` | optional | What to review: any artifact (see Step 0). Absent means the current discussion. |
| `personality_filter` | optional | List of personality **names** (strings). Restricts the swarm to the named personalities and bypasses trigger evaluation for them. It names the whole swarm, so a required personality is dropped when omitted (the safety-critical auto-trigger still adds three). Indices aren't accepted (the registry is built by filesystem crawl; index positions are unstable across reviewer-file changes). |
| `model_overrides` | optional | Map of personality name to model class. Overrides affect model class only, not backend type. |
| `arbiter_model` | optional | Model class for the arbiter dispatch. Defaults to `haiku-class`. Upgrade to `sonnet-class` when the artifact is safety-critical (Step 2 auto-trigger), security- or privacy-sensitive, or the result gates a ship decision, or when a first `haiku-class` result looks off (no Dropped section, near-wholesale acceptance of proposed cuts, many UNSURE verdicts). Use `opus-class` for the highest-stakes reviews. |

Model economics: `haiku-class` swarm is where value is. Breadth (several independent lenses plus skeptical check) is cheap, and breadth finds problems. Return per step up in class shrinks, so stronger model in one role buys little versus another lens. Prefer `haiku-class` for every role (members, challengers, arbiter); upgrade only where a specific lens or verdict needs it, one role at a time: persona via `model_overrides`, then arbiter via `arbiter_model`. Whole-swarm upgrade is for highest-stakes only. Adding another `haiku-class` lens usually returns more than upgrading one. Every personality starts `haiku-class`. Personality may ask escalation; host may re-run just that persona higher (Step 6, host option 4), so extra spend follows evidence. Each agent has large fixed cost; run = 2N+1 agents (N reviewers, N challengers, one arbiter), so small artifacts suit fewer lenses.

Caller tier: host executing this skill must be SONNET-CLASS minimum. Swarm runs in host, never dispatched as sub-agent. No dispatch mechanism in host runtime: return E_NO_DISPATCH "Swarm requires dispatch capability; no dispatch mechanism available."

Step 0 — Decide what is swarmed: do first, before anything else. Say in one line before any dispatch: `Swarming: <subject> — <what the review will check>`. Don't ask which subject unless truly impossible to tell: pick most likely, state choice, let operator correct.

Subject can be anything: conversation, file(s), diff, plan, document, concept, idea, decision, claim, question, or code. Resolve in order:
1. Explicit subject in request or `problem`: path, diff, quoted text, URL, or named thing ("swarm the caching design", "swarm this file").
2. Deictic subject ("this", "that", "it", "what you just said"): most recent matching thing in conversation (last file touched, last proposal, last answer).
3. No subject (`/swarm`, "swarm", or "swarm this" with nothing to point at): swarm the discussion. That is current topic from where it began to now, including own statements, claims, decisions, reasoning.

When subject is conversation: artifact is conversation excerpt. Write relevant turns into packet verbatim, not summarized, covering stretch on current topic (whole session only if all one topic). Goal states review checks discussion for correctness, gaps, unsupported claims. Prefer topic-specific generated lenses (e.g. claim checker) in addition to always-on lenses.

Steps 1-8 run in order for every invocation.

Step 1 — Build review packet:
Cache key: before packet, extract file list directly from `problem` (deterministic parse, script, no LLM). Read file contents; compute manifest hash HASH (sorted paths + content hashes, SHA-256; or SHA-256 of artifact text for non-file inputs). Per-persona reports cached under `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/` (XX = first two hex chars of HASH; D7 sets base path), holding `review.md` and `challenge-<challenger_key>.md`. `persona_key` = first 8 hex chars of SHA-256 of that persona's file, `member-contract.md`, and raw subject text (`problem` string or conversation excerpt), concatenated in that order, no separator. `challenger_key` = first 8 hex chars of SHA-256 of `challenger-contract.md`. Step 5 reuses cached report. No whole-run cache.

Construct packet from `problem`. Must be self-contained: zero-context reader understands what is reviewed, why, key decisions.
Fields (omit if N/A): Goal; Approach; Key decisions; Files affected (brief descriptions); Blast radius (downstream consumers, imports, integrations); Conventions; Artifacts (actual content: diffs, text, config, not description). Keep under about 50 KB: members' Read calls cap near 25,000 tokens, so trim artifact to what review needs.
Verify before proceeding: Goal names artifact type and states outcome evaluated (e.g. "evaluate diff for correctness and security"); Artifacts include actual content, not references. If either fails, resolve from available context. Don't ask caller to fill gaps. Unresolvable: return E_PACKET_INCOMPLETE and halt.
Once verified, create run folder (new path that didn't exist before; see Run folder), write packet to `<run>/packet.md`. Halt above leaves no folder.

Step 2 — Select personalities:
Build combined registry: crawl `reviewers/` (metadata gate) + append caller custom menu entries.
With `personality_filter`: restrict to named; dispatch regardless of trigger (triggers bypassed for named). No filter: evaluate triggers against problem traits inferred from packet; exclude unsatisfied. Evaluation is semantic judgment against packet content, not literal string match to `trigger` text.

Safety-critical auto-trigger: fires when packet Files-affected list (or, if omitted, files named in Artifacts) contains artifact whose failure could break host environment, propagate across fleet, or compromise process lifecycle: control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar. Fires: add Engineer, Devil's Advocate, Minimalist to active set regardless of trigger or `personality_filter`. Callers can't opt out via filter. Supersedes `personality_filter` override of trigger evaluation for these three. Additions protected from 6-cap drop.

Every personality starts `haiku-class`. Caller `model_overrides` take precedence. `escalation_model` is advisory: names tier to re-run at if persona asks escalation (Step 6, host option 4); never raises starting tier. Internal-dispatch backends (handled by `dispatch` skill): no model-class probe.

Always include `required: true` personalities regardless of trigger. `personality_filter` may exclude a required personality only when caller explicitly names subset omitting it. Devil's Advocate and Minimalist are `required: true`.

6-cap: if more than 6 pass trigger evaluation, priority: (1) Devil's Advocate and Minimalist always; (2) safety-critical auto-trigger additions (Engineer, Devil's Advocate, Minimalist) and generated conversation lens, protected from cap; (3) most-specific trigger match (specificity = count of distinct comma-delimited terms in `trigger`; `"always"` scores 0; tie-break alphabetical personality name); (4) drop lowest-priority remaining until count = 6.

Manifest gap fill: if selection yields fewer than 3 suitable after filter and triggers, manifest generated personas inline to reach at least 3. Each: name relevant to artifact domain, critique lens covering traits not already represented, scope limiter avoiding overlap. Dispatched same as built-in; not added to registry; not cached in hash record.

Conversation lens: when subject is conversation (Step 0), also add one topic-specific generated lens (e.g. claim checker) even if 3+ selected. Counts toward 6-cap; never the one dropped.

Step 3 — Availability gating:
For each selected personality with external backend (not handled internally by `dispatch` skill, e.g. `copilot-cli`): run availability probe before including. Probe succeeds: include. Fails: drop for this invocation; note drop in synthesis. Don't fail-stop or surface error to caller.
Internal-dispatch backends: no probe; dispatch skill handles errors.

Step 4 — Resolve reviewer prompts:
Only after swarm finalized (post-gating): resolve absolute path per survivor: `swarm/reviewers/<name>.md`, filename = personality name lowercased, spaces to hyphens, apostrophes dropped (e.g. `devils-advocate.md`, `security-auditor.md`). Host doesn't read these; each member reads its own. Missing file: treat as non-contributing per E3; Custom Specialist entry has no file, replaced by generated persona. Generated persona prompt (name, critique lens, scope limiter) written by host to `<run>/<persona-name>.persona.md`, passed same way.

Step 5 — Dispatch:
Use runtime dispatch mechanism per `dispatch` skill. Use `dispatch` agent type for personalities, NOT `scout` (read-only; reviewers must write report file). Concurrency: `haiku-class` no cap, launch all at once (6-cap bounds size). Other classes: rolling window of 3; as each completes, dispatch next. Host-defined timeout (default: 5 min member or arbiter, 3 min challenger) = timed out per B4. Default tool-call budgets in dispatch prompts: 10 for member or challenger, 2N+6 for arbiter (reads N reports and N challenge files).

Reuse before dispatch: per persona compute per-persona directory (Step 1 key) at resolved class. Cached `review.md` there ending with line `END OF REPORT` (not "No findings") satisfies persona; not dispatched. Use its `challenge-<challenger_key>.md` too if present and ending with `END OF REPORT`, else dispatch only challenger. Reports at other classes don't satisfy.

Reports go to files, not host. Each member writes full report to report path, replies exactly one line: `done: <path>`. Report paths:
- Built-in persona: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/review.md`. `<persona-name>` uses Step 4 slugification. Member creates missing directories.
- Generated persona: `<run>/<persona-name>.md` (never in hash record).

Challenge pass (each member is a pair): as soon as member returns usable report, dispatch its `haiku-class` challenger (`dispatch` agent type) asynchronously, in background, without waiting for other members. Host dispatches challengers (sub-agents can't dispatch). Dispatch prompt short: "Read and follow `challenger-contract.md`" (absolute path of `swarm/challenger-contract.md`), absolute paths of packet, member report, challenge file, plus in-prompt sentence that writing challenge file is required deliverable, and read-only constraint (write only challenge file). Challenger adds no findings; writes verdict for every finding (CONFIRMED, REJECTED with contradicting quote, UNSURE), replies `done: <path>`. Challenge path: `challenge-<challenger_key>.md` beside report (generated: `<run>/<persona-name>.challenge.md`). Challengers `haiku-class`: uncapped, run as each member returns. Usable report = structured, ends with `END OF REPORT`, not "No findings"; member without usable report gets no challenger. Failed/timed-out challenger simply absent; arbiter verifies that member's findings itself. Challenger dispatch: `<tier>` = `fast-cheap`, `<description>` = `swarm-challenger:<persona-name>`.

Host doesn't read report files by default (Step 6 host options). Usable check = one-line shell test of last line, not a read. `done:` reply alone proves nothing: refused write can still answer `done:`; confirm file exists. Host gives arbiter report paths of members that returned, names of timed-out or crashed (B4). Timed-out member non-contributing; any file it left ignored, so half-written report never read.

Each personality dispatch receives:
- Path to `<run>/packet.md` (member reads it; host doesn't paste packet).
- Absolute paths of personality prompt (Step 4) and `swarm/member-contract.md`; member reads both. Always absolute: sub-agent working dir may differ.
- Report path (absolute). Reply rule, report format, evidence checks, severity vocabulary live in `member-contract.md`, so prompt short: "Read and follow member-contract.md", three paths, tool-call budget, one sentence saying in prompt's own words that writing findings file is explicit required deliverable and findings mustn't be returned as text. That sentence must be in prompt itself, not only contract file.
- Read-only constraint and single exception (write only own report file) in prompt as well as `member-contract.md` (C1).

Apply `model_overrides` at dispatch: override if present, else `haiku-class`. Internal-dispatch: tier follows resolved model class, not backend name. Diversity check (B8) after model selection, before dispatch.

Dispatch parameters:
- `<tier>` = dispatch tier of resolved class (`haiku-class` = `fast-cheap`, `sonnet-class` = `standard`, `opus-class` = `deep`); challengers always `fast-cheap`.
- `<description>` = `swarm-personality:<personality-name>`.

Report format, evidence shapes, severity vocabulary: `member-contract.md`. Report that is "No findings", missing, or lacks final `END OF REPORT` line = non-contributing (B4).

Step 6 — Arbiter consolidation:
After all members and challengers returned, failed, or timed out, dispatch single arbiter (`dispatch` agent type) using `arbiter_model` (default `haiku-class`; see Inputs). Dispatch prompt short: "Read and follow `swarm/arbiter-prompt.md`" (absolute path), run folder, report path of each returned member, challenge file path of each member that has one, each returned persona's `escalation_model` (if set), names of timed-out, any Unavailable personalities and homogeneity warning, tool-call budget, same in-prompt sentence that writing `RESULT.md` is required deliverable, and read-only constraint (write only `RESULT.md`). `arbiter-prompt.md` holds verification rules, classification, confidence rule, `RESULT.md` format. Arbiter fails or `RESULT.md` missing: retry once before E6.

File-existence filter (discard findings citing file not in packet's Files-affected list; skipped when packet has no such list), B4 handling, and rule that timed-out member's file is never read: all in `arbiter-prompt.md`. Arbiter writes only `RESULT.md`, deletes nothing. Run folder left in place for drill-down; session scratch space; no cleanup step.

Dispatch parameters:
- `<tier>` = dispatch tier of `arbiter_model` (default `fast-cheap`).
- `<description>` = `swarm-arbiter`.

Must write `<run>/RESULT.md`: structured three-section action list (Obvious actions, Critical actions, Conflicting conclusions) per `arbiter-prompt.md`, plus Participants, Confidence, Escalation, Dropped, Non-contributing, Reports sections. Concise: one line per item, no restating reports. No actionable findings: state "No actionable findings" explicitly. Must reply with: `RESULT.md` path, counts (critical / obvious / conflicts / non-contributing), short headline of most important findings, enough for host to hand off unread (option 1). No word limit; keep brief.

Host options. Host picks by operator need; cheapest serving option; default option 1 (arbiter reply has counts and headline). Option 1 when operator needs result or will read it; option 2 when host must act or operator asks synthesized write-up; option 3 only when finding needs original reasoning:
1. Hand off: give operator `RESULT.md` path and arbiter reply, unread by host. Steps 7-8 replaced by handoff message.
2. Read and synthesize: read `RESULT.md`, present per Step 8.
3. Read deeper: after `RESULT.md`, read specific member reports when finding needs original reasoning or operator asks about one persona (e.g. what the Minimalist said).
4. Escalate: when `RESULT.md` recommends re-running persona at higher tier and extra cost worth it, re-run only that persona at recommended tier (default next tier up), asynchronously, passing earlier report as hypothesis list to confirm, refute, extend, not as fact. New run gets own report and challenge paths (`<persona-name>-<model-class>-<persona_key>/`), launch its challenger as usual, then re-dispatch arbiter over updated report set; escalated report replaces that persona's earlier one (stays on disk). At most one escalation round per persona, at most two personas per run. Operator may decline.

Operator may read `RESULT.md` or any report directly, instead of or in addition to host.
If `RESULT.md` has no actionable findings, option 2 states clean result.

Step 7 — Aggregate findings and track disagreements:
Collect findings from `RESULT.md`. Per item record: personality names cited, finding summary, cited evidence.
Identify disagree set from arbiter's Conflicting conclusions section. Each entry records personalities involved and conflicting claims as arbiter captured them.

Step 8 — Synthesize and return:
Synthesize from arbiter's structured action list into single host-voice output. Don't dump raw sub-agent or arbiter output. Speak as host, presenting refined takeaways.

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

Synthesis at most 2000 words. Over budget: truncation preserves disagreements + high-severity; medium and low drop first.

Hash record: members and challengers write per-persona reports and challenge files (Step 5); host writes nothing here. Path segment `v2` changes only if `persona_key` algorithm changes.

Error envelope:

All error returns use `{ error: { code, message } }`. Stable codes, callers may branch:
- `E_NO_DISPATCH` — no dispatch mechanism in host runtime.
- `E_NO_ARTIFACT` — no reviewable subject (B1).
- `E_EMPTY_SWARM` — swarm empty after gating (B2).
- `E_ARBITER_FAIL` — arbiter dispatch failed or no structured output (E6).
- `E_PACKET_INCOMPLETE` — Step 1 packet verification failed, gap unresolvable.

Constraints:

C1. Dispatched sub-agents operate READ-ONLY. NO editing files, side-effecting commands, commits, or mutating tools. Single exception: personality writes only own report file (and parent dirs) at assigned path; arbiter writes only `RESULT.md` in run folder and deletes nothing. State constraint and exception explicitly in every dispatch prompt.
C2. Each personality dispatch prompt includes explicit read-only language: prohibit file edits, commits, side-effecting shell commands, except writing own report file. Exact wording is implementation choice. Per-finding evidence checks in `member-contract.md`.
C3. Skill can't technically prevent sub-agent mutating tool calls; constraint is behavioral, enforced by prompt.
C4. Every finding must cite specific evidence, enforced by `member-contract.md`.
C5. MUST NOT invoke `code-review` skill internally. Siblings with separate intent; neither depends on other.
C6. Refer to models by capability tier, not version string. Bare model names forbidden in skill, reviewer files, synthesis output.
C7. CLI-as-dispatch out of scope until dispatch skill's CLI extension lands. Then CLI-backed personalities may use CLI dispatch pattern defined there.
C8. Don't expand registry with new built-in entries without spec amendment and audit pass.

Behavior:

B1. Subject (Step 0) can't resolve into packet with non-empty Artifacts (e.g. `/swarm` with no prior discussion): return E_NO_ARTIFACT "No reviewable artifact found." Dispatch no personalities.
B2. Swarm empty after gating: return E_EMPTY_SWARM "Swarm empty after gating — no personalities available." No synthesis.
B3. Swarm only Devil's Advocate: proceed single-personality; note in synthesis review is adversarial only.
B4. Dispatched personality returns no findings or times out: non-contributing, excluded from synthesis. Note in `Non-contributing personalities` field.
B5. All dispatched return no findings, or none contributed (all timed out, missing, or unstructured): synthesis states "No findings from any reviewer" (or "No contributing reviewers" when none contributed); confidence Low.
B6. Devil's Advocate ALWAYS dispatched unless `personality_filter` names a subset omitting it.
B7. Custom menu personalities evaluated against caller trigger. Trigger "always": always include (subject to gating if external backend).
B8. Cross-vendor diversity: if all finalized personalities resolve to same family or vendor, attempt resolution before dispatch. Order:
1. Find any personality in full candidate registry on different family; include it.
2. Internally re-assign Devil's Advocate to model class in different family, informed by `vendor` hint.
If neither resolves, proceed homogeneous; include `homogeneity_warning` in synthesis. Until C7 lifts, `gpt-class` has no dispatch backend, so steps (1)-(2) can't cross families and warning applies every default run (one line, not error).
B9. Generated personas dispatched like built-in (prompt at `<run>/<persona-name>.persona.md`, read-only), never added to registry or cached, always re-dispatched.

Defaults:

D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: `haiku-class` for every personality (first pass). Callers override via `model_overrides`; escalation is Step 6 host option 4.
D3. Default dispatch: `haiku-class` all at once (no cap); other classes rolling window of 3 (never more than 3 in flight).
D3b. Member reports and arbiter reply: no word limit; reply and `RESULT.md` kept brief.
D4. Default `model_overrides`: none.
D4b. Default `arbiter_model`: `haiku-class` (upgrade guidance: Inputs).
D5. Custom menu entry with no model class and no caller override: `haiku-class`.
D6. Confidence rating set by arbiter (rule in `arbiter-prompt.md`); host reports unchanged.
D7. `.hash-record/` base path: workspace root (repo or project root containing reviewed artifact; in git worktree, worktree root). Relative `.hash-record/` resolves against workspace root. Ambiguous: directory containing `problem` artifact's nearest root marker (e.g. `.git`). Conversation subject (no artifact path): host's current workspace root.

Footguns:

- F1: load reviewer prompt files only after swarm finalized and gated (Step 4); host never reads them.
- F2: failed availability probe drops personality; never fails swarm (Step 3).
- F3: put read-only constraint (C2) and write-the-file sentence in every dispatch prompt.
- F4: never dispatch one at a time: `haiku-class` all at once, other classes in window of 3 (Step 5).
- F5: speak in host voice; keep each finding's source personalities, not persona narrative voice.
- ANTI-PATTERN: `personality_filter: ["Security Auditor"]` runs only Security Auditor (plus safety-critical additions); name every personality wanted, Devil's Advocate included.

Error handling:

E3. Dispatch failure for individual personality (crash, incoherent output, or prompt load failure at Step 4): non-contributing (B4). Don't block synthesis. Incoherent: response not parseable into structured findings and not recognizable "No findings" statement. "No findings" with or without brief rationale is valid (B4, non-contributing). Structurally garbled, off-topic, or unparseable = incoherent (E3).
E5. Synthesis exceeds word budget: truncate by priority: disagreements first, then high-severity, then medium, then low. Note truncation in output.
E6. Arbiter dispatch fails or `RESULT.md` missing or unstructured: return error to caller with list of returned members (names and report paths) so operator can read reports directly. No synthesis from raw member reports.
E7. Report write failure (Step 5): non-fatal. Member that can't write its report is non-contributing (B4), named under Non-contributing in `RESULT.md`; swarm continues. Don't abort or surface write error to caller.

Precedence:

P1. `personality_filter` overrides trigger evaluation; only named dispatched; triggers bypassed for named. Exception: safety-critical auto-trigger (Step 2) still adds Engineer, Devil's Advocate, Minimalist.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: personality passing selection but failing probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.

Related:

- `dispatch`: how to launch sub-agents; read for mechanics, don't dispatch it.
- `hash-record`: key-addressed layout convention for per-persona cache under `.hash-record/`.
- `member-contract.md`: what every member reads and follows (report format, evidence checks, severity, reply).
- `arbiter-prompt.md`: what arbiter reads and follows (verification, classification, `RESULT.md` format).
- `challenger-contract.md`: what each challenger reads and follows (per-finding verdicts, cut rule).
