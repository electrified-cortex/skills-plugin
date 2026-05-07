# swarm — Personality File

Sub-spec of `swarm/spec.md`. Covers: personality body-file structure, frontmatter handling, system-prompt extraction, and loading timing. Does not cover index metadata schema (see `registry-format.md`).

## Body-File Rule

A personality body file at `reviewers/<kebab-name>.md` contains exactly the system prompt for that reviewer — nothing else. No swarm scaffolding. No cross-cutting concerns. No exposition about the swarm system. The body file's content IS what gets inserted verbatim into the sub-agent dispatch for that personality.

This is a normative constraint. An implementor must not pad body files with framing text, headers, or swarm-level instructions.

## Optional Frontmatter

Body files may include a YAML frontmatter block for human readability. If present, the frontmatter block is excluded from the system prompt inserted into the dispatch. Only the content after the closing `---` separator is used.

The skill never reads body-file frontmatter for operational data. All metadata (trigger condition, model class, backend, scope, vendor diversity signal) lives in the registry index, not in the body file.

Example body file with optional frontmatter:

```yaml
---
# This frontmatter is for human reference only — the skill does not read it.
name: Security Auditor
---
You are a security auditor. Your job is to identify vulnerabilities in the artifact under review...
```

In the example above, the system prompt inserted into the dispatch begins at "You are a security auditor."

## Loading Timing

Body files are loaded only after the swarm is finalized (post availability gate). An implementation that reads body files during selection violates this rule regardless of whether body content is used.

Loading sequence:

1. Registry index is read once (Step 2) — no body files touched.
2. Availability gate runs (Step 3) — no body files touched.
3. Body files are loaded for surviving personalities only (Step 4).
4. Dispatches are issued (Step 5).

## System-Prompt Content Rules

A personality body file contains only the reviewer's voice, perspective, and task framing. It must not include:

- Swarm scaffolding (references to the swarm system, the arbitrator, or other personalities).
- Cross-cutting constraints (read-only instructions are injected by the dispatch layer, not the body file).
- Step-sequence instructions (dispatch orchestration is the skill's job, not the personality's).
- Evidence citation requirements (also injected by the dispatch layer).

If a body file contains any of the above, the dispatch layer may produce incoherent or conflicting instructions. The body is treated verbatim; nothing is stripped from it except the frontmatter block.

## On-the-Fly Personalities (Custom Specialist)

Custom Specialist is a built-in personality with no static body file. Its system prompt is generated inline at dispatch time based on the inferred domain role. Because there is no body file, the validation gate in `registry-format.md` (which checks for a non-empty `reviewers/<name>.md`) must treat Custom Specialist as exempt from the body-file existence check.

Generated system prompts follow the same content rules as registered body files: reviewer voice and task framing only, no swarm scaffolding, no cross-cutting constraints (those are injected by the dispatch layer). The generated prompt is ephemeral — it is not written to disk and is not persisted to the registry.

Registry entries always have body files. On-the-fly generation is exclusive to Custom Specialist.

## Naming Convention

The body file name is the personality name lowercased, with spaces and apostrophes replaced by hyphens, with a `.md` extension.

Examples:

| Personality name  | Body file                 | Notes                            |
| ----------------- | ------------------------- | -------------------------------- |
| Devil's Advocate  | `devils-advocate.md`      |                                  |
| Security Auditor  | `security-auditor.md`     |                                  |
| Custom Specialist | (none — generated inline) | Exempt from body-file existence check |
