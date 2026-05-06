---
name: copilot-cli-ask
description: General query or advice operation via the standalone Copilot CLI binary. Returns Copilot's plain text answer. Triggers - ask copilot, copilot question, get advice from copilot, query copilot, copilot answer.
---

## Prerequisites

```bash
copilot --version   # must resolve; fail-fast if not
```

If this fails: return `Status: UNAVAILABLE`; surface stderr; stop. Do NOT attempt installation.

## Invocation

```bash
copilot -p "<prompt>" -s --allow-all-tools
```

MAY add `--model <model>` only when the caller explicitly supplied a model name. Omit otherwise; do not pin a model inside the skill.

## Prompt Construction

Pass the caller's question directly. Prepend context if supplied:

```text
<context if any>

<caller's question>
```

Do not add framing or instructions.

## Output Parsing

Return Copilot's response as a structured result:

```text
Status: OK | ERROR | UNAVAILABLE
Answer: <Copilot's plain text response>
```

| Status | Condition |
| --- | --- |
| `OK` | Copilot returned a response |
| `ERROR` | Binary returned non-zero exit code |
| `UNAVAILABLE` | `copilot --version` failed before invocation |

## Error Handling

| Condition | Action |
| --- | --- |
| `copilot --version` fails | Output `Status: UNAVAILABLE`, set `Answer:` to the stderr, stop. |
| Caller-supplied model is unsupported (Copilot rejects) | Output `Status: ERROR`, set `Answer:` to "model not available: `<model>`", stop. |
| `copilot -p ...` exits non-zero | Output `Status: ERROR`, set `Answer:` to the stderr, stop. |
| `copilot -p ...` exits zero with empty stdout | Output `Status: OK`, set `Answer:` to empty string. |

## Rules

- Do not interpret or filter Copilot's answer — return it verbatim in the `Answer` field.
- One question per invocation.
- Constrain the working directory to the relevant repo or a neutral directory — never run in `/`, `~`, or any directory containing secrets.

Related: `copilot-cli` (router), `copilot-cli-review`, `copilot-cli-explain`
