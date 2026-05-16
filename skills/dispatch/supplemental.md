# Dispatch — Supplemental

Background, evidence, and nuance for the `dispatch` skill. Agents read this on demand when the runtime card is insufficient. Not loaded by default.

## Empirical: Context Inheritance

**Conversation context does NOT inherit.**

Empirical (2026-04-19, secret-phrase): host wrote `purple-tractor-mountain-9183` in conversation, then dispatched a sub-agent and asked it to quote the token. Sub-agent reported nothing visible. Confirmed across all subagent types tested.

Implication: any prompt that says "continue what we were doing" or "use the findings from earlier" delivers zero context to the dispatched agent. Hand-feed every relevant prior turn.

**Project context IS inherited.**

Empirical (2026-04-19, enumerate-context): dispatched both a `Dispatch`-type and a `general-purpose`-type sub-agent and asked each to list `CLAUDE.md` and memory files visible in its system prompt. Both reported workspace and project-scoped `CLAUDE.md` files plus the project memory index.

Implication: don't waste tokens repeating project conventions in every prompt. The agent already has them.

Both claims may drift between Claude Code releases. Re-verify if behavior seems off.

## System-Prompt Pollution

A heavy `CLAUDE.md` (or any project-level system prompt) reduces dispatch effectiveness in ways that aren't immediately obvious from the runtime card.

The Dispatch sub-agent inherits project context automatically (see "Project context IS inherited" above). That includes the workspace and project-scoped `CLAUDE.md` files. Every line in those files becomes part of the dispatched agent's system prompt — the cleanest "zero-context" sub-agent still carries that weight.

Implications:

- **Bias.** Strong opinions in `CLAUDE.md` (style preferences, role framings, narrative voice) bias the dispatched agent's output even when the task has nothing to do with them. A markdown linter dispatched under a "be concise and stoic" `CLAUDE.md` returns terser fix lines than the same dispatch under a neutral system prompt.
- **Token cost.** Every dispatch pays the `CLAUDE.md` token cost up front, before any task work begins. Heavier `CLAUDE.md` = more cost per dispatch with no benefit when the task doesn't intersect.
- **Contamination across roles.** A `CLAUDE.md` written for one role (e.g. operator-facing Curator behavior) leaks into dispatches that should be role-agnostic (e.g. mechanical detection tasks).

Mitigations:

- Keep `CLAUDE.md` minimal at the workspace level. Reserve it for genuinely cross-role conventions.
- Push role-specific framing into the role's agent root, not into shared context.
- For dispatch-heavy workflows, periodically audit `CLAUDE.md` for content that doesn't earn its dispatch-time cost.

Empirically untested under formal conditions but widely observed: dispatches under lean project context produce more focused output than dispatches under heavy project context for the same task.

## Subagent Type Dimensions

Types differ on three axes:

- **Tool scope** — which tools the agent may call. Some types deliberately restrict (e.g. audit-style types with no file-write).
- **System prompt size** — heavier types cost more tokens per dispatch. Prefer lean for simple tasks.
- **Default model** — some types pin a model. Override if the pin is heavier than the task warrants.

Type names as of 2026-04-19: `Dispatch` (scope-isolated), `general-purpose` (broader). The complete list and properties evolve; treat known names as examples, not a stable enumeration.

## Anti-Pattern Walkthrough

ANTI-PATTERN: Host is midway through a research conversation. Operator has narrowed the scope of a code audit across several turns. Host has accumulated partial findings. Host dispatches: "Continue the code audit and produce the final findings report."

What goes wrong: dispatched agent has no conversation context. It does not know the operator's narrowing instructions, the partial findings, or what "continue" means. It will refuse (no goal), produce an unscoped audit (ignoring narrowing), or invent findings.

Correct decision:

- (a) Inline where the host already has the context. Usually cheaper.
- (b) Dispatch with a fully hand-fed prompt that includes the operator's scope instructions (quoted), the partial findings (written out), and the specific remaining work.

## Error Handling

| Symptom | Likely cause | Action |
| --- | --- | --- |
| Decision tree gives no clear outcome | Ambiguous case | Inline. File draft task or feedback. Don't guess. |
| Footgun fires (e.g. F1 error) | Wrong dispatch decision | Revise decision before retry. Don't retry unchanged. |
| Output incoherent or off-topic | F5 (missing hand-fed context) | Inspect prompt for gaps. Fix, then re-dispatch. |
| Inline cost unaffordable | Context too large or work too slow | (a) dispatch with full hand-fed prompt accepting overhead, or (b) defer. |

## Precedence

- Consuming skill defines a domain-specific dispatch pattern → that pattern governs over this skill's general guidance for that domain. This skill provides primitives; consumers shape them.
- Empirical claims here conflict with an agent's expectation about inherited context → empirical governs.
- Correctness > throughput. Decision tree says inline but host is overloaded → not permission to dispatch incorrectly. Defer or reduce scope.

