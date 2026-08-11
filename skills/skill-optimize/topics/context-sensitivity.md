# Context Sensitivity — Assessment Procedure

## What to assess

Does skill-optimize work correctly across different callers, environments,
working directories, and input variations?

## Evidence to check

1. Read `uncompressed.md` — check for hardcoded paths, model names, task IDs,
   or platform-specific commands.
2. Check how file paths are constructed — relative to `<skill-path>` or absolute?
3. Check for platform-specific assumptions (Windows path separators, etc.).
4. Check for caller context assumptions — does the skill assume a particular
   agent state or session context?

## Assessment criteria

**Hardcoded constants:**

- Are there any hardcoded paths, model names, or constants that would break
  in a different deployment?

**Working directory sensitivity:**

- Does the skill assume a specific CWD, or does it resolve all paths from
  `<skill-path>`?

**Platform sensitivity:**

- Any Windows-specific path handling? Forward/backward slash assumptions?

**Caller context assumptions:**

- Does the skill require the caller to have loaded specific context beforehand?
- Does behavior degrade silently in low-context calling conditions?

**Input variation:**

- Does the skill handle the optional `<topic>` and `<mode>` inputs gracefully?
- What happens with an invalid topic slug?

## Scoring

- **MEDIUM**: Hardcoded constants or platform assumptions make the skill non-portable.
- **LOW**: Skill works but has undocumented caller context assumptions or fragile
  edge-case handling on optional inputs.
- **CLEAN**: Fully parameterized, no hardcoded constants, paths are relative to
  caller-supplied `<skill-path>`.
