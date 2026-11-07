---
name: swarm
description: Multi-lens review of anything (the current conversation by default, or a file, a diff, a plan, a concept). Cheap parallel reviewers, a skeptic for each, one arbiter, one result file. Triggers - /swarm, swarm this, swarm the discussion, double check what we discussed, swarm review, multi-reviewer, run all reviewers.
---

# swarm

NEVER dispatch this skill as sub-agent.

Key Terms:

- Subject: what swarmed, decided Step 0. No explicit subject = current discussion.
- Artifact: subject content under review (convo excerpt, file path, diff, plan, doc, concept, structured desc). Passed as `problem` or taken from convo.
- Review packet: self-contained brief from artifact. Fields: Goal, Approach, Key decisions, Files affected, Blast radius, Conventions, Artifacts (actual content; last, bulk). Omit n/a fields.
- Personality: named reviewer role. Prompt `reviewers/<name>.md` + `reviewers/index.yaml` entry. Has trigger, optional advisory escalation model, backend pref list, scope limiter. Loaded lazily; full prompts absent at selection.
- Vocabulary: persona, personality, reviewer, member = same role. Disagree set, Disagreements, Conflicting conclusions = same list.
- Selection: filter combined registry vs artifact problem traits = active personality set.
- Availability gate: probe confirming personality's required backend reachable before dispatch.
- Swarm: surviving personalities after selection + gating.
- Dispatch skill: `dispatch` skill, runtime how-to for launching sub-agents. Host reference, not delegation target. Host dispatches directly via own runtime (runSubagent in VS Code Copilot, Agent in Claude Code).
- Disagree set: swarm findings where 2+ personalities reach contradictory conclusions on same point.
- Confidence rating: High / Medium / Low scalar on synthesis. Reflects reviewer agreement, evidence quality, scope coverage.
- Model class: abstract tier. `haiku-class` (shallow/mechanical), `sonnet-class` (moderate), `opus-class` (heavy architectural), `gpt-class` (external OpenAI). Each resolves to one family (haiku/sonnet/opus: Anthropic; gpt: OpenAI).
- Caller override: caller `model_overrides` map pinning personalities to model class for invocation.
- High-severity point: finding that blocks ship or requires architectural change. = member `blocking` severity (member-contract.md). Maps to arbiter Critical actions. Used in E5 truncation and arbiter confidence rule.
- Availability probe: lightweight shell cmd (e.g., `copilot --version`) or tool call confirming backend live before including personality.
- Backend: execution target. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
- Arbiter: single sub-agent (haiku-class default) dispatched after all members complete. Reads member reports, challenge files, packet header (not whole packet) at host-given paths. Writes `RESULT.md` in run folder. Replies brief summary. Not reviewer. Not in registry. Not subject to selection, gating, `personality_filter`.
- Run folder: unique scratch dir (session scratchpad or temp) host creates after packet verifies, before dispatch, at new path (`swarm-<first 8 hex of manifest hash>-<UTC timestamp>`). Holds `packet.md`, generated-persona reports, `RESULT.md`. Host only picks/creates path; does not read reports by default. After creation arbiter owns it.
- Report file: member full findings, written by member itself (no size cap).
- Challenger: haiku-class sub-agent paired with one member. Reads packet + that member's report, adds no findings, writes verdict (CONFIRMED, REJECTED, UNSURE) per finding to challenge file. Follows `challenger-contract.md`.
- RESULT.md: arbiter structured action list at `<run>/RESULT.md`. File host reads by default (Step 6 host options).
- Generated persona: reviewer manifested inline when registry yields <3 suitable personalities. Name, critique lens, scope limiter, all domain-specific. Current invocation only; not cached; no `reviewers/` file.
- Manifest hash: SHA-256 of manifest text: one line `<path> <SHA-256 of content>` per file, paths sorted bytewise, LF. Non-file artifacts (text, convo excerpts): SHA-256 of artifact content. Artifact key for per-persona hash-record entries.

## Personality Registry

External to skill. Built-in defs at `swarm/reviewers/<name>.md`. Registry = dir listing: every `*.md` in `reviewers/` passing metadata gate = registered personality. Add built-in = `index.yaml` entry + `reviewers/<name>.md` (C8: spec amendment). One-off uses custom menu.

Loading: crawl `reviewers/` at runtime when invocation begins. No compile-time enumeration. `reviewers/index.yaml` = ordered manifest; metadata + ordering for crawled personalities.

