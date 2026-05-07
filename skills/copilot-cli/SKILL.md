---
name: copilot-cli
description: Router — accepts any GitHub Copilot CLI task and dispatches to the correct operation sub-skill. Does not execute copilot commands itself. Triggers - ask copilot, copilot ask, explain with copilot, copilot explain, copilot review, copilot code review.
---

Execution, flag assembly, prompt framing, and output parsing live inside the dispatched sub-skill — not here.

## Operation Routing Table

| Operation | Sub-skill | Use for |
| --- | --- | --- |
| review | copilot-cli-review/ | Code review of a change set; structured findings + raw markdown |
| ask | copilot-cli-ask/ | General query or advice; plain text answer |
| explain | copilot-cli-explain/ | Explain a code region or file; explanatory markdown |

## How to Route

1. Parse the task → identify operation from the table above.
2. Operation unclear → ask the caller; in non-interactive flows return `Status: NEEDS_CLARIFICATION`.
3. Load + dispatch the identified sub-skill; pass the full task and all caller-supplied context.
4. Task spans multiple operations → run the primary operation; report remaining operations to the caller without dispatching them.
5. Return the sub-skill's structured result unchanged to the caller.

## Result Envelope

```text
Status: CLEAN | FINDINGS | OK | ERROR | UNAVAILABLE | NEEDS_CLARIFICATION
<sub-skill result fields>
Source: <sub-skill name>
```

`UNAVAILABLE` and `NEEDS_CLARIFICATION` originate from the router. All other statuses pass through from sub-skills unchanged.

## Cache Integration

Before dispatching any sub-skill, check the capability cache (see `capability-cache/SKILL.md`):

- Cache HIT with `result: unavailable` → skip all CLI invocations; return `Status: UNAVAILABLE` to the caller immediately.
- Cache HIT with `result: available` → use cached model list without re-probing.
- Cache MISS → proceed to dispatch; the probe happens inside the sub-skill; cache is populated by the sub-skill on first run.

## Rules

- Do NOT execute any `copilot` command. All execution is inside sub-skills.
- Do NOT inject flags, model names, prompts, or defaults. Sub-skills own those choices.
- Do NOT log or inspect Copilot's raw output. Only the sub-skill's structured result is returned.
- Do NOT attempt installation or auth recovery if `copilot` is unavailable — surface the sub-skill's error and stop.
- Sub-skill missing → report that and stop; do not improvise.

Related: `copilot-cli-review`, `copilot-cli-ask`, `copilot-cli-explain`, `capability-cache`
