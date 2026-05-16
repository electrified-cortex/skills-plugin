---
name: explain
description: Explain operation via the standalone Copilot CLI binary. Returns an explanatory markdown description of a code region or file. Triggers - explain this code, copilot explain, what does this do, explain this file, describe this function.
---

# Copilot CLI — Explain

## Inputs

| Parameter | Required | Notes |
| --- | --- | --- |
| `content` | yes | Code to explain, serialized inline (no file-path flags exist) |
| `working_dir` | yes | Repo root of the source file; never `/` or `~` |
| `model` | no | Copilot model name; pass as `--model <model>` only when supplied |

## Procedure

1. Run `copilot --version` in `working_dir`. If it fails: return `Status: UNAVAILABLE`, surface stderr, stop. Do NOT install.
2. Build prompt by embedding `content` inline:

   ```text
   Explain the following code. Describe what it does, why it works that way, and any
   non-obvious behavior. Be concise.

   <content>
   ```

3. Run: `copilot -p "<prompt>" -s --allow-all-tools` in `working_dir` (append `--model <model>` only when caller supplied one).
4. Classify exit code and return output shape below.

## Return

```text
Status: OK | ERROR | UNAVAILABLE
Explanation: <Copilot's markdown explanation verbatim>
```

`OK` = exit zero. `ERROR` = non-zero (Explanation = stderr). `UNAVAILABLE` = version check failed.
Do not summarize or reinterpret. One code region per invocation.

Related: `copilot-cli` (router), `review`, `ask`
