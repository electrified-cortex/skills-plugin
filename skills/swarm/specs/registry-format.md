# swarm — Registry Format

Sub-spec of `swarm/spec.md`. Covers: personality registry index file format options, validation rules, body-file naming convention, and loading policy. Does not cover personality body-file content (see `personality-file.md`).

## Index File Location and Format

The personality registry is external to the skill. Metadata for all personalities lives in a single index file at `reviewers/<index-filename>` relative to the skill invocation directory.

The index format is the implementor's choice: markdown, YAML, JSON, plain-text, or other machine-parseable plain-text. The recommended default is `reviewers/index.md` for human readability. The skill must parse the index in whatever format it has; the format is not constrained by this spec.

The index is the only authoritative source of personality metadata. Adding a new personality requires two steps only: (1) add an entry to the index file, and (2) drop the body file at `reviewers/<name>.md`. No edit to `spec.md` or `SKILL.md` is required.

## YAML Index Structure

When the index is authored as YAML (the recommended default), it is a top-level list. Each item is a personality entry.

Required fields per entry:

| Field              | Type                   | Description                                                             |
| ------------------ | ---------------------- | ----------------------------------------------------------------------- |
| `name`             | string                 | Display name. Must be unique across all entries in the index.           |
| `trigger`          | string                 | Trigger condition. Use `"always"` for unconditional inclusion.          |
| `required`         | bool                   | `true` = always dispatched regardless of `custom menu` unless the caller explicitly names a subset that omits it. |
| `suggested_models` | list of model-class    | Preference-ordered list of model-class terms. First available entry is selected at dispatch time. |
| `suggested_backends` | list of backend IDs  | Preference-ordered list of backend identifiers.                         |
| `scope`            | string                 | What this personality reviews and what it explicitly ignores.           |

Optional fields per entry:

| Field    | Type   | Description                                                                  |
| -------- | ------ | ---------------------------------------------------------------------------- |
| `vendor` | string | Model vendor hint (e.g. `anthropic`, `openai`). Used by diversity rule B8.  |

Valid backend identifiers: `dispatch-sonnet`, `dispatch-haiku`, `dispatch-opus`, `copilot-cli`, `local-llm` (reserved — v1 out of scope), `varies` (custom entries only).

## Body-File Naming Convention

The body file for a personality is located at `reviewers/<kebab-name>.md`. The kebab name is derived from the personality name by lowercasing and replacing spaces and apostrophes with hyphens.

Examples:

| Personality name   | Body file path                     |
| ------------------ | ---------------------------------- |
| Devil's Advocate   | `reviewers/devils-advocate.md`     |
| Security Auditor   | `reviewers/security-auditor.md`    |
| Code Quality Critic | `reviewers/code-quality-critic.md` |

## Loading Policy

The runtime loading model is a directory crawl of `reviewers/`. At the start of a swarm invocation, the skill crawls the `reviewers/` directory to discover body files, then reads `reviewers/index.md` (or the chosen index file) as an ordered manifest that provides metadata and ordering for the discovered personalities. The index provides ordering metadata; individual body files are the canonical source of personality content.

This two-step approach (crawl for discovery, index for ordering) means that a new personality is visible to the runtime as soon as its body file is dropped into `reviewers/` and its entry is added to the index. The index is not the sole gating mechanism — both an index entry and a body file are required for a personality to be dispatched.

## Validation Gate

Applied during the index read:

1. Entries with missing required fields or malformed data are silently skipped.
2. For each valid entry, the skill verifies that `reviewers/<name>.md` exists and is non-empty. An entry whose body file is missing or empty is dropped with a warning; the rest of the swarm proceeds. This is not a fatal error.

No human approval is required for the validation gate. It is structural only.

## Index-Authoritative Rule

The index is the authoritative source of personality metadata. Body files may include YAML frontmatter for human readability, but the skill does not read it. Selection and dispatch use only the index entry for metadata.

## Built-In Personalities (Informative)

Built-ins are generic personalities applicable to any artifact regardless of domain. Code-domain personalities are not built-in; see "Caller-Supplied Personalities" below.

The table below describes the personalities typically defined in `reviewers/index.md`. It is informative only — the authoritative list is the index contents at runtime.

| #  | Personality        | Trigger condition                                                                        | Suggested model class | Backend         | Scope limiter                                      |
| -- | ------------------ | ---------------------------------------------------------------------------------------- | --------------------- | --------------- | -------------------------------------------------- |
| 1  | Devil's Advocate   | always                                                                                   | sonnet-class          | dispatch-sonnet | Challenge assumptions; no constructive suggestions |
| 2  | Security Auditor   | problem touches auth, user input, API endpoints, data access, secrets, or network calls | sonnet-class          | dispatch-sonnet | Find vulnerabilities only; no design advice        |
| 3  | Custom Specialist  | generated on-the-fly when no built-in or caller-supplied personality fits the problem    | sonnet-class          | dispatch-sonnet | Role and scope inferred from the problem domain    |

The integer `#` in this table is informative only. The stable runtime index is entry order in `reviewers/index.md` (1-based). Entry reordering changes the numeric index; callers using `custom menu` by name are unaffected.

## On-the-Fly Personality Generation (Custom Specialist)

Custom Specialist is a first-class built-in with special generation behavior. Rather than having a static body file, the swarm generates an inline system prompt for this personality at dispatch time.

Generation steps:

1. Infer the appropriate role from the problem domain (e.g. "chef" for a recipe, "baker" for pastry technique, "civil engineer" for structural plans).
2. Author a brief system-prompt body for that role following the same constraints as registered personalities (read-only, evidence rule, scope limiter).
3. Include it in the dispatch with the same constraints as any dispatched personality.
4. The generated personality is one-shot — not persisted to the registry.

This behavior is default-ON. Callers who want strict registry-only evaluation (no on-the-fly generation) must set `disable_inline_personality_generation: true` in the invocation.

**When triggered:** Custom Specialist is evaluated after built-ins and caller-supplied personalities. It is selected only when the problem analysis suggests a domain-specific reviewer role that no built-in or caller-supplied personality covers.

## Caller-Supplied Personalities

Code-domain personalities are not built-in. They are supplied by the consumer skill via `custom menu`. The `code-review` skill, for example, supplies the following via its `custom menu` set:

- Code Quality Critic — code conventions, readability, duplication; no security or arch
- Test Reviewer — test coverage and quality only
- Architect — structural and interface concerns only
- Operational Readiness — observability, recovery, degraded-mode behavior
- Performance Reviewer — throughput, latency, resource use only
- Copilot Reviewer (gpt-class, copilot-cli backend) — full code review via Copilot; availability-gated

**Pre-implementation gate — Copilot Reviewer:** before adding any CLI-backed personality to `reviewers/index.md` or to `code-review`'s `custom menu`, verify that task 10-0845 (dispatch skill CLI-extension) has reached PASS.

## Custom Personality Menu

Callers may supply additional personalities that extend the registry for a single invocation. Each entry must specify: name, trigger condition, model class (or inherit from caller override), backend, and scope limiter. Custom entries are appended after the last built-in entry in evaluation order. They do not mutate the persistent registry.
