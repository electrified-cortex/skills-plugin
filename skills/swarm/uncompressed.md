# swarm — Uncompressed Reference

## Key Terms

- **Artifact**: input content under review — conversation excerpt, file path, diff, plan, document, or structured description. Passed as `problem`.
- **Review packet**: self-contained brief assembled from the artifact. Fields: Goal, Approach, Key decisions, Artifacts (actual content), Files affected, Blast radius, Conventions. Omit fields not applicable to the artifact type.
- **Personality**: named reviewer role defined by a `reviewers/<name>.md` file with YAML frontmatter. Has trigger condition, suggested model list (preference-ordered), backend preference list, and scope limiter. Loaded lazily — full prompts not present at selection time.
- **Personality registry**: set of personalities discovered by crawling `reviewers/` at runtime. Not a static table. Extended per-invocation by caller-supplied custom menu.
- **Custom menu**: caller-supplied list of additional personalities appended to the registry for the current invocation only. Does not persist.
- **Selection**: filtering the combined registry against artifact problem traits to produce the active personality set.
- **Availability gate**: probe step confirming a personality's required backend is reachable before dispatch.
- **Swarm**: surviving personalities after selection and availability gating.
- **Dispatch skill**: the `dispatch` skill — authoritative agent-launching mechanism. Swarm delegates all sub-agent launches here; never reinvent the launch primitive.
- **Disagree set**: subset of swarm findings where two or more personalities reached contradictory conclusions on the same point.
- **Confidence rating**: High / Medium / Low scalar attached to synthesis output. Reflects reviewer agreement, evidence quality, and scope coverage.
- **Model class**: abstract tier identifier — `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning, default), `opus-class` (heavy architectural reasoning). No bare model names anywhere.
- **Caller override**: caller-supplied `model_overrides` map pinning one or more personalities to a specific model class for the current invocation.
- **High-severity point**: finding that would block shipping or require architectural change. Used in confidence rating determination.
- **Availability probe**: lightweight shell command (e.g., `copilot --version`) or tool call confirming backend is live before including the personality.
- **Backend**: execution target for a personality. Values: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved, v1 out of scope).
- **Arbitrator**: single sonnet-class sub-agent dispatched after all swarm members complete. Receives full member outputs and review packet. Returns structured action list only. Not a reviewer. Not in the registry. Not subject to personality selection, availability gating, or `personality_filter`.

## Personality Registry

The registry is external to the skill. Built-in personality definitions live as separate files at `swarm/reviewers/<name>.md`. The registry is the directory listing — every `*.md` file present in `reviewers/` that passes the metadata-validation gate is a registered personality. Adding a personality requires only dropping a new file; no spec or SKILL.md edit required.

**Registry loading**: crawl `reviewers/` at runtime when a swarm invocation begins. Compile-time enumeration is not used. `reviewers/index.md` serves as the ordered manifest for the registry — it provides metadata and ordering for personalities discovered during the crawl.

**Metadata-validation gate**: any file in `reviewers/` is subject to automatic metadata-validation before registration. A file failing validation is silently skipped. No human approval required. Valid files are automatically registered.

**Built-in personalities (informative — not normative)**:

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

The integer index is informative only. The stable runtime index is assigned by alphabetical crawl (1-based). Personality renames change the index; callers using `personality_filter` by name are not affected.

**Pre-implementation gate — entry 8**: before implementing entry 8 or any CLI-backed personality, verify that task 10-0845 (dispatch skill CLI-extension) has reached PASS. Entry 8 must not be implemented until that task is complete.

## Personality Metadata Schema

Each `reviewers/<name>.md` must begin with a YAML frontmatter block. Files missing required fields or with malformed frontmatter fail the validation gate and are silently skipped.

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

**Model selection at dispatch**: read `suggested_models` from frontmatter, pick first available. Caller `model_overrides` take precedence. If no `suggested_models` entry is available and no override applies, fall back to `sonnet-class`.

## Custom Personality Menu

Callers may supply additional personalities for a single invocation. Each entry must specify: name, trigger condition, model class (or inherit from caller override), backend, and scope limiter. Custom entries are appended after entry 9 in evaluation order. They do not mutate the built-in registry.

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `problem` | required | The content under review. |
| `personality_filter` | optional | List of personality names or indices. Named personalities dispatched regardless of trigger evaluation; triggers bypassed for named entries. Inclusion list only — not an exclusion gate. |
| `model_overrides` | optional | Map of personality name to model class. Overrides affect model class only, not backend type. |

## Caller Tier

The host agent executing this skill must be **sonnet-class minimum**. The orchestration requires judgment-intensive work: constructing a self-contained review packet from arbitrary input, evaluating trigger conditions inline against inferred problem traits, and synthesizing arbitrator output into host-voice with a confidence rating. Haiku-class is insufficient for these tasks. Callers dispatching swarm via the `dispatch` skill must use `tier: standard` or higher.

## Step Sequence

### Step 1 — Build the review packet

Construct a review packet from `problem`. The packet must be self-contained: a reader with zero prior context must understand what is being reviewed, why, and what the key decisions were.

Packet fields (omit if not applicable to artifact type):

- Goal: what problem is being solved or what output is being evaluated.
- Approach: what was proposed, implemented, or produced.
- Key decisions: why this approach over alternatives.
- Artifacts: actual content under review (diffs, text, config — not a description of it).
- Files affected: list with brief descriptions.
- Blast radius: downstream consumers, imports, integrations affected.
- Conventions: applicable project conventions.

Verify the packet before proceeding: Goal must be specific enough to evaluate; Artifacts must include actual content, not just references. If either condition fails, attempt to resolve the gap from available context. Do not ask the caller to fill gaps.

### Step 2 — Select personalities

Build the combined registry by crawling `reviewers/` (applying the metadata-validation gate) and appending any caller-supplied custom menu entries.

If `personality_filter` is supplied: restrict candidate set to named personalities; dispatch those regardless of trigger evaluation (triggers bypassed for named entries). If no filter: evaluate trigger conditions against problem traits inferred from the review packet; exclude personalities whose trigger is not satisfied.

For each personality in the active set, read `suggested_models` from frontmatter and select the first available model. Caller `model_overrides` take precedence. If no `suggested_models` entry is available and no override applies, default to `sonnet-class`.

Selection logic must be inline within the skill. A separate dispatch for personality selection is not used.

Personalities with `required: true` must always be included regardless of trigger evaluation. `personality_filter` may exclude a required personality only when the caller explicitly names a subset that omits it. Devil's Advocate carries `required: true`.

### Step 3 — Availability gating

For each selected personality whose backend is not `dispatch-sonnet`, `dispatch-haiku`, or `dispatch-opus` (i.e., any external backend such as `copilot-cli`):

- Run the availability probe before including the personality.
- Probe succeeds: include the personality.
- Probe fails: drop the personality from the swarm for this invocation. Note the drop in synthesis output. Do not fail-stop or surface an error to the caller.

For `dispatch-*` backends, no probe is required; the dispatch skill handles errors internally.

### Step 4 — Load reviewer prompts

Only after the swarm is finalized (post-gating) load the prompt for each surviving personality. Reviewer prompts are stored as separate sub-skill files under `swarm/reviewers/<name>.md`. The filename is the personality name lowercased with spaces and apostrophes replaced by hyphens (e.g., `devils-advocate.md`, `security-auditor.md`). Load only files for dispatched personalities. Do not load files for non-dispatched personalities.

### Step 5 — Dispatch

Dispatch all swarm personalities in parallel using the `dispatch` skill. All dispatches in a single swarm invocation must be issued as a single batch; do not issue them sequentially.

Each personality dispatch receives:

1. The full review packet from Step 1.
2. The personality's prompt loaded in Step 4.
3. An explicit read-only constraint (see Constraints C1–C3).

Apply `model_overrides` at dispatch time: if a caller override exists, use it; otherwise use first available entry from `suggested_models`; otherwise fall back to `sonnet-class`. Apply the diversity preference rule (B8) after model selection to attempt cross-vendor coverage.

Dispatch parameters:

- `<tier>` = `standard` — personality reviews require moderate reasoning over a supplied artifact; fast-cheap is insufficient for evidence-cited findings.
- `<description>` = `swarm-personality:<personality-name>`

Should return: a structured findings list. Each finding: description of the issue, evidence cite (snippet, line reference, scenario, or direct quote). Empty response or "No findings" is a valid return — treated as non-contributing (B4).

### Step 6 — Arbitrator consolidation

After all swarm member outputs are collected, dispatch a single arbitrator sub-agent (sonnet-class by default). The arbitrator receives all raw member outputs and the original review packet. Per B4, non-contributing member outputs (empty/timeout) are excluded from the arbitrator's input set.

Dispatch parameters:

- `<tier>` = `standard` — arbitration requires comparing N member outputs and applying judgment to produce an action list; fast-cheap is insufficient.
- `<description>` = `swarm-arbitrator`

Should return: a structured two-section action list — Obvious actions and Critical actions — as specified in the Required arbitrator output format below. If no actionable findings: "No actionable findings" stated explicitly.

The arbitrator's sole job: produce a structured action list — not a narrative synthesis.

Required arbitrator output format (two sections):

- **Obvious actions**: items where two or more swarm members independently flagged the same concern, or where the concern is self-evident from the artifact. Each entry: action description + source personality indices + evidence cite.
- **Critical actions**: items that, if unaddressed, would block shipping or require architectural change, regardless of reviewer agreement count. Each entry: action description + source personality indices + evidence cite + severity rationale.

The arbitrator must not include speculative, low-confidence, or duplicate items. Its output is the input to Step 7; the host synthesizes from this list only, not from raw member output.

If the arbitrator produces an empty list, it must state "No actionable findings" explicitly. The host must still proceed to synthesis and note the clean result.

The arbitrator is structurally separate from the registry. It must not appear in the registry, must not be subject to personality selection, availability gating, or `personality_filter`.

### Step 7 — Aggregate findings and track disagreements

Collect findings from the arbitrator's structured action list. For each item, record: personality indices cited, finding summary, cited evidence.

Identify the disagree set: items where the arbitrator flagged conflicting conclusions (source indices from different members with contradictory claims on the same point). Each disagree entry records the personalities involved and the conflicting claims.

### Step 8 — Synthesize and return

Synthesize from the arbitrator's structured action list into a single host-voice output. Do not dump raw sub-agent output or raw arbitrator output to the caller. Speak as the host, presenting refined takeaways.

Required synthesis output fields:

- **Summary**: consolidated findings in host voice.
- **Disagreements**: explicit statement of each disagree-set item; state the tension and apply judgment.
- **Dropped personalities**: list of any personalities dropped by availability gate with reason.
- **Confidence rating**: High, Medium, or Low. Include rationale. If Low, state specifically what would raise it.

Synthesis output template (use this structure exactly):

```md
**Summary**: <consolidated findings in host voice>

