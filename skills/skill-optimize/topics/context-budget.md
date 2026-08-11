# Context Budget — Assessment Procedure

## What to assess

Is skill-optimize responsible with its total context load — instructions, inputs,
intermediate state, and what it passes to sub-agents?

## Evidence to check

1. Read `uncompressed.md` — Step 3a (qualifier dispatch), Step 4 (analyzer dispatch).
2. Note what each dispatch passes as context.
3. Estimate token load for each dispatch path.
4. Check whether any full history or stale context is passed.

## Assessment criteria

**Qualifier dispatch (Step 3a):**

- What is passed? One-line descriptions of topic slugs and their assessment question.
- Assessment: lean; minimal context; no source files.

**Analyzer dispatch (Step 4):**

- What is passed? All skill source files (spec.md + uncompressed.md + SKILL.md +
  instructions.txt if present).
- Assessment: deliberate and justified — VERIFICATION STRATEGY topic confirmed that
  passing primary sources is required for accurate analysis. Analyst cannot assess
  without the actual skill content.

**Full history passed?**

- No. Sub-agents receive only the specific artifact package for their task.

**Stale context risk?**

- Step 1 reads source files before any analysis. If the skill's source files are
  modified mid-session (by "acted" findings), subsequent analysis dispatches would
  use stale copies. However, the iteration model (one topic per invocation) means
  the host re-invokes for each topic, which re-reads source files at Step 1.
  Stale context within a single invocation is not a risk.

## Scoring

- **MEDIUM**: Sub-agent receives full conversation history or decorative context;
  budget management is poor.
- **LOW**: Budget is acceptable but there is a specific prunable element.
- **CLEAN**: Context is correctly scoped — minimal for qualifier, sufficient for
  analyzer, no history leakage.