Metadata gate: every file in `reviewers/` validated before registration. Fail = silently skipped. Reads persona's `index.yaml` entry + dir listing, never persona body; no complete index entry = fail. No human approval; valid files auto-registered.

Built-in: `reviewers/index.yaml` = source of truth (trigger, scope, escalation hint per persona). Callers select by name, never index.

## Personality Metadata Schema

Metadata = entry in `reviewers/index.yaml`. `<name>.md` = reviewer prompt only.

Required: `name` (unique across `reviewers/`); `trigger` (`"always"` = unconditional); `required` (true = dispatched regardless of `personality_filter` unless explicitly excluded); `suggested_backends` (pref-ordered backend kinds; model class resolved Step 5); `scope` (reviews + ignores).

Optional: `vendor` (B8 hint only; never selects backend); `escalation_model` (advisory re-run tier if persona asks escalation; absent = next tier up; never raises starting tier).

No `model` field: every personality starts lowest tier. Entry missing required field = gate fail, file skipped.

## Custom Personality Menu

Callers may supply extra personalities per invocation. Each: name, trigger condition, model class (or inherit caller override), backend, scope limiter. Appended after built-ins in eval order. Never mutate built-in registry.

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `problem` | optional | What to review: any artifact (Step 0). Absent = current discussion. |
| `personality_filter` | optional | List of personality names. Restricts swarm to named; bypasses trigger eval for them. Names whole swarm: omitted required personality dropped (safety-critical auto-trigger still adds three). Indices not accepted (crawl-built registry; indices unstable). |
| `model_overrides` | optional | Map personality name to model class. Affects class only, not backend type. `gpt-class` has no dispatch backend until C7 lifts: `gpt-class` value in `model_overrides` or `arbiter_model` ignored; host says so in one line. |
| `arbiter_model` | optional | Arbiter model class. Default `haiku-class`. Upgrade to `sonnet-class` when artifact safety-critical (Step 2 auto-trigger), security/privacy-sensitive, result gates ship, or first haiku result looks off (no Dropped section, near-wholesale acceptance of proposed cuts, many UNSURE). `opus-class` for highest stakes. |

## Model Economics

haiku-class swarm = value: breadth (several independent lenses + skeptic) cheap, breadth finds problems. Return per class step shrinks; stronger model one role buys little vs another lens.

Prefer haiku-class all roles (members, challengers, arbiter). Upgrade only where a specific lens or the verdict needs it, one role at a time: persona via `model_overrides`, then arbiter via `arbiter_model`. Whole-swarm upgrade = highest stakes only. Another haiku lens usually beats upgrading one.

Every personality starts haiku-class. Personality may ask escalation; host may re-run just that persona higher (Step 6, option 4): spend follows evidence. Run = 2N+1 agents (N reviewers, N challengers, arbiter); fixed cost per agent, so small artifacts suit fewer lenses.

## Caller Tier

Host executing skill MUST be sonnet-class minimum. No dispatch mechanism in host runtime: return E_NO_DISPATCH: "Swarm requires dispatch capability; no dispatch mechanism available." Host below sonnet-class: say so in one line, continue.

## Step 0 — Decide subject

First, before anything. One line before any dispatch: `Swarming: <subject> — <what the review will check>`. Ask only if truly impossible to tell: pick most likely, state choice, operator corrects.

Subject = anything: convo, file(s), diff, plan, doc, concept, decision, claim, question, code. Resolve in order:

1. Explicit in request or `problem`: path, diff, quoted text, URL, named thing ("swarm the caching design", "swarm this file").
2. Deictic ("this", "that", "it", "what you just said"): most recent matching thing in convo (last file touched, last proposal, last answer).
3. None (`/swarm`, "swarm", "swarm this" with nothing to point at): swarm the discussion = current topic from its start to now, incl own statements, claims, decisions, reasoning.

Convo subject: artifact = convo excerpt. Write relevant turns into packet verbatim, not summarized, covering current-topic stretch (whole session only if one topic). Goal: review checks discussion for correctness, gaps, unsupported claims. Prefer topic-specific generated lenses (e.g., claim checker) plus always-on lenses.

## Step Sequence

Steps 1-8 run in order every invocation.

### Step 1 — Build review packet

Cache key: extract file list from `problem` (deterministic parse, script, no LLM). Read files, compute manifest hash HASH (paths in `problem`, sorted, content SHA-256; or SHA-256 of artifact text if no files named). Use `sha256sum`; timestamps `date -u +%Y%m%dT%H%M%SZ`.