## CLI Dispatch Examples

Worked examples for CLI dispatch mode (see `spec.md §CLI Dispatch Mode` for normative requirements CDR1–CDR17).

### Pattern: `claude -p` — Foreground, Read-Only Analysis

Trigger: calling agent is a dispatched sub-agent (no `Agent` tool re-entry), needs to analyze a file.

Enforcement method applied: prompt instruction (explicit "do not modify") + permission policy (no Edit/Write tools in scope).

```bash
claude -p "Analyze the following TypeScript file for null-safety issues. Return a markdown list of findings. Do not modify any files or produce side effects.

$(cat src/auth.ts)"
```

What happens: Claude Code CLI runs stateless in print mode. stdout is the findings list. No session state, no file writes.

Aggregation: caller captures stdout directly; no further merge step needed for a single call.

---

### Pattern: `claude -p` — Parallel Background Invocations

Trigger: calling agent needs to analyze multiple independent files simultaneously; `Agent` tool unavailable.

Enforcement method applied: prompt instruction per call + permission policy.

```bash
# Fire both calls in background; capture PIDs for wait.
claude -p "List exported symbols in src/auth.ts as JSON array. Read-only." > /tmp/auth_out.json &
AUTH_PID=$!

claude -p "List exported symbols in src/session.ts as JSON array. Read-only." > /tmp/session_out.json &
SESSION_PID=$!

# Block until both complete.
wait $AUTH_PID $SESSION_PID

# Aggregate: merge both JSON arrays into a single result.
# (Caller parses /tmp/auth_out.json and /tmp/session_out.json and merges.)
```

Aggregation pattern: each call writes to a discrete temp file; caller reads both files after `wait`, merges outputs into the task's expected output shape, returns merged result. Per CDR16, partial results are not forwarded until both calls complete.

---

### Pattern: `copilot` — Dispatch via copilot-cli Skill

Trigger: task requires Copilot CLI analysis (review, ask, or explain). Calling agent uses CLI dispatch because `Agent` tool is unavailable.

Enforcement method applied: copilot-cli skill owns flag assembly and ensures read-only invocation; prompt instruction constrains scope.

The calling agent **must** load the `copilot-cli` skill and route through it. Direct `gh copilot` invocation bypasses sub-skill routing and output parsing — only acceptable for illustrative reference.

```bash
# Via copilot-cli skill routing (correct path):
# 1. Load copilot-cli skill.
# 2. Identify operation: "ask" (general query).
# 3. Sub-skill ask assembles flags and invokes:
gh copilot ask "What does the authenticate() function in src/auth.ts do? Explain only — do not modify files."
```

Cross-reference: `copilot-cli` skill — operation routing table (review / ask / explain), flag assembly rules, output parsing. CLI dispatch does not override `copilot-cli` sub-skill routing (CDR6).

---

### Read-Only Enforcement — Decision Table

Use this table to select the enforcement method when setting up a CLI dispatch invocation.

| Enforcement method | When to use | How to apply |
| --- | --- | --- |
| Permission policy | Calling agent controls tool permissions (most common in Claude Code) | Ensure no `Edit`, `Write`, or mutable `Bash` permissions are active for the dispatch context. |
| Prompt instruction | Permission policy not applicable; CLI accepts text instructions | Include an explicit line in the dispatch prompt: "Do not modify any files or produce side effects. Return output only." |
| Wrapper enforcement | CLI tool has dangerous default flags or side-effecting modes that require stripping | Wrap the CLI call in a script that passes only the allowed flags; strip or reject any flags that enable mutations. |

At least one method must be applied per CDR10. Prefer permission policy; layer prompt instruction on top for defense in depth.

ANTI-PATTERN: Calling agent dispatches `claude -p "Refactor auth.ts and save the result."` — this violates CDR8 (mutation) and CDR3 (no scope-limiting prompt on what to return). Correct: `claude -p "Suggest refactoring changes for auth.ts. Return proposed diff as text. Do not modify any files."`

## Hash-Record Integration

Dispatch and hash-record are orthogonal. Dispatch has no knowledge of any cache or hash-record.

The integration pattern used by consuming skills like `skill-auditing` and `markdown-hygiene`:

1. **Pre-dispatch**: the host calls the hash-record `result` tool (a script, not a dispatch call). If the result is `HIT`, dispatch is skipped — the cached report is used directly.
2. **Dispatch**: the host builds a prompt and calls the dispatch skill. The sub-agent reads `instructions.txt` and executes. The host **never** reads `instructions.txt` directly.
3. **Post-dispatch**: the host calls `result` again to verify the dispatched agent wrote the report. `MISS` means the agent failed; `HIT` resolves the result.

Dispatch does not manage cache records. Hash-record decisions belong to the consuming skill.
