---
name: copilot-cli-review
description: Code review operation via the standalone Copilot CLI binary. Runs adversarial review of a change set and returns structured findings. Triggers - copilot review, review these changes, adversarial review, copilot code review, review this diff.
---

# copilot-cli-review

## Prerequisites

```bash
copilot --version   # must resolve; fail-fast if not
```

If this fails: return `Status: UNAVAILABLE` with stderr output and stop. Do NOT attempt installation.

## Invocation

Canonical form for new invocations:

```bash
copilot -p "<prompt>" -s --allow-all-tools
```

MAY add `--output-format=json` when structured machine-readable output is needed AND the installed version supports the flag. Prefer JSON when available; fall back to markdown parsing otherwise.

MAY add `--model <model>` only when the caller explicitly supplied a model name. Omit otherwise; do not pin a model inside the skill.

Long-form alias equivalence: when reading existing tool wrappers (e.g. `tools/copilot-review.ps1`), treat `--no-ask-user --prompt "<prompt>"` as equivalent to `-p "<prompt>" -s`. New invocations MUST use the canonical short form above.

## Prompt Construction

Embed all diff or file content inline in the prompt string. There is no file-input flag — do NOT use `-P` (uppercase) or any file path flag; they do not exist. Content MUST be serialized into the prompt string by the caller before invocation.

Frame the prompt as an adversarial review request using the canonical severity vocabulary:

```text
Review the following change set for correctness, security vulnerabilities, and code quality.
Return a structured findings list. Each finding must include:
  severity: blocker | major | minor | nit
  file: <path>
  line: <line number or range>
  description: <one sentence>
If there are no issues, respond with exactly: No findings.

<inline diff or file content>
```

Severity vocabulary is fixed to `blocker / major / minor / nit`. The prompt enforces canonical labels directly.

## Output Parsing

Parse Copilot's response (JSON or markdown) into a structured result before returning. Never return raw Copilot output to the caller.

```text
Status: CLEAN | FINDINGS | UNAVAILABLE | ERROR
Findings:
  - severity: blocker | major | minor | nit
    file: <path>
    line: <number or range>
    description: <one sentence>
Raw: <Copilot's full response, JSON or markdown>
```

Status semantics:

| Status | Condition |
| --- | --- |
| `CLEAN` | Copilot responded with exactly "No findings." |
| `FINDINGS` | Copilot returned one or more findings |
| `UNAVAILABLE` | `copilot --version` failed before invocation |
| `ERROR` | Binary returned non-zero exit code OR output is unparseable |

Severity normalization — apply before returning:

| Copilot output | Canonical |
| --- | --- |
| `critical` | `blocker` |
| `nitpick` | `nit` |
| any other | coerce to nearest or flag in description |

## Error Handling

- `copilot --version` fails → return `Status: UNAVAILABLE`; surface stderr; stop.
- Model unavailable → return `Status: ERROR`; surface error; stop. Do not retry with a different model.
- Copilot exits non-zero → return `Status: ERROR`; surface stderr; stop.
- Output unparseable → return `Status: ERROR`; include raw in `Raw:` field; stop.

## Rules

- Constrain working directory to the target repo — never run in an unconstrained path.
- Return the structured result, not raw markdown or JSON.
- One review per invocation; do not fan out across multiple directories.