Per-persona cache: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/` (XX = first 2 hex of HASH; D7 sets base) holds `review.md` + `challenge-<challenger_key>.md`.
- `persona_key` = first 8 hex of SHA-256 of (persona file + `member-contract.md` + raw subject text (`problem` string or conversation excerpt)), concatenated in that order, no separator.
- `challenger_key` = first 8 hex of SHA-256 of `challenger-contract.md`.

Step 5 reuses cached report. No whole-run cache.

Build packet from `problem`. Self-contained: zero-context reader must grasp what, why, key decisions. Fields (omit n/a):

- Goal: problem solved or output evaluated.
- Approach: what proposed, implemented, produced.
- Key decisions: why this over alternatives.
- Files affected: list + brief desc.
- Blast radius: downstream consumers, imports, integrations.
- Conventions: applicable project conventions.
- Artifacts: actual content under review (diffs, text, config; not description).

Keep under ~50 KB: member Read calls cap ~25,000 tokens; trim artifact to what review needs.

Verify: Goal names artifact type + outcome evaluated (e.g., "evaluate diff for correctness and security"). Artifacts hold actual content, not refs. Gap: resolve from context. Never ask caller to fill. Unresolvable: E_PACKET_INCOMPLETE, halt.

Verified: create run folder (new path; see Run folder), write `<run>/packet.md`. Halt above leaves no folder.

### Step 2 — Select personalities

Combined registry = crawl `reviewers/` (metadata gate) + custom menu entries.

`personality_filter`: restrict active set to named; dispatch regardless of trigger eval. Name in `personality_filter` or `model_overrides` matching no persona: ignored, host says so one line. No filter: eval triggers vs problem traits inferred from packet; exclude unsatisfied. Eval = semantic judgment vs packet, not literal string match to `trigger`.

Safety-critical auto-trigger: fires when packet Files-affected (or files named in Artifacts if omitted) contains artifact whose failure could break host env, propagate across fleet, or compromise process lifecycle: control plane, supervisor, watchdog, signal handling, container/harness config, scheduled jobs, or similar. Plan/convo/concept with no files: fires when subject proposes changing such system. Fires → add Engineer, Devil's Advocate, Minimalist regardless of trigger eval or `personality_filter`. Callers cannot opt out. Supersedes filter override of trigger eval for these three. Protected from 6-cap drop.

Caller `model_overrides` win. `escalation_model` advisory only (Step 6 option 4); never raises start tier. Internal-dispatch backends: no model-class probe.

`required: true` included regardless of trigger eval. Filter excludes required only when caller explicitly names subset omitting it. Devil's Advocate + Minimalist = `required: true`.

6-cap: if >6 pass trigger eval, priority:
1. Devil's Advocate + Minimalist always.
2. Safety-critical additions (Engineer, DA, Minimalist) + generated convo lens: protected.
3. Most-specific trigger (specificity = count distinct comma-delimited terms in `trigger`; `"always"` = 0; tie-break alphabetical name).
4. Drop lowest remaining until 6.

Gap fill: <3 suitable after filter + trigger eval → manifest one or more generated personas inline to reach at least 3. Each: domain-relevant invented name, critique lens covering uncovered traits, scope limiter avoiding overlap. Dispatched like built-in; not added to registry; not cached.

Convo lens: convo subject → add one topic-specific generated lens (e.g., claim checker) even if 3+ selected. Counts toward 6-cap; never dropped.

### Step 3 — Availability gating

External backend (not internal to `dispatch` skill, e.g., `copilot-cli`): run probe before including.
- Pass: include.
- Fail: drop for this invocation; note in synthesis. No fail-stop, no error to caller.

Internal-dispatch backends: no probe; dispatch skill handles errors.

### Step 4 — Resolve reviewer prompts

After swarm final (post-gating): absolute path per survivor `swarm/reviewers/<name>.md`; filename = name lowercased, spaces to hyphens, apostrophes dropped (e.g., `devils-advocate.md`, `security-auditor.md`). Host never reads these; each member reads own. Missing file: non-contributing per E3, continue. Custom Specialist entry has no file: replaced by generated persona. Generated prompt (name, lens, scope limiter) written by host to `<run>/<persona-name>.persona.md`, passed same way.

### Step 5 — Dispatch

Use runtime dispatch per `dispatch` skill. `dispatch` agent type for personalities, NOT `scout` (read-only; reviewers must write report).

Concurrency: haiku-class no cap; launch all at once (6-cap bounds). Other classes: rolling window of 3, dispatch next as each completes. Not returned within host-defined threshold (default 5 min member/arbiter, 3 min challenger) = timed out per B4. Tool-call budgets: 10 member/challenger; 2N+6 arbiter (reads N reports + N challenges).

Reuse first: per persona compute dir (Step 1 key) at resolved class. Cached `review.md` ending `END OF REPORT` (not "No findings") satisfies persona: skip dispatch. Its `challenge-<challenger_key>.md` reused if present and ending `END OF REPORT`; else dispatch challenger only. Other-class reports don't satisfy. Two runs same subject share cache: never start second while one in flight.

Reports to files, not host. Member writes full report, replies exactly one line: `done: <path>`. Paths:
- Built-in: `.hash-record/XX/HASH/swarm/v2/personas/<persona-name>-<model-class>-<persona_key>/review.md` (slug as Step 4; member creates missing dirs).
- Generated: `<run>/<persona-name>.md` (never in hash record).

Challenge pass (member pair): on member return, dispatch its haiku-class challenger (`dispatch` agent type) async in background, without waiting for others. Host dispatches challengers (sub-agents cannot).

Challenger prompt short: "Read and follow `challenger-contract.md`" (absolute path `swarm/challenger-contract.md`) + absolute paths of packet, member report, challenge file; same in-prompt sentence: writing challenge file is required deliverable; read-only (write only challenge file). Challenger adds no findings; verdict per finding (CONFIRMED, REJECTED with contradicting quote, UNSURE); replies `done: <path>`.

Challenge path: `challenge-<challenger_key>.md` beside report (generated: `<run>/<persona-name>.challenge.md`). Challengers uncapped, run as each member returns. Usable report = structured, ends `END OF REPORT`, not "No findings". No usable report = no challenger. Failed/timed-out challenger simply absent; arbiter verifies that member itself. `<tier>` = `fast-cheap`, `<description>` = `swarm-challenger:<persona-name>`.

Host does not read reports by default (Step 6 options). Usable check = one-line shell test of last line, not a read. `done:` alone proves nothing (refused write can still answer): confirm file exists. Host gives arbiter paths of returned members + names of timed-out/no-usable-file/crashed (B4). Timed-out member's leftover file ignored; half-written never read.

Each personality dispatch receives:

- Path to `<run>/packet.md` (member reads; host never pastes).
- Absolute paths of personality prompt (Step 4) and `swarm/member-contract.md`. Always absolute: sub-agent cwd may differ.
- Report path (absolute). Reply rule, report format, evidence checks, severity in `member-contract.md`. Prompt short: "Read and follow member-contract.md", three paths, tool-call budget, one sentence in prompt's own words: writing findings file is explicit required deliverable; findings must not be returned as text. Sentence goes in prompt itself, not only contract.
- Read-only constraint + single exception (own report file), in prompt as well as contract (C1).

Apply `model_overrides` at dispatch: override if present, else haiku-class. Internal tier follows resolved class, not backend name. Run B8 diversity check after model selection, before dispatch.

Params:
- `<tier>` = tier of resolved class (haiku-class = `fast-cheap`, sonnet-class = `standard`, opus-class = `deep`).
- `<description>` = `swarm-personality:<personality-name>`.

Report format, evidence shapes, severity vocab: `member-contract.md`.

### Step 6 — Arbiter consolidation

After all members + challengers returned/failed/timed out: dispatch one arbiter with `arbiter_model` (default haiku-class; Inputs for upgrade), `dispatch` agent type. Prompt short: "Read and follow `swarm/arbiter-prompt.md`" (absolute path); run folder; each returned member (name, model class, report path); challenge path of each member that has one; each returned persona's `escalation_model` (if set); names of timed-out or no-usable-file; Unavailable personalities + homogeneity warning; tool-call budget; in-prompt sentence: writing `RESULT.md` is required deliverable; read-only (write only `RESULT.md`). `arbiter-prompt.md` holds verification, classification, confidence rule, `RESULT.md` format. Arbiter fails, or `RESULT.md` missing or not ending `END OF REPORT`: retry once, then E6.

File-existence filter (discard findings citing file not in packet Files-affected list; skipped if none listed), B4 handling, timed-out file never read: all in `arbiter-prompt.md`. Run folder kept for drill-down; session scratch, no cleanup.

Params:
- `<tier>` = tier of `arbiter_model` (default `fast-cheap`).
- `<description>` = `swarm-arbiter`.

MUST write `<run>/RESULT.md`: three-section action list (Obvious actions, Critical actions, Conflicting conclusions) per `arbiter-prompt.md`, plus Participants, Confidence, Escalation, Dropped, Non-contributing, Reports. Concise: one line per item where possible, no restating reports. None actionable: state "No actionable findings" explicitly. Arbiter reply: `RESULT.md` path, counts (critical / obvious / conflicts / non-contributing), short headline of key findings, enough for unread handoff (option 1). No word limit; keep brief.

Host options. Pick by operator need; cheapest that serves. Default option 1 (arbiter reply gives counts + headline). Option 1: operator just needs result or reads it. Option 2: host must act on findings or operator wants synthesized write-up. Option 3: only when finding needs original reasoning.

1. Hand off: give operator `RESULT.md` path + arbiter reply, unread. Steps 7-8 replaced by handoff message.
2. Read + synthesize: read `RESULT.md`, present per Step 8.
3. Read deeper: after reading `RESULT.md`, read specific member reports when finding needs reasoning or operator asks about one persona (e.g., what Minimalist said).
4. Escalate: when `RESULT.md` recommends higher-tier re-run and worth cost, re-run only that persona at recommended tier (default next up), async, passing earlier report as hypothesis list to confirm/refute/extend, not as fact. New run: own report + challenge paths (`<persona-name>-<model-class>-<persona_key>/`), launch challenger as usual, re-dispatch arbiter over updated set (escalated report replaces earlier; earlier stays on disk). Max one escalation round per persona, two personas per run. Operator may decline.

Operator may read `RESULT.md` or any report directly, instead of or in addition to host.

No actionable findings: option 2 states clean result.

### Step 7 — Aggregate, track disagreements

From `RESULT.md`, per item record: personality names cited, finding summary, cited evidence.

Disagree set from arbiter Conflicting conclusions. Each entry: personalities involved + conflicting claims as arbiter captured.

### Step 8 — Synthesize and return

Option 1 returns arbiter reply instead; options 2-3 return this. Synthesize from arbiter action list into single host-voice output. Never dump raw sub-agent/arbiter output. Host voice, refined takeaways.

Template (use exactly):

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

Max 2000 words. Over budget: keep disagreements + high-severity; drop medium, low first.

Hash record: members + challengers write per-persona reports + challenges (Step 5); host writes nothing. `v2` segment changes only if `persona_key` algorithm changes.

## Error Envelope

All errors: `{ error: { code, message } }`. Stable codes (callers may branch):

- `E_NO_DISPATCH`: no dispatch mechanism in host runtime.
- `E_NO_ARTIFACT`: no reviewable subject (B1).
- `E_EMPTY_SWARM`: empty after gating (B2).
- `E_ARBITER_FAIL`: arbiter failed or no structured output (E6).
- `E_PACKET_INCOMPLETE`: Step 1 verify failed, gap unresolvable.

## Constraints

C1. Sub-agents READ-ONLY. MUST NOT edit files, run side-effecting commands, commit, or call mutating tools. Sole exception: personality writes own report file (+ parent dirs) at assigned path; arbiter writes only `RESULT.md` in run folder, deletes nothing. State constraint + exception in every dispatch prompt.

C2. Each personality dispatch prompt has explicit read-only language: no edits, commits, side-effecting shell commands, except own report file. Exact wording free. Evidence checks in `member-contract.md`.

C3. Skill cannot technically block sub-agent mutating tools; constraint behavioral, enforced by prompt.

C4. Every finding MUST cite specific evidence (`member-contract.md`).

C5. MUST NOT invoke `code-review` internally. Siblings; neither depends on other.

C6. Refer to models by capability tier, never version string. Bare model names forbidden in skill, reviewer files, synthesis.

C7. CLI-as-dispatch out of scope until dispatch skill CLI extension lands; then CLI personalities may use its pattern.

C8. No new built-in registry entries without spec amendment + audit pass.

## Behavior

B1. Subject (Step 0) cannot resolve to packet with non-empty Artifacts (e.g., `/swarm` with no prior discussion): E_NO_ARTIFACT: "No reviewable artifact found." Dispatch nothing.

B2. Swarm empty after gating: E_EMPTY_SWARM: "Swarm empty after gating — no personalities available." No synthesis.

B3. Only Devil's Advocate remains: proceed; note in synthesis review is adversarial only.

B4. Dispatched personality returns no findings or times out: non-contributing, excluded from synthesis. Note in `Non-contributing personalities`.

B5. All return no findings, or none contributed (all timed out, missing, unstructured): synthesis states "No findings from any reviewer" (or "No contributing reviewers" if none contributed); confidence Low.

B6. Devil's Advocate MUST always dispatch unless `personality_filter` explicitly excludes via named subset omitting it.

B7. Custom menu personalities eval'd vs caller trigger. "always" = always include (subject to gating if external backend).

B8. Cross-vendor diversity: if all finalized personalities resolve to same family/vendor, attempt before dispatch:
1. Find any personality in full candidate registry on different family; include.
2. Re-assign Devil's Advocate internally to a model class in different family, per its `vendor` hint.

Neither resolves: proceed homogeneous; include `homogeneity_warning` in synthesis. Until C7 lifts, `gpt-class` has no dispatch backend, so (1)-(2) can't cross families; warning on every default run (one line, not error).

B9. Generated personas dispatched like built-in (prompt `<run>/<persona-name>.persona.md`, read-only), never added to registry or cached, always re-dispatched.

## Defaults

D1. Default `personality_filter`: none (all registry entries eval'd).

D2. Default class: haiku-class for every personality (first pass). Callers override via `model_overrides`; escalation = Step 6 option 4.

D3. Dispatch: haiku-class all at once (no cap); other classes rolling window of 3 (never >3 in flight).

D3b. Member reports + arbiter reply: no word limit; reply and `RESULT.md` brief.

D4. Default `model_overrides`: none.

D5. Custom entry with no class, no override: haiku-class.

D6. Confidence rating set by arbiter (rule in `arbiter-prompt.md`); host reports unchanged.

D7. `.hash-record/` base: workspace root (repo/project root containing reviewed artifact; worktree root in worktree). Relative `.hash-record/` resolves against it. Ambiguous: dir containing `problem` artifact's nearest root marker (e.g., `.git`). Convo subject (no artifact path): host's current workspace root. Windows: keep root short; cache paths add ~150 chars vs 260-char limit.

## Footguns

- F1: load reviewer prompts only after swarm final + gated (Step 4); host never reads them.
- F2: failed probe drops personality; never fails swarm (Step 3).
- F3: C2 read-only + write-the-file sentence in every dispatch prompt.
- F4: never dispatch one at a time: haiku-class all at once, others window of 3 (Step 5).
- F5: host voice; keep per-finding source personalities, not persona narrative.
- ANTI-PATTERN: `personality_filter: ["Security Auditor"]` runs only Security Auditor (+ safety-critical additions); name every wanted personality, Devil's Advocate included.

## Error Handling

E3. Individual dispatch failure (crash, incoherent output, prompt load failure at Step 4): non-contributing (B4). Never blocks synthesis. Incoherent = not parseable into structured findings and not recognizable "No findings". "No findings" with or without rationale = valid (B4, non-contributing). Garbled, off-topic, unparseable = incoherent.

E5. Synthesis over budget: truncate priority: disagreements first, then high-severity (`blocking`), then medium (`issue`), then low. Note truncation.

E6. Arbiter fails or `RESULT.md` missing/unstructured: return error with list of returned members (names + report paths) so operator reads reports directly. No synthesis from raw member reports.

E7. Report write failure (Step 5): non-fatal. Member that can't write = non-contributing (B4), named under Non-contributing in `RESULT.md`; swarm continues. No abort, no write error to caller.

## Precedence

P1. `personality_filter` overrides trigger eval; only named dispatched; triggers bypassed. Exception: safety-critical auto-trigger (Step 2) still adds Engineer, DA, Minimalist.

P2. `model_overrides` override registry defaults.

P3. Availability gate overrides selection: passes selection, fails probe = dropped.

P4. C1 read-only overrides any personality instruction. No personality prompt may authorize editing, committing, side-effecting commands.

## Related

- `dispatch`: how to launch sub-agents; read for mechanics, never dispatch it.
- `hash-record`: key-addressed layout convention for per-persona cache under `.hash-record/`.
- `member-contract.md`: what each member reads and follows (report format, evidence checks, severity, reply).
- `arbiter-prompt.md`: what arbiter reads and follows (verification, classification, `RESULT.md` format).
- `challenger-contract.md`: what each challenger reads and follows (per-finding verdicts, cut rule).
