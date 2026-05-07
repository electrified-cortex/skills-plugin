# swarm — Dispatch Integration

Sub-spec of `swarm/spec.md`. Covers: how the swarm skill uses the `dispatch` skill, model-class routing, parallelism requirements, and the CLI dispatch deferral. Does not cover the dispatch skill's own decision tree (see the `dispatch` skill: `dispatch/SKILL.md`).

## Normative Reference

All sub-agent launches by the swarm skill are delegated to the `dispatch` skill. The swarm must not reinvent the launch primitive. Operators adding CLI dispatch or new backend types must extend the dispatch skill (see task 10-0845) before referencing those patterns here.

The dispatch skill's Well-Formed Prompt checklist applies to every personality dispatch the swarm constructs. Each dispatch must satisfy:

- Goal stated in one sentence with no implicit context
- All hand-fed context included (review packet, personality prompt, read-only constraint, evidence citation rule)
- Output shape described (finding list with evidence cites)
- Scope and length constraints stated

## Parallelism

All personality dispatches in a single swarm invocation must be issued as a single parallel batch. Sequential dispatch is prohibited when parallel dispatch is available.

If the dispatched swarm's runtime does not support parallel sub-agent dispatch (e.g., CLI invocation with no Agent tool), sequential runs are acceptable. The step sequence is identical in both modes; only the execution model differs. No configuration changes are required to switch modes.

## Model-Class Routing

Model selection at dispatch time:

1. If a caller `model_overrides` entry exists for the personality, use it.
2. Otherwise, use the first available entry from the personality's `suggested_models` list (from the registry index).
3. If no `suggested_models` entry is available and no override applies, fall back to `sonnet-class`.

`model_overrides` affect model class only. They must not be used to change the backend type for a personality.

## Dispatch Tier Mapping

The swarm maps registry backend identifiers to dispatch tiers as follows:

| Registry backend   | Dispatch tier  |
| ------------------ | -------------- |
| `dispatch-sonnet`  | standard       |
| `dispatch-haiku`   | fast-cheap     |
| `dispatch-opus`    | deep           |
| `copilot-cli`      | CLI (deferred) |
| `local-llm`        | reserved (v1 out of scope) |

## Availability Gating for Non-Dispatch Backends

For personalities whose backend is `dispatch-sonnet`, `dispatch-haiku`, or `dispatch-opus`, no availability probe is required. The dispatch skill handles errors internally.

For personalities whose backend is `copilot-cli` or any other external backend, the swarm must run an availability probe before including the personality in the swarm. A failing probe drops the personality (not a fatal error); the drop is noted in synthesis output.

The availability probe for `copilot-cli` is a lightweight shell command (e.g., `copilot --version`). The exact probe command for each external backend must be specified when that backend type is added to the registry.

## CLI Dispatch Deferral

`claude -p` and copilot CLI as parallel dispatch backends are explicitly deferred to task 10-0845 (dispatch skill CLI-extension). Until task 10-0845 reaches PASS:

- No personality in `reviewers/index.md` may use `copilot-cli` as its backend in the live registry.
- The Copilot Reviewer entry (registry entry 8 in the informative table) must not be added to the live index.
- Once 10-0845 defines the CLI dispatch contract, this sub-spec must be amended to reference it and the scope exclusion in the primary spec (C6) must be removed.

## Diversity Rule at Dispatch Time

After model selection for all personalities, apply the diversity preference rule (B8 in primary spec): if all personalities resolve to the same model family as the host, prefer to route at least one personality to a different vendor or model class. The mechanism is the `vendor` field in the registry index entry and the `suggested_models` preference order.

Devil's Advocate is the natural carrier for vendor diversity because it is always required and its index entry should express a preference for a non-Anthropic reasoning model (`vendor: openai`, `copilot-cli` as suggested backend, `gpt-class` as suggested model class). If the copilot-cli backend is unavailable, fall back to the next backend in `suggested_backends`.

Diversity is best-effort. If no diverse option is available after gating, the swarm proceeds without it and notes the monoculture condition in synthesis output.

## Selection Is Inline

Personality selection (Step 2 of the swarm execution) is performed inline within the skill. A separate dispatch for personality selection is not used. Rationale: the token cost of a selection dispatch exceeds the cost of inline evaluation for registries of the current scale (under 12 entries). This decision should be revisited if the registry grows beyond approximately 20 entries.
