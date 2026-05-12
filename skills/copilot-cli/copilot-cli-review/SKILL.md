---
name: copilot-cli-review
description: Code review operation via the standalone Copilot CLI binary. Runs adversarial review of a change set and returns structured findings. Triggers - copilot review, review these changes, adversarial review, copilot code review, review this diff.
---

# Copilot CLI — Review

## Inputs

| Parameter | Required | Notes |
| --- | --- | --- |
| `diff` | yes (or `file_content`) | Diff or inline file content to review |
| `file_content` | yes (or `diff`) | Inline file content when no diff is available |
| `working_dir` | yes | Target repo root; never `/`, `~`, or a secrets directory |
| `model` | no | Copilot model name; pass as `--model <model>` only when supplied |

## Procedure

1. Run `copilot --version` in `working_dir`. If it fails: return `Status: UNAVAILABLE`, surface stderr, stop. Do NOT install.
2. Build prompt by embedding `diff` or `file_content` inline:

   ```text
   Review the following change set for correctness, security vulnerabilities, and code quality.
   Return a structured findings list. Each finding must include:
     severity: blocker | major | minor | nit
     file: <path>
     line: <line number or range>
     description: <one sentence>
   If there are no issues, respond with exactly: No findings.

   <diff or file_content>
   ```

3. Run: `copilot -p "<prompt>" -s --allow-all-tools` in `working_dir` (append `--model <model>` only when caller supplied one).
4. Parse Copilot's stdout:
   - If stdout is exactly `No findings.` → `Status: CLEAN`, `Findings:` empty.
   - If stdout contains findings → `Status: FINDINGS`; normalize severity (`critical` → `blocker`, `nitpick` → `nit`; others coerce to nearest or note in description).
   - If exit non-zero → `Status: ERROR`; surface stderr.
   - If output unparseable → `Status: ERROR`; include raw.
5. Return output shape below.

## Return

```text
Status: CLEAN | FINDINGS | UNAVAILABLE | ERROR
Findings:
  - severity: blocker | major | minor | nit
    file: <path>
    line: <number or range>
    description: <one sentence>
Raw: <Copilot's full response>
```

One repo per invocation. Do not advise on severity thresholds — that is the caller's policy.

Related: `copilot-cli` (router), `copilot-cli-ask`, `copilot-cli-explain`
