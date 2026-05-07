# swarm — Arbitrator

Sub-spec of `swarm/spec.md`. Covers: arbitrator role, dispatch conditions, required output structure, exclusion from registry, and confidence rating logic.

## Role

The arbitrator is a single sub-agent dispatched after all swarm member outputs are collected. Its sole job is to consolidate the raw member outputs into a structured action list. It is not a reviewer. It does not form opinions about the artifact. It distills, deduplicates, and classifies findings.

The arbitrator is structurally separate from the personality registry. It must not appear in the registry, must not be subject to personality selection, availability gating, or `personality_filter`. It is always dispatched as part of the standard step sequence; it cannot be disabled.

## Dispatch

The arbitrator runs at sonnet-class by default. It receives:

- All non-empty, non-timeout member outputs from the swarm.
- The original review packet.

Member outputs that are empty or that timed out are excluded from the arbitrator's input set (B4 in primary spec). If all member outputs are empty, the arbitrator is still dispatched with the review packet; it must return an empty list.

## Output Structure

The arbitrator returns a structured action list only — not a narrative synthesis. Two sections:

**Obvious actions** — items where two or more swarm members independently flagged the same concern, or where the concern is self-evident from the artifact.

Each entry includes:

- Action description
- Source personality indices (from the runtime index in `reviewers/index.md`)
- Evidence cite (snippet, line reference, scenario, or direct quote)

**Critical actions** — items that, if unaddressed, would block shipping or require an architectural change, regardless of reviewer agreement count.

Each entry includes:

- Action description
- Source personality indices
- Evidence cite
- Severity rationale (why this would block shipping or require architectural change)

The arbitrator must not include speculative, low-confidence, or duplicate items. If no actionable findings exist, it must state "No actionable findings" explicitly.

## Host Synthesis Rule

The host synthesizes from the arbitrator's structured action list only. Raw member output must not be passed to the synthesis step. The host never reads or parses raw member output directly.

This rule exists to prevent the host from becoming a second-pass synthesizer of unstructured output. The arbitrator is the consolidation step; the host is the presentation step.

## Confidence Rating Logic

The confidence rating reflects reviewer agreement, evidence quality, and scope coverage.

| Condition | Rating |
| --- | --- |
| All personalities agree AND all findings cite specific evidence | High |
| Default (no special condition met) | Medium |
| Disagree set is non-empty on a high-severity point, or any personality returned no findings | Low |

A high-severity point is a finding that would block shipping or require an architectural change to address.

If the rating is Low, the synthesis output must state specifically what would raise it (e.g., "would raise to Medium if X agreed with Y on Z").

## Empty List Handling

If the arbitrator produces an empty action list, it must state "No actionable findings" explicitly. The host must still proceed to synthesis and note the clean result; it does not short-circuit or return an error.

## Disagreement Tracking

The arbitrator flags items where swarm members reached contradictory conclusions on the same point (source indices from different members with contradictory claims). These form the disagree set. The host presents the disagree set explicitly in the Disagreements section of the synthesis output, states the tension, and applies judgment.
