# Arbitrator Output Format — swarm v1

The arbitrator is a single sonnet-class sub-agent dispatched after all swarm members complete. It receives all raw member outputs and the original review packet. Its sole job is to produce a structured two-section action list — not narrative synthesis.

## Required Output Structure

```md
## Obvious actions

<For each item: action description + source personality names + evidence cite.>
<"None" if no obvious actions.>

## Critical actions

<For each item: action description + source personality names + evidence cite + severity rationale.>
<"None" if no critical actions.>
```

## Section Definitions

**Obvious actions**: items where 2 or more swarm members independently flagged the same concern, OR the concern is self-evident from the artifact without inference. Each entry must name the source personalities and cite the evidence they provided.

**Critical actions**: items that, if unaddressed, would block shipping or require architectural change — regardless of reviewer agreement count. Covers both HIGH and CRITICAL severity labels equally. Each entry must include:
- Action description
- Source personality names
- Evidence cite (snippet, line reference, or direct quote)
- Severity rationale (why this blocks shipping or requires architectural change)

## Constraints

- Do NOT include speculative, low-confidence, or duplicate items.
- Before citing a member finding as incorrect, MUST quote the exact sentence from that finding believed to be wrong. Challenging an interpretation rather than an explicit claim is not permitted.
- If no actionable findings exist, state "No actionable findings" explicitly in both sections.
- Output feeds Step 7 of swarm skill — host synthesizes from this list only, not raw member output.
- Arbitrator MUST NOT appear in the personality registry, MUST NOT be subject to personality selection, availability gating, or `personality_filter`.

## Version note

This spec governs `swarm v1`. Any amendment to the output structure requires updating both this file and the inline summary in `swarm/SKILL.md` in the same commit.
