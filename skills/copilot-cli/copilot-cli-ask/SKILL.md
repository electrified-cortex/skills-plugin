---
name: copilot-cli-ask
description: General query or advice operation via the standalone Copilot CLI binary. Returns Copilot's plain text answer. Triggers - ask copilot, copilot question, get advice from copilot, query copilot, copilot answer.
---

# Copilot CLI — Ask

## Inputs

| Parameter | Required | Notes |
| --- | --- | --- |
| `question` | yes | Question or advisory prompt to send verbatim |
| `context` | no | Factual background to prepend; not a Q&A exchange |
| `model` | no | Copilot model name; pass as `--model <model>` only when supplied |
| `working_dir` | no | Neutral directory for invocation; never `/` or `~` |

## Procedure

1. Run `copilot --version` in `working_dir`. If it fails: return `Status: UNAVAILABLE`, surface stderr, stop. Do NOT install.
2. Build prompt: prepend `context` if supplied, then `question`. No added framing.
3. Run: `copilot -p "<prompt>" -s --allow-all-tools` (append `--model <model>` only when caller supplied one).
4. Classify exit code and return output shape below.

## Return

```text
Status: OK | ERROR | UNAVAILABLE
Answer: <Copilot's plain text response verbatim>
```

`OK` = exit zero. `ERROR` = non-zero (Answer = stderr). `UNAVAILABLE` = version check failed.
Do not interpret, filter, or rewrite the answer. One question per invocation.

Related: `copilot-cli` (router), `copilot-cli-review`, `copilot-cli-explain`