**Disagreements**: <each disagree-set item with tension stated and judgment applied; "None" if disagree set is empty>

**Dropped personalities**: <name — reason for each dropped personality; "None" if none dropped>

**Confidence rating**: <High | Medium | Low> — <rationale; if Low, state what would raise it>
```

Synthesis output must not exceed 2000 words. If findings exceed this budget, prioritize high-severity and disagreement items. Note any truncation in output.

## Constraints

C1. All dispatched sub-agents operate in read-only mode. Sub-agents must not edit files, run side-effecting commands, commit, or call any mutating tool. State this constraint explicitly in every personality's dispatch prompt.

C2. Include the literal phrase "read-only review — analyze and report only, no file edits, no commits, no shell commands" in each personality's dispatch prompt.

C4. Every finding must cite specific evidence: a snippet, line reference, scenario, or direct quote. Instruct each reviewer to either cite or retract.

C5. Must not merge or replace the `code-review` skill. `swarm` is infrastructure; `code-review` is a consumer. Maintain a defined consumer-service boundary.

C6. No bare model names may appear in the skill, reviewer files, or synthesis output. Use model class terms only: `haiku-class`, `sonnet-class`, `opus-class`.

C7. CLI-as-dispatch (e.g., `claude -p`, copilot CLI) is out of scope until task 10-0845 reaches PASS. Once 10-0845 lands, the Copilot Reviewer and any CLI-backed personalities may use the CLI dispatch pattern defined there.

C8. Do not expand the personality registry with new built-in entries without a spec amendment and audit pass.

## Behavior

B1. If `problem` is empty or cannot be resolved into a review packet with a non-empty Artifacts field, return error: "No reviewable artifact found." Do not dispatch any personalities.

B2. If the swarm is empty after availability gating, return error: "Swarm empty after gating — no personalities available." Do not attempt synthesis.

B3. If the swarm contains only Devil's Advocate, proceed with a single-personality swarm and note in synthesis that the review is adversarial only.

B4. If a dispatched personality returns no findings or times out, record it as non-contributing and exclude from synthesis. Note the dropped personality in synthesis output.

B5. If all dispatched personalities return no findings, synthesis must state "No findings from any reviewer" and assign confidence rating Low.

B6. Devil's Advocate must always be dispatched unless explicitly excluded by `personality_filter` with a named subset that omits it.

B7. Custom menu personalities are evaluated against their caller-supplied trigger condition. If trigger is "always", always include (subject to availability gating if backend is external).

B8. Cross-vendor diversity: prefer at least one personality on a different model family or vendor than the host. Best-effort: if no diverse option is available after availability gating, proceed and note monoculture in synthesis output. Devil's Advocate is the natural carrier for diversity (always required, `vendor` frontmatter field expresses preference for non-Anthropic model).

## Defaults

D1. Default `personality_filter`: none (all registry entries evaluated).
D2. Default model class: first available from `suggested_models` frontmatter; fallback `sonnet-class`.
D3. Default dispatch: parallel (all at once, single batch).
D4. Default `model_overrides`: none.
D5. Custom menu entry with no model class and no caller override: default `sonnet-class`.
D6. Confidence rating default: Medium. Raised to High when all personalities agree and all findings cite evidence. Lowered to Low when disagree set is non-empty on a high-severity point, or when any personality returns no findings.

Calibration examples:

- **High**: Security Auditor, Code Quality Critic, and Devil's Advocate all flag the same SQL injection risk with evidence cites; no disagreements. → High.
- **Medium** (default): Reviewers agree on two findings but one personality returns "No findings." Wait — "any personality returns no findings" triggers Low, not Medium. → Low.
- **Medium** (true): Reviewers produce 3 findings with evidence; no high-severity disagreements; all personalities contributed. → Medium.
- **Low**: Devil's Advocate flags no concerns (returns "No findings"); or Security Auditor and Architect reach contradictory conclusions on a shipping-blocking concern. → Low; state what would raise it (e.g., "re-run with explicit security artifact to get Security Auditor finding").

## Error Handling

E1. Unavailable external backend (probe fails): drop personality, note in synthesis, continue. Do not fail-stop.
E2. Empty swarm after gating: return error (B2). Do not synthesize.
E3. Dispatch failure for individual personality (crash or incoherent output): treat as non-contributing (B4). Do not block synthesis.
E4. Review packet assembly fails (no artifact resolvable): return error (B1). Do not dispatch.
E5. Synthesis exceeds word budget: truncate at priority order — disagreements first, then high-severity, then medium, then low. Note truncation in output.

## Precedence

P1. `personality_filter` overrides trigger-condition evaluation; only named personalities are dispatched; triggers bypassed for named entries.
P2. `model_overrides` override registry defaults.
P3. Availability gate overrides selection: a personality that passes selection but fails the probe is dropped.
P4. Read-only constraint (C1) overrides any personality-specific instruction. No personality prompt may authorize editing, committing, or side-effecting commands.
P5. Synthesis word budget (2000-word cap) overrides completeness. Truncation required over exceeding the cap.

## Related

- `dispatch` — agent-launching skill; swarm delegates all sub-agent launches here.
- `compression` — compression skill used to produce the compressed form of this skill.
- `specs/arbitrator.md` — sub-specification for the arbitrator consolidation role.
- `specs/dispatch-integration.md` — sub-specification for dispatch integration patterns.
- `specs/glossary.md` — canonical term definitions for the swarm skill family.
- `specs/personality-file.md` — sub-specification for the reviewer personality file format.
- `specs/registry-format.md` — sub-specification for the personality registry format and crawl behavior.

## Scope Boundaries

Does NOT cover:

- The `code-review` consumer skill or any other consumer skill's internal logic.
- How to write reviewer prompts (data concern, not a behavioral requirement of this skill).
- Non-review dispatch use cases (search, generation, transformation).
- Any side-effecting operation by a dispatched personality; all personalities are strictly read-only.
- CLI-as-dispatch patterns until task 10-0845 is complete.
- `local-llm` backend routing in v1.
