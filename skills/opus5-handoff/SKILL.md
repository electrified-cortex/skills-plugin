---
name: opus5-handoff
description: Hand a complete, scopeable unit of autonomous work from a human-facing driver model (Opus 4.8, Sonnet 5) to Claude Opus 5 running as a background agent — recognize the handoff, compile a self-contained brief that lets Opus 5 run start-to-finish without asking, tune it to suppress Opus 5's over-narration, over-verification, over-delegation, and scope creep, set effort and thinking, dispatch, and relay the result. Triggers - offload to Opus 5, hand this to Opus 5, dispatch to Opus 5, spawn an Opus 5 background agent, run this in the background on Opus 5, write an Opus 5 prompt, background agent for a multi-file feature or review pass or research sweep.
---

Lock the full spec with the user first, then hand Opus 5 a self-contained brief and let it run untouched. Keep scope, dispatch, and relay on your side.

## Hand off only when all of these pass

- Scopeable — you can name the files/entities it touches right now.
- Autonomous — it needs nothing from you between dispatch and done.
- Pinnable — you could write its Done-criteria section right now.

Do it yourself when the task finishes in a few tool calls, needs live back-and-forth, or a gate fails. If only Pinnable fails, close the gaps with the user first, then hand off.

Calibrate: a 3-file fix you could just make → do it yourself; a 12-file refactor with a locked spec → hand off.

## Candidate categories (recognize by pattern — not limited to these)

- Multi-file coding feature or refactor.
- Code-review or bug-finding pass.
- Research or investigation sweep.

## Not a fit for Opus 5

- Bounded, low-stakes, cheaply-checked text-in/text-out (summarize, classify, extract) → consider a cheaper tier or a local model, not Opus 5.
- A simple single-file edit or lookup where Opus 5's edge is marginal → a lower tier.
- Needs live human interaction → keep it with the driver.

## Lock the spec first

Ask every clarifying question now. Gather the objective, exact file paths / entity IDs / commands, hard constraints, and what "done" looks like. Resolve any reading of the request that would change the work.

## Compile the brief

The brief is a complete spec — everything the agent needs to finish without asking. Sections:

```markdown
# Objective
<one sentence: the deliverable a finished run produces>

# Context
<repo/dir, exact file paths, entity IDs, endpoints, constraints, conventions to honor — everything needed to run without asking>

# Task
<the complete spec; number the steps if order matters; name the end state of each part>

# Scope
- In scope: <boundary of what to change or touch>
- Out of scope: <what to leave alone — name it explicitly>
- Stop / check-in: finish exactly what was asked; make routine judgment calls; stop short of actions beyond it; surface only a reading that would materially change the work

# Done criteria
<objective, checkable conditions — e.g. config check passes; all call sites updated; each finding has file:line + a repro>

# Report back
<what to return, outcome first — e.g. a one-line outcome, then a findings table / the diff / which done-criteria passed>

# Behavior
<paste the tuning block below>
```

## Behavior block — paste into every brief

- Skip verification/re-check steps and verifying subagents — you already verify your own work.
- Delegate to a subagent only for large, genuinely independent tracks; keep spawn counts low.
- Lead the report with the outcome; put supporting detail after it.
- Match written-file length to the task; no filler sections, redundant summaries, or boilerplate.
- Correct an earlier statement only when the error changes code, conclusions, or decisions; otherwise fix it and move on.
- If you cannot finish within budget, checkpoint your progress and report partial completion honestly — do not present unfinished work as done.
- Narrate sparingly — one line before you start, then an update only on a material finding or a change of direction; no step-by-step play-by-play.

Review or bug-finding briefs add: report every finding — do not cap severity or self-limit; filtering happens in a separate driver pass.

## Set the run

These settings apply to the precise-control dispatch paths; the Primary subagent path exposes none of them.

| Workload | Effort |
| --- | --- |
| Demanding coding / agentic | `xhigh` |
| Default | `high` |
| Small or cost-sensitive | `medium` or `low` |

- Control response length with an explicit brief instruction, not by lowering effort.
- Keep thinking on (default); lower effort for cost instead of disabling it. Disabling is allowed only at effort `high` or below — disabled + `xhigh`/`max` returns a 400.
- Set `max_tokens` for the run; use ≥64k for `xhigh`/`max`.
- Do not set `temperature`, `top_p`, or `top_k` — non-default values return a 400.
- Model id: `claude-opus-5`. If the API rejects it as unrecognized or deprecated, confirm the current Opus 5 id, then retry or fall back.

## Dispatch

Primary — Claude Code background subagent: dispatch the brief as the prompt at the `deep` tier (model `opus`), run in background (see the `dispatch` skill). No effort/thinking control here — the brief is the lever — and `opus` resolves to the session's configured Opus, not a pinned version. To identify the current session's model, see the `model-detect` skill.

Precise control — use when Opus 5 must be guaranteed or a specific effort is required:

- CLI: `claude -p --model claude-opus-5` with the brief passed from a file (avoids shell-quoting).
- API: model `claude-opus-5`; set `output_config.effort`; leave thinking on (omit the field); size `max_tokens` per the Set-the-run guidance.

## Relay

Re-shape the agent's report; do not pass it through unmodified:

- Outcome — one line: what happened or what was found.
- Detail — the supporting substance.
- Flags — the agent's uncertainties and out-of-scope notes.

## Fallback and failed runs

No Opus 5 background agent reachable → run the brief on the best available model, or do the work yourself. A handoff is an optimization, never a dependency.

Dispatched but failed, timed out, killed, or returned incomplete → inspect the partial, then recover by cause:

- Missing fact → re-brief with the gap closed, retry once.
- Budget or time exhausted → finish it yourself.
- Dispatch itself broken → fall back to the best available model.

Never accept a silent partial as done.

## Related

- `dispatch` — background subagent mechanics and model tiers.
- The inverse handoff — offloading bounded, low-stakes work down to a local model — is worth considering when Opus 5 is overkill.
- `model-detect` — confirm which model the target session actually is.
