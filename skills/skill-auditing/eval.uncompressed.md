# Eval Log Check

Performed after all verdict-bearing Phase 3 checks complete. Informational only — does not affect verdict.

## Procedure

Check for `eval.md` co-located with the skill (sibling of `SKILL.md`).

- **Present** — record "eval.md present" as a positive signal. If the last entry date is readable, note it: "eval.md present, last entry YYYY-MM-DD." Do not critique the content — presence is what matters.
- **Absent** — include the following suggestion verbatim:

  "No eval.md found. Suggest adding one and recording one of:
  (a) evaluations performed and their results,
  (b) 'no evaluation planned — this skill is too small / not a candidate',
  (c) 'evaluation planned — pending capacity',
  (d) 'nothing evaluated yet' — honest acknowledgment that work is open.
  Honest-state principle: presence of eval.md (even if it says 'nothing yet') is a stronger signal
  than absence. Absence reads as oversight; explicit 'no evaluation planned' is a deliberate decision."

## Honest-State Principle

Presence (even if it says "nothing yet") is stronger than absence. Absence reads as oversight; an explicit "no evaluation planned" is a deliberate decision. Eval.md with any honest state beats no file at all.

## Verdict-Gate Rule

Absence of `eval.md` MUST NOT affect the PASS / NEEDS_REVISION / FAIL verdict. This check is informational and runs after all verdict-bearing checks have been evaluated. Never escalate an absent eval.md to a finding that changes the verdict.
