# swarm — Glossary

Terms used in the swarm skill. See `spec.md` for normative rules.

- **Review packet**: self-contained brief assembled from the artifact. Fields: Goal, Approach, Key decisions, Artifacts (actual content), Files affected, Blast radius, Conventions. Omit fields not applicable.
- **Availability gate**: probe confirming a personality's required backend is reachable before dispatch. Only required for non-`dispatch-*` backends.
- **Disagree set**: subset of swarm findings where two or more personalities reached contradictory conclusions on the same point.
- **Confidence rating**: High / Medium / Low. Reflects reviewer agreement, evidence quality, scope coverage. Full logic: `specs/arbitrator.md`.
- **Model class**: abstract tier — `haiku-class` (shallow/mechanical), `sonnet-class` (moderate reasoning, default), `opus-class` (heavy architectural reasoning), `gpt-class` (non-Anthropic frontier). No bare model names anywhere.
- **Arbitrator**: single sonnet-class sub-agent dispatched after all members complete. Returns structured action list only. Not a reviewer. Not in the registry. See `specs/arbitrator.md`.
- **Dispatch skill**: `electrified-cortex/dispatch` — authoritative agent-launching mechanism. All sub-agent launches delegated here. See `specs/dispatch-integration.md`.
- **Personality**: named reviewer role. Metadata lives in the registry index; system-prompt body lives in `reviewers/<name>.md`. Loaded lazily — body not present at selection time.
- **Personality registry**: index at `reviewers/index.md` (or format of implementor's choice). External to skill. Authoritative. See `specs/registry-format.md`.
- **Custom menu**: caller-supplied additional personalities for the current invocation only. Appended to the index; does not mutate the persistent registry.
- **Swarm**: surviving personalities after selection and availability gating.
