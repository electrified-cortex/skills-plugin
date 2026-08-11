# Activation Discipline — Assessment Procedure

## What to assess

Does skill-optimize define the conditions under which it should be invoked, and
the conditions under which it should not?

## Evidence to check

1. Read `uncompressed.md` — Inputs section and any preamble describing when to use
   the skill.
2. Read `spec.md` — Description or Triggers section if present.
3. Read `SKILL.md` if it exists — does the description hint at activation criteria?

## Assessment criteria

**Positive triggers documented?**

- Is there a statement of what input pattern, request type, or context state
  justifies invoking the skill?
- Example of sufficient: "Invoke when a SKILL.md file is identified as a candidate
  for improvement."
- Example of insufficient: "Invoke when optimizing a skill." (too broad)

**Negative triggers documented?**

- Is there any statement of when NOT to invoke?
- E.g.: do not invoke on skills under active revision, do not re-invoke on
  already-clean topics in the same session.

**Confidence threshold documented?**

- Does the skill define a minimum input quality below which it should decline?

**Activation mode declared?**

- Is the skill default (always available), opt-in, last-resort, or guard?
- If undeclared, it is treated as default by callers — is that correct?

## Scoring

- **MEDIUM**: Activation mode is wrong for the skill's risk profile, or negative
  triggers are needed but absent and would prevent real over-triggering failures.
- **LOW**: No positive/negative triggers or confidence threshold documented; skill
  is implicitly always-available without stating this as a design decision.
- **CLEAN**: Activation criteria documented or the skill is simple enough that
  absence of documentation is not a risk.
